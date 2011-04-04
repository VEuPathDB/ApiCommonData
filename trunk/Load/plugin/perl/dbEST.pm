package ApiCommonData::Load::Plugin::dbEST;
#package GUS::Common::Plugin::dbEST;


@ISA = qw( GUS::PluginMgr::Plugin );

use strict;
#my $DBEST_EXTDB_ID = 22; # global variable

$| = 1;

############################################################
# Add any specific objects you need (GUS30::<nams-space>::<table-name>
############################################################

use GUS::Model::DoTS::EST;
use GUS::Model::DoTS::Clone;
use GUS::Model::DoTS::Library;
use GUS::Model::DoTS::ExternalNASequence;
use GUS::Model::DoTS::SequenceType;
use GUS::Model::SRes::Taxon;
use GUS::Model::SRes::TaxonName;
use GUS::Model::SRes::Anatomy;
use GUS::Model::SRes::Contact;
use GUS::Model::SRes::ExternalDatabase;
use GUS::Model::SRes::ExternalDatabaseRelease;

use FileHandle;

#####################################################################
# The new method should create and bless a new instance and call the
# following methods to initialize the necessary attributes of a
# plugin.
#####################################################################

sub new {
	my $Class = shift;

	my $M = bless {}, $Class;
  
  my $easycsp = [{ h => 'number of iterations for testing',
                   t => 'int',
                   o => 'test_number',
                   r => 0,
                 },
                 { h => 'The span of entries to retrieve in batches',
                   t => 'int',
                   o => 'span',
                   d => 100,
                   r => 0,
                 },
                 { h => 'A log file (path relative to current/working directory)',
                   t => 'string',
                   r => 0,
                   d => 'DataLoad_dbEST.log',
                   o => 'log',
                 },
                 { h => 'An update file containing the EST entries that changed,
                         useful for incremental update ie. chron jobs',
                   t => 'string',
                   o => 'update_file',
                   r => 0,
                 },
                 { h => 'Signifies that sequences in ExternalNASequence should NOT be updated, 
                         regardless of discrepencies in dbEST-Used when reassembly is not going to occur.',
                   t => 'boolean',
                   o => 'no_sequence_update',
                   r => 0,
                 },
                 {
                   h=> 'Restart number. If input is a file, then the line number is given. 
                        If from the DB then the id_est is given.',
                   t=> 'int',
                   o => 'restart_number',
                   r => 0,
                 },
		 { h => 'Comma delimited list of scientific names to load',
		   t => 'string',
		   o => 'taxon_name_list',
		   r => 0,
		 },
                 { h => 'Comma delimited list of taxon_ids to load',
		   t => 'string',
		   o => 'taxon_id_list',
		   r => 0,
		 },
		 { h => 'flag indicating that atts should be checked for discrepensies',
		   t => 'boolean',
		   o => 'fullupdate'
		 },
                 {h => 'the name of a dblink, if the dbEST mirror is a linked db',
                  t => 'string',
                  o => 'dblink',
                  r => 0,
                 },
                 {h => 'dots.externaldatabase.name',
                  t => 'string',
                  o => 'extDbName'
                 },
                 {h => 'dots.externaldatabaserelease.version',
                  t => 'string',
                  o => 'extDbRlsVer'
                 }
                 ];
  
  ## Initialize the plugin
  
  $M->initialize({requiredDbVersion => 3.5,
                  cvsRevision => ' $Revision$ ', # cvs fills this in
                  cvsTag => ' $Name$ ', # cvs fills this in!
                  name => ref($M),
                  revisionNotes => 'GUS 3.5 compliant',
                  easyCspOptions => $easycsp,
                  usage => 'Loads dbEST information into GUS',
                });
  
  $M;
}

# ----------------------------------------------------------------------

