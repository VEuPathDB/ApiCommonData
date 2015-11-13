package ApiCommonData::Load::Plugin::InsertInvestigations;

@ISA = qw(GUS::PluginMgr::Plugin);
use GUS::PluginMgr::Plugin;
use strict;

use CBIL::ISA::Investigation;

use File::Basename;

use GUS::Model::Study::ProtocolAppNode;
use GUS::Model::Study::ProtocolApp;
use GUS::Model::Study::Input;
use GUS::Model::Study::Output;
use GUS::Model::Study::Protocol;
use GUS::Model::Study::Characteristic;
use GUS::Model::Study::StudyLink;

use GUS::Model::SRes::OntologyTerm;

use CBIL::ISA::Investigation;

use Data::Dumper;

my $argsDeclaration =
  [

   stringArg({name           => 'metaDataRoot',
            descr          => 'directory where to find directories of isa tab files',
            reqd           => 1,
            constraintFunc => undef,
            isList         => 0, }),

   stringArg({name           => 'investigationBaseName',
            descr          => 'directory where to find directories of isa tab files',
            reqd           => 1,
            constraintFunc => undef,
            isList         => 0, }),


   stringArg({name           => 'investigationSubset',
            descr          => 'Skip directory unless it is one of these',
            reqd           => 0,
            constraintFunc => undef,
            isList         => 1, }),

  ];

my $documentation = { purpose          => "",
                      purposeBrief     => "",
                      notes            => "",
                      tablesAffected   => "",
                      tablesDependedOn => "",
                      howToRestart     => "",
                      failureCases     => "" };

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

  my $metaDataRoot = $self->getArg('metaDataRoot');
  my $investigationBaseName = $self->getArg('investigationBaseName');

  my @investigationFiles;

  my $investigationSubset = $self->getArg('investigationSubset');
  if($investigationSubset) {
    @investigationFiles = map { "$metaDataRoot/$_/$investigationBaseName" } @$investigationSubset;
  }
  else { 
    @investigationFiles = glob "$metaDataRoot/*/$investigationBaseName";
  }

  foreach my $investigation (@investigationFiles) {
    my $dirname = dirname $investigation;
    my $investigation = CBIL::ISA::Investigation->new($investigationBaseName, $dirname, "\t");

    $investigation->parse();

    my $iOntologyTermAccessions = $investigation->getOntologyAccessionsHash();

    # TODO:  This should return a mapping to the found ontology term ids so I can use them later
    $self->checkOntologyTermsExist($iOntologyTermAccessions);

    $self->checkProtocols($study->getProtocols());

    my $studies = $investigation->getStudies();
    foreach my $study (@$studies) {
      my %foundDatasets;

      my $studyAssays = $study->getStudyAssays();
      foreach my $studyAssay (@$studyAssays) {
        my $comments = $studyAssay->getComments();
        foreach my $comment (@$comments) {
          next unless($comment->getQualifier() eq 'dataset_names');
          my @datasetNames = split(/;/, $comment->getValue());
          foreach my $datasetName (@datasetNames) {
            $foundDatasets{$datasetName}++;
          }
        }
      }
      $self->checkExistingDatabaseNodesAreHandled(\%foundDatasets, $study->getNodes());
      $self->checkExistingProtocolApplicationsAreHandledAndMark(\%foundDatasets, $study->getEdges());

      $self->loadNodesAndEdges($study);
    }
  }
}

