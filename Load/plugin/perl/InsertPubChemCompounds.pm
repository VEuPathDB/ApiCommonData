package ApiCommonData::Load::Plugin::InsertPubChemCompounds;
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
# Plugin to load PubChem Compound data
# ----------------------------------------------------------

use strict;
use warnings;

use XML::Simple;
use GUS::PluginMgr::Plugin;
use GUS::Model::ApiDB::PubChemCompound;
use GUS::Model::ApiDB::PubChemCompoundProperty;


my %cmpd;
my $cmpd_id;

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
	       })
    ];

  return $argsDeclaration;
}

# ----------------------------------------------------------
# Documentation
# ----------------------------------------------------------

sub getDocumentation {

  my $description = <<DESCR;
Plugin to load PubChem Compounds out of a single XML file, into ApiDB.PubChemCompound and ApiDB.PubChemCompoundProperty
DESCR

  my $purpose = <<PURPOSE;
Plugin to load PubChem Compounds
PURPOSE

  my $purposeBrief = <<PURPOSEBRIEF;
Plugin to load PubChem Compounds
PURPOSEBRIEF

  my $notes = <<NOTES;
NOTES

  my $tablesAffected = <<AFFECT;
ApiDB.PubChemCompound
ApiDB.PubChemCompoundProperty
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
  my $fileDir = $self->getArg('fileDir');
  my @fileArray = @{$self->getArg('fileNames')};

  my $simple = XML::Simple->new (ForceArray => 1, KeepRoot => 1);
  foreach my $file (@fileArray){
    $fileCount++;
    $file = $fileDir. "/" . $file;
     my $data    = $simple->XMLin($file);
    $self->parseFile($data);
  }
  $self->insertPubChemCompound();

  return "Processed $fileCount files.";
}

sub parseFile {
  my ($self, $data) = @_;
  my $compounds = $data->{'eSummaryResult'}->[0]->{'DocSum'};
  my @compArray = @{$compounds}; 

  foreach (@compArray){  # for each compound
    $cmpd_id = $_->{'Id'}[0];      # CID

    foreach my $data ( @{$_->{'Item'}}) {
      my %hsh = %{$data};
      my $val;
      my $prop;
      foreach my $attributes (keys %hsh){
	if ($attributes eq 'content' || $attributes eq 'Item') {
	  $val = $hsh{$attributes};
	} elsif ($attributes eq 'Name') {
	  $prop = $hsh{$attributes};
	}
      }

      if ($prop eq 'MeSHHeadingList' && $val) { 
	my @list = @{$val};
	$cmpd{$cmpd_id}{'Name'} = \@list;
      } elsif ($prop eq 'SynonymList' && $val) {
	my @list = @{$val};
	$cmpd{$cmpd_id}{'Synonym'} = \@list;
      } elsif  ($prop eq 'IUPACName' || $prop eq 'InChI' || $prop eq 'InChIKey' || $prop eq 'MolecularWeight' || $prop eq 'MolecularFormula' || $prop eq 'IsomericSmiles' || $prop eq 'CanonicalSmiles') {
	$prop =~ s/(Smiles)/ $1/;

	$cmpd{$cmpd_id}{$prop} = $val if ($val);
      }
    }

  }
}


# get CIDs of already_loaded PubChem compounds
sub getExistingCids {
  my ($self) = @_;
  my %cidHash;

  my $sql = "SELECT compound_id from ApiDB.PubChemCompound";

  my $dbh = $self->getQueryHandle();
  my $sth = $dbh->prepareAndExecute($sql);

  while(my $cid = $sth->fetchrow_array()){
    $cidHash{$cid} = 1;
  }
  return \%cidHash;
}



sub insertPubChemCompound {
  my $self = shift;
  my $count;

  # get list (as hash) of compound (IDs) that are already in the database
  my $hashRef=$self->getExistingCids();
  my %loadedCids = %$hashRef;


  my @data = keys(%cmpd);  # keys of outer hash are compound IDs
  foreach my $cid (@data) {

    # load compound if CID is not in database
    if ($loadedCids{$cid}) {
      $self->log("Ignoring CID $cid; it is already present in ApiDB.PubChemCompound.");
    } else {
      my %y = %{$cmpd{$cid}};
      my @props = keys(%y);   # keys are inner various properties for each compound

      my $pubChemCmpd = GUS::Model::ApiDB::PubChemCompound->new({
								 compound_id => $cid,
								 MolecularWeight   => $cmpd{$cid}{'MolecularWeight'},
								 MolecularFormula  => $cmpd{$cid}{'MolecularFormula'},
								 IUPACName   => $cmpd{$cid}{'IUPACName'},
								 InChI   => $cmpd{$cid}{'InChI'},
								 InChIKey  => $cmpd{$cid}{'InChIKey'},
								 IsomericSmiles   => $cmpd{$cid}{'IsomericSmiles'},
								 CanonicalSmiles   => $cmpd{$cid}{'CanonicalSmiles'},
								});
      if (!$pubChemCmpd->retrieveFromDB()) {
	$pubChemCmpd->submit()  ;
	$count++;
      }
      my $pubchem_compound_id = $pubChemCmpd->getPubchemCompoundId($cid);

      foreach my $p (@props) {
	if($p eq 'Synonym' || $p eq  'Name') {
	  my @lst = @{$cmpd{$cid}{$p}};
	  foreach my $l (@lst) {
	    my $pubChemCmpdProperty = GUS::Model::ApiDB::PubChemCompoundProperty->new({ 
									       pubchem_compound_id => $pubchem_compound_id,
									       property    => $p,
									       value       => $l->{content}
									      });
            if (!$pubChemCmpdProperty->retrieveFromDB()) {
              $pubChemCmpdProperty->submit()  ;
            }
	  }
	}

        if ($count % 1000 == 0) {
          $self->undefPointerCache();
          $self->log("Inserted entries for $count PubChem Compounds.");
        }
      }
    }
  }
  $self->log("Inserted entries for $count PubChem Compounds.");
}

sub undoTables {
  my ($self) = @_;

  return (
	  'ApiDB.PubChemCompoundProperty',
      'ApiDB.PubChemCompound'
	 );
}


return 1;
