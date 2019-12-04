package ApiCommonData::Load::EBITableReader;
use base qw(ApiCommonData::Load::UniDBTableReader);

use strict;

use File::Temp qw/ tempfile /;

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

sub prepareTable {}

sub finishTable {}

sub nextRowAsHashref {}

sub isRowGlobal {}

sub skipRow {}
sub loadRow {}


=head2 Helpers for Caching Foreign Keys

=over 4

=item C<getDistinctTablesForTableIdField>

Soft Key Helper.  For a field which is a foreign key to Core::TableInfo, get distinct table_id->TableName mappings

B<Parameters:>

 $self(TableReader): a table reader object
 $field(string): database filed which is a fk to Core::TableInfo (example query_table_id)
 $table(string): database table name like "DoTS.Similarity"

B<Return type:> 

 C<hashref> key is table_id and value is gus model table string.  example:  GUS::Model::DoTS::Similarity

=cut

sub getDistinctTablesForTableIdField {
  my ($self, $field, $table) = @_;
}


=item C<getDistinctValuesForField>

Foreign Key Helper.  For a table and field, lookup distinct possible values and return a hash

B<Parameters:>

 $self(TableReader): a table reader object
 $table(string): gus model table string.  example:  GUS::Model::DoTS::Similarity
 $field(string): this field is a foreign key field in the gus $table

B<Return type:> 

 C<hash> $seen{$id} = 1;

=cut

sub getDistinctValuesForField {
  my ($self, $table, $field) = @_;
}


=item C<getMaxFieldLength>

For memory allocation we need to know the biggest possible length for the field

B<Parameters:>

 $self(TableReader): a table reader object
 $table(string): gus model table string.  example:  GUS::Model::DoTS::Similarity
 $field(string): field name

B<Return type:> 

 C<hash> $length

=cut

sub getMaxFieldLength {
  my ($self, $table, $field) = @_;
}


=item C<getTableCount>

count how many rows are in the table with primary key value <= some value

B<Parameters:>

 $self(TableReader): a table reader object
 $fullTableName(string): gus model table string.  example:  GUS::Model::DoTS::Similarity
 $primaryKeyColumn(string): name of of the primary key field
 $maxPrimaryKey(number): do not count rows with pk greater than this value

B<Return type:> 

 C<number> $count

=cut

sub getTableCount {
  my ($self, $fullTableName, $primaryKeyColumn, $maxPrimaryKey) = @_;
}


1;