sub checkProtocols {
  my ($self, $protocols) = @_;

  # check protocols easy
  # check no protocol series eash

  my $sql = "select name from study.protocol";

  my $dbh = $self->getQueryHandle();
  my $sh = $dbh->prepare($sql);
  $sh->execute();
  my %protocols;
  while(my ($protocol) = $sh->fetchrow_array()) {
    $protocols{$protocol} = 1;
  }
  $sh->finish();

  foreach(@$protocols) {
    $self->logOrError("Protocol $_ Not found in the database") unless($protocols{$_};
  }
}

sub loadNodesAndEdges {
  my ($self, $study) = @_;

  $self->loadNodes($study->getNodes());
  $self->loadEdges($study->getEdges());
}


sub loadNodes {
  my ($self, $nodes) = @_;

  foreach my $node (@$nodes) {
    my $pan;
    if(my $panId = $node->{_PROTOCOL_APP_NODE_ID}) {
      $pan = GUS::Model::Study::ProtocolAppNode->new({protocol_app_node_id => $panId});
      unless($pan->retrieveFromDB()) {
        $self->error("Could not retrieve ProtocolAppNode [$panId] w/ name " . $node->getValue());
      }
    }
    else {
      $pan = GUS::Model::Study::ProtocolAppNode->new({name => $node->getValue()});
    }

    # TODO: if Material entity need to get type, else set to "data transformation" ?

    my $characteristics = $node->getCharacteristics();
    foreach my $characteristic (@$characteristics) {
      # TODO: Make new CHaracteristic and set parent
      # Deal w/ OntologyTerm Correctly
    }
  }
}

sub loadEdges {
  my ($self, $edges) = @_;

  # TODO:  check _DATABASE_STATUS for each node (does it have outputs, inputs and outputs or neither
  # if it has both ... should add parametervalues/params if they don't already exist
  # if only has outputs ... add inputs and paramvalues/params
  #if neither, need to make/get the protocol, params, paramvalues, protocolapp, inputs and outputs
}



sub checkExistingProtocolApplicationsAreHandledAndMark {
  my ($self, $foundDatasets, $edges) = @_;

  my $sql = "select * from (
select d.name dataset, p.name protocol, pa.PROTOCOL_APP_ID, pan.name, pan.protocol_app_node_id, 'input' as io
from study.protocolapp pa
   , study.protocol p
   , study.input i
   , study.protocolappnode pan
   , study.studylink sl
   , study.study s
   , study.study i
   , SRES.EXTERNALDATABASE d
   , sres.externaldatabaserelease r
where pa.PROTOCOL_ID = p.protocol_id
and pa.PROTOCOL_APP_ID = i.PROTOCOL_APP_ID
and i.PROTOCOL_APP_NODE_ID = pan.PROTOCOL_APP_NODE_ID
and pan.PROTOCOL_APP_NODE_ID = sl.PROTOCOL_APP_NODE_ID
and sl.STUDY_ID = s.study_id
and s.INVESTIGATION_ID = i.STUDY_ID
and i.EXTERNAL_DATABASE_RELEASE_ID = r.EXTERNAL_DATABASE_RELEASE_ID
and r.EXTERNAL_DATABASE_ID = d.external_database_id
union
select d.name dataset, p.name protocol, pa.PROTOCOL_APP_ID, pan.name, pan.protocol_app_node_id, 'output' as io
from study.protocolapp pa
   , study.protocol p
   , study.Output i
   , study.protocolappnode pan
   , study.studylink sl
   , study.study s
   , study.study i
   , SRES.EXTERNALDATABASE d
   , sres.externaldatabaserelease r
where pa.PROTOCOL_ID = p.protocol_id
and pa.PROTOCOL_APP_ID = i.PROTOCOL_APP_ID
and i.PROTOCOL_APP_NODE_ID = pan.PROTOCOL_APP_NODE_ID
and pan.PROTOCOL_APP_NODE_ID = sl.PROTOCOL_APP_NODE_ID
and sl.STUDY_ID = s.study_id
and s.INVESTIGATION_ID = i.STUDY_ID
and i.EXTERNAL_DATABASE_RELEASE_ID = r.EXTERNAL_DATABASE_RELEASE_ID
and r.EXTERNAL_DATABASE_ID = d.external_database_id
) 
where dataset = ? ";

  my $dbh = $self->getQueryHandle();
  my $sh = $dbh->prepare($sql);

  my $databaseEdges = {};
  foreach my $datasetName(keys %$foundDatasets) {
    $sh->execute($datasetName);
    while(my ($dataset, $protocol, $protocolAppId, $pan, $panId, $io) = $sh->fetchrow_array()) {
      push @{$databaseEdges->{$protocol}->{$protocolAppId}->{$io}}, $pan;
    }
    $sh->finish();
  }

  foreach my $databaseProtocol (keys %$databaseEdges) {
    foreach my $protocolAppId (keys %{$databaseEdges->{$databaseProtocol}}) {

      my @databaseOutputs = sort @{$databaseEdges->{$databaseProtocol}->{$protocolAppId}->{output}};

      unless(scalar @databaseOutputs > 0) {
        $self->logOrError("ProtocolApp [$protocolAppId] is missing Outputs");
      }

      my $found;

      foreach my $edge (@$edges) {
        my $protocolApps = $edge->getProtocolApplications();

        # Not in the business of matching protocol series.  
        next if(scalar @$protocolApps > 1);
        my $protocolApp = $protocolApps->[0];

        next unless($databaseProtocol eq $protocolApp->getValue());

        my @outputs = sort map { $_->getValue()} @{$edge->getOutputs()};
        next unless(join(".", @outputs) eq join(".", @databaseOutputs));

        $found++;
        $edge->{_DATABASE_STATUS} = 'FOUND_OUTPUTS';
        $edge->{_PROTOCOL_APP_ID} = $protocolAppId;

        if($databaseEdges->{$databaseProtocol}->{$protocolAppId}->{input}) {
          my @databaseInputs = sort @{$databaseEdges->{$databaseProtocol}->{$protocolAppId}->{input}};
          my @inputs = sort map {$_->getValue()} @{$edge->getInputs()};

          $self->logOrError("Inputs found for ProtocolApp [$protocolApp] but they do not match the Inputs defined for this Edge in the ISA Tab File") unless(join(".", @inputs) eq join(".", @databaseInputs));
          $edge->{_DATABASE_STATUS} = 'FOUND_OUTPUTS_AND_INPUTS';
        }
      }
      $self->logOrError("ProtocolApp [$protocolAppId] could not be matched to Edges in the ISA Tab file") unless($found);
    }
  }
}


