package ApiCommonData::Load::EBITableReader;
use base qw(ApiCommonData::Load::UniDBTableReader);

use strict;

use Data::Dumper;

use File::Temp qw/ tempfile /;

$/ = "#EOR#\n";
my $FIELD_DELIMITER = "#EOC#\t";

sub setTableFileHandle { $_[0]->{_table_file_handle} = $_[1] }
sub getTableFileHandle { $_[0]->{_table_file_handle} }

sub setTableHeader { $_[0]->{_table_header} = $_[1] }
sub getTableHeader { $_[0]->{_table_header} }

sub getContainerName { $_[0]->{_container_name} }
sub setContainerName { $_[0]->{_container_name} = $_[1] }

sub getSchemaDefinitionFile { $_[0]->{_schema_definition_file} }
sub setSchemaDefinitionFile { $_[0]->{_schema_definition_file} = $_[1] }

sub getChromosomeMapFile { $_[0]->{_chromosome_map_file} }
sub setChromosomeMapFile { $_[0]->{_chromosome_map_file} = $_[1] }

sub getEbi2gusVersion { $_[0]->{_ebi2gus_version} }
sub setEbi2gusVersion { $_[0]->{_ebi2gus_version} = $_[1] }

sub getNcbiTaxon { $_[0]->{_ncbi_taxon} }
sub setNcbiTaxon { $_[0]->{_ncbi_taxon} = $_[1] }

sub getOrganismDatasetName { $_[0]->{_organism_dataset_name} }
sub setOrganismDatasetName { $_[0]->{_organism_dataset_name} = $_[1] }

sub getOrganismDatasetVersion { $_[0]->{_organism_dataset_version} }
sub setOrganismDatasetVersion { $_[0]->{_organism_dataset_version} = $_[1] }

sub getInitDir { $_[0]->{_init_dir} }
sub setInitDir { $_[0]->{_init_dir} = $_[1] }

sub getDataDir { $_[0]->{_data_dir} }
sub setDataDir { $_[0]->{_data_dir} = $_[1] }

sub getOutputDir { $_[0]->{_output_dir} }
sub setOutputDir { $_[0]->{_output_dir} = $_[1] }

sub new {
  my ($class, $organismAbbrev, $schemaDefinitionFile, $chromosomeMapFile, $ebi2gusTag, $ncbiTaxon, $datasetName, $datasetVersion, $mysqlInitDir, $mysqlDataDir, $mysqlOutputDir) = @_; 

  die "ERROR:  required param for organismAbbrev is missing" unless($organismAbbrev);
  die "ERROR:  required param for ebi2gusTag is missing" unless($ebi2gusTag);
  die "ERROR:  required param for ncbiTaxon is missing" unless($ncbiTaxon);
  die "ERROR:  required param for datasetName is missing" unless($datasetName);
  die "ERROR:  required param for datasetVersion is missing" unless($datasetVersion);

  die "ERROR:  schemaDefinition file does not exist" unless(-e $schemaDefinitionFile);
  die "ERROR:  chromosomeMapFile file does not exist" unless(-e $chromosomeMapFile);

  die "ERROR:  mysqlInitDir directory does not exist" unless(-d $mysqlInitDir);
  die "ERROR:  mysqlDataDir directory does not exist" unless(-d $mysqlDataDir);

  my $containerName = "ebi_wf_${organismAbbrev}";

  my $self = $class->SUPER::new($class, $containerName, undef, undef);

  $self->setContainerName($containerName);
  $self->setSchemaDefinitionFile($schemaDefinitionFile);
  $self->setChromosomeMapFile($chromosomeMapFile);
  $self->setEbi2gusVersion($ebi2gusTag);
  $self->setOrganismDatasetName($datasetName);
  $self->setOrganismDatasetVersion($datasetVersion);
  $self->setNcbiTaxon($ncbiTaxon);
  $self->setInitDir($mysqlInitDir);
  $self->setDataDir($mysqlDataDir);
  $self->setOutputDir($mysqlOutputDir);

  return $self;
 }

sub connectDatabase {
}