sub run {
  my $M   = shift;

  $M->logRAIID;
  $M->logCommit;
  $M->logArgs;

  ## Set the log file
  $M->getCla()->{log_fh}  = FileHandle->new(">" . $M->getCla->{log})
    or die ("Log file " . $M->getCla->{log} . "not open\n");
  $M->getCla()->{log_fh}->autoflush(1);
  
  ## Make a few cache tables for common info
  $M->{libs} = {};          # dbEST library cache
  $M->{anat} = {};          # Anatomy (tissue/organ) cache
  $M->{taxon} = {};         # Taxonomy (est.organism) cache
  $M->{contact} = {};       # Contact info cache
  $M->setTableCaches();
  
  $M->{dbest_ext_db_rel_id} = $M->getExternalDatabaseRelease();
  
  my $nameStrings = $M->getNameStrings();

  $M->{dblink} = $M->getArg('dblink');
  
  #####################################################################
  ## If an update file is given, use this as the basis 
  ## for an update. Otherwise query GUS for what needs to 
  ## be updated.
  #####################################################################

  my $count = 0;

	############################################################
	# Put loop here...remember to $M->undefPointerCache()!
	############################################################
  
  if ($M->getCla->{update_file}) {
    my $fh = FileHandle->new( "<" . $M->getCla->{update_file})  or 
      die "Could not open update file ". $M->getCla->{update_file} . "\n";
    
    while (!$fh->eof()) {
      ## Testing condition 
      last if ($M->getCla->{test_number} && $count > $M->getCla->{test_number});

      ## Skip entries until we get to the restart point, if defined
      next if ($M->getCla()->{restart_number} && $M->getCla()->{restart_number} > $fh->input_line_number);
      ## Main loop
      # A setof dbEST EST entries
      my ($e);
      for (my $i = 0; $i < $M->getCla->{span}; $i++) {
	last if $fh->eof();
        my $l = $fh->getline();
        my ($eid) = split /\t/, $l;
	next unless ($eid);
        my $ests = $M->sql_get_as_hash_refs_lc("select * from dbest.est$M->{dblink} where id_est = $eid");
        foreach my $est ( @{$ests}) {
          $e->{$est->{id_est}}->{e} = $est;
        }
      }
      $count += $M->processEntries($e);
      $M->undefPointerCache();
    }
  }else {
        # get the absolute max id_est
    my $dbh = $M->getQueryHandle();
    my $st = $dbh->prepareAndExecute("select max(id_est) from dbest.est$M->{dblink}");
    my ($abs_max) = $st->fetchrow_array();
    # get the min and max ids
    
    my $min = 0;
    # Set the restart entry id if defined
    $min = $M->getCla()->{restart_number} ? $M->getCla()->{restart_number} : $min ;
    
    my $max = $min + $M->getCla->{span};
    while ($max <= $abs_max) {
      ## Testing condition 
      last if ($M->getCla->{test_number} && $count > $M->getCla->{test_number});
      
      ## Main loop

      my $ests;
      
      $ests = $M->sql_get_as_hash_refs_lc("select est.* from dbest.est$M->{dblink} est, dbest.library$M->{dblink} library where est.id_est >= $min and est.id_est < $max and library.id_lib = est.id_lib and library.organism in ($nameStrings)");

     $M->logAlert("Processing id_est from $min to $max\n"); 
      my ($e);
      foreach my $est ( @{$ests}) {
        $e->{$est->{id_est}}->{e} = $est;
      }
      $count += $M->processEntries($e);
      $M->undefPointerCache();
      $min = $max;
      $max += $M->getCla()->{span};
    }
  }
  ############################################################
  # return status
  # replace word "done" with meaningful return value/summary of the
  # work that was done.
  ############################################################
  my $dbh = $M->getQueryHandle();
  my $st1 = $dbh->prepareAndExecute("select count(est.id_est) from dbest.est$M->{dblink} est, dbest.library$M->{dblink} library where library.id_lib = est.id_lib and library.organism in ($nameStrings)and est.replaced_by is null");
  my $numDbEST = $st1->fetchrow_array();

  # change to get taxon_id_list from cache or something
  my $taxon_id_list = $M->{taxon_id_list};

  my $st2 = $dbh->prepareAndExecute("select count(e.est_id) from dots.est e, dots.library l where l.taxon_id in ($taxon_id_list) and l.library_id = e.library_id");
  my $finalNumGus = $st2->fetchrow_array();
  my $diff = ($numDbEST-$finalNumGus);
  $M->logAlert("Total number id_est for taxon(s) $taxon_id_list in dbEST:$numDbEST\nTotal number id_est in dots.EST:$finalNumGus\nDifference dbEST and dots:$diff\n");
  return "Inserted/Updated $count dbEST est entries";
}


=pod

=head1 Description

B<DataLoad::dbEST> - A plugin for inserting/updating the EST information in GUS 
from a mirror of dbEST.

=head1 Purpose

B<DataLoad::dbEST> will insert or update DoTS.EST, DoTS.Clone, DoTS.Library, 
DoTS.ExternalNASequence and SRes.Contact tables.

Note that this plugin B<DOES NOT> update library or contact information from dbEST, 
It only handles insertions of new Library or Contact entries. For update of the 
DoTS.Library and SRes.Contact tables, see the C<DataLoad::dbESTLibrary> and C<DataLoad::dbESTContact> plugins, respectively.


=head1 Plugin methods

These methods are used by this plugin alone. 

=head2 processEntries

Process a set of EST entries and return the number of 
entries that were updated/inserted into GUS.

=cut



sub getNameStrings {
  my ($M) = @_;
  my $nameStrings;
  foreach my $name (keys %{$M->{taxon}}) {
      $nameStrings .= " '$name',";
  }
  $nameStrings =~ s/\,$//;
  return $nameStrings;
}
 
