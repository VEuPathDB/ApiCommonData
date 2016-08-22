package ApiCommonData::Load::Plugin::fixCDScoords;
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
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^
@ISA = qw( GUS::PluginMgr::Plugin);

use strict;

use Getopt::Long;
use GUS::PluginMgr::Plugin;
use GUS::ObjRelP::DbiDatabase;
use GUS::Supported::GusConfig;
use GUS::Model::DoTS::ExonFeature;

my $purposeBrief = <<PURPOSEBRIEF;
This script has a one time intended use of correcting the CDS coding start/stop for T.gondii data in the toxo projects
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
This script has a one time intended use of correcting the CDS coding start/stop for T.gondii data in the toxo projects
PLUGIN_PURPOSE

my $tablesAffected =
	[['DoTS.ExonFeature', 'The entries for the codingStart/Stop will be fixed.']];

my $tablesDependedOn = [['DoTS.NALocation', 'The exonStop/Starts will come from here.'],['DoTS.ExonFeature','The exons must exist here.']];

my $howToRestart = <<PLUGIN_RESTART;
There is currently no restart method.
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
There are no known failure cases.
PLUGIN_FAILURE_CASES

my $notes = <<PLUGIN_NOTES;

PLUGIN_NOTES

my $documentation = { purpose=>$purpose,
		      purposeBrief=>$purposeBrief,
		      tablesAffected=>$tablesAffected,
		      tablesDependedOn=>$tablesDependedOn,
		      howToRestart=>$howToRestart,
		      failureCases=>$failureCases,
		      notes=>$notes
		    };


my $argsDeclaration =
  [
	 stringArg ({name  => 'algInvocId',
	              descr => 'The row_alg_invocation_id to update.',
                      constraintFunc => undef,
	              reqd  => 1,
                      isList => 0,
                     }),
  ];


sub new {
    my ($class) = @_;
    my $self = {};
    bless($self,$class);


    $self->initialize({requiredDbVersion => 3.6,
		       cvsRevision => '$Revision$', # cvs fills this in!
		       name => ref($self),
		       argsDeclaration => $argsDeclaration,
		       documentation => $documentation
		      });

    return $self;
}

sub run {
  my ($self) = @_;

  my $msg = $self->fixExons();

  return $msg;

}


sub fixExons{
  my ($self) = @_;
  my %exons;
  my $dbh = $self->getQueryHandle();
  my $algInvocId = $self->getArg('algInvocId');

  my $idSQL = <<EOSQL;
  SELECT e.na_feature_id, l.start_max, l.end_min, l.is_reversed
  FROM   DoTS.ExonFeature e,
         DoTS.NALocation l
  WHERE  e.na_feature_id = l.na_feature_id
    AND  e.row_alg_invocation_id = $algInvocId
EOSQL

  my $sth = $dbh->prepareAndExecute($idSQL);

  print STDERR "Retrieving exon feature locations\n";

  while (my ($featureId, $exonStart, $exonEnd, $strand) = $sth->fetchrow_array()) {
    push(@{$exons{$featureId}}, [$strand, $exonStart, $exonEnd]);
  }

  foreach my $exon (keys %exons){
    my $exonFeature = GUS::Model::DoTS::ExonFeature->new({'na_feature_id'=> $exon});

    $exonFeature->retrieveFromDB();

    print STDERR "Fixing exon feature $exon\n";

    foreach my $array (@{%exons->{$exon}}){
      if($$array[0]){
	$exonFeature->setCodingStart($$array[2]);
	$exonFeature->setCodingEnd($$array[1]);
      }
      else{
	$exonFeature->setCodingStart($$array[1]);
	$exonFeature->setCodingEnd($$array[2]);
      }
    }

    $exonFeature->submit();
    $self->undefPointerCache();

  }

  $sth->finish();
}

1;
