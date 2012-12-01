package ApiCommonData::Load::Plugin::InsertPubChemSubstances;

@ISA = qw(GUS::PluginMgr::Plugin);

# ----------------------------------------------------------
# Plugin to load PubChem Substance data
# ----------------------------------------------------------

use strict;
use warnings;

use XML::Twig;
use GUS::PluginMgr::Plugin;
use GUS::Model::ApiDB::PubChemSubstance;


my %subst;
my $subst_id;
my @compoundArr;
my @idAndTypeArr;

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
		 reqd  => 1,
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

  my $roots = { 'PC-Substance_sid' => 1,
		'PC-Compound' => 1,
		'PC-Substance_source/PC-Source/PC-Source_db/PC-DBTracking' => 1,
		'PC-Substance_synonyms' => 1
	      };

  my $handlers = { 'PC-Substance_sid/PC-ID' => \&get_ID,
		   'PC-Compound' => \&get_CID,
		   'PC-Substance_source/PC-Source/PC-Source_db/PC-DBTracking'  => \&get_KEGG,
		   'PC-Substance_synonyms' => \&get_Syns
		 };
  my $twig = new XML::Twig(TwigRoots => $roots,
			   TwigHandlers => $handlers);

  my $fileCount = 0;
  my $fileDir  = $self->getArg('fileDir');
  my @fileArray = @{$self->getArg('fileNames')};
  my $cidFile  = $self->getArg('compoundIdsFile');


  foreach my $file (@fileArray){
    $fileCount++;
    $file = $fileDir. "/" . $file;
    $twig->parsefile($file);
  }
  $self->insertPubChemSubstance();
  $self->makeCidFile($cidFile) if $cidFile;

  return "Processed $fileCount files.";
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
	if ($p eq 'KEGG') {
	  my $pubChemSubst = GUS::Model::ApiDB::PubChemSubstance->new({ substance_id => $sid,
									property     => $p,
									value        => $subst{$sid}{$p}
								      });
	  # add entry unless it already exists in the table
	  $pubChemSubst->submit() if (!$pubChemSubst->retrieveFromDB());
	} elsif ($p eq 'CID'){
	  my @cpds =  @{ $subst{$sid}{CID} }; #BB
	  foreach my $c (@cpds) {
	    my ($id, $type) = split(/\|type\=/, $c);  	    # break $c into cid and type
	    my $pubChemSubst = GUS::Model::ApiDB::PubChemSubstance->new({ substance_id => $sid,
									  property     => $p,
									  value        => $id ,
									  type         => $type
									});
	  # add entry unless it already exists in the table
	  $pubChemSubst->submit() if (!$pubChemSubst->retrieveFromDB());
	  }
	} else {
	  my @syns = @{ $subst{$sid}{synonyms} };
	  foreach my $s (@syns) {
	    # skip KEGG_ID, as it is repeated as a synonym in the XML file
	    # print "$sid, synonym, $s \n" if ($s ne $subst{$sid}{KEGG});
	    if ($s ne $subst{$sid}{KEGG}) {
	      my $pubChemSubst = GUS::Model::ApiDB::PubChemSubstance->new({ substance_id => $sid,
									    property     => $p,
									    value        => $s
									  });
	      # add entry unless it already exists in the table
	      $pubChemSubst->submit() if (!$pubChemSubst->retrieveFromDB());
	    }
	  }
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
  my @cidArr;

  open(FILE, "> $file");
  foreach my $c (@compoundArr) {
    print FILE "$c\n";
  }
  close(FILE);

}

# get substance ID
sub get_ID {
  my ($twig, $ele) = @_;
  my $id = $ele->first_child('PC-ID_id')->text;

  $subst_id = $id;
}

# get the synonym list
sub get_Syns {
  my ($twig, $ele) = @_;

  my @desc = $ele->find_by_tag_name('PC-Substance_synonyms_E');
  my @synonyms;
  foreach my $des (@desc) {
    push (@synonyms, $des->text);
  }
  $subst{$subst_id}{synonyms} = \@synonyms;
}

#get the KEGG ID
sub get_KEGG {
  my ($twig, $ele) = @_;
  my $name = $ele->first_child('PC-DBTracking_name')->text;
  my $id = $ele->first_child('PC-DBTracking_source-id')->text;

  $subst{$subst_id}{$name} = $id;
}


#get the compound ID (CID)
sub get_CID {
  my ($twig, $ele) = @_;
  my @cArr = $ele->find_by_tag_name('PC-CompoundType');

  foreach my $c (@cArr) {
    # get the compound_id
    my @cidArr = $c->find_by_tag_name('PC-CompoundType_id_cid');

    foreach my $cid (@cidArr) {
      my $compound_id = $cid->text;
      my $compound_type;
      # for each compound_id found, capture it's type
      my @type = $c->find_by_tag_name('PC-CompoundType_type');
      $compound_type = $type[0]->att( 'value' );

      push (@compoundArr, $compound_id);
      push (@idAndTypeArr, ($compound_id  . "|type="  . $compound_type) );
    }
    $subst{$subst_id}{CID} = \@idAndTypeArr if ($#idAndTypeArr + 1);
  }
}

sub undoTables {
  my ($self) = @_;

  return ('ApiDB.PubChemSubstance');
}


return 1;