sub processEntries {
  my ($M, $e ) = @_;
  my $count = 0;
  return $count unless (keys %$e) ;
  # get the most recent entry 
  foreach my $id (sort {$a <=> $b} keys %$e) {
    if ($e->{$id}->{e}->{replaced_by}){
      my $re =  $M->getMostRecentEntry($e->{$id}->{e});
      #this entry is bogus, delete from insert hash
      delete $e->{$id};
      #enter the new entry into the insert hash
      $e->{$re->{new}->{id_est}}->{e} = $re->{new};
      $e->{$re->{new}->{id_est}}->{old} = $re->{old};
    }
  }
  
  # get the sequences only for most current entry
  my $ids = join "," , sort {$a <=> $b} keys %$e;

  my $A = $M->sql_get_as_hash_refs_lc("select * from dbest.SEQUENCE$M->{dblink} where id_est in ($ids) order by id_est, local_id");
  if ($A) {
    foreach my $s (@{$A}){
	$e->{$s->{id_est}}->{e}->{sequence} .= $s->{data};
    }
  }
  
  # get the comments, if any
  $ids = join "," , keys %$e;
  $A = $M->sql_get_as_hash_refs_lc("select * from dbest.CMNT$M->{dblink} where id_est in ($ids) order by id_est, local_id");
  if ($A) {
    foreach my $c (@{$A}){
      $e->{$c->{id_est}}->{e}->{comment} .= $c->{data};
    }
  }
  
  # Now that we have all the information we need, start processing
  # this batch 
  foreach my $id (sort {$a <=> $b} keys %$e) {
    
    #####################################################################
    # If there are older entries, then we need to go through an update 
    # proceedure of historical entries. Else just insert if not already 
    # present.
    #####################################################################
    if ($e->{$id}->{old} && @{$e->{$id}->{old}} > 0) {
      $count +=  $M->updateEntry($e->{$id});
    }else {
      $count += $M->insertEntry($e->{$id}->{e});
    }
  }
  return $count;
}

=pod 

=head2 updateEntry

Checks whether any of the historical entries are in GUS. Updates the 
Entry as necessary. 

Returns 1 if succesful update or 0 if not.

=cut

sub updateEntry {
  my ($M,$e) = @_;

  #####################################################################
  ## Go through the older entries and determine which is in GUS, if any.
  ## Since there should only be one entry in GUS, it is valid to just 
  ## update the first older entry encountered.
  #####################################################################

  foreach my $oe (@{$e->{old}}) { 
    next unless ($e->{id_est});
    my $est = GUS::Model::DoTS::EST->new({'dbest_id_est' => $e->{id_est}});
    
    if ($est->retrieveFromDB()) {
      # Entry present in the DB; UPDATE
      return  $M->insertEntry($e->{e},$est);
    }
  }
  ## No historical entries; INSERT if not already present
  return $M->insertEntry($e->{e});
}


=pod 

=head2 insertEntry

Checks for the entry in GUS. If not already present, then it inserts a 
new entry. If already present, it will check the atts for discrepencies 
if the 'fullupdate' flag was given. It will also determine whether we need 
to do anything at all.

In all cases it will check the sequence against DoTS.ExternalNASequence. 
Unless the C<no_sequence_update> flag is given, the sequence will be updated.
Else the conflict is reported to the log and sequence is left as-is.

Returns 1 if successful insert or 0 if not.

=cut

sub insertEntry{
  my ($M,$e,$est) = @_;
  my $needsUpdate = 0;
  #####################################################################
  ## Do a full update only if the dbest.id_est is not the same
  ## This is valid since all EST
  #####################################################################
  if ((defined $est) && ($est->getDbestIdEst() != $e->{id_est} )){
    $needsUpdate = 1;
  }else {
    $est = GUS::Model::DoTS::EST->new({'dbest_id_est' => $e->{id_est}});
  }
  
  if ($est->retrieveFromDB()){    
    # The entry exists in GUS. Must check to see if valid
    if ($M->getCla()->{fullupdate} || $needsUpdate) {
      # Treat this as a new entry
      $M->populateEst($e,$est);
      # check to see if clone information already exists
      # for this EST
      $M->checkCloneInfo($e,$est);
    }
    # else this is already in the DB. Do Nothing.
    
  } else {
    # This is a new entry
    $M->populateEst($e,$est);
    # check to see if clone information already exists
    # for this EST
    $M->checkCloneInfo($e,$est);
  }
  

  #####################################################################
  # Check for an update of the sequence. Change the sequence unless 
  # the no_sequence_update flag is given
  #####################################################################

  my $seq = $est->getParent('GUS::Model::DoTS::ExternalNASequence',1);
  if ((defined $seq) && $e->{sequence} ne $seq->getSequence()){
    if (! $M->getCla->{no_sequence_update}) {
      $seq->setSequence($e->{sequence});
      # set the ExtDBId to dbEST if not already so.
      #$seq->setExternalDatabaseReleaseId( $DBEST_EXTDB_ID);
      # log the change of sequence
      $M->getCla->{log_fh}->print($M->logAlert('WARN: SEQ_UPDATE:', $seq->getId(),'\n'));
      $M->logAlert('WARN: SEQ_UPDATE:', $seq->getId(),'\n');
    } else {

      #####################################################################
      # There is a conflict, but the 'no_sequence_update' flag given
      # Output a message to the log
      #####################################################################

      $M->getCla->{log_fh}->print($M->logAlert('WARN: SEQ_NO_UPDATE: NA_SEQUENCE_ID=' , $seq->getId(), " DBEST_ID_EST=$e->{id_est}\n"));
      $M->logAlert('WARN: SEQ_NO_UPDATE: NA_SEQUENCE_ID=' , $seq->getId(), " DBEST_ID_EST=$e->{id_est}\n");
    }
  }else {
    #####################################################################
    ## This sequence entry does no0t exist. We must make it. 
    #####################################################################

    $seq = GUS::Model::DoTS::ExternalNASequence->new({'source_id' => $e->{gb_uid}, 'sequence_version' => 1, 'external_database_release_id' => $M->{dbest_ext_db_rel_id}});
    $seq->retrieveFromDB();
    $M->checkExtNASeq($e,$seq);
    $est->setParent($seq);
  }
  
  ## Add the clone entry (if there is one) to the submit list
  my $clone = $est->getParent('GUS::Model::DoTS::Clone');
  if ($clone) { $seq->addToSubmitList($clone); }
  
  # submit the sequence and EST entry. Return the submit() result.
  my $result = $seq->submit();
  if ($result) {
    $M->getCla->{log_fh}->print($M->logAlert('INSERT/UPDATE', $e->{id_est}),"\n");
  }
  return $result;
}

