package ApiCommonData::Load::Plugin::InsertEdaStudyFromArtifacts;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use GUS::Model::EDA::Study;
use GUS::Model::EDA::EntityTypeGraph;

use ApiCommonData::Load::InstallEdaStudyFromArtifacts;

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

  my $extDbRlsSpec = $self->getArg('extDbRlsSpec');
  my $inputDir = $self->getArg("inputDirectory");
  my $outputDir = $self->getArg("outputDirectory");
  my $gusConfigFile = $self->getArg("gusConfigFile");

  my $extDbRlsId = $self->getExtDbRlsId($extDbRlsSpec);
  my $installer = $self->makeInstaller($inputDir, $outputDir, $gusConfigFile);

  my $installJsonFile = $installer->getInstallJsonFile($inputDir);
  my $configsArray = $installer->getConfigsArrayFromInstallJsonFile($installJsonFile); 

  my ($studyConfig) = grep { $_->{type} eq 'table' && $_->{name} eq 'study' } @$configsArray;
  my $studyHash = $self->preexistingTable($studyConfig, 'study.cache');

  $studyHash->{'external_database_release_id'} = $extDbRlsId;

  my $study = GUS::Model::EDA::Study->new($studyHash);

  my ($entityTypeGraphConfig) = grep { $_->{type} eq 'table' && $_->{name} eq 'entitytypegraph' } @$configsArray;


  my $entityTypeGraphHash = $self->preexistingTable($entityTypeGraphConfig, 'entitytypegraph.cache');  
  my $entityTypeGraph = GUS::Model::EDA::EntityTypeGraph->new($entityTypeGraphHash);


  $entityTypeGraph->setParent($study);
  $entityTypeGraph->submit();

  print $entityTypeGraph->toString(); 
  


  if($self->getArg('commit')) {
    # now install the artifacts
    $installer->installData();
  }
  return("Loaded an EDA Study for external_database_release_id = $extDbRlsId");
}

sub preexistingTable {
  my ($self, $config, $cacheFile) = @_;

  my $cacheFileFullPath = $self->getArg('inputDirectory') . "/" . $cacheFile;

  open(FILE, $cacheFileFullPath) or $self->error("Could not open file $cacheFileFullPath for reading: $!");
  
  my @data = ();

  my $count;
  while(<FILE>) {
    chomp;
    my @line = split(/\t/, $_);
    @data = @line;
    $count++;
  }

  $self->userError("cache file $cacheFile must contain exactly one row") if($count != 1);

  my $rv = {};

  foreach my $field (@{$config->{fields}}) {
    next if($field->{macro}); 

    my $key = $field->{name};
    my $index = $field->{cacheFileIndex};
    my $value = $data[$index];
    $rv->{$key} = $value;
  }
  
  
  close FILE;
  return $rv;
}



sub makeInstaller {
    my ($plugin, $inputDir, $outputDir, $gusConfigFile) = @_;

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
        );

    return ApiCommonData::Load::InstallEdaStudyFromArtifacts->new(\%requiredVars);
}


sub undoPreprocess {
  my($self, $dbh, $rowAlgInvocationList) = @_;
  $self->SUPER::undoPreprocess($dbh, $rowAlgInvocationList);

  my ($inputDir) = $self->getAlgorithmParam($dbh,$rowAlgInvocationList,'inputDir');
  my ($outputDir) = $self->getAlgorithmParam($dbh,$rowAlgInvocationList,'outputDir');
  my ($gusConfigFile) = $self->getAlgorithmParam($dbh,$rowAlgInvocationList,'gusConfigFile');

  my ($extDbRlsSpec) = $self->getAlgorithmParam($dbh,$rowAlgInvocationList,'extDbRlsSpec');

  unless(-e $inputDir && -e $outputDir && -e $gusConfigFile) {
    $self->error("Required algorithm param missing OR does not exist inputDir=$inputDir, outputDir=$outputDir, gusConfigFile=$gusConfigFile");
  }

  my $installer = $self->makeInstaller($inputDir, $outputDir, $gusConfigFile);
  $installer->uninstallData();

  my $query = "select d.external_database_id, r.external_database_release_id, s.study_id, etg.entity_type_graph_id
from sres.externaldatabase d 
  inner join sres.externaldatabaserelease r on d.external_database_id = r.external_database_id 
  inner join eda.study s on s.external_database_release_id = r.external_database_release_id
  inner join eda.entitytypegraph etg on etg.study_id = s.study_id
where 
d.name || '|' || r.version = '$extDbRlsSpec'
";
  my $sh = $dbh->prepare($query);

  my @studyIds;
  my @extDbIds;

  $sh->execute();
  while(my ($externalDatabaseId, $externalDatabaseReleaseId, $studyId, $entityTypeGraphId) = $sh->fetchrow_array()) {
    push @studyIds, $studyId;
    push @extDbIds, $externalDatabaseId;
  }
  $sh->finish();

  my $studyIdsString = join(",", @studyIds);
  my $extDbIdsString = join(",", @extDbIds);

  $dbh->do("DELETE FROM EDA.ENTITYTYPEGRAPH WHERE study_id in ($studyIdsString)");
  $dbh->do("DELETE FROM EDA.STUDY WHERE study_id in ($studyIdsString)");

  $dbh->do("DELETE FROM SRES.EXTERNALDATABASERELEASE WHERE external_database_id in ($extDbIdsString)");
  $dbh->do("DELETE FROM SRES.EXTERNALDATABASE WHERE external_database_id in ($extDbIdsString)");



}





1;