sub checkOntologyTermsExist {
  my ($self, $iOntologyTermAccessionsHash) = @_;

  my $sql = "select d.name, ot.source_id
from sres.ontologyterm ot
   , sres.externaldatabaserelease r
   , sres.externaldatabase d
where (ot.source_id = ? OR ot.name = ?)
and lower(ot.source_id) not like 'ncbitaxon%'
and ot.EXTERNAL_DATABASE_RELEASE_ID = r.EXTERNAL_DATABASE_RELEASE_ID
and r.EXTERNAL_DATABASE_ID = d.EXTERNAL_DATABASE_ID
UNION
select 'NCBITaxon', 'NCBITaxon_' || ncbi_tax_id
from sres.taxon 
where 'NCBITaxon_' || ncbi_tax_id = ?
and lower(?) like  'ncbitaxon%'
";

  my $dbh = $self->getQueryHandle();
  my $sh = $dbh->prepare($sql);

  foreach my $os (keys %$iOntologyTermAccessionsHash) {
    foreach my $ota (keys %{$iOntologyTermAccessionsHash->{$os}}) {
      my $accessionOrName = basename $ota;
      $sh->execute($accessionOrName, $accessionOrName, $accessionOrName, $accessionOrName);

      my %foundIn;
      while(my ($os, $sourceId) = $sh->fetchrow_array()) {
        $foundIn{$os} = $sourceId;
      }

      unless(scalar keys %foundIn > 0) {
        $self->logOrError("ERROR:  Neither OntologyTerm Accession nor Name [$accessionOrName] was not found in the database");
      }

      if(scalar keys %foundIn > 1) {

        my $found;
        foreach my $extDbName (keys %foundIn) {
          my $accession = $foundIn{$extDbName};

          my $lcOs = lc $os;
          $found++ if($extDbName =~ /_${lcOs}_/);

          my @splitAccession = split(/_/, $accession);
          my $lcSplitAccession = lc($splitAccession[0]);
          $found++ if($extDbName =~ /_${lcSplitAccession}_/);
        }

        unless($found) {
          $self->logOrError("ERROR:  OntologyTerms with Accession Or Name [$accessionOrName] were found multiple times in the database but none for source $os and none where the loaded source matches the prefix of the accession");
        }
      }
    }
  }
}

