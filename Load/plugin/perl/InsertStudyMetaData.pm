package ApiCommonData::Load::Plugin::InsertStudyMetaData;
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
  # GUS4_STATUS | Study.OntologyEntry            | auto   | fixed
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | absent
  # GUS4_STATUS | RAD.Analysis                   | auto   | absent
  # GUS4_STATUS | ApiDB.Profile                  | auto   | fixed
  # GUS4_STATUS | Study.Study                    | auto   | fixed
  # GUS4_STATUS | Dots.Isolate                   | auto   | absent
  # GUS4_STATUS | DeprecatedTables               | auto   | absent
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

@ISA = qw(GUS::PluginMgr::Plugin);
use GUS::PluginMgr::Plugin;
use strict;

use GUS::Model::Study::ProtocolAppNode;
use GUS::Model::Study::ProtocolApp;
use GUS::Model::Study::Input;
use GUS::Model::Study::Output;
use GUS::Model::Study::Protocol;
use GUS::Model::Study::Characteristic;
use GUS::Model::Study::StudyLink;

use GUS::Model::SRes::OntologyTerm;

use Data::Dumper;

my $argsDeclaration =
  [
   stringArg({name           => 'studyExtDbRlsSpec',
            descr          => 'External Database Spec (external_database_name|external_database_version) for the study.',
            reqd           => 1,
            constraintFunc => undef,
            isList         => 0, }),


   stringArg({name           => 'orderedOntologyExtDbRlsSpecs',
            descr          => 'External Database Specs (external_database_name|external_database_version) for the ontologys which should be used if the term is available.  Ordered for the case when the term is found in more than one ontology ',
            reqd           => 1,
            constraintFunc => undef,
            isList         => 1, }),

   fileArg({name           => 'file',
            descr          => 'file for the sample data',
            reqd           => 1,
            mustExist      => 1,
            format         => '',
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

  $self->getDb()->setDoNotUpdateAlgoInvoId(1);

  my $studyExtDbRlsSpec = $self->getArg('studyExtDbRlsSpec');
  my $studyExtDbRlsId = $self->getExtDbRlsId($studyExtDbRlsSpec);

  $self->setStudyExtDbRlsId($studyExtDbRlsId);

  my $ontologySpecs = $self->getArg('orderedOntologyExtDbRlsSpecs');

  my @ontologyExtDbRlsIds = map { $self->getExtDbRlsId($_) } @$ontologySpecs;
  $self->setOrderedOntologyExtDbRlsIds(\@ontologyExtDbRlsIds);

  $self->setProtocolAppNodes($studyExtDbRlsId);

  $self->setOntologyStatementHandle();

  my $file = $self->getArg('file');
  open(FILE, $file) or $self->error("Cannot open file $file for reading: $!");

  my $header = <FILE>;
  chomp $header;

  $self->validateHeader($header);

  my $count = 0;
  while(<FILE>) {
    chomp;

    my $rowAsHash = $self->parseRow($header, $_);

    $self->processRow($rowAsHash);
    $count++;
  }

  close FILE;

  if($count < 1) {
    $self->userError("No rows processed. Please check your input file.");
  }

  return("Processed $count rows of sample meta data.");
}


sub setStudyExtDbRlsId {
  my ($self, $studyExtDbRlsId) = @_;

  $self->{_study_ext_db_rls_id} = $studyExtDbRlsId;
}

sub getStudyExtDbRlsId {
  my ($self) = @_;

  return $self->{_study_ext_db_rls_id};
}

sub setOntologyStatementHandle {
  my ($self) = @_;

  my $dbh = $self->getQueryHandle();
  my $sql ="select o.name as ontology_term_name
     , o.ontology_term_id
     , r.external_database_release_id 
     , d.name as external_database_name
     , rlsct.ct as ontology_count
from sres.externaldatabase d
   , sres.externaldatabaserelease r
   , sres.ontologyterm o
   , (select external_database_release_id, count(*) as ct from sres.ontologyterm group by external_database_release_id) rlsct
where o.name = ?
and o.external_database_release_id = r.external_database_release_id
and r.external_database_id = d.external_database_id
and rlsct.external_database_release_id = o.external_database_release_id"; 

  my $sh = $dbh->prepare($sql);

  $self->{_ontology_statement_handle} = $sh;
}

sub getOntologyStatementHandle {
  my ($self) = @_;

  return $self->{_ontology_statement_handle};
}

sub getOrderedOntologyExtDbRlsIds {
  my ($self) = @_;
  return $self->{_ordered_ontology_ext_db_rls_ids};
}

sub setOrderedOntologyExtDbRlsIds {
  my ($self, $orderedOntoloygExtDbRlsIds) = @_;
  $self->{_ordered_ontology_ext_db_rls_ids} = $orderedOntoloygExtDbRlsIds;
}


sub getProtocolAppNodeByName {
  my ($self, $name) = @_;

  return $self->{_protocol_app_nodes}->{sample}->{$name};
}

sub getHostProtocolAppNodeByName {
  my ($self, $name) = @_;
  return $self->{_protocol_app_nodes}->{host}->{$name};
}


sub lookupTaxonId {
  my ($self, $name) = @_;

  return unless($name);

  my $dbh = $self->getQueryHandle();
  my $sql = "select taxon_id
from sres.taxonname 
where name = ?";

  my $sh = $dbh->prepare($sql);
  $sh->execute($name);

  my $count;

  my $taxonId;
  while( my ($id) = $sh->fetchrow_array()) {
    $taxonId = $id;
    $count++;
  }
  $sh->finish();

  unless($count == 1) {
    $self->error("Found $count Rows in Taxon Name for $name");
  }

  return $taxonId;
}


sub setProtocolAppNodes {
  my ($self, $studyExtDbRlsId) = @_;

  my $dbh = $self->getQueryHandle();
  my $sql = "select sl.PROTOCOL_APP_NODE_ID
from study.study s
   , study.studylink sl
where s.EXTERNAL_DATABASE_RELEASE_ID = ?
and s.study_id = sl.STUDY_ID";

  my $sh = $dbh->prepare($sql);
  $sh->execute($studyExtDbRlsId);

  my %seen;

  while( my ($id) = $sh->fetchrow_array()) {
    my $pan = GUS::Model::Study::ProtocolAppNode->new({protocol_app_node_id => $id});
    unless($pan->retrieveFromDB()) {
      $self->error("Protocol app node $id not retrieved");
    }

    my $name = $pan->getName();
    if($seen{$name}) {
      $self->userError("This Study Has more than one protocol app node named $name");
    }
    $seen{$name} = 1;
    $self->{_protocol_app_nodes}->{sample}->{$name} = $pan;
  }
  $sh->finish();
}

sub validateHeader {
  my ($self, $header) = @_;

#  my @columns = split(/\t/, $header);
  my @columns = split("," , $header);
  my %counts;
  foreach my $column (@columns) {
    $counts{$column}++;
  }

  my @requiredSingleColumns = ('Name',
                               'Description',
                               'Taxon Name',
                               'Characteristics [Strain]',
                               'Host Name',
                               'Host Taxon Name',
      );

  my @otherRequiredColumns = ('Characteristics [Environmental Material]', 
                              'Characteristics [geographic location]',
      );


  foreach my $r (@requiredSingleColumns) {
    unless($counts{$r} == 1) {
      $self->userError("Required Column [$r] must be found exactly once");
    }
  }

  foreach my $r (@otherRequiredColumns) {
    unless($counts{$r} >= 1) {
      $self->userError("Required Column [$r] must be found at least once");
    }
  }
}


sub getHostByName {
  my ($self, $hostName) = @_;

  return $self->{_hosts}->{$hostName};
}

sub addHost {
  my ($self, $host) =@_;

  my $hostName = $host->getName();

  if($self->{_hosts}->{$hostName}) {
    $self->error("Should not be adding another host w/ same name $hostName.  getHostByName instead");
  }

  $self->{_hosts}->{$hostName} = $host;
}

sub processRow {
  my ($self, $rowAsHash) = @_;

  # already validated found exactly once  
  my $sampleName = $rowAsHash->{Name}->[0]; 
  my $description = $rowAsHash->{Description}->[0];
  my $taxonName = $rowAsHash->{'Taxon Name'}->[0]; 

  # host items already validated found exactly once  
  my $hostName = $rowAsHash->{'Host Name'}->[0]; 
  my $hostTaxonName = $rowAsHash->{'Host Taxon Name'}->[0]; 

  my $pan = $self->getProtocolAppNodeByName($sampleName);
  $pan->setDescription($description);

  my $taxonId = $self->lookupTaxonId($taxonName);
  $pan->setTaxonId($taxonId) if($taxonId);

  my $host = $self->getHostByName($hostName); # try to get obj from cache
  unless($host) {
    $host = GUS::Model::Study::ProtocolAppNode->new({name => $hostName});
    my $hostTaxonId = $self->lookupTaxonId($hostTaxonName);
    $host->setTaxonId($hostTaxonId) if($hostTaxonId);
  }

  $self->makeProtocolApplication($pan, $host);

  foreach my $key (keys %$rowAsHash) {
    next unless($key =~ /characteristics/i);


    foreach my $value (@{$rowAsHash->{$key}}) {
      my $characteristic = $self->makeCharacteristic($key, $value);
      $characteristic->setParent($pan);
    }
  }

  $pan->submit();
  $self->undefPointerCache();
}

sub makeProtocolApplication {
    my ($self, $pan, $host) = @_;

    my $protocolName = 'isolate collection from host';

    my $protocol = $self->makeProtocol($protocolName);

    my $protocolApp =  GUS::Model::Study::ProtocolApp->new();
    $protocolApp->setParent($protocol);

    my $input = GUS::Model::Study::Input->new();
    $input->setParent($protocolApp);
    $input->setParent($host);

    $protocolApp->addToSubmitList($input);

    my $output = GUS::Model::Study::Output->new();
    $output->setParent($protocolApp);
    $output->setParent($pan);

    return $protocolApp;
}

sub makeProtocol {
  my ($self, $protocolName) = @_;

  my $protocols = $self->getProtocols() or [];

  foreach my $protocol (@$protocols) {
    if($protocol->getName eq $protocolName) {
      return $protocol;
    }
  }

  my $protocol = GUS::Model::Study::Protocol->new({name => $protocolName});
  $protocol->retrieveFromDB();

  $self->addProtocol($protocol);

  return $protocol;
}

sub getProtocols { $_[0]->{_protocols} }
sub addProtocol  { push @{$_[0]->{_protocols}}, $_[1]; }


sub makeCharacteristic {
  my ($self, $header, $value) = @_;

  $self->error("Characteristic header malformed:  $header") unless($header =~ /characteristics \[(.+)\]/i);
  my $category = $1;

  # first look for the value.  If that is an ontologyterm use that and leave characteristics.value null
  my $valueTermId = $self->fetchOntologyTerm($value);
  if($valueTermId) {
    return GUS::Model::Study::Characteristic->new({ontology_term_id => $valueTermId});
  }

  # Require that the header at least be an existing ontology term and put the value as the string value
  my $categoryTermId = $self->fetchOntologyTerm($category);
  if($categoryTermId) {
    return GUS::Model::Study::Characteristic->new({ontology_term_id => $categoryTermId, value => $value});    
  }

  my $studyExtDbRlsId = $self->getStudyExtDbRlsId();
  my $newOntologyTerm = GUS::Model::SRes::OntologyTerm->new({name => $category, external_database_release_id => $studyExtDbRlsId});
  return GUS::Model::Study::Characteristic->new({ontology_term_id => $newOntologyTerm->getId(), value => $value});    
}

sub getCachedOntologyTerms {
  my ($self) = @_;

  return $self->{_cached_ontology_terms};
}

sub fetchOntologyTerm {
  my ($self, $term) = @_;

  my $cachedTerms = $self->getCachedOntologyTerms();

  if($cachedTerms->{$term}) {
    return $cachedTerms->{$term};
  }

  my $ontologyExtDbRlsIds = $self->getOrderedOntologyExtDbRlsIds();
  my $sh = $self->getOntologyStatementHandle();

  $sh->execute($term);

  my $ontologyExtDbRlsCount = scalar @$ontologyExtDbRlsIds;

  my @ar;

  while(my $row = $sh->fetchrow_hashref()) {

    $row->{ONTOLOGY_ORDER} = $ontologyExtDbRlsCount + 1;
    
    for(my $i = 0; $i < scalar @$ontologyExtDbRlsIds; $i++) {
      my $extDbRlsId = $ontologyExtDbRlsIds->[$i];

      if($row->{EXTERNAL_DATABASE_RELEASE_ID} == $extDbRlsId) {
        $row->{ONTOLOGY_ORDER} = $i;
      }
    }
    
    push @ar, $row;
  }
  $sh->finish();

  my @sorted = sort {$a->{ONTOLOGY_ORDER} <=> $b->{ONTOLOGY_ORDER} || $b->{ONTOLOGY_COUNT} <=> $a->{ONTOLOGY_COUNT} || $b->{ONTOLOGY_TERM_ID} <=> $a->{ONTOLOGY_TERM_ID}} @ar;

  my $rv = $sorted[0]->{ONTOLOGY_TERM_ID};

  $self->{_cached_ontology_terms}->{$term} = $rv;

  return $rv;
}


sub parseRow {
  my ($self, $header, $row) = @_;

#  my @keys = split(/\t/, $header);
 # my @values = split(/\t/, $row);

  my @keys = split(",", $header);
  my @values = split(",", $row);


  unless(scalar @keys == scalar @values) {
    $self->error("Mismatched number of headers and data columns");
  }

  my %rv;

  for(my $i = 0; $i < scalar @keys; $i++) {
    my $header = $keys[$i];
    my $value = $values[$i];
    
    push @{$rv{$header}}, $value;
  }

  return \%rv;
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

