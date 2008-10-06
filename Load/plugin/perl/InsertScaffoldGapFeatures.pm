package ApiCommonData::Load::Plugin::InsertScaffoldGapFeatures;

@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use GUS::PluginMgr::Plugin;
use GUS::Model::DoTS::ScaffoldGapFeature;
use GUS::Model::DoTS::NALocation;
use GUS::Model::SRes::SequenceOntology;


sub getArgsDeclaration {
my $argsDeclaration  =
[

stringArg({name => 'extDbRlsName',
       descr => 'External database for the scaffolds',
       constraintFunc=> undef,
       reqd  => 1,
       isList => 0
      }),

stringArg({name => 'extDbRlsVer',
       descr => 'Version of external database for the scaffolds',
       constraintFunc=> undef,
       reqd  => 1,
       isList => 0
      }),

stringArg({name => 'SOTerm',
       descr => 'SO term for the gap',
       constraintFunc=> undef,
       reqd  => 0,
       isList => 0,
       default => "gap",
      }),
 integerArg({name => 'gapSize',
       descr => 'Number of Ns inserted between contigs in a scaffold',
       constraintFunc=> undef,
       reqd  => 0,
       isList => 0,
       default => 100,
      })
];

return $argsDeclaration;
}


# ----------------------------------------------------------
# Documentation
# ----------------------------------------------------------

sub getDocumentation {

my $description = <<NOTES;
NOTES

my $purpose = <<PURPOSE;
To load gap info for scaffolds into the database.
PURPOSE

my $purposeBrief = <<PURPOSEBRIEF;
For every scaffold, the plugin find the poistions of the gaps, and loads this info the ScaffoldGapFeature and NALocation tables.
PURPOSEBRIEF

my $syntax = <<SYNTAX;
SYNTAX

my $notes = <<NOTES;
NOTES

my $tablesAffected = <<AFFECT;
AFFECT

my $tablesDependedOn = <<TABD;
TABD

my $howToRestart = <<RESTART;
RESTART

my $failureCases = <<FAIL;
FAIL

my $documentation = {purpose=>$purpose, purposeBrief=>$purposeBrief,tablesAffected=>$tablesAffected,tablesDependedOn=>$tablesDependedOn,howToRestart=>$howToRestart,failureCases=>$failureCases,notes=>$notes};

return ($documentation);
}


sub new {
  my $class = shift;
  my $self = {};
  bless($self, $class);
  bless($self, $class);

  my $documentation = &getDocumentation();

  my $args = &getArgsDeclaration();

  my $configuration = {requiredDbVersion => 3.5,
		       cvsRevision => '$Revision$',
		       cvsTag => '$Name$',
		       name => ref($self),
		       revisionNotes => '',
		       argsDeclaration => $args,
		       documentation => $documentation
		      };
  $self->initialize($configuration);

  return $self;
}


sub run {
  my $self = shift;

  my $extDbName = $self->getArg('extDbRlsName');
  my $extDbVer = $self->getArg('extDbRlsVer');
  my $extDbRlsId = $self->getExtDbRlsId($extDbName, $extDbVer)
    or die "Couldn't find source db: $extDbName, $extDbVer\n";

  my $SOTermArg = $self->getArg("SOTerm");
  my $SOTerm = GUS::Model::SRes::SequenceOntology->new({ term_name => $SOTermArg });
  unless($SOTerm->retrieveFromDB()) {
    die "SO Term $SOTerm not found in database.\n";
  }
  my $SOTermId = $SOTerm->getId();

  my $gapSize = $self->getArg("gapSize");

  # retrieve sequences for each scaffold in a hash
  my $scaffSeqsRef = $self->retrieveScaffoldSeqs($extDbRlsId);

  # for each scaffold, create a row in ScaffoldGapFeature, with chr coords for the gaps
  my $ct = $self->makeGapFeatureAssignments($scaffSeqsRef, $extDbRlsId, $gapSize, $SOTermArg, $SOTermId);

  return("$ct scaffold gap features created.");
}

# retrieve sequences of scaffolds in a hash
sub retrieveScaffoldSeqs {
  my ($self, $extDbRlsId) = @_;

  my $dbh = $self->getQueryHandle();
  my %scaffSeqs;

  my $stmt = $dbh->prepare("SELECT na_sequence_id, sequence FROM DoTS.ExternalNASequence WHERE external_database_release_id =?");
  $stmt->execute($extDbRlsId);

  while(my ($na_seq_id, $seq) = $stmt->fetchrow_array()) {
    $scaffSeqs{$na_seq_id}=$seq;
  }

  $self->undefPointerCache();
  return(\%scaffSeqs);
}

sub makeGapFeatureAssignments {
  my ($self, $scaffRef, $extDbRlsId, $gapSize, $termName, $seqOntId) = @_;

  my $count=0;
  my %map = %{$scaffRef};
  my @keyed = keys(%map);  # array of scaffold IDs
  $self->log("Number of scaffolds = $#keyed");

  foreach my $key (@keyed) {
    my $seq = $map{$key};

    my $start = $self->getScaffStart($key);  # get location of scaffold on chromosome, if mapped
    $start =1 if (!$start);                  # for scaffold that are not mapped to chromosomes

    my $gapLocsRef = $self->findGapLocations($start, $seq, $key, $gapSize);
    my @gapLocations = @$gapLocsRef;   # gap locations for a particular scaffold

    # now, for each gap location, create rows in  dots.ScaffoldGapFeature
    foreach my $loc (@gapLocations) {
      my $scaffGap = $self->createScaffoldGapEntry($key, $extDbRlsId, $gapSize, $termName, $seqOntId);

      my $naLocation = $self->createNaLocation($loc, ($loc+$gapSize));

      $$scaffGap->addChild($$naLocation);
      $$scaffGap->submit();
      $count++;
    }
  }
  return $count;
}

sub getScaffStart {
  my ($self, $naSeqId) = @_;

  my $dbh = $self->getQueryHandle();
  my $stmt = $dbh->prepare("SELECT startm FROM apidb.scaffold_map WHERE piece_na_sequence_id =?");
  $stmt->execute($naSeqId);

  my ($start) = $stmt->fetchrow_array();
  $self->undefPointerCache();

  return ($start);
}

# find gap locations for each scaffold, **in chromosome coordinates**
sub findGapLocations {
  my ($self, $start, $seq, $naSeqId, $gapSize) = @_;

  my $prev_pos = 0;
  my $pos;
  my @locations;

  while( $seq =~ m/(NNN*)/gi){
    $pos = index ($seq, $1, $prev_pos);
    push (@locations, $pos+1+$start);   # $start is the scaffold start in chromosome
    $prev_pos = $pos + $gapSize;
  }
  return \@locations;
}


sub createScaffoldGapEntry{
  my ($self, $naSeqId, $extDbRlsId, $gapSize, $termName, $seqOntId) = @_;

  my $scaffGap = GUS::Model::DoTS::ScaffoldGapFeature->new({na_sequence_id => $naSeqId,
							    name => $termName,
							    sequence_ontology_id => $seqOntId,
							    external_database_release_id => $extDbRlsId,
							    min_size => $gapSize,
							    max_size => $gapSize,
							   });
  return \$scaffGap;
}

sub createNaLocation{
  my ($self, $start, $end) = @_;

  my $naLocation = GUS::Model::DoTS::NALocation->new({start_min => $start,
						      start_max => $start,
						      end_min => $end,
						      end_max => $end,
						     });
  return \$naLocation;

}

1;
