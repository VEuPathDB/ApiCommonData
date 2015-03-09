package ApiCommonData::Load::Plugin::InsertStudyResults;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use CBIL::Util::Disp;
use GUS::PluginMgr::Plugin;

use GUS::Model::Study::Study;
use GUS::Model::Study::StudyLink;
use GUS::Model::Study::Protocol;
use GUS::Model::Study::ProtocolParam;
use GUS::Model::Study::ProtocolAppNode;
use GUS::Model::Study::ProtocolApp;
use GUS::Model::Study::ProtocolAppParam;
use GUS::Model::Study::Input;
use GUS::Model::Study::Output;

use GUS::Model::SRes::OntologyTerm;

use GUS::Supported::Util;

use Data::Dumper;

my $argsDeclaration =
[
   fileArg({name           => 'inputDir',
	    descr          => 'Directory in which to find input files',
	    reqd           => 1,
	    mustExist      => 1,
	    format         => '',
	    constraintFunc => undef,
	    isList         => 0, }),

   fileArg({name           => 'configFile',
	    descr          => 'Describes the profiles being loaded',
	    reqd           => 1,
	    mustExist      => 1,
	    format         => 'Tab file with no header and these columns: file_base_name, profile_name, profile_descrip, source_id_type, skip_second_row, load_profile_element.  The source_id_type must be one of: oligo, gene, none. The skip_second_row is 1 if second row in file is unneeded header, and load_profile_element is 1 if we want to load the expression data into the profileElement table.',
	    constraintFunc => undef,
	    isList         => 0, }),

   stringArg({name => 'extDbSpec',
	      descr => 'External database from whence this data came|version',
	      constraintFunc=> undef,
	      reqd  => 1,
	      isList => 0
	     }),

   stringArg({name => 'studyName',
	      descr => 'Name of the Study;  Will be added if it does not already exist',
	      constraintFunc=> undef,
	      reqd  => 1,
	      isList => 0
	     }),
    
    stringArg({name => 'platformExtDbSpec',
	      descr => 'External database spec for probeset',
	      constraintFunc=> undef,
	      reqd  => 0,
	      isList => 0
	     }),

#   stringArg({name => 'organismAbbrev',
#	      descr => 'if supplied, use a prefix to use for tuning manager tables',
#	      reqd => 0,
#	      constraintFunc => undef,
#	      isList => 0,
#	     }),

];

my $purpose = <<PURPOSE;
Insert a group of profiles into the results and study tables.
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
Insert a group of profiles into the results and study tables.
PURPOSE_BRIEF

my $notes = <<NOTES;
NOTES

my $tablesAffected = <<TABLES_AFFECTED;
TABLES_AFFECTED

my $tablesDependedOn = <<TABLES_DEPENDED_ON;
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

sub run {
  my ($self) = @_;

  my $configFile = $self->getArg('configFile');


  open(CONFIG, $configFile) or $self->error("Could not open $configFile for reading: $!");



  my $header = <CONFIG>;

  my $study = $self->makeStudy();

  my $existingAppNodes = $self->retrieveAppNodesForStudy($study);
  my $nodeOrderNum = 1;

  while(<CONFIG>) {
    chomp;
    my ($nodeName, $file, $sourceIdType, $inputProtocolAppNodeNames, $protocolName,  $protocolParamValues) = split(/\t/, $_);

    my $inputAppNodes = $self->getInputAppNodes($inputProtocolAppNodeNames, $existingAppNodes);

    my $protocolAppNode = $self->makeProtocolAppNode($nodeName, $existingAppNodes, $nodeOrderNum, $protocolName);
    push @$existingAppNodes, $protocolAppNode;

    my $studyLink = $self->linkAppNodeToStudy($study, $protocolAppNode);

    my $protocol = $self->makeProtocol($protocolName);

    my $protocolApp =  GUS::Model::Study::ProtocolApp->new();
    $protocolApp->setParent($protocol);
    $study->addToSubmitList($protocolApp);

    foreach my $inputAppNode (@$inputAppNodes) {
      my $input = GUS::Model::Study::Input->new();
      $input->setParent($protocolApp);
      $input->setParent($inputAppNode);
    }

    my $output = GUS::Model::Study::Output->new();
    $output->setParent($protocolApp);
    $output->setParent($protocolAppNode);

    my @appParams = $self->makeProtocolAppParams($protocolApp, $protocol, $protocolParamValues);

    $study->submit();

    $self->addResults($protocolAppNode, $sourceIdType, $protocolName, $file);

    $nodeOrderNum++;

  }

  close CONFIG;

  return "added a bunch of stuff";
}


