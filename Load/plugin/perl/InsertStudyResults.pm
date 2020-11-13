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
	    format         => 'Tab file with header',
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

  $self->setPointerCacheSize(100000);

  my $dbiDatabase = $self->getDb();
  $dbiDatabase->setDoNotUpdateAlgoInvoId(1);

  my $configFile = $self->getArg('configFile');
  open(CONFIG, $configFile) or $self->error("Could not open $configFile for reading: $!");

  my $header = <CONFIG>;

  my $nodeOrderNum = 1;

  while(<CONFIG>) {
    chomp;

    my ($nodeName, $file, $sourceIdType, $inputProtocolAppNodeNames, $protocolName,  $protocolParamValues, $studyName) = split(/\t/, $_);
    my $investigation = $self->makeStudy($self->getArg('studyName'));

    my @investigationLinks = $investigation->getChildren('Study::StudyLink');

    $self->userError("Study name $investigation provided on command line cannot be the same as the profilesetname from the config file") if($investigation eq $studyName);

    my $study = $self->makeStudy($studyName);

    $study->setParent($investigation);

    my @studyLinks = $study->getChildren('Study::StudyLink');

    my $existingInvestigationAppNodes = $self->retrieveAppNodesForStudy(\@investigationLinks);
    my $existingStudyAppNodes = $self->retrieveAppNodesForStudy(\@studyLinks);

    my $inputAppNodes = $self->getInputAppNodes($inputProtocolAppNodeNames, $existingInvestigationAppNodes, $investigation, $nodeOrderNum);

    my $protocolType;
    if($protocolName =~ /DESeq2Analysis/ || $protocolName =~ /PaGE/ || $protocolName =~ /DEGseqAnalysis/ || $protocolName eq "differential expression analysis data transformation") {
      $protocolType = "differential expression analysis data transformation";
    }
    else {
      $protocolType = "data transformation";
    }

    my $appNodeType = "data item";

    my $protocolAppNode = $self->makeProtocolAppNode($nodeName, $existingStudyAppNodes, $nodeOrderNum, $appNodeType);

    my $protocol = $self->makeProtocol($protocolType);

    my $protocolApp =  GUS::Model::Study::ProtocolApp->new();
    $protocolApp->setParent($protocol);
    $investigation->addToSubmitList($protocolApp);

    foreach my $inputAppNode (@$inputAppNodes) {
      my $input = GUS::Model::Study::Input->new();
      $input->setParent($protocolApp);
      $input->setParent($inputAppNode);

      $self->linkAppNodeToStudy($study, $inputAppNode);
      $self->linkAppNodeToStudy($investigation, $inputAppNode);
    }

    my $output = GUS::Model::Study::Output->new();
    $output->setParent($protocolApp);
    $output->setParent($protocolAppNode);

    $self->linkAppNodeToStudy($study, $protocolAppNode);
    $self->linkAppNodeToStudy($investigation, $protocolAppNode);

    my @appParams = $self->makeProtocolAppParams($protocolApp, $protocol, $protocolParamValues);

    $investigation->submit();

    $self->addResults($protocolAppNode, $sourceIdType, $protocolName, $file);
    $self->undefPointerCache();
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
  if($protocolName =~ /DESeq2Analysis/ || $protocolName =~ /PaGE/ || $protocolName =~ /DEGseqAnalysis/ || $protocolName eq "differential expression analysis data transformation") {
    $tableString = "Results::NAFeatureDiffResult";
  }
  elsif ($protocolName =~ /cghArrayQuantification/ ) {
    $tableString = "Results::ReporterIntensity";
  }
  elsif ($protocolName =~ /chipChipSmoothed/ || $protocolName =~ /chipChipPeaks/ || $protocolName =~ /HOMER peak calls/) {
    $tableString = "Results::SegmentResult";
  }
  elsif ($protocolName =~ /MetaboliteProfiles/) {
    $tableString = "Results::CompoundMassSpec";
  }
  elsif ($protocolName =~ /Antibody Microarray/) {
    $tableString = "Results::NaFeatureHostResponse";
  }
  elsif ($protocolName =~ /taxonomic_diversity_assessment_by_targeted_gene_survey/) {
    $tableString = "Results::LineageAbundance";
    warn "You seem to be using " .__PACKAGE__ . ", have you seen ApiCommonData::Load::LineageAbundances?";
  }
  elsif ($protocolName =~ /Ploidy/) {
    $tableString = "ApiDB::ChrCopyNumber";
  }
  elsif ($protocolName =~ /geneCNV/) {
    $tableString = "ApiDB::GeneCopyNumber";
  }
  elsif ($protocolName =~ /simple_ontology_term_results/) {
    $tableString = "ApiDB::OntologyTermResult";
  }
  elsif ($protocolName =~ /subject_result/) {
    $tableString = "ApiDB::SubjectResult";
  }
  elsif ($protocolName =~ /haplotype/) {
    $tableString = "ApiDB::HaplotypeResult";
  }
  elsif ($protocolName eq 'GSNAP/Junctions') {
    $tableString = "ApiDB::IntronJunction";
  }
  elsif ($protocolName eq 'Splice Site Features') {
    $tableString = "ApiDB::SpliceSiteFeature";
  }
  elsif ($protocolName eq 'RFLPGenotype') {
    $tableString = "ApiDB::RflpGenotype";
  }
  elsif ($protocolName eq 'phenotype_score') {
    $tableString = "ApiDB::PhenotypeScore";
  }
  elsif ($protocolName eq 'phenotype_growth_rate') {
    $tableString = "ApiDB::PhenotypeGrowthRate";
  }
  elsif ($protocolName eq 'phenotype_knockout_mutants') {
    $tableString = "ApiDB::PhenotypeMutants";
  }
  elsif ($protocolName eq 'RFLPGenotypeNumber') {
    $tableString = "ApiDB::RflpGenotypeNumber";
  }
  elsif ($protocolName eq 'crispr_phenotype') {
    $tableString = "ApiDB::CrisprPhenotype";
  }
  elsif ($protocolName eq 'ClinEpiData::Load::WHOProfiles') {
    $tableString = "ApiDB::WHOStandards";
  }
  elsif ($protocolName =~ /MetaCycle/) {
    $tableString = "ApiDB::NAFeatureMetaCycle";
  }
  elsif ($protocolName =~ /Lopit/) {
    $tableString = "ApiDB::LopitResults";
  }
  elsif ($protocolName eq "compoundMassSpec") {
    $tableString = "ApiDB::CompoundMassSpecResult"; 
  }
  else {
# TODO check what protocol this is for, and die in the else clause
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
    if ($sourceIdType =~ /segment/ || $sourceIdType =~ /NASequence/) {
        my $naSequenceId = $self->lookupIdFromSourceId($a[0], $sourceIdType);
        $hash = { na_sequence_id => $naSequenceId};
        $start = 1;
        if ($sourceIdType =~ /segment/) {
            $hash->{'segment_start'} = $a[1];
            $hash->{'segment_end'} = $a[2];
            $start = 3;
        }
    }

    elsif ($sourceIdType =~ /reporter/) {
      my $reporterId = $self->lookupIdFromSourceId($a[0], $sourceIdType);
      $hash = { reporter_id => $reporterId };
      $start = 1;
    }

    elsif ($sourceIdType =~ /ontology_term/) {
        my $ontologyTermId = $self->lookupIdFromSourceId($a[0], $sourceIdType);
        $hash = { ontology_term_id => $ontologyTermId };
        $start = 1;
    }

    elsif ($sourceIdType =~ /literal/) {
	if($protocolName eq 'ClinEpiData::Load::WHOProfiles'){
	    $hash = {label=>$a[0]};
	    $start = 1;
	}
    }

    elsif ($sourceIdType =~ /subject/) {
      $hash = { subject => $a[0] };
      $start = 1;
    }

	elsif($sourceIdType =~ /compound_MassSpec/){   #ROSS - also from config file.
	  
	  @a = split(/\t/, $_);
	  # There are two ways of mapping peaks to compounds - peakID or mass/rt pairs. This passes the values into an array used below to query the DB. -- This is now only one way - using all 3 pieces of data.
	  my @massRTSplit = split(/\|/,$a[0]);
	  my @peakMassRT =[@massRTSplit[0], @massRTSplit[1], @massRTSplit[2]];  
	  my $compoundPeaksID = $self->lookupIdFromSourceId(@peakMassRT, $sourceIdType);
	  #print STDERR "Compound Peaks Id: $compoundPeaksID \n";
	  my $percentile = $a[1];
	  my $standard_error = $a[2]; 
	  $hash->{compound_peaks_id} = $compoundPeaksID;
	  $hash->{percentile} = $percentile;
	  $hash->{standard_error} = $standard_error;
	  #print STDERR "################\n\n";
	  #print STDERR Dumper $hash; 
	  $start = 3; 
	}

    else {
        my $naFeatureId = $self->lookupIdFromSourceId($a[0], $sourceIdType);
	$self->log("WARN:  No source_id for [$a[0]] with type $sourceIdType") unless $naFeatureId;
        next unless $naFeatureId;
	$hash = { na_feature_id => $naFeatureId };
        $start = 1;
    }

    for(my $i = $start; $i < scalar @header; $i++) {
      my $key = $header[$i];
      my $value = $a[$i];

      $value = undef if($value eq "NA");

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
    $rv = GUS::Supported::Util::getNaFeatureIdsFromSourceId($self, $sourceId, 'Transcript');
  }
  elsif($sourceIdType eq 'gene') {
    $rv = GUS::Supported::Util::getGeneFeatureId($self, $sourceId);
  }
  elsif ($sourceIdType eq 'segment' || $sourceIdType eq 'NASequence') {
    $rv = GUS::Supported::Util::getNASequenceId ($self, $sourceId);
  }
  elsif ($sourceIdType eq 'reporter') {
    my $probeExtDbRlsSpec = $self->getArg('platformExtDbSpec');
    my $probeExtDbRlsId = $self->getExtDbRlsId($probeExtDbRlsSpec);
    $rv = GUS::Supported::Util::getReporterIdFromSourceId($self, $sourceId, $probeExtDbRlsId);
  }

  elsif ($sourceIdType eq 'ontology_term') {
    my @ontologyTermIds = $self->sqlAsArray(Sql => "select ontology_term_id from sres.ontologyterm where name = '$sourceId'");
    unless (scalar @ontologyTermIds == 1) {
        die "Number of ontologyTermIds should be 1 for term $sourceId\n";
    }
    $rv = @ontologyTermIds[0];
  }

  elsif ($sourceIdType eq 'compound') {
    my @compoundIds = $self->sqlAsArray(Sql => "select id from chebi.compounds where chebi_accession = '$sourceId'");

    unless (scalar @compoundIds == 1) {
        die "Number of compounds returned should be 1\n";
    }

    $rv = @compoundIds[0];
  }

  elsif($sourceIdType eq "compound_MassSpec"){

    #my $peakMapping =  $self->getArg('hasPeakMappingID');
    my $compoundPeaksExtDbRlsId = $self->getExtDbRlsId($self->getArg('extDbSpec'));
 	my @compoundPeaksID; 
	my $peakID = @$sourceId[0];
    my $mass = @$sourceId[1];
	my $rt = @$sourceId[2];
    @compoundPeaksID = $self->sqlAsArray(Sql=> "select cp.compound_peaks_id from ApiDB.CompoundPeaks cp
  													where cp.peak_id = $peakID
													and cp.mass = '$mass'
													and cp.retention_time = '$rt'
												    and cp.external_database_release_id = $compoundPeaksExtDbRlsId"); 
  
    
									#print STDERR "Ross $peakID, $mass, $rt  ";									
									#print STDERR Dumper @compoundPeaksID;
    unless (scalar @compoundPeaksID == 1){
      die "Number of Compoud Peaks returned should be 1\n."
    }
	  $rv = @compoundPeaksID[0];
  }


  # USES Name instead of source_id here
  elsif ($sourceIdType eq 'haploblock') {
    my @naFeatureIds = $self->sqlAsArray(Sql => "select na_feature_id from dots.ChromosomeElementFeature where source_id = '$sourceId'");
    unless (scalar @naFeatureIds == 1) {
        die "Number of naFeatureIds should be 1 for source_id $sourceId\n";
    }
    $rv = @naFeatureIds[0];
  }

  else {
    $self->error("Unsupported sourceId Type:  $sourceIdType");
  }

  return $rv;
}


sub getInputAppNodes {
  my ($self, $inputNames, $existingAppNodes, $study, $nodeOrderNum) = @_;

  my @inputNames = split(';', $inputNames);

  my @rv;

  foreach my $input (@inputNames) {
    my $found;
    foreach my $existing (@$existingAppNodes) {

      if($existing->getName eq $input) {
        push @rv, $existing;
        $found++;
      }
    }

    $self->error("Found multiple app nodes named $input in Investigation.  App nodes used as Inputs must be unique w/in an investigation.") if($found > 1);

    next if($found);

    my $newInput = GUS::Model::Study::ProtocolAppNode->new({name => $input, node_order_num => $nodeOrderNum});

    push @$existingAppNodes, $newInput;
    push @rv, $newInput;
  }

  unless(scalar @inputNames == scalar @rv) {
    my $foundNames = join(";",  map { $_->getName() } @rv);
    $self->log("Could not match Input Names $inputNames.  Found:   $foundNames");
  }

  return \@rv;
}

sub linkAppNodeToStudy {
  my ($self, $study, $protocolAppNode) = @_;

  my @studyLinks = $study->getChildren('Study::StudyLink');

  foreach my $sl (@studyLinks) {
    my $linkParent = $sl->getParent("Study::ProtocolAppNode", 1);

    # already Linked
    return $sl if($linkParent->getName() eq $protocolAppNode->getName());
  }

  my $studyLink = GUS::Model::Study::StudyLink->new();
  $studyLink->setParent($study);
  $studyLink->setParent($protocolAppNode);

  return $studyLink;
}

sub retrieveAppNodesForStudy {
  my ($self, $studyLinks) = @_;

  my @appNodes;

  foreach my $link (@$studyLinks) {
    my $appNode = $link->getParent('Study::ProtocolAppNode', 1);

    push(@appNodes, $appNode) if($appNode);
  }

  return \@appNodes;
}


sub makeProtocolAppNode {
  my ($self, $nodeName, $existingAppNodes, $nodeOrderNum, $appNodeType) = @_;

  my $ontologyTerm = GUS::Model::SRes::OntologyTerm->new({name => $appNodeType});
  unless($ontologyTerm->retrieveFromDB()) {
    $self->error("Required ontology term \"$appNodeType\" either is not found in the database or returns more than one row from the database");
  }

  foreach my $e (@$existingAppNodes) {
    my $existingName = $e->getName();

    if($nodeName eq $existingName) {
      $self->log("WARN:  Study already contains ProtocolAppNode Named $nodeName.  If this node is output in more than one ProtocolApplication, It is impossible to distinguish results unless you either store in different Results Tables or can distinguish by some GUS Subclass (Transcripts and GeneFeature are ok for example)");
      return $e;
    }
  }

  my $protocolAppNode = GUS::Model::Study::ProtocolAppNode->new({name => $nodeName, node_order_num => $nodeOrderNum, type_id => $ontologyTerm->getId()});

  return $protocolAppNode;
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
  my ($self, $studyName) = @_;

  # if(my $cachedStudy = $self->{_study_names}->{$studyName}) {
  #   return $cachedStudy;
  # }

  my $extDbSpec = $self->getArg('extDbSpec');
  my $extDbRlsId = $self->getExtDbRlsId($extDbSpec);

  my $study = GUS::Model::Study::Study->new({name => $studyName, external_database_release_id => $extDbRlsId});
  $study->retrieveFromDB();

  $study->getChildren("Study::StudyLink", 1);

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
    'Results.NAFeatureHostResponse',
    'Results.CompoundMassSpec',
    'Results.LineageAbundance',
    'ApiDB.GeneCopyNumber',
    'ApiDB.ChrCopyNumber',
    'ApiDB.ONTOLOGYTERMRESULT',
    'ApiDB.SUBJECTRESULT',
    'ApiDB.INTRONJUNCTION',
    'ApiDB.HAPLOTYPERESULT',
    'ApiDB.RflpGenotype',
    'ApiDB.RflpGenotypeNumber',
    'ApiDB.SpliceSiteFeature',
    'ApiDB.CRISPRPHENOTYPE',
    'ApiDB.PHENOTYPEMUTANTS',
    'ApiDB.PHENOTYPESCORE',
    'ApiDB.PhenotypeGrowthRate',
    'ApiDB.WHOSTANDARDS',
    'ApiDB.NAFeatureMetaCycle',
    'ApiDB.LopitResults',
    'ApiDB.CompoundMassSpecResult',
    'ApiDB.CompoundPeaksChebi',
    'ApiDB.CompoundPeaks',
    'Study.ProtocolAppNode',
    'Study.ProtocolAppParam',
    'Study.ProtocolApp',
    'Study.Study',
     );
}


1;