sub getExternalDatabaseRelease{

  my $M = shift;
  my $name = $M->getCla()->{extDbName};
  if (! $name) {
    $name = 'dbEST';
  }
  
  my $externalDatabase = GUS::Model::SRes::ExternalDatabase->new({"name" => $name});
  $externalDatabase->retrieveFromDB();
  
  if (! $externalDatabase->getExternalDatabaseId()) {
    $externalDatabase->submit();
  }	
  my $external_db_id = $externalDatabase->getExternalDatabaseId();
  
  my $version = $M->getCla()->{extDbRlsVer};
  if (! $version) {
    $version = 'continuous';
  }
  
  my $externalDatabaseRel = GUS::Model::SRes::ExternalDatabaseRelease->new ({'external_database_id'=>$external_db_id,'version'=>$version});

  $externalDatabaseRel->retrieveFromDB();

  if (! $externalDatabaseRel->getExternalDatabaseReleaseId()) {
    $externalDatabaseRel->submit();
  }
  my $external_db_rel_id = $externalDatabaseRel->getExternalDatabaseReleaseId();
  return $external_db_rel_id;

}


=pod 

=head2 populateEST 

This is a doozy of a method that populate all the various parts of an EST, 
entry, including library, contact and sequence information. It also makes calls 
to other methods that parse fields for clone information and other columns.

No return value.

=cut

sub populateEst {
  my ($M,$e,$est) = @_;
  
  #parse the comment for hard to find information
  $M->parseEntry($e);
  
  ## Mapping to dots.EST columns
  my %atthash = ('id_est' => 'dbest_id_est',
                 'id_gi'         => 'g_id'             ,
                 'id_lib'        => 'dbest_lib_id'     ,
                 'id_contact'    => 'dbest_contact_id' ,
                 'gb_uid'        => 'accession'        ,
                 'clone_uid'     => 'dbest_clone_uid'  ,
                 'insert_length' => 'seq_length'     ,
                 'seq_primer'    => 'seq_primer'      ,
                 'p_end'         => 'p_end'           ,
                 'dna_type'      => 'dna_type'        ,
                 'hiqual_start'  => 'quality_start'    ,
                 'hiqual_stop'   => 'quality_stop'     ,
                 'est_uid'       => 'est_uid'          ,
                 'polya'         => 'polya_signal'     ,
                 'gb_version'    => 'gb_version'       ,
                 'replaced_by'   => 'replaced_by'      ,
                 'est_uid'       => 'est_uid',
                 'washu_id' =>      'washu_id',
                 'washu_name' =>    'washu_name',
                 'image_id' =>      'image_id',
                 'is_image' =>      'is_image',
                 'possibly_reversed'   => 'possibly_reversed',
                 'putative_full_length_read'   => 'putative_full_length_read',
                 'trace_poor_quality'   => 'trace_poor_quality',
                );
  
  # set the easy stuff
  foreach my $a (keys %atthash) {
    my $att = $atthash{$a};
    if ( $est->isValidAttribute($att)) {
      my $method = 'set';
      $method .= ucfirst $att;
      $method =~s/\_(\w)/uc $1/ge;
      $est->$method($e->{$a});
    }
  }
  
  # Set the contact from the contact hash
  if ($M->{contact}->{$e->{id_contact}}){
    $est->setContactId($M->{contact}->{$e->{id_contact}});
  }else {
    # get from DB and cache
    my $c = GUS::Model::SRes::Contact->new({'source_id' => $e->{id_contact},
                                            'external_database_release_id' => $M->{dbest_ext_db_rel_id}});
    unless ($c->retrieveFromDB()) {
      $M->newContact($e,$c);
    }
    # Add to cache
    $M->{contact}->{$c->getSourceId()} = $c->getId();
    # Set the parent-child relationship
    $est->setParent($c);
  }

  # Set the library information
  if (exists $M->{libs}->{$e->{id_lib}}){
    $est->setLibraryId($M->{libs}->{$e->{id_lib}}->{dots_lib});
  }else {
    # get from DB and cache
    my $l = GUS::Model::DoTS::Library->new({'dbest_id' => $e->{id_lib},
                                           });
    unless ($l->retrieveFromDB()) {
      $M->newLibrary($e,$l);
    }
    # Add to cache
    $M->{libs}->{$l->getDbestId()}->{dots_lib} = $l->getId();
    $M->{libs}->{$l->getDbestId()}->{taxon} = $l->getTaxonId();    
    # set parent-child relationship
    $est->setParent($l);
  }
  $M;
}