sub addResults {
  my ($self, $protocolAppNode, $sourceIdType, $protocolName, $file) = @_;

  my $inputDir = $self->getArg('inputDir');
  my $fullFilePath = "$inputDir/$file";


  my $tableString;
  if($protocolName =~ /RNASeqFishers/ || $protocolName =~ /PaGE/ ) {
    $tableString = "Results::NAFeatureDiffResult";
  }
  elsif ($protocolName =~ /cghArrayQuantification/ ) {
    $tableString = "Results::ReporterIntensity";
  }
  elsif ($protocolName =~ /chipChipSmoothed/ || $protocolName =~ /chipChipPeaks/) {
    $tableString = "Results::SegmentResult";
  } 
  else {
    $tableString = "Results::NAFeatureExpression";
  }

  my $class = "GUS::Model::$tableString";

  eval "require $class";
  if($@) {
    $self->error($@);
  }

  open(RESULTS, $fullFilePath) or $self->error("Could not open $fullFilePath for reading: $!");

  my $header = <RESULTS>;
  chomp $header;

  my @header = split(/\t/, $header);

  while(<RESULTS>) {
    chomp;

    my @a = split(/\t/, $_);

    my ($hash, $start);
    if ($sourceIdType =~ /segment/) {
        my $naSequenceId = $self->lookupIdFromSourceId($a[0], $sourceIdType);
        $hash = { na_sequence_id => $naSequenceId,
                  segment_start => $a[1],
                  segment_end => $a[2]
                };
        $start = 3;
    }
    elsif ($sourceIdType =~ /reporter/) {
        my $reporterId = $self->lookupIdFromSourceId($a[0], $sourceIdType);
        $hash = { reporter_id => $reporterId };
        $start = 1;
    }
    else {
        my $naFeatureId = $self->lookupIdFromSourceId($a[0], $sourceIdType);
	next unless $naFeatureId;
        $hash = { na_feature_id => $naFeatureId };
        $start = 1;
    }

    for(my $i = $start; $i < scalar @header; $i++) {
      my $key = $header[$i];
      my $value = $a[$i];

      $hash->{$key} = $value;
    }

    my $result = eval {
      $class->new($hash);
    };

    if($@) {
      $self->error($@);
    }

    $result->setParent($protocolAppNode);
    $result->submit();

    $self->undefPointerCache();
  }

  close RESULTS;
}

