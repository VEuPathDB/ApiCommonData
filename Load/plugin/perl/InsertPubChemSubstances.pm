package ApiCommonData::Load::Plugin::InsertPubChemSubstances;

@ISA = qw(GUS::PluginMgr::Plugin);

# ----------------------------------------------------------
# Plugin to load PubChem Substance data
# ----------------------------------------------------------

use strict;
use warnings;

use XML::Simple;
use GUS::PluginMgr::Plugin;
use GUS::Model::ApiDB::PubChemSubstance;


my %subst;
my $subst_id;
my %compoundH;

# ----------------------------------------------------------
# Load Arguments
# ----------------------------------------------------------

sub getArgsDeclaration {
  my $argsDeclaration  =
    [
     stringArg({ name => 'fileDir',
		 descr => 'full path to xml files',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0,
		 mustExist => 1,
	       }),
     stringArg({ name => 'fileNames',
		 descr => 'comma-separated xml data files',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 1,
		 mustExist => 0,
	       }),
     stringArg({ name => 'compoundIdsFile',
		 descr => 'file for compound IDs, with complete path',
		 constraintFunc=> undef,
		 reqd  => 0,
		 isList => 0,
		 mustExist => 0,
	       })
    ];

  return $argsDeclaration;
}

# ----------------------------------------------------------
# Documentation
# ----------------------------------------------------------

sub getDocumentation {

  my $description = <<DESCR;
Plugin to load PubChem Substances out of a single XML file, into ApiDB.PubChemSubstance, and to create a file of PubChem compounds IDs (that were in the XML file)
DESCR

  my $purpose = <<PURPOSE;
Plugin to load PubChem Substances, and make a PubChem compound ID file
PURPOSE

  my $purposeBrief = <<PURPOSEBRIEF;
Plugin to load PubChem Substances, and make a PubChem compound ID file
PURPOSEBRIEF

  my $notes = <<NOTES;
NOTES

  my $tablesAffected = <<AFFECT;
ApiDB.PubChemSubstance
AFFECT

  my $tablesDependedOn = <<TABD;
TABD

  my $howToRestart = <<RESTART;
No restart provided. Must undo and reload.
RESTART

  my $failureCases = <<FAIL;
FAIL

  my $documentation = { purpose          => $purpose,
                        purposeBrief     => $purposeBrief,
                        tablesAffected   => $tablesAffected,
                        tablesDependedOn => $tablesDependedOn,
                        howToRestart     => $howToRestart,
                        failureCases     => $failureCases,
                        notes            => $notes
                      };

  return ($documentation);
}

# ----------------------------------------------------------

sub new {
  my $class = shift;
  my $self = {};
  bless($self, $class);

  my $documentation = &getDocumentation();
  my $args = &getArgsDeclaration();
  my $configuration = { requiredDbVersion => 3.6,
                        cvsRevision => '$Revision$',
                        name => ref($self),
                        argsDeclaration => $args,
                        documentation => $documentation
                      };
  $self->initialize($configuration);
  return $self;
}

# ----------------------------------------------------------

sub run {
  my $self = shift;
  my $fileCount = 0;
  my $fileDir  = $self->getArg('fileDir');
  my @fileArray = @{$self->getArg('fileNames')};
  my $cidFile  = $self->getArg('compoundIdsFile');

  my $simple = XML::Simple->new (ForceArray => 1, KeepRoot => 1);
  foreach my $file (@fileArray){
    $fileCount++;
    $file = $fileDir. "/" . $file;
    my $data    = $simple->XMLin($file);
    $self->parseFile($data);
  }
  $self->insertPubChemSubstance();
  $self->makeCidFile($cidFile) if $cidFile;

  return "Processed $fileCount files.";
}

