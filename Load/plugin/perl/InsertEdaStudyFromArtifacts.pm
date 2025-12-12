package ApiCommonData::Load::Plugin::InsertEdaStudyFromArtifacts;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use GUS::Model::EDA::Study;
use GUS::Model::EDA::EntityTypeGraph;
use GUS::Model::EDA::StudyExternalDatabaseRelease;

use Data::Dumper;

use DBI;

use ApiCommonData::Load::InstallEdaStudyFromArtifacts;

use GUS::Supported::GusConfig;

use DBI::Const::GetInfoType;

use GUS::PluginMgr::Plugin;

# ----------------------------------------------------------------------

my $argsDeclaration =
  [


   fileArg({name => 'inputDirectory',
            descr => 'directory which contains the artifacts',
            constraintFunc=> undef,
            reqd  => 1,
            isList => 0,
            mustExist => 1,
            format=>'Text'
           }),

   fileArg({name => 'outputDirectory',
            descr => 'directory to write stuff',
            constraintFunc=> undef,
            reqd  => 1,
            isList => 0,
            mustExist => 0,
            format=>'Text'
           }),


   stringArg({name           => 'extDbRlsSpec',
            descr          => 'External Database Spec for this study',
            reqd           => 1,
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

  my $extDbRlsSpec = $self->getArg('extDbRlsSpec');

  my $inputDir = $self->getArg("inputDirectory");
  my $outputDir = $self->getArg("outputDirectory");
  my $gusConfigFile = $self->getArg("gusConfigFile");

  if(-e $outputDir) {
    $self->userError("Output Directory already Exists");
  }

  #my $extDbRlsId = $self->getExtDbRlsId($extDbRlsSpec);
  my $installer = $self->makeInstaller($inputDir, $outputDir, $gusConfigFile, $extDbRlsSpec);

  my $installJsonFile = $installer->getInstallJsonFile($inputDir);
  my $configsArray = $installer->getConfigsArrayFromInstallJsonFile($installJsonFile); 

  my ($studyConfig) = grep { $_->{type} eq 'table' && $_->{name} eq 'study' } @$configsArray;
  my $studyArray = $self->preexistingTable($studyConfig, 'study.cache');
  if(scalar @$studyArray != 1) {
    $self->error("study.cache must contain one row of data");
  }

  my $study = GUS::Model::EDA::Study->new($studyArray->[0]);

  my ($entityTypeGraphConfig) = grep { $_->{type} eq 'table' && $_->{name} eq 'entitytypegraph' } @$configsArray;
  my $entityTypeGraphArray = $self->preexistingTable($entityTypeGraphConfig, 'entitytypegraph.cache');  

  foreach my $entityTypeGraphHash (@$entityTypeGraphArray) {
    my $entityTypeGraph = GUS::Model::EDA::EntityTypeGraph->new($entityTypeGraphHash);
    $entityTypeGraph->setParent($study);
  }

  foreach my $spec (@{$extDbRlsSpec}) {
    my $extDbRlsId = $self->getExtDbRlsId($spec);

    my $studyExtDbRls = GUS::Model::EDA::StudyExternalDatabaseRelease->new({external_database_release_id => $extDbRlsId});
    $studyExtDbRls->setParent($study);
  }

  $study->submit();

  if($self->getArg('commit')) {
    # now install the artifacts
    $installer->installData();
  }


  return("Loaded an EDA Study for ");
}

sub preexistingTable {
  my ($self, $config, $cacheFile) = @_;

  my $cacheFileFullPath = $self->getArg('inputDirectory') . "/" . $cacheFile;

  open(FILE, $cacheFileFullPath) or $self->error("Could not open file $cacheFileFullPath for reading: $!");
  
  my $rv = [];
  while(<FILE>) {
    chomp;
    my @line = split(/\t/, $_);

    my $row = {};
    foreach my $field (@{$config->{fields}}) {
      next if($field->{macro}); 

      my $key = $field->{name};
      my $index = $field->{cacheFileIndex};
      my $value = $line[$index];

      $row->{$key} = $value;
    }
    push @$rv, $row;
  }
  
  close FILE;
  return $rv;
}



sub makeInstaller {
    my ($plugin, $inputDir, $outputDir, $gusConfigFile, $extDbRlsSpec) = @_;

    my $edaSchema = "EDA";

    die "gus.confg $gusConfigFile does not exist" unless -e $gusConfigFile;

    my $gusconfig = GUS::Supported::GusConfig->new($gusConfigFile);
    my ($host, $port, $dbname);
    my $dsn = $gusconfig->getDbiDsn();
    my ($dbi, $dbPlatform, $dbnameFull) = split(':', $dsn);

    # if we are postgres, these should be in gus config (port is optional)
    if($dbPlatform eq 'Pg') {
        foreach my $pair (split(";", $dbnameFull)) {

            my ($key, $value) = split("=", $pair);

            if(lc $key eq 'port') {
                $port = $value;
            }
            if(lc $key eq 'host') {
                $host = $value;
            }
            if(lc $key eq 'dbname') {
                $dbname = $value;
            }

        }
        $port = 5432 unless($port);

        $dbPlatform = "Postgres";
    }
    # otherwise we can get connect info from tnsnames
    else {
        my $connectInfo = `tnsping $dbnameFull`;
        ($port) = $connectInfo =~ /PORT=([^\)]+)/;
        ($host) = $connectInfo =~ /HOST=([^\)]+)/;
        ($dbname) = $connectInfo =~ /SERVICE_NAME=([^\)]+)/;
    }

    my $login = $gusconfig->getDatabaseLogin();
    my $password = $gusconfig->getDatabasePassword();

    my %requiredVars = ('DB_HOST' => $host,
                        'DB_PORT' => $port,
                        'DB_NAME' => $dbname,
                        'DB_PLATFORM' => $dbPlatform,
                        'DB_USER' => $login,
                        'DB_PASS' => $password,
                        'DB_SCHEMA' => $edaSchema,
                        'DATA_FILES' => $outputDir,
                        'INPUT_DIR' => $inputDir,
                        'SKIP_PREEXISTING_TABLES' => 1, # we are loading these rows here not in the VDI artifact loader
                        'EXTERNAL_DATABASE_RLS_SPECS' => $extDbRlsSpec, # This is needed for Undo only
        );

    return ApiCommonData::Load::InstallEdaStudyFromArtifacts->new(\%requiredVars);
}

