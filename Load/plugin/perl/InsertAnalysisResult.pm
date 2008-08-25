package ApiCommonData::Load::Plugin::InsertAnalysisResult;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use GUS::PluginMgr::Plugin;

use GUS::Model::Study::OntologyEntry;
use GUS::Model::RAD::Analysis;
use GUS::Model::RAD::Protocol;

$| = 1;

# ---------------------------------------------------------------------------
# Load Arguments
# ---------------------------------------------------------------------------

sub getArgumentsDeclaration{
  my $argsDeclaration =
    [

     fileArg({name           => 'inputDir',
              descr          => 'Directory in which to find input files',
              reqd           => 1,
              mustExist      => 1,
              format         => '',
              constraintFunc => undef,
              isList         => 0, 
             }),

     fileArg({ name           => 'configFile',
               descr          => 'tab-delimited file with differential expression stats',
               reqd           => 1,
               mustExist      => 1,
               format         => '',
               constraintFunc => undef,
               isList         => 0,
             }),

     enumArg({ descr          => 'View of analysisResultImp',
               name           => 'analysisResultView',
               isList         => 0,
               reqd           => 1,
               constraintFunc => undef,
               enum           => "DataTransformationResult,DifferentialExpression",
             }),

     enumArg({ descr          => 'View of naFeatureImp',
               name           => 'naFeatureView',
               isList         => 0,
               reqd           => 1,
               constraintFunc => undef,
               enum           => "ArrayElementFeature,DifferentialExpression", 
             }),

    ];
  return $argsDeclaration;
}

# ----------------------------------------------------------------------
# Documentation
# ----------------------------------------------------------------------

sub getDocumentation {
  my $purposeBrief = "Inserts Rad.Analysis and Rad.AnalysisResultImp View.  Creates the associated Rad.Protocol if it doesn't exist";

  my $purpose = "Inserts Rad.Analysis and Rad.AnalysisResultImp View.  Creates the associated Rad.Protocol if it doesn't exist";

  my $tablesAffected = [['RAD::Analysis', 'One Row to Identify this experiment'],['RAD::AnalysisResultImp', 'one row per line in the data file'],['RAD::Protocol', 'Will Create generic row if the specified protocol does not already exist']];

  my $tablesDependedOn = [['Study::OntologyEntry',  'new protocols will be assigned unknown_protocol_type'],
                          ['DoTS::GeneFeature', 'The id in the data file must ge an existing Gene Feature']];

  my $howToRestart = "No restart";

  my $failureCases = "";

  my $notes = "The first column in the data file specifies the Dots.GeneFeature SourceId.  Subsequent columns are view specific. (ex:  fold_change for DifferentialExpression OR float_value for DataTransformationResult).  The Config file has the following columns (no header):file analysis_name protocol_name protocol_type(OPTOINAL)";

  my $documentation = {purpose=>$purpose, purposeBrief=>$purposeBrief, tablesAffected=>$tablesAffected, tablesDependedOn=>$tablesDependedOn, howToRestart=>$howToRestart, failureCases=>$failureCases,notes=>$notes};

  return $documentation;
}

#--------------------------------------------------------------------------------

sub new {
  my ($class) = @_;
  my $self = {na_sequences => []
             };
  bless($self,$class);

  my $documentation = &getDocumentation();
  my $argumentDeclaration = &getArgumentsDeclaration();

  $self->initialize({requiredDbVersion => 3.5,
		             cvsRevision => '$Revision: 22467 $',
                     name => ref($self),
                     revisionNotes => '',
                     argsDeclaration => $argumentDeclaration,
                     documentation => $documentation});

  return $self;
}

#--------------------------------------------------------------------------------

sub run {
  my ($self) = @_;

  my $config = $self->readConfig();

  my $totalLines;

  my $analysisResultView = $self->getArg('analysisResultView');
  my $naFeatureView = $self->getArg('naFeatureView');

  my $class = "GUS::Model::RAD::$analysisResultView";
  eval "require $class";

  foreach my $configRow (@$config) {
    my $dataFile = $configRow->[0];
    my $analysisName = $configRow->[1];
    my $protocolName = $configRow->[2];
    my $protocolType = $configRow->[3];

    my $protocol = $self->getProtocol($protocolName, $protocolType);

    my $analysis = $self->createAnalysis($protocol, $analysisName);

    my $count = $self->processDataFile($analysis, $dataFile, $class, $naFeatureView);

    $self->log("File Finished.  $count lines processed");

    $totalLines = $totalLines + $count;
  }

  my $totalInserts = $self->getTotalInserts();

  return "Processed $totalLines lines from data files and $totalInserts Total Inserts";
}