sub parseFile {
  my ($self, $data) = @_;
  my $substances = $data->{'eSummaryResult'}->[0]->{'DocSum'};
  my @substArray = @{$substances};

  foreach (@substArray){  # for each substance
   my $subst_id = $_->{'Id'}[0];      # SID
    my $val;
    my $prop;

   foreach my $data ( @{$_->{'Item'}}) {
     my %hsh = %{$data};
     foreach my $attributes (keys %hsh){    
       if ($attributes eq 'content' || $attributes eq 'Item') {
	 $val = $hsh{$attributes};
       } elsif ($attributes eq 'Name') {
	 $prop = $hsh{$attributes};
       }

     }
     if ($prop eq 'SynonymList' ) {
       my @list = @{$val};
       $subst{$subst_id}{synonyms} = \@list;

     } elsif ($prop eq 'CompoundIDList' ) {

       my @list = @{$val}; 
       foreach (@list) {
	 my $comp = $_->{content};
	 $compoundH{$comp} = 1; # to capture CIDs for output file
       }
       $subst{$subst_id}{CID} = \@list;

     } elsif ($prop eq 'SourceID') {
       $subst{$subst_id}{'KEGG'} = $val;
     }
   }

 }
}

# get SIDs of already_loaded PubChem structures
sub getExistingSids {
  my ($self) = @_;
  my %sidHash;

  my $sql = "SELECT distinct substance_id from ApiDB.PubChemSubstance";

  my $dbh = $self->getQueryHandle();
  my $sth = $dbh->prepareAndExecute($sql);

  while(my $sid = $sth->fetchrow_array()){
    $sidHash{$sid} = 1;
  }
  return \%sidHash;
}


# insert rows in table
sub insertPubChemSubstance {
  my $self = shift;
  my $count;

  # get list (as hash) of substance (IDs) that are already in the database
  my $hashRef=$self->getExistingSids();
  my %loadedSids = %$hashRef;

  # process array of hashes (of hashes) for each substance
  my @data = keys(%subst);  # keys of outer hash are substance IDs
  foreach my $sid (@data) {

    # load substance if SID is not in database
    if ($loadedSids{$sid}) {
      $self->log("Ignoring SID $sid; it is already present in ApiDB.PubChemSubstance.");
    } else {

      my %y = %{$subst{$sid}};
      my @props = keys(%y);   # keys of inner hash are various properties for each substance

      foreach my $p (@props) {
	if ($p eq 'CID'){
	  my @cpds =  @{ $subst{$sid}{CID} };

	  my $type = 'standardized';
	  foreach my $c (@cpds) {
	    ##my ($id, $type) = split(/\|type\=/, $c);  	    # break $c into cid and type

	    my $pubChemSubst = GUS::Model::ApiDB::PubChemSubstance->new({ substance_id => $sid,
									  property     => $p,
									  value        => $c->{content} ,
									  type         => $type
									});
	    $type = 'component';
	    # add entry unless it already exists in the table
	    $pubChemSubst->submit() if (!$pubChemSubst->retrieveFromDB());
	  }
	} elsif($p eq 'synonyms') {
	  my @syns = @{ $subst{$sid}{synonyms} };
	  foreach my $s (@syns) {

	    if ($s->{content} ne $subst{$sid}{KEGG}) {    # skip KEGG_ID
	      my $pubChemSubst = GUS::Model::ApiDB::PubChemSubstance->new({ substance_id => $sid,
									    property     => $p,
									    value        => $s->{content}
									  });
	      $pubChemSubst->submit() if (!$pubChemSubst->retrieveFromDB());
	    }
	  }
	} else {
	  my $pubChemSubst = GUS::Model::ApiDB::PubChemSubstance->new({ substance_id => $sid,
									property     => $p,
									value        => $subst{$sid}{$p}
								      });
	  $pubChemSubst->submit() if (!$pubChemSubst->retrieveFromDB());
	}
      }
      $count++;
      $self->undefPointerCache() if $count % 100 == 0;

      $self->log("Processed entries for $count PubChem Substance(s).");
    }
  }

}


# make file of PubChem compound IDs (CIDs)
sub makeCidFile {
  my ($self, $file) = @_;

  open(FILE, "> $file");
  for my $cid (keys %compoundH) {
    print FILE "$cid\n";
  }
  close(FILE);
}


sub undoTables {
  my ($self) = @_;

  return ('ApiDB.PubChemSubstance');
}


return 1;
