package OrthoMCLData::Load::Plugin::InsertOrthomclTaxon;

@ISA = qw(GUS::PluginMgr::Plugin);

# ----------------------------------------------------------------------

use strict;
use GUS::PluginMgr::Plugin;
use FileHandle;

use GUS::Model::ApiDB::OrthomclTaxon;

use ApiCommonData::Load::Util;
use Data::Dumper;


my $argsDeclaration =
[
    fileArg({name           => 'cladeFile',
            descr          => 'a file containing the clade tree',
            reqd           => 1,
            mustExist      => 1,
	    format         => 'see Notes',
            constraintFunc => undef,
            isList         => 0, }),

    fileArg({name           => 'speciesFile',
            descr          => 'a file containing the species',
            reqd           => 1,
            mustExist      => 1,
	    format         => 'see Notes',
            constraintFunc => undef,
            isList         => 0, }),

];

my $purpose = <<PURPOSE;
Insert the Orthomcl-DB specific taxonomy.  The clade input file has the tree flattened depth first.  we use the line number for the depth_first_index.  sibling_depth_first_index is the depth_first_index of the next clade at the same level in the hierarchy.
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
Insert the Orthomcl-DB specific taxonomy used by the "Phyletic Pattern Expression" (PPE) query.  
PURPOSE_BRIEF

my $notes = <<NOTES;
Both input files are both constructed manually as part of the Orthomcl-DB genome acquistion phase.

The speciesFile is a columnar file with these columns:
  - four_letter_abbrev
  - ncbi_tax_id
  - clade_four_letter_abbrev  # an index into the cladeFile

The cladesFile is a depth first serialization of the clade tree.  Each clade has a four letter abbreviation, a display name, and a depth indicated by pipe characters

The head of a sample cladesFile looks like this: 
ALL All
|  ARCH Archea:common name
|  BACT Bacteria:common name
|  |  PROT Protobacteria:common name


NOTES

my $tablesAffected = <<TABLES_AFFECTED;
ApiDB.OrthomclTaxon,
TABLES_AFFECTED

my $tablesDependedOn = <<TABLES_DEPENDED_ON;
Sres.Taxon,

TABLES_DEPENDED_ON

my $howToRestart = <<RESTART;
Use the Undo plugin first.
RESTART

my $failureCases = <<FAIL_CASES;

FAIL_CASES

my $documentation = { purpose          => $purpose,
                      purposeBrief     => $purposeBrief,
                      notes            => $notes,
                      tablesAffected   => $tablesAffected,
                      tablesDependedOn => $tablesDependedOn,
                      howToRestart     => $howToRestart,
                      failureCases     => $failureCases };

# ----------------------------------------------------------------------

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  $self->initialize({ requiredDbVersion => 3.5,
                      cvsRevision       => '$Revision$',
                      name              => ref($self),
                      argsDeclaration   => $argsDeclaration,
                      documentation     => $documentation});

  return $self;
}

# ======================================================================

sub run {
    my ($self) = @_;

    my $cladeFile = $self->getArgs()->{cladeFile};
    my $speciesFile = $self->getArgs()->{speciesFile};

    # make taxon tree with clades only
    my $taxonTree = $self->parseCladeFile($cladeFile);

    # add species to it
    $self->parseSpeciesFile($speciesFile);

    $self->printCladeList(); # for debugging
 
    # off you go to the database, and behave yourself
    $taxonTree->submit();
}

sub parseCladeFile {
    my ($self, $cladeFile) = @_;

    open(FILE, $cladeFile) || $self->userError("can't open clade file '$cladeFile'");

    while(<FILE>) {
      chomp;
      push(@{$self->{cladeLines}}, $_);
    }
    $self->{cladeLinesCursor} = 0;
    $self->{nextLeafIndex} = 1;

    my $clade = $self->parseCladeLine();
    $self->makeTree($clade);
    return $clade;
}

sub makeTree {
  my ($self, $parentClade) = @_;
  push(@{$self->{cladeList}}, $parentClade);

  # assume the parent is a leaf clade
  my $parentIsLeaf = 1;

  while (my $clade = $self->parseCladeLine()) {

      # done with parent's children
      if ($clade->{level} <= $parentClade->{level}) {
	  $self->{cladeLinesCursor}--;
	  last;
      } 

      # handle a child
      $clade->setParent($parentClade);
      $self->{newCladeCount}++;
      $parentIsLeaf = 0;
      $self->makeTree($clade);
      if ($clade->getDepthFirstIndex()-1 < $parentClade->getDepthFirstIndex()) {
	  $parentClade->setDepthFirstIndex($clade->getDepthFirstIndex()-1);
	  $parentClade->setSpeciesOrder($parentClade->getDepthFirstIndex());
      }
      if ($clade->getSiblingDepthFirstIndex() > $parentClade->getSiblingDepthFirstIndex()) {
	  $parentClade->setSiblingDepthFirstIndex($clade->getSiblingDepthFirstIndex());
      }
  }
  if ($parentIsLeaf) {
      $self->{nextLeafIndex} += $self->{newCladeCount};
      $self->{newCladeCount} = 0;
      $parentClade->setDepthFirstIndex($self->{nextLeafIndex});
      $parentClade->setSpeciesOrder($parentClade->getDepthFirstIndex());
      $parentClade->setSiblingDepthFirstIndex($self->{nextLeafIndex} + 1);
  } 
}