sub lookupIdFromSourceId {
  my ($self, $sourceId, $sourceIdType) = @_;

  my $rv;

  if($sourceIdType eq 'transcript') {
    my $ids = GUS::Supported::Util::getNaFeatureIdsFromSourceId($self, $sourceId, 'Transcript');
    if(scalar @$ids == 1) {
      $rv = $ids->[0];
    }
  }
  elsif($sourceIdType eq 'gene') {
    $rv = GUS::Supported::Util::getGeneFeatureId($self, $sourceId);
  }
  elsif ($sourceIdType eq 'segment') {
    $rv = GUS::Supported::Util::getNASequenceId ($self, $sourceId);
  }
  elsif ($sourceIdType eq 'reporter') {
    my $probeExtDbRlsSpec = $self->getArg('platformExtDbSpec');
    my $probeExtDbRlsId = $self->getExtDbRlsId($probeExtDbRlsSpec);
    my @reporterIds = $self->sqlAsArray(Sql => "select r.reporter_id
                                                from platform.reporter r
                                                where r.external_database_release_id = $probeExtDbRlsId
                                                and r.source_id = $sourceId");
    unless (scalar @reporterIds == 1) {
        die "Number of probes returned should be 1\n";
    }
 
    $rv = @reporterIds[0];
  }
  else {
    $self->error("Unsupported sourceId Type:  $sourceIdType");
  }

  return $rv;
}


sub getInputAppNodes {
  my ($self, $inputNames, $existingAppNodes) = @_;

  my @inputNames = split(';', $inputNames);

  my @rv;

  foreach my $input (@inputNames) {
    foreach my $existing (@$existingAppNodes) {
      if($existing->getName eq $input) {
        push @rv, $existing;
      }
    }
  }

  unless(scalar @inputNames == scalar @rv) {
    my $foundNames = join(";",  map { $_->getName() } @rv);
    $self->log("Could not match Input Names $inputNames.  Found:   $foundNames");
  }

  return \@rv;
}

sub linkAppNodeToStudy {
  my ($self, $study, $protocolAppNode) = @_;

  my $studyLink = GUS::Model::Study::StudyLink->new();
  $studyLink->setParent($study);
  $studyLink->setParent($protocolAppNode);

  return $studyLink;
}

sub retrieveAppNodesForStudy {
  my ($self, $study) = @_;

  my @studyLinks = $study->getChildren('Study::StudyLink', 1);

  my @appNodes;

  foreach my $link (@studyLinks) {
    my $appNode = $link->getParent('Study::ProtocolAppNode', 1);

    push(@appNodes, $appNode) if($appNode);
  }

  return \@appNodes;
}


sub makeProtocolAppNode {
  my ($self, $nodeName, $existingAppNodes, $nodeOrderNum, $protocolName) = @_;

  my $oe;
  if($protocolName =~ /RNASeqFishers/ || $protocolName =~ /PaGE/ ) {
    $oe = "differential expression analysis data transformation";
  }
  else {
    $oe = "data transformation";
  }

  my $ontologyTerm = GUS::Model::SRes::OntologyTerm->new({name => $oe});
  unless($ontologyTerm->retrieveFromDB()) {
    $self->error("Required Ontology Term $oe not found in database");
  }

  foreach my $e (@$existingAppNodes) {
    my $existingName = $e->getName();

    if($nodeName eq $existingName) {
      $self->warn("Study contains ProtocolAppNode Named $nodeName ... will reuse");
      return $e;
    }
  }

  return GUS::Model::Study::ProtocolAppNode->new({name => $nodeName, node_order_num => $nodeOrderNum, type_id => $ontologyTerm->getId()});
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

sub makeProtocolAppParams {
  my ($self, $protocolApp, $protocol, $protocolParamValues) = @_;

  my @rv;

  my %protocolParamValues;

  my @protocolParamValues = split(';', $protocolParamValues);
  foreach my $ppv (@protocolParamValues) {
    my ($ppName, $ppValue) = split(/\|/, $ppv);

    my $protocolParam = GUS::Model::Study::ProtocolParam->new({name => $ppName});
    $protocolParam->setParent($protocol);
    $protocolParam->retrieveFromDB();

    my $protocolAppParam = GUS::Model::Study::ProtocolAppParam->new({value => $ppValue});
    $protocolAppParam->setParent($protocolApp);
    $protocolAppParam->setParent($protocolParam);

    push @rv, $protocolAppParam;
  }

  return \@rv;
}

sub makeStudy {
  my ($self) = @_;
  
  my $studyName = $self->getArg('studyName');

  my $extDbSpec = $self->getArg('extDbSpec');
  my $extDbRlsId = $self->getExtDbRlsId($extDbSpec);

  my $study = GUS::Model::Study::Study->new({name => $studyName, external_database_release_id => $extDbRlsId});
  $study->retrieveFromDB();

  return $study;
}


sub undoTables {
  my ($self) = @_;

  return ( 
    'Study.Input',
    'Study.Output',
    'Study.StudyLink',
    'Results.NAFeatureExpression',
    'Results.NAFeatureDiffResult',
    'Results.ReporterIntensity',
    'Results.SegmentResult',
    'Study.ProtocolAppNode',
    'Study.ProtocolAppParam',
    'Study.ProtocolApp',
    'Study.Study',
     );
}


1;
