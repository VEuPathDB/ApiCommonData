package ApiCommonData::Load::Plugin::InsertOrthologousGroups;
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

# ----------------------------------------------------------------------

use strict;
use GUS::PluginMgr::Plugin;
use FileHandle;

use GUS::Model::DoTS::SequenceSequenceGroup;
use GUS::Model::DoTS::OrthologExperiment;
use GUS::Model::DoTS::SequenceGroup;
use GUS::Model::Core::TableInfo;

use GUS::Supported::Util;


my $argsDeclaration =
  [

   enumArg({ descr => 'Table that holds the members of the groups.  (The portal uses DoTS::SplicedNaSequence)',
	   name  => 'ElementResultTable',
	   isList    => 0,
	   constraintFunc => undef,
	   reqd           => 0,
	   enum => "DoTS::GeneFeature, DoTS::SplicedNASequence",
	   default => "DoTS::GeneFeature"
	 }),

  fileArg({name          => 'OrthologFile',
	   descr          => 'Ortholog Data (ortho.mcl). OrthologGroupName followed by a colon then the ids for the members of the group',
	   reqd           => 1,
	   mustExist      => 1,
	   format         => 'OG2_1009: osa|ENS1222992 pfa|PF11_0844...',
	   constraintFunc => undef,
	   isList         => 0, }),

  stringArg({ descr => 'name of the orthoMCL analysis',
	      name  => 'AnalysisName',
	      isList    => 0,
	      reqd  => 1,
	      constraintFunc => undef,
	    }),

  stringArg({ descr => 'description of the orthoMCL analysis',
	      name  => 'AnalysisDescription',
	      isList    => 0,
	      reqd  => 1,
	      constraintFunc => undef,
	    }),

  stringArg({ descr => 'List of taxon abbrevs we want to load (eg: pfa, pvi).  If you provide this list then do not provide a projectName argument.',
	      name  => 'taxaToLoad',
	      isList    => 1,
	      reqd  => 0,
	      constraintFunc => undef,
	    }),

  stringArg({ descr => 'Use projectName to discover the set of orthomclAbbrevs to load from the ApiDB.Organism table (ie, those that are in this project).  If you provide this value then do not provide the taxaToLoad argument.',
	      name  => 'projectName',
	      isList    => 0,
	      reqd  => 0,
	      constraintFunc => undef,
	    }),

];

my $purpose = <<PURPOSE;
The purpose of this plugin is to insert rows representing orthologous groups.  Each time the plugin is run, a new Dots::OrthologExperiment is inserted.  Each child of OrthologExperiment represents a line from the orthologFile (ie an orthologGroup) and a row in Dots.SequenceGroup is inserted for each.  For each orthoId which can be mapped to a source_id a row in Dots.SequenceSequenceGroup is inserted.
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
Load an orthoMCL analysis.
PURPOSE_BRIEF

my $notes = <<NOTES;
Currently the Arg ElementResultTable should only be set to DoTS::GeneFeature
NOTES

my $tablesAffected = <<TABLES_AFFECTED;
DoTS::SequenceSequenceGroup,
DoTS::OrthologExperiment,
DoTS::SequenceGroup
TABLES_AFFECTED

my $tablesDependedOn = <<TABLES_DEPENDED_ON;
Core::TableInfo
TABLES_DEPENDED_ON

my $howToRestart = <<RESTART;
There are no restart facilities for this plugin
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

  $self->initialize({ requiredDbVersion => 4.0,
                      cvsRevision       => '$Revision$',
                      name              => ref($self),
                      argsDeclaration   => $argsDeclaration,
                      documentation     => $documentation});

  return $self;
}

# ======================================================================