#--------------------------------------------------------------------------------

sub readConfig {
  my ($self) = @_;

  my $fn = $self->getArg('configFile');

  open(CONFIG, "$fn") or $self->error("Cannot open file $fn for reading: $!");

  my @rv;

  while(<CONFIG>) {
    chomp;

    next unless($_);
    next if /^#/;

    my @a = split(/\t/, $_);

    push @rv, \@a;
  }

  close CONFIG;

  return \@rv;
}


#--------------------------------------------------------------------------------

sub processDataFile {
  my ($self, $analysis, $fn, $class, $naFeatureView) = @_;

  my $inputDir = $self->getArg('inputDir');

  open(FILE, "$inputDir/$fn") or $self->error("Cannot open file $inputDir/$fn for reading: $!");

  my $tableId = $self->getTableId();

  my $header = <FILE>;
  chomp $header;

  my @headers = split(/\t/, $header);

  my $count;

  while(<FILE>) {
    chomp;

    $count++;
    if($count % 500 == 0) {
      $self->undefPointerCache();
      $self->log("Processed $count rows from $fn");
    }

    my @row = split(/\t/, $_);

    $self->userError("The number of columns in the data file didn't match the number of columns in the header for row $count") unless(scalar @row == scalar @headers);

    my $sourceId = $row[0];

    my $naFeatureId = $self->getNaFeatureId($sourceId, $naFeatureView);
    next unless $naFeatureId;

    foreach(@$naFeatureId) {

      my $hashRef = {table_id => $tableId,
                     row_id => $naFeatureId
                    };

      for(my $i = 1; $i < scalar @headers; $i++) {
        my $key = $headers[$i];
        my $value = $row[$i];

        $hashRef->{$key} = $value;
      }

      my $analysisResult = eval {
        $class->new($hashRef);
      };

      $self->error($@) if $@;

      $analysisResult->setParent($analysis);

      $analysisResult->submit();
    }
  }

  close FILE;

  return $count;
}

#--------------------------------------------------------------------------------

sub getNaFeatureId {
  my ($self, $sourceId, $naFeatureView) = @_;

  my @naFeatures; 

  if($naFeatureView eq 'ArrayElementFeature') {
    @naFeatures = $self->sqlAsArray( Sql => "select na_feature_id from dots.ArrayElementFeature where source_id = '$sourceId'" );
   } else {
    @naFeatures = $self->sqlAsArray( Sql => "select na_feature_id from dots.geneFeature where source_id = '$sourceId'" );
   }

  if(scalar @naFeatures != 1) {
    $self->log("WARN:  Skipping $sourceId...Dots.GeneFeature na_feature_id not found.");
  }
  return \@naFeatures;

}

#--------------------------------------------------------------------------------

sub getTableId {
  my ($self) =  @_;

  my $table = 'GeneFeature';
  my @tableIds = $self->sqlAsArray( Sql => "select table_id from core.tableinfo where name = '$table'" );

  if(scalar @tableIds != 1) {
    $self->error("Core::TableInfo not found for $table");
  }
  return $tableIds[0];
}

#--------------------------------------------------------------------------------

sub createAnalysis {
  my ($self, $protocol, $analysisName) = @_;

  my $analysis = GUS::Model::RAD::Analysis->new({name => $analysisName});

  $analysis->setParent($protocol);

  return $analysis;
}

#--------------------------------------------------------------------------------

sub getProtocol {
  my ($self, $protocolName, $protocolType) = @_;

  my $protocol = GUS::Model::RAD::Protocol->new({name => $protocolName });

  unless($protocol->retrieveFromDB()) {
    my $protocolTypeId = $self->getProtocolTypeId($protocolType);

    # Can't set parent because there are many fk to Study::OntologyEntry
    $protocol->setProtocolTypeId($protocolTypeId);
  }

  return $protocol;

}

#--------------------------------------------------------------------------------

sub getProtocolTypeId {
  my ($self, $protocolType) = @_;

  $protocolType = 'unknown_protocol_type' unless($protocolType);
  my $category = 'ExperimentalProtocolType';

  my $oe = GUS::Model::Study::OntologyEntry->new({value => $protocolType,
                                                  category => $category,
                                                 });

  unless($oe->retrieveFromDB()) {
    $self->error("Could not retrieve Study::OntologyEntry for value $protocolType");
  }

  return $oe->getId();
}

1;