sub _connectDatabase {
  my ($self) = @_;

  my $databaseName = "core";

  my $containerName = $self->getContainerName();

  my @alphanumeric = ('a'..'z', 'A'..'Z', 0..9);
  my $randomPassword = join '', map $alphanumeric[rand @alphanumeric], 0..8;

  my ($registryFh, $registryFn) = tempfile("${containerName}XXXX", UNLINK => 1, SUFFIX => '.conf');

  $self->writeRegistryConf($randomPassword, $databaseName, $registryFh);
  $self->startService($registryFn, $randomPassword, $databaseName, $registryFn);

  $self->dumpEbi();
}


sub writeRegistryConf {
  my ($self, $randomPassword, $databaseName, $registryFh) = @_;

  print $registryFh "use strict;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::ConfigRegistry;

new Bio::EnsEMBL::DBSQL::DBAdaptor(
  -host    => 'localhost',
  -pass    => '$randomPassword',
  -user    => 'root',
  -group   => '$databaseName',
  -driver => 'mysql',
  -dbname  => '$databaseName'
);
1;
";
  
}

sub dumpEbi {
  my ($self) = @_;

  my $ncbiTaxon = $self->getNcbiTaxon();
  my $organismDatasetName = $self->getOrganismDatasetName();
  my $organismDatasetVersion = $self->getOrganismDatasetVersion();
  my $containerName = $self->getContainerName();

  system("singularity exec instance://$containerName dumpGUS.pl -d $organismDatasetName -v $organismDatasetVersion -n $ncbiTaxon");
}

sub startService {
  my ($self, $registryFn, $randomPassword, $databaseName, $registryFile) = @_;

  my $containerName = $self->getContainerName();
  my $initDir = $self->getInitDir();
  my $dataDir = $self->getDataDir();
  my $outputDir = $self->getOutputDir();
  my $schemaDefinitionFile = $self->getSchemaDefinitionFile();
  my $chromosomeMapFile = $self->getChromosomeMapFile();
  my $ebi2gusVersion = $self->getEbi2gusVersion();

  my $containerExists = `singularity instance list |grep $containerName`;
  if($containerExists) {
    die "There is an existing container named $containerName";
  }

  my $mysqlServiceCommand = "singularity instance start --bind ${outputDir}:/tmp --bind ${registryFile}:/usr/local/etc/ensembl_registry.conf --bind ${dataDir}:/var/lib/mysql --bind ${initDir}:/docker-entrypoint-initdb.d  docker://veupathdb/ebi2gus $containerName";

  system($mysqlServiceCommand);

  my $runscript = "SINGULARITYENV_MYSQL_ROOT_PASSWORD=${randomPassword} SINGULARITYENV_MYSQL_DATABASE=${databaseName} singularity run instance://${containerName} mysqld --defaults-file=/etc/mysql/my.cnf --basedir=/usr --datadir=/var/lib/mysql";

  my $servicePid = open(SERVICE, "-|", $runscript) or die "Could not start service: $!";

  sleep(5); # entrypoint script startup

  my $healthCheckCommand = "singularity exec instance://${containerName} ps -aux |grep docker-entrypoint.sh";
  # could also ping mysql db... but i don't think this is needed
  #  my $healthCheckCommand2 = "singularity exec instance://ebi2gus  mysqladmin --defaults-extra-file=<(cat <<-EOF\n[client]\npassword=\"${randomPassword}\"\nEOF) ping -u root --silent";

  my $healthStatus = `$healthCheckCommand`;
  chomp $healthStatus;

  # the docker-entrypoint.sh process will go away
  while($healthStatus) {
     print "Entrypoint script is running... \n";    
     sleep(3);
     $healthStatus = `$healthCheckCommand`;
     chomp $healthStatus;
  }
}

sub DESTROY {
  my $self = shift;

  unless($self->{_cleanup}) {
    $self->disconnectDatabase();
  }
}


sub disconnectDatabase {
  my ($self) = @_;

  my $containerName = $self->getContainerName();
  system("singularity instance stop $containerName");

  $self->{_cleanup} = 1;
}


sub getTableNameFromPackageName {
  my ($self, $fullTableName) = @_;

  $fullTableName =~ /GUS::Model::(.+)::(.+)/i;
  my $tableName = $1 . "." . $2;
  return uc $tableName;
}


