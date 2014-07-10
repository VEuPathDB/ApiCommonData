package ApiCommonData::Load::Plugin::InsertPubChemSubstances;
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | absent
  # GUS4_STATUS | RAD.Analysis                   | auto   | absent
  # GUS4_STATUS | ApiDB.Profile                  | auto   | absent
  # GUS4_STATUS | Study.Study                    | auto   | absent
  # GUS4_STATUS | Dots.Isolate                   | auto   | absent
  # GUS4_STATUS | DeprecatedTables               | auto   | absent
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | absent
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

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
my $property;

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
		 mustExist => 1,
	       }),
     stringArg({ name => 'compoundIdsFile',
		 descr => 'file for compound IDs, with complete path',
		 constraintFunc=> undef,
		 reqd  => 0,
		 isList => 0,
		 mustExist => 0,
	       }),
     stringArg({ name => 'property',
		 descr => 'CID or Synonym',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0,
		 mustExist => 1,
	       })

    ];

  return $argsDeclaration;
}

# ----------------------------------------------------------
# Documentation
# ----------------------------------------------------------

sub getDocumentation {

  my $description = <<DESCR;
Plugin to load PubChem Substances data (compound_id or synonymns) into ApiDB.PubChemSubstance, and to create a file of PubChem compounds IDs (ithat were in the data file).
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
  my $configuration = { requiredDbVersion => 4.0,
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
  $property = $self->getArg('property');

  my $simple = XML::Simple->new (ForceArray => 1, KeepRoot => 1);
  foreach my $file (@fileArray){
    $fileCount++;
    $file = $fileDir. "/" . $file;
    my $data    = $simple->XMLin($file);
    $self->parseFile($data);
  }
  $self->insertPubChemSubstance();
  $self->makeCidFile($cidFile) if ($cidFile && $property eq 'CID');

  return "Processed $fileCount files.";
}

sub parseFile {
  my ($self, $data) = @_;
  my $substances = $data->{'InformationList'}->[0]->{'Information'};
  my @substArray = @{$substances};

  foreach (@substArray){    # for each substance
    my $subst_id = $_->{'SID'}[0];  # SID

    if ($property eq 'CID') {
      $subst{$subst_id}{CID} = $_->{'CID'}[0];
    } else {    # for Synonym
      $subst{$subst_id}{Synonym} = \@{$_->{'Synonym'}};
    }

  }
}

# get SIDs of already_loaded PubChem structures
sub getExistingSids {
  my ($self) = @_;
  my %sidHash;

  my $sql = <<EOSQL;
  SELECT distinct substance_id 
  FROM ApiDB.PubChemSubstance 
  WHERE property= '$property'
EOSQL

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
      $self->log("Ignoring SID $sid; it is already present in ApiDB.PubChemSubstance with property = $property.");
    } else {

      my %y = %{$subst{$sid}};
      my @props = keys(%y);   # keys of inner hash are various properties for each substance

      foreach my $p (@props) {
	if($p eq 'Synonym') {
	  my @syns = @{ $subst{$sid}{Synonym} };
	  foreach my $s (@syns) {
	    my $pubChemSubst = GUS::Model::ApiDB::PubChemSubstance->new({ substance_id => $sid,
									  property     => $p,
									  value        => $s
									});
	    $pubChemSubst->submit() if (!$pubChemSubst->retrieveFromDB());
	  }
	} elsif ($p eq 'CID' && $subst{$sid}{$p}){
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
  $self->log("Making file $file with CIDs.");
  open(FILE, "> $file");

  my @data = keys(%subst);  # keys of outer hash are substance IDs
  $self->log("Array [ @data ] has ($#data + 1) elements.");

  foreach my $sid (@data) {
    my $cid = $subst{$sid}{CID};
    $self->log("sid is $sid AND cid is $cid");
    print FILE "$cid\n";
  }
  close(FILE);
}


sub undoTables {
  my ($self) = @_;

  return ('ApiDB.PubChemSubstance');
}


return 1;