=pod

=head2 checkCloneInfo

Checks a dbEST entry for presence of reliable clone 
information. If the EST comes from either WashU or the 
IMAGE Consortium, then the entry is processed.

=cut

sub checkCloneInfo {
  my ($M,$e,$est) = @_;
  
  #####################################################################
  # It only makes sense to check clone entries if the EST comes from
  # WashU or IMAGE
  #####################################################################
  return $M unless (($e->{is_image} && $e->{image_id}) 
                    || $e->{washu_name});
  
  # This is a clone. Try and grab the entry from GUS
  my $c = $est->getParent("GUS::Model::DoTS::Clone",1);
  unless (defined $c) {
    $c =  GUS::Model::DoTS::Clone->new();
    if ($e->{is_image}) {
      $c->setImageId($e->{image_id});
    } else {
      $c->setWashuName($e->{washu_name});
    }
    $c->retrieveFromDB();
    $est->setParent($c);
  }
  $M->updateClone($e,$c);  
}

=pod

=head2 updateClone

Populates the attributes of a new clone from a dbEST EST entry.
It only makes sense to do this if the EST came from 
WashU or the IMAGE Consortium, but these test have 
already been done by this point.

=cut

sub updateClone {
  my ($M, $e, $c) = @_;
  # Check the clone for updated attributes
  my %atthash = ('id_est' => 'dbest_id_est',
                 'id_gi'         => 'g_id'             ,
                 'id_lib'        => 'dbest_lib_id'     ,
                 'id_contact'    => 'dbest_contact_id' ,
                 'gb_uid'        => 'accession'        ,
                 'clone_uid'     => 'dbest_clone_uid'  ,
                 'insert_length' => 'seq_length'     ,
                 'seq_primer'    => 'seq_primer'      ,
                 'p_end'         => 'p_end'           ,
                 'dna_type'      => 'dna_type'        ,
                 'hiqual_start'  => 'quality_start'    ,
                 'hiqual_stop'   => 'quality_stop'     ,
                 'est_uid'       => 'est_uid'          ,
                 'polya'         => 'polya_signal'     ,
                 'gb_version'    => 'gb_version'       ,
                 'replaced_by'   => 'replaced_by'      ,
                 'est_uid'       => 'est_uid',
                 'washu_id' =>      'washu_id',
                 'washu_name' =>    'washu_name',
                 'image_id' =>      'image_id',
                 'is_image' =>      'is_image',
                 'possibly_reversed'   => 'possibly_reversed',
                 'putative_full_length_read'   => 'putative_full_length_read',
                 'trace_poor_quality'   => 'trace_poor_quality',
                 );
  
  foreach my $a (keys %atthash) {
    my $att = $atthash{$a};
    if ( $c->isValidAttribute($att)) {
      my $getmethod = 'get';
      my $setmethod = 'set';
      $setmethod .= ucfirst $att;
      $setmethod =~s/\_(\w)/uc $1/ge;
      $getmethod .= ucfirst $att;
      $getmethod =~s/\_(\w)/uc $1/ge;
      if ($c->$getmethod() ne $e->{$a}) {
        $c->$setmethod($e->{$a});
      }
    }
  }
  # check the library information 
  unless  (exists $M->{libs}->{$e->{id_lib}}->{dots_lib}){
    # get from DB and cache
    my $l = GUS::Model::DoTS::Library->new({ 'dbest_id' => $e->{id_lib} });
    unless ($l->retrieveFromDB()) {
      $M->newLibrary($e,$l);
    }
    
    # Add to cache
    $M->{libs}->{$l->getDbestId()}->{dots_lib} = $l->getDbestId();
    $M->{libs}->{$l->getDbestId()}->{taxon} = $l->getTaxonId();    
  }
  
  ######################################################################
  ## OK this lib exists, but there are currently no is_image libraries 
  ## in the DB, which is obviously false. 
  ## Check to make sure that the lib.is_image column is set currectly.
  ## After the first run of this plugin I will take out this test. 
  ## since it only need be done once.
  ######################################################################
  if ($e->{is_image} && !$M->{libs}->{$e->{id_lib}}->{is_image}) {        
    my $l = GUS::Model::DoTS::Library->new({'dbest_id' => $e->{id_lib}});
    $l->retrieveFromDB();
    $l->setIsImage(1);
    $l->submit();
    $M->{libs}->{$e->{id_lib}}->{is_image} = 1;
  }
  
  if ($c->getLibraryId() ne $M->{libs}->{$e->{id_lib}}->{dots_lib}){
    $c->setLibraryId($M->{libs}->{$e->{id_lib}}->{dots_lib});
  }
  # RETURN 
  $M;
}

