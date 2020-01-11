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
    while (my ($samplePanId) = $studyToSamples->fetchrow_array()) {
      my $sample = GUS::Model::Study::ProtocolAppNode->new({protocol_app_node_id => $samplePanId});
      $sample->retrieveFromDB();

      $self->log("LOG\tGot a sample: '".$sample->getName()."'");

      # get all PANs that are immediate outputs of sample
      # that have characteristics with qualifier "species assay result"
      # and get the characteristic.ontology_term_id results of those
      my $sampleToSpeciesAssayResultsSql = << 'EOT';
select spt.ontology_term_id
from study.protocolappnode ni, study.output i, study.protocolapp a, study.input o, study.protocolappnode no,
     study.characteristic noc, sres.ontologyterm qt, sres.ontologyterm spt
where ni.protocol_app_node_id = o.protocol_app_node_id and
      o.protocol_app_id = a.protocol_app_id and
      i.protocol_app_id = a.protocol_app_id and
      no.protocol_app_node_id = i.protocol_app_node_id and
      ni.protocol_app_node_id = ? and
      no.protocol_app_node_id = noc.protocol_app_node_id and
      noc.qualifier_id = qt.ontology_term_id and
      qt.name = 'species assay result' and
      noc.ontology_term_id = spt.ontology_term_id
EOT

      my $sampleToSpeciesAssayResults = $dbh->prepare($sampleToSpeciesAssayResultsSql);
      $sampleToSpeciesAssayResults->execute($samplePanId);
      # foreach species term
      while (my ($speciesTermId) = $sampleToSpeciesAssayResults->fetchrow_array()) {
	my $speciesTerm = GUS::Model::SRes::OntologyTerm->new({ontology_term_id => $speciesTermId});
	$speciesTerm->retrieveFromDB();

	$self->log("LOG\t\tRaw species: '".$speciesTerm->getName()."'");
      }
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
