package ApiCommonData::Load::Plugin::InsertOrthologousGroups;

@ISA = qw(GUS::PluginMgr::Plugin);

# ----------------------------------------------------------------------

use strict;
use GUS::PluginMgr::Plugin;
use FileHandle;

use GUS::Model::DoTS::SequenceSequenceGroup;
use GUS::Model::DoTS::OrthologExperiment;
use GUS::Model::DoTS::SequenceGroup;
use GUS::Model::Core::TableInfo;

use ApiCommonData::Load::Util;


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
	   format         => 'ORTHOMCL9(446 genes,1 taxa): osa1088(osa) osa1089(osa) osa11015(osa)...',
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

  stringArg({ descr => 'List of taxon abbrevs we want to load (eg: pfa, pvi)',
	      name  => 'taxaToLoad',
	      isList    => 1,
	      reqd  => 1,
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

  open(FILE, $self->getArg('OrthologFile')) || die "Could Not open Ortholog File for reading: $!\n";

  my $orthologExperimentId = $self->_makeOrthologExperiment();
  my $elementResultTableId = $self->_getElementResultTableId();

  my ($expLoaded, $seqGroupLoaded, $seqSeqGroupLoaded, $skipped) = (1);

  my $counter = 0;

  my $taxaToLoad = $self->getArg('taxaToLoad');

  while (my $line = <FILE>) {
    chomp($line);
    $counter++;
    if ($counter % 1000 == 0) {
      $self->log("Processed $counter lines");
    }

    my ($orthoName, $restOfLine) = split(':', $line);
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
      ('DoTS::GeneFeature'=> \&ApiCommonData::Load::Util::getGeneFeatureId,
       'DoTS::SplicedNASequence'=> \&ApiCommonData::Load::Util::getSplicedNASequenceId);
    foreach my $sourceId (@foundIds) {
      my $geneFeatureId = $sourceid_method{$sourceIdTable}->($self, $sourceId);
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
