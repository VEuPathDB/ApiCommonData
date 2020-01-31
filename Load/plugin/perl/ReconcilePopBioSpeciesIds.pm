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
	      descr          => 'external database (more accurately, dataset) release spec',
	      reqd           => 1,
	      constraintFunc => undef,
	      isList         => 0, }),

   stringArg({name           => 'fallbackSpeciesAccession',
	      descr          => 'A tiny handful of datasets have some samples with no species ID assay performed on them. This option provides the ontology term accession for the fallback/default species to be assigned to these samples.',
	      reqd           => 0,
	      constraintFunc => undef,
	      isList         => 0, }),

  ];

my $documentation = { purpose          => "Merges multiple species identification results into one and adds this as a Sample Characteristic",
                      purposeBrief     => "Merges multiple species identification results into one and adds this as a Sample Characteristic",
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
  my %countQualifiers = ();

  my $computed_taxonomy_term = GUS::Model::SRes::OntologyTerm->new({source_id => 'VBcv_0001151'});
  $computed_taxonomy_term->retrieveFromDB() || $self->error("No ontology term found for computed_taxonomy_term/VBcv_0001151");

  my $computed_taxonomy_qualifier = GUS::Model::SRes::OntologyTerm->new({source_id => 'VBcv_0001152'});
  $computed_taxonomy_qualifier->retrieveFromDB() || $self->error("No ontology term found for computed_taxonomy_qualifier/VBcv_0001152");

  my $investigation = GUS::Model::Study::Study->new({investigation_id=>undef, external_database_release_id=>$extDbRlsId});

  if ($investigation->retrieveFromDB()) {
    my $investigationId = $investigation->getStudyId(); # yes this is correct
    my $study = GUS::Model::Study::Study->new({investigation_id=>$investigationId, external_database_release_id=>$extDbRlsId});
    $study->retrieveFromDB();
    $self->log("LOG\tgot study named '".$study->getName()."'");
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

      $self->log("LOG\tGot a sample: '".$sample->getName()."'") if ($self->getArg('verbose'));

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

      # reimplemented from https://github.com/bobular/VBPopBio/blob/30495e55b549b94fd053918b568de599db949150/api/Bio-Chado-VBPopBio/lib/Bio/Chado/VBPopBio/Result/Stock.pm#L586
      my $result; # ID of final species term
      my $qualifier = 'unambiguous';
      my $internalResult; # Boolean flag

      ## perform business logic with the ontology term values of the species_PANs and end up with one species term id --> $result
      while (my ($speciesTermId) = $sampleToSpeciesAssayResults->fetchrow_array()) {
	# retrieve the term just for human-readable logging purposes
	my $speciesTerm = GUS::Model::SRes::OntologyTerm->new({ontology_term_id => $speciesTermId});
	$speciesTerm->retrieveFromDB();
	$self->log("LOG\t\tRaw species: '".$speciesTerm->getName()) if ($self->getArg('verbose'));

	if (!defined $result) {
	  $result = $speciesTermId;
	} elsif ($self->isAchildofB($speciesTermId, $result)) {
	  # return the leaf-wards term unless we already chose an internal node
	  $result = $speciesTermId unless ($internalResult);
	} elsif ($speciesTermId == $result || $self->isAchildofB($result, $speciesTermId)) {
	  # that's fine - stick with the leaf term
	} else {
	  # we need to return a common 'ancestral' internal node
	  $result = $self->commonAncestor($result, $speciesTermId);
	  $internalResult = 1;
	  $qualifier = 'ambiguous';
	}
      }

      if (!defined $result) {
	my $fallbackSpeciesAccession = $self->getArg('fallbackSpeciesAccession');
	if ($fallbackSpeciesAccession) {
	  $fallbackSpeciesAccession =~ s/:/_/; # colon to underscore, if needed
	  my $fallbackTerm = GUS::Model::SRes::OntologyTerm->new({source_id => $fallbackSpeciesAccession});
	  if ($fallbackTerm->retrieveFromDB()) {
	    $result = $fallbackTerm->getOntologyTermId();
	    $qualifier = 'fallback';
	  } else {
	    $self->error("Could not find ontology term with source_id = fallbackSpeciesAccession '$fallbackSpeciesAccession'");
	  }
	} else {
	  $self->error("No species reconciliation result and no --fallbackSpeciesAccession option provided");
	}
      }

      if ($self->getArg('verbose')) {
	my $finalTerm = GUS::Model::SRes::OntologyTerm->new({ontology_term_id => $result});
	$finalTerm->retrieveFromDB();
	$self->log("LOG\t\tFinal species: '".$finalTerm->getName()."' ($qualifier)");
      }

      ## add new characteristic to 'sample' with value final_species

      my $characteristic =
	GUS::Model::Study::Characteristic->new({protocol_app_node_id => $samplePanId,
						qualifier_id => $computed_taxonomy_term->getOntologyTermId(),
						ontology_term_id => $result,
					       });
      $characteristic->submit();

      ## store the qualifier also
      my $characteristic2 =
	GUS::Model::Study::Characteristic->new({protocol_app_node_id => $samplePanId,
						qualifier_id => $computed_taxonomy_qualifier->getOntologyTermId(),
						value => $qualifier,
					       });
      $characteristic2->submit();

      $countQualifiers{$qualifier}++;
    }

  } else {
    $self->error("could not find Study with extDbRlsSpec '$extDbRlsSpec'");
  }
  my $summary = join ", ", map { "$countQualifiers{$_} $_" } keys %countQualifiers;
  return("Added computed taxonomy terms: $summary (samples)");
}



sub isAchildofB {
  my ($self, $termA_id, $termB_id) = @_;

  my $sql = << 'EOT';
with r1(subject_term_id, object_term_id) as (
  select subject_term_id, object_term_id
  from sres.ontologyrelationship r
  where object_term_id = ?
  union all
  select r2.subject_term_id, r2.object_term_id
  from sres.ontologyrelationship r2, r1
  where r2.object_term_id = r1.subject_term_id
)
select * from r1 where subject_term_id = ?
EOT

  my $dbh = $self->getQueryHandle();
  my $isChild = $dbh->prepare($sql);
  $isChild->execute($termB_id, $termA_id);

  # does it return something?
  my ($retval) = $isChild->fetchrow_array();
  return $retval ? 1 : 0;
}


sub commonAncestor {
  my ($self, $termA_id, $termB_id) = @_;

#
# find common ancestor (first row contains it)
#

  my $sql = << 'EOT';
with r1(subject_term_id, object_term_id, query_term_id, lvl) as (
  select subject_term_id, object_term_id, subject_term_id as query_term_id, 1 as lvl
  from sres.ontologyrelationship r
  where subject_term_id in (?, ?)
  union all
  select r2.subject_term_id, r2.object_term_id, query_term_id, lvl+1
  from sres.ontologyrelationship r2, r1
  where r2.subject_term_id = r1.object_term_id
)
select object_term_id
from r1
group by object_term_id
having count(distinct query_term_id) = 2
order by avg(lvl)
EOT

  my $dbh = $self->getQueryHandle();
  my $commonAncestor = $dbh->prepare($sql);
  $commonAncestor->execute($termA_id, $termB_id);

  # does it return something?
  my ($term_id) = $commonAncestor->fetchrow_array();
  return $term_id;
}

sub undoTables {
  my ($self) = @_;

  return (
    'Study.Characteristic',
      );
}

1;