sub prepareTable {
  my ($self, $tableName, $isSelfReferencing, $primaryKeyColumn, $maxAlreadyLoadedPk) = @_;

  my $fileName = $self->getTableNameFromPackageName($tableName);

  my $outputDir = $self->getOutputDir();

  my $fullFilePath = "$outputDir/$fileName";

  my $fh;
  open($fh, $fullFilePath) or die "Cannot open file $fullFilePath: $!";

  my $header = <$fh>;
  chomp $header;

  my @a = split($FIELD_DELIMITER, $header);
  $self->setTableFileHandle($fh);
  $self->setTableHeader(\@a);
}

sub finishTable {
  my ($self) = @_;

  my $fh = $self->getTableFileHandle();

  close $fh;

  $self->setTableFileHandle(undef);
  $self->setTableHeader(undef);
}

sub nextRowAsHashref {
  my ($self) = @_;

  my $fh = $self->getTableFileHandle();

  my $row = <$fh>;
  chomp $row;

  my @a = split($FIELD_DELIMITER, $row);

  my $header = $self->getTableHeader();

  my %hash;
  @hash{@$header} = @a;

  return \%hash;
}

# rows will only be global if entire table is
sub isRowGlobal {
  return 0; 
}

sub skipRow {
  return 0;
}

sub loadRow {
  return 1;
}

sub getDistinctTablesForTableIdField {
  my ($self, $field, $table) = @_;

  my $fileName = "CORE.TABLEINFO";
  my $nameField = "name";
  my $tableIdField = "table_id";


  my $outputDir = $self->getOutputDir();
  my $fullFilePath = "$outputDir/$fileName";
  
  open(FILE, $fullFilePath) or die "Cannot open file $fullFilePath: $!";
  my $header = <FILE>;
  chomp $header;
  my @header = split($FIELD_DELIMITER, $header);

  my ($nameIndex) = grep { lc($header[$_]) eq lc($nameField) } 0 .. $#header;
  my ($tableIdIndex) = grep { lc($header[$_]) eq lc($tableIdField) } 0 .. $#header;
  my %rv;

  if(uc($table) eq "DOTS.GOASSOCIATION") {
    my $softTable = "TranslatedAASequence";

    while(<FILE>) {
      my @a = split($FIELD_DELIMITER, $_);

      my $name = $a[$nameIndex];
      my $tableId = $a[$tableIdIndex];

      if($name eq $softTable) {
        $rv{$tableId} = "GUS::Model::DoTS::${softTable}";
      }
    }
    
  }
  else {
    die "Table $table is not handled for soft keys"
  }
  
  close FILE;

  unless(scalar(keys(%rv)) > 0) {
    die "Could not identify tables for soft key for $table, $field";
  }

  return \%rv;
}



sub getDistinctValuesForField {
  my ($self, $table, $field) = @_;

  my $fileName = $self->getTableNameFromPackageName($table);

  my $outputDir = $self->getOutputDir();
  my $fullFilePath = "$outputDir/$fileName";

  open(FILE, $fullFilePath) or die "Cannot open file $fullFilePath: $!";

  <FILE>;

  my @header = @{$self->getTableHeader()};
  my ($index) = grep { lc($header[$_]) eq lc($field) } 0 .. $#header;

  my %seen;
  while(<FILE>) {
    my @a = split($FIELD_DELIMITER, $_);
    my $value = $a[$index];
    $seen{$value} = 1;
  }
  close FILE;

  return \%seen;
}


sub getMaxFieldLength {
  my ($self, $table, $field) = @_;

  my $fileName = $self->getTableNameFromPackageName($table);

  my $outputDir = $self->getOutputDir();
  my $fullFilePath = "$outputDir/$fileName";

  open(FILE, $fullFilePath) or die "Cannot open file $fullFilePath: $!";

  <FILE>;
  my @header = @{$self->getTableHeader()};
  my ($index) = grep { lc($header[$_]) eq lc($field) } 0 .. $#header;

  my $length = 0;
  while(<FILE>) {
    my @a = split($FIELD_DELIMITER, $_);
    my $value = $a[$index];
    my $l = length $value;
    $length = $l if($l > $length);
  }
  close FILE;

  return $length;
}


# not used
sub getTableCount {
  die "";
}


1;