sub parseCladeLine {
    my ($self) = @_;

    my $clade = GUS::Model::ApiDB::OrthomclTaxon->
      new({depth_first_index => 999999,
	   sibling_depth_first_index => -99999});
    my $level;
    my $line = $self->{cladeLines}->[$self->{cladeLinesCursor}++];
    return undef unless $line;
    # handle a clade, which looks like the following:
    # |  |  PRO Protobacteria
    if ($line =~ /^([\|\s\s]*)(ALL|[A-Z]{4}) ([\S|\s]+)/) {
      my $pipes = $1;
      my $cladeAbbrev = $2;
      my $cladeNames = $3;
      my @nameArr = split(/\:/,$cladeNames);
      my $cladeName = $nameArr[0];
      my $commonName = $nameArr[1];
      $clade->{level} = length($pipes)/3; #count of pipe chars
      $clade->setThreeLetterAbbrev($cladeAbbrev);
      $clade->setName($cladeName);
      $clade->setCommonName($commonName) if $commonName;
      $clade->setIsSpecies(0);
      $clade->setTaxonId(undef);
      $self->{clades}->{$clade->getThreeLetterAbbrev()} = $clade;
    } else {
      $self->userError("invalid line in clade file: '$line'");
    }

    return $clade;
}

sub parseSpeciesFile {
    my ($self, $speciesFile) = @_;

    open(FILE, $speciesFile) || $self->userError("can't open species file '$speciesFile'");

    my $dbh = $self->getQueryHandle();
    my $sql = "SELECT t.taxon_id, tn.name
               FROM sres.taxon t, sres.taxonname tn
               WHERE ncbi_tax_id = ?
               AND t.taxon_id = tn.taxon_id
               AND tn.name_class = 'scientific name'";

    my $stmt = $dbh->prepare($sql);
    my $speciesOrder = 1;
    my $speciesAbbrevs = {};
    while(<FILE>) {
	chomp;

	my $species = GUS::Model::ApiDB::OrthomclTaxon->new();

	# pfa APIC 123345
	if (/([a-z]{4})\t([A-Z]{4})\t(\d+)/) {
	  my $speciesAbbrev = $1;
	  my $cladeAbbrev = $2;
	  my $ncbiTaxonId = $3;
	  $self->error("duplicate species abbrev '$speciesAbbrev'") if $speciesAbbrevs->{$speciesAbbrev};
	  $self->error("species abbreviation must have 4 letters") if length($speciesAbbrev) != 4;
	  $speciesAbbrevs->{$speciesAbbrev} = 1;
	  $species->setThreeLetterAbbrev($speciesAbbrev);
	  my $clade = $self->{clades}->{$cladeAbbrev};
	  my ($taxonId, $taxonName) = $self->getTaxonId($stmt, $ncbiTaxonId);
	  $species->setTaxonId($taxonId);
	  $clade || die "can't find clade with code '$cladeAbbrev' for species '$speciesAbbrev'\n";
	  $species->setParent($clade);
	  $species->setIsSpecies(1);
	  $species->setSpeciesOrder($speciesOrder++);
	  $species->setName($taxonName);
	  $species->setDepthFirstIndex($clade->getDepthFirstIndex());
	}  else {
	  $self->userError("invalid line in species file: '$_'");
	}
    }
}

sub getTaxonId {
  my ($self, $stmt, $ncbiTaxId) = @_;


  my @ids = $self->sqlAsArray( Handle => $stmt, Bind => [$ncbiTaxId] );

  if(scalar @ids != 2) {
    $self->error("Should return one value for ncbi_tax_id '$ncbiTaxId'");
  }
  return @ids;

}

sub printCladeList {
  my ($self) = @_;
  my $pipes = '|  |  |  |  |  |  |  |  |  |  |  |  |  |  ';

  foreach my $clade (@{$self->{cladeList}}) {
    my $indent = substr($pipes,0,$clade->{level}*3);
    print STDERR join(" ", ($indent.$clade->getThreeLetterAbbrev(), 
		     $clade->getDepthFirstIndex(),
		     $clade->getSiblingDepthFirstIndex()), "\n");
  }
}

sub undoTables {
  my ($self) = @_;

  return ('ApiDB.OrthomclTaxon',
	 );
}



1;
