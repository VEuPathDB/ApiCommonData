package ApiCommonData::Load::Plugin::ReconcilePopBioSpeciesIds;
@ISA = qw(GUS::PluginMgr::Plugin);
use GUS::PluginMgr::Plugin;
use strict;

use GUS::Model::Study::ProtocolAppNode;
use GUS::Model::Study::ProtocolApp;
use GUS::Model::Study::ProtocolAppParam;
use GUS::Model::Study::Input;
use GUS::Model::Study::Output;
use GUS::Model::Study::Protocol;
use GUS::Model::Study::ProtocolSeriesLink;
use GUS::Model::Study::ProtocolParam;
use GUS::Model::Study::Characteristic;
use GUS::Model::Study::StudyLink;
use GUS::Model::Study::Study;

use GUS::Model::SRes::OntologyTerm;

use Scalar::Util qw(blessed);
use POSIX qw/strftime/;
use File::Temp qw/ tempfile /;

use Data::Dumper;

my $argsDeclaration =
  [

   stringArg({name           => 'extDbRlsSpec',
	      descr          => 'external database release spec',
	      reqd           => 1,
	      constraintFunc => undef,
	      isList         => 0, }),

  ];

my $documentation = { purpose          => "",
                      purposeBrief     => "",
                      notes            => "",
                      tablesAffected   => "",
                      tablesDependedOn => "",
                      howToRestart     => "",
                      failureCases     => "" };

# ----------------------------------------------------------------------
sub getIsReportMode { }

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
  my $extDbRlsSpec = $self->getArg('extDbRlsSpec');
  my $extDbRlsId = $self->getExtDbRlsId($extDbRlsSpec);

  my $investigation = GUS::Model::Study::Study->new({investigation_id=>undef, external_database_release_id=>$extDbRlsId});

  if ($investigation->retrieveFromDB()) {
    my $investigationId = $investigation->getStudyId(); # yes this is correct
    my $study = GUS::Model::Study::Study->new({investigation_id=>$investigationId, external_database_release_id=>$extDbRlsId});
    $study->retrieveFromDB();
    $self->log("LOG\tgot study named >".$study->getName()."< for investigation_id $investigationId");
    my $studyId = $study->getStudyId();

    # get all protocolapp nodes where isa_type = 'Sample' belonging to this Study
    my $studyToSamplesSql = << 'EOT';
select sl.protocol_app_node_id
from study.studylink sl, study.protocolappnode pan
where sl.study_id = ?
and sl.protocol_app_node_id = pan.protocol_app_node_id
and pan.isa_type = 'Sample'
EOT

    my $dbh = $self->getQueryHandle();
    my $studyToSamples = $dbh->prepare($studyToSamplesSql);
    $studyToSamples->execute($studyId);
    # foreach sample
    while (my ($panId) = $studyToSamples->fetchrow_array()) {
      my $sample = GUS::Model::Study::ProtocolAppNode->new({protocol_app_node_id => $panId});
      $sample->retrieveFromDB();

      $self->log("LOG\tGot a sample named '".$sample->getName."'");

      ## get all PANs that are immediate outputs of sample with characteristics with qualifier "species assay result" --> species_PANs
      ## exclude those with deprecated term
      ## perform business logic with the ontology term values of the species_PANs and end up with one species term --> final_species
      ## add new characteristic to 'sample' with value final_species

    }

  } else {
    $self->error("could not find Study with extDbRlsSpec '$extDbRlsSpec'");
  }

  return("TO DO: Add return value here.");
}



sub undoTables {
  my ($self) = @_;

  return (
#    'Study.Characteristic',
     );
}

1;