=pod

=head2 getMostRecentEntry

Gets the most recent EST entry from dbEST. Shoves all older entries into
an array to check for in GUS.

Returns HASHREF{ new => newest entry,
                 old => array of all older entries,
               }

=cut

sub getMostRecentEntry {
  my ($M,$e,$R) = @_;
  $R->{new} = $e;

  my $re = $M->sql_get_as_hash_refs_lc("select * from dbest.EST$M->{dblink} where id_est = $e->{replaced_by}")->[0];
  # angel:2/20/2003: Found that sometimes replaced_by points to non-existent id_est
  # Account for this by inserting the most recent & *valid* entry and
  # log the id_est of the entry that eventually needs an update

  if ($re) {
    print STDERR "Recent Entry=$re;\n" ;
    $R->{new} = $re;
    push @{$R->{old}}, $e;
    if ($re->{replaced_by} ) {
      $R = $M->getMostRecentEntry($re,$R);
    }
  }else {
    $M->getCla->{log_fh}->print($M->logAlert("ERR:BOGUS REPLACED BY","ID_EST", $e->{id_est}, "REPLACED_BY=$e->{replaced_by}","\n"));
  }
  return $R;
}


=pod

=head2 parseEntry

Method to parse various information from the EST\'s comment 
field, as well as a bit of clone information. It only makes 
sense in GUS to designate IMAGE and WashU clones as clones.

=cut