sub checkExistingDatabaseNodesAreHandled {
  my ($self, $foundDatasets, $nodes) = @_;

  unless(scalar keys %$foundDatasets > 0) {
    $self->logOrError("ERROR:  Required Comment[dataset_name] for assay not found");
  }

  my $sql = "select pan.name, pan.protocol_app_node_id
from apidb.datasource ds
   , SRES.EXTERNALDATABASE d
   , SRES.EXTERNALDATABASERELEASE r
   , study.study i
   , study.study ps
   , study.studylink sl
   , STUDY.PROTOCOLAPPNODE pan
where ds.name = ?
 and ds.EXTERNAL_DATABASE_NAME = d.name
 and d.EXTERNAL_DATABASE_ID = r.EXTERNAL_DATABASE_ID
 and r.EXTERNAL_DATABASE_RELEASE_ID = i.EXTERNAL_DATABASE_RELEASE_ID
 and i.STUDY_ID = ps.INVESTIGATION_ID
 and ps.study_id = sl.study_id
 and sl.PROTOCOL_APP_NODE_ID = pan.PROTOCOL_APP_NODE_ID
 UNION
select pan.name, pan.protocol_app_node_id
from apidb.datasource ds
   , SRES.EXTERNALDATABASE d
   , SRES.EXTERNALDATABASERELEASE r
   , study.study i
    , study.studylink sl
   , STUDY.PROTOCOLAPPNODE pan
where ds.name = ?
 and ds.EXTERNAL_DATABASE_NAME = d.name
 and d.EXTERNAL_DATABASE_ID = r.EXTERNAL_DATABASE_ID
 and r.EXTERNAL_DATABASE_RELEASE_ID = i.EXTERNAL_DATABASE_RELEASE_ID
 and i.STUDY_ID = sl.study_id
 and sl.PROTOCOL_APP_NODE_ID = pan.PROTOCOL_APP_NODE_ID";

  my $dbh = $self->getQueryHandle();
  my $sh = $dbh->prepare($sql);

  my %studyNodes;

  foreach my $datasetName(keys %$foundDatasets) {
    $sh->execute($datasetName, $datasetName);

    while(my ($pan, $panId) = $sh->fetchrow_array()) {
      push @{$studyNodes{$pan}}, $panId;

      my $found = 0;
      foreach my $node (@$nodes) {
        if($node->getValue() eq $pan) {
          $node->{_PROTOCOL_APP_NODE_ID} = $panId;
          $found++ ;
        }
      }

      unless($found == 1) {
        $self->logOrError("ERROR:  ProtocolAppNode named $pan for dataset $datasetName was not handled in the ISATab file.  Found it $found times.");
      }
    }
    $sh->finish();
  }

  foreach my $pan (keys %studyNodes) {
    $self->logOrError("ProtocolAppNode name $pan not unique w/in a study") if(scalar @{$studyNodes{$pan}} > 1);
  }

  return \%studyNodes
}

sub logOrError {
  my ($self, $msg) = @_;

  if($self->getArg('commit')) {
    $self->userError($msg);
  }
  else {
    $self->log($msg);
  }
}


sub undoTables {
  my ($self) = @_;

  return ( 
    'Study.Input',
    'Study.Output',
    'Study.Characteristic',
    'Study.ProtocolAppNode',
    'Study.ProtocolApp',
     );
}

1;