sub undoTables {
  # all undo stuff done in the undoPreprocess method
  return ();
}

sub undoPreprocess {
  my($self, $dbh, $rowAlgInvocationList) = @_;

  my $gusConfigFile = $self->getAlgorithmParam($dbh,$rowAlgInvocationList,'gusConfigFile')->[0];


  my $extDbRlsSpec = $self->getAlgorithmParam($dbh,$rowAlgInvocationList,'extDbRlsSpec');

  unless(-e $gusConfigFile && scalar @$extDbRlsSpec > 0) {
    $self->error("Required algorithm param missing OR does not exist gusConfigFile=$gusConfigFile, extDbRlsSpec=$extDbRlsSpec");
  }

  my $installer = $self->makeInstaller("NA", "NA", $gusConfigFile, $extDbRlsSpec);
  $installer->uninstallDataFromExternalDatabase();
}


sub getAlgorithmParam {
  my ($self, $dbh, $rowAlgInvocationList, $paramKey) = @_;
  my $pluginName = ref($self);
  my %paramValues;
  foreach my $rowAlgInvId (@$rowAlgInvocationList){
    my $sql  = "SELECT p.STRING_VALUE
      FROM core.ALGORITHMPARAMKEY k
      LEFT JOIN core.ALGORITHMIMPLEMENTATION a ON k.ALGORITHM_IMPLEMENTATION_ID = a.ALGORITHM_IMPLEMENTATION_ID 
      LEFT JOIN core.ALGORITHMPARAM p ON k.ALGORITHM_PARAM_KEY_ID = p.ALGORITHM_PARAM_KEY_ID 
      WHERE a.EXECUTABLE = ? 
      AND p.ROW_ALG_INVOCATION_ID = ?
      AND k.ALGORITHM_PARAM_KEY = ?";
    my $sh = $dbh->prepare($sql);
    $sh->execute($pluginName,$rowAlgInvId, $paramKey);
    while(my ($name) = $sh->fetchrow_array){
      $paramValues{ $name } = 1;
    }
    $sh->finish();
  }

  my @values = keys %paramValues;

  return \@values;
}



1;