sub parseEntry {
  my ($M,$e) = @_;

  ## Parse for WashU atts

  if (($e->{comment} =~ /Washington University Genome Sequencing
Center/i) || ( $e->{est_uid} =~ /([\w\-]+)\.[a-z]\d/)) {
    # probably a washu_id
    $e->{est_uid} =~ /([\w\-]+)\.\w{2}/;
    my $wname = $1;
    unless ($wname =~ /[\.\s]/) {
      $e->{washu_id} = $e->{est_uid};
      $e->{washu_name} = $1;
    }
  }

  
  
  #if (length ($e->{washu_id}) > 15) {
  #  $e->{washu_id} = undef;
  #  print STDOUT "dbest_id_est : $e->{id_est} \n";
  #}
	
  ## Parse IMAGE clone information 
  if ($e->{clone_uid}  =~ /IMAGE\:(\d+)/) {
    $e->{image_id} = $1;
    $e->{is_image} = 1;
  }else {
    $e->{is_image} = 0;
  }

  ## Parse for trace_poor_quality
  if ($e->{comment} =~ /poor quality/i) {
    $e->{trace_poor_quality} = 1;
  } else { 
    $e->{trace_poor_quality} = 0;
  }
  ## Parse for possibly_reversed
  if ($e->{comment} =~ /possible\s+reversed/i) {
    $e->{possibly_reversed} = 1;
  } else {
    $e->{possibly_reversed} = 0;
  }
  ## Parse for putative_full_length_read
  if ($e->{comment} =~ /putative\s+full\s+length\s+read/i) {
    $e->{putative_full_length_read} = 1;
  } else {
    $e->{putative_full_length_read} = 0;
  }
  
  ## Parse p_end information
  if ($e->{p_end} eq " " || $e->{p_end} eq "" || $e->{p_end} =~ /\?/) {
    delete $e->{p_end};
  } elsif (($e->{p_end} =~ /5\'|5 prime|five prime/i) && 
           ($e->{p_end} =~ / 3\'|3 prime|three prime/i)) {
    delete $e->{p_end};
    # Look for 5 or 3 prime designation	
  } elsif ($e->{p_end} =~ /3\'|3\s?prime|three\s+prime/i) {
    $e->{p_end} = 3;
  } elsif ($e->{p_end} =~ /5\'|5\s?prime|five\s+prime/i) {
    $e->{p_end} = 5;
  } else {
    # not covered by cases above, so delete the biznatch
    delete $e->{p_end};
  }
}

=pod 

=head2 setTableCaches

A method to set certain cache information to speed up the load. 

=cut


sub setTableCaches {
  my $M = shift;
  
  # Library cache
  my $q = 'select dbest_id as dbest_lib_id, library_id, taxon_id, is_image from dots.Library';
  my $A = $M->sql_get_as_array_refs($q);
  foreach my $r (@$A) {
    $M->{libs}->{$r->[0]}->{dots_lib} = $r->[1];
    $M->{libs}->{$r->[0]}->{taxon} = $r->[2];
    $M->{libs}->{$r->[0]}->{is_image} = $r->[3];
  }
  
  # Contact info, get entries only from dbEST
  $q = qq[select contact_id, source_id 
          from sres.contact 
          where source_id is not null 
          ];
          # and external_database_release_id = $DBEST_EXTDB_ID

  $A = $M->sql_get_as_array_refs($q);
  foreach my $r (@$A) {
    $M->{contact}->{$r->[1]} = $r->[0];
  }
  
  # Anatomy cache is on-demand
  
  # Taxon cache
  # changed to get all organism names for human and mouse
  # all else is on-demand cache

  my $taxon_id_list = $M->getCla()->{taxon_id_list}; 

  if (! $taxon_id_list) {
    my $taxon_name_list = $M->getCla()->{taxon_name_list};
    die "Supply taxon_id_list or taxon_name_list\n" unless $taxon_name_list;
    my $dbh = $M->getQueryHandle();
    my $qTaxonName = "select taxon_id from sres.taxonname  where name in ($taxon_name_list) and name_class = 'scientific name'";
    print STDERR "running query: $qTaxonName\n";
    my $st = $dbh->prepareAndExecute($qTaxonName);
    my @taxon_id_array;
    while ( my $taxon = $st->fetchrow()) {
      push (@taxon_id_array,$taxon);
    }
    $st->finish();
    $taxon_id_list = join(',', @taxon_id_array);
  }

  $M->{taxon_id_list} = $taxon_id_list;

  $q = "select name, taxon_id  from sres.TaxonName where taxon_id in ($taxon_id_list)";

  $A = $M->sql_get_as_array_refs($q);
  foreach my $r (@$A) {
    $M->{taxon}->{$r->[0]} = $r->[1];
  }
}

=pod

=head2 newLibrary

Populates the attributes for a new DoTS.Library entry from dbEST.

=cut

sub newLibrary {
  my ($M,$e,$l) = @_;
  my $dbest_lib = $M->sql_get_as_hash_refs_lc("select * from dbest.library$M->{dblink} where id_lib = $e->{id_lib}")->[0];
  my $atthash = {'id_lib' => 'dbest_id',
                 'name' => 'dbest_name',
                 'organism' => 'dbest_organism',
                 'strain' => 'strain',
                 'cultivar' => 'cultivar',
                 'sex' => 'sex',
                 'organ' => 'dbest_organ',
                 'tissue_type' => 'tissue_type',
                 'cell_type' => 'cell_type',
                 'cell_line' => 'cell_line',
                 'dev_stage' => 'stage',
                 'lab_host' => 'host',
                 'vector' => 'vector',
                 'v_type' => 'vector_type',
                 're_1' => 're_1',
                 're_2' => 're_2',
                 'description' => 'comment_string'
                };

  ##truncate tissue_type to fit 

  $dbest_lib->{'tissue_type'} = substr($dbest_lib->{'tissue_type'},0,99);

  ## Set the easy of the attributes

  foreach my $a (keys %{$atthash}) {
    my $att = $atthash->{$a};
    if ($l->isValidAttribute($att)) {
      $l->set($att,$dbest_lib->{$a});
    }
  }

  ## Set the sex of the library 
  my $sex = $dbest_lib->{'sex'};
  if ($sex =~ /(male.+female)|(female.+male)|mix/i) {
    $l->set('sex', 'B');
  } elsif ($sex =~ /female/i) {
    $l->set('sex', 'F');
  } elsif ($sex =~ /male/i) {
    $l->set('sex', 'M');
  } elsif ($sex =~ /hemaph/i) {
    $l->set('sex', 'H');
  } elsif ($sex =~ /none|not/i) {
    $l->set('sex', 'n');
  } else {
    $l->set('sex', '?');
  }

  ## Set the library's taxon
  if ($M->{taxon}->{$dbest_lib->{organism}}) {
    $l->setTaxonId($M->{taxon}->{$dbest_lib->{organism}});
  } 
  #else {
  # my $taxon = GUS::Model::SRes::TaxonName->new({'name' => $dbest_lib->{organism}});
  # if ($taxon->retrieveFromDB()){
  #   $M->{taxon}->{$dbest_lib->{organism}} = $taxon->getTaxonId();
  #   $l->setTaxonId($taxon->getTaxonId());
  # }
  else{
    my $dbh = $M->getQueryHandle();
    my $name = $dbest_lib->{organism};
    my $st = $dbh->prepareAndExecute("select taxon_id from sres.taxonname where name = '$name'");
    my $taxon_id = $st->fetchrow_array();
    $st->finish();
    if ($taxon_id) {
      $M->{taxon}->{$dbest_lib->{organism}} = $taxon_id;
      $l->setTaxonId($M->{taxon}->{$dbest_lib->{organism}});
    }
    else {
      #Log the fact that we couldn't parse out a taxon
      $M->logAlert('ERR:NEW LIBRARY: TAXON', ' LIB_ID:',  $l->getId(), ' DBEST_ID:',
		   $l->getDbestId(), ' ORGANISM:', $dbest_lib->{organism},"\n");
    }
  }
  
  
  ## parse out the anatomy of the library entry
  if ($M->{anat}->{$dbest_lib->{organ}}) {
    $l->setAnatomyId($M->{anat}->{$dbest_lib->{organ}});
  } else {
    my $anat = GUS::Model::SRes::Anatomy->new({'name' => $dbest_lib->{organ}});
    if ($anat->retrieveFromDB()){
      $M->{anat}->{$dbest_lib->{organ}} = $anat->getId();
      $l->setAnatomyId($anat->getId());
    }else {
      #Log the fact that we couldn't parse out an anatomy
      $M->logAlert('ERR: NEW LIBRARY: ANATOMY', ' LIB_ID:',  $l->getId(), ' DBEST_ID:',
              $l->getDbestId(), ' ORGAN:', $dbest_lib->{organ},"\n");
    }
  }
  
  ## Check to see whether this is an IMAGE library via EST entry
  if ($e->{is_image}) {
    $l->setIsImage(1);
  } else {
    $l->setIsImage(0);
  }

  ## Submit the new library
  $l->submit();
  # return
  $M;
}

=pod

=head2 newContact

Populate the attributes of a new SRes.Contact entry

=cut

  

sub newContact {
  my ($M,$e,$c)  = @_;
  
  my $q = qq[select * 
             from dbest.contact$M->{dblink} 
             where id_contact = $e->{id_contact}];
  my $C = $M->sql_get_as_hash_refs_lc($q)->[0];
  $C->{lab} = "$C->{lab}; $C->{institution}";
  my %atthash = ('id_conact' => 'source_id',
                 'name' => 'name',
                 'lab' => 'address1',
                 'address' => 'address2',
                 'email' => 'email',
                 'phone' => 'phone',
                 'fax' => 'fax',
                 );
  
  foreach my $k (keys %atthash) {
    next if ($C->{$k} eq ' ' || $C->{$k} eq '') ;
    $c->set($atthash{$k}, $C->{$k});
  }
  # Set the external_database_release_id
  #$c->setExternalDatabaseReleaseId($DBEST_EXTDB_ID);
  # submit the new contact to the DB
  $c->submit();
  $M;
}

=pod 

=head2 checkExtNASeq

Method that checks the attributes of a sequence entry and updates it as
necessary to reflect the EST entry. This is only if the C<no_sequence_update>
is not given.

=cut

sub checkExtNASeq {
  my ($M,$e,$seq) = @_;

  my $name = "EST";
  my $sequenceType = GUS::Model::DoTS::SequenceType->new({"name" => $name});
  $sequenceType->retrieveFromDB() || die "Unable to obtain sequence_type_id from dots.sequencetype with name = EST";
  my $sequence_type_id= $sequenceType->getId();
  
  my %seq_vals = ( 'taxon_id' => $M->{libs}->{$e->{id_lib}}->{taxon},
                   'sequence' => $e->{sequence},
                   'length' => length $e->{sequence},
                   'sequence_type_id' =>  $sequence_type_id,
                   'a_count' => (scalar($e->{sequence} =~ s/A/A/g)) || 0,
                   't_count' => (scalar($e->{sequence} =~ s/T/T/g)) || 0,
                   'c_count' => (scalar($e->{sequence} =~ s/C/C/g)) || 0,
                   'g_count' => (scalar($e->{sequence} =~ s/G/G/g)) || 0,
                   'description' => substr($e->{comment},0,1999)
                   );
  foreach my $a (keys %seq_vals) {
    if ( $seq->isValidAttribute($a)) {
      my $getmethod = 'get';
      my $setmethod = 'set';
      $setmethod .= ucfirst $a;
      $setmethod =~s/\_(\w)/uc $1/ge;
      $getmethod .= ucfirst $a;
      $getmethod =~s/\_(\w)/uc $1/ge;
      if ($seq->$getmethod() ne $seq_vals{$a}) {
        if ( $M->getCla()->{no_sequence_update}) {
          # Log an entry 
          $M->logAlert("WARN:", "ExternalNaSequence.$a not updated", $e->{id_est},"\n");
        } else {
          $seq->$setmethod($seq_vals{$a});
        }
      }
    }
  }
}

1;

__END__