sub run {
  my ($self) = @_;

  my $dbiDb = $self->getDb();
  $dbiDb->setMaximumNumberOfObjects(100000);

  my $taxaToLoad = $self->getArg('taxaToLoad');
  my $projectName = $self->getArg('projectName');

  $self->error("Provide only one or the other of these two arguments: --taxaToLoad and --projectName") if ($taxaToLoad && $projectName);

  if ($projectName) {
      my $sql = "select orthomcl_abbrev from ApiDB.Organism
                 where project_name = '$projectName'";
      my $sth = $self->prepareAndExecute($sql);
      while (my ($orthomclAbbrev) = $sth->fetchrow_array()) {
	  push(@$taxaToLoad, $orthomclAbbrev);
      }
  }

  open(FILE, $self->getArg('OrthologFile')) || die "Could Not open Ortholog File for reading: $!\n";

  my $orthologExperimentId = $self->_makeOrthologExperiment();
  my $elementResultTableId = $self->_getElementResultTableId();

  my ($expLoaded, $seqGroupLoaded, $seqSeqGroupLoaded, $skipped) = (1);

  my $counter = 0;

  while (my $line = <FILE>) {
    chomp($line);
    $counter++;
    if ($counter % 1000 == 0) {
      $self->log("Processed $counter lines");
    }

    my ($orthoName, @restsOfLine) = split(':', $line);
    my $restOfLine=join (':', @restsOfLine);
    my @elements = split(/\s+/, $restOfLine);

    my @foundIds;
    foreach my $element (@elements) {
      my ($taxonCode, $sourceId) = split(/\|/, $element);
      next unless grep(/$taxonCode/, @$taxaToLoad);
      push(@foundIds, $sourceId);
    }

    my $numElements = scalar(@foundIds);
    next if $numElements == 0;

    my $seqGroup = GUS::Model::DoTS::SequenceGroup->
      new({name => $orthoName,
           number_of_members => $numElements,
           sequence_group_experiment_id => $orthologExperimentId,
          });
    $seqGroupLoaded++;

    my $sourceIdTable = $self->getArg('ElementResultTable');
    my %sourceid_method =
      ('DoTS::GeneFeature'=> \&GUS::Supported::Util::getGeneFeatureId,
       'DoTS::SplicedNASequence'=> \&GUS::Supported::Util::getSplicedNASequenceId);
    foreach my $sourceId (@foundIds) {

      my @allIds = split(/\//, $sourceId);
      my @geneFeatureIds = map {$sourceid_method{$sourceIdTable}->($self, $_)} @allIds;

      my $geneFeatureId = $self->getSingleGeneFeatureId(\@geneFeatureIds, $sourceId);

      if ($geneFeatureId) {
	my $seqSeqGroup = GUS::Model::DoTS::SequenceSequenceGroup->
	  new({sequence_id => $geneFeatureId,
	       source_table_id => $elementResultTableId,
	      })->setParent($seqGroup);
	$seqSeqGroupLoaded++;
      } else {
	print STDERR "Skipping $sourceId\n";
	$skipped++;
      }
    }

    $seqGroup->submit();
    $self->undefPointerCache();
  }
  return("Inserted $expLoaded OrthologExperiment, $seqGroupLoaded SequenceGroups, and $seqSeqGroupLoaded SequenceSequenceGroups.  Skipped $skipped lines");
}


sub getSingleGeneFeatureId {
  my ($self, $geneFeatureIds, $sourceId) = @_;

  my %geneFeatures;
  my $geneFeature;

  foreach(@$geneFeatureIds) {
    next unless $_;

    $geneFeatures{$_} = 1;
    $geneFeature = $_;
  }

  if(scalar keys %geneFeatures > 1) {
    $self->error("More than one gene feature Id idenfied for sourceId $sourceId");
  }
  return $geneFeature;
}



# ----------------------------------------------------------------------

=pod

=head2 Subroutines

=over 4

=item C<_getElementResultTableId>

getter for result table id

B<Return type:> C<scalar>

=cut

sub _getElementResultTableId {
  my ($self) = @_;

  my $rv;

  my $fullName = $self->getArgs()->{ElementResultTable};
  my ($prefix, $suffix) = split('::', $fullName);

  my $tableInfo = GUS::Model::Core::TableInfo->
    new({name => $suffix});

  if (!$tableInfo->retrieveFromDB()) {
    die "TableName not uniquely matched in the db";
  }
  return($tableInfo->getId());
}

=pod

=item C<_makeOrthologExperiment>

build an OrthologExperiment Obj and retrieve its id.

B<Return type:> C<scalar>

primary key for the orthologExperiment

=cut

sub _makeOrthologExperiment {
  my ($self) = @_;

  my $orthologExperiment = GUS::Model::DoTS::OrthologExperiment->
    new({sequence_source => $self->getArgs()->{AnalysisName},
         description => $self->getArgs()->{AnalysisDescription},
        });

  $orthologExperiment->submit();
  $self->undefPointerCache();

  my $id = $orthologExperiment->getId();

  return($id);
}


# ----------------------------------------------------------------------

sub undoTables {
  my ($self) = @_;

  return ('DoTS.SequenceSequenceGroup',
          'DoTS.SequenceGroup',
          'DoTS.OrthologExperiment',
	 );
}

1;
