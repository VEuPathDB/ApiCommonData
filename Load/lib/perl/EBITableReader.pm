package ApiCommonData::Load::EBITableReader;

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

sub new {
  my ($class) = @_; # TODO.. add applicable variables here

  my $self = $class->SUPER::new($class, "todo", undef, undef);

   # unless($containerName) {
   #   die "required container name is missing";
   # }
 }

sub connectDatabase {
  my ($self) = @_;

  my $databaseName = "core";

  my $containerName = $self->getContainerName();

  my @alphanumeric = ('a'..'z', 'A'..'Z', 0..9);
  my $randomPassword = join '', map $alphanumeric[rand @alphanumeric], 0..8;

  my ($registryFh, $registryFn) = tempfile("${containerName}XXXX", UNLINK => 1, SUFFIX => '.conf');

  $self->writeRegistryConf($randomPassword, $databaseName, $registryFh);
  $self->startService($registryFn, $randomPassword, $databaseName);

  $self->dumpEbi();
}

sub dumpEbi {
  my ($self) = @_;

  my $containerName = $self->getContainerName();
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
  -group   => 'core',
  -driver => 'mysql',
  -dbname  => '$databaseName'
);
1;
";
  
}

sub dupmEbi {
  my ($self) = @_;

  my $ncbiTaxon = $self->getNcbiTaxon();
  my $organismDatasetName = $self->getOrganismDatasetName();
  my $organismDatasetVersion = $self->getOrganismDatasetVersion();
  my $containerName = $self->getContainerName();

  # TODO:  check status of output
  system("docker exec $containerName dumpGUS.pl -d $organismDatasetName -v $organismDatasetVersion -n $ncbiTaxon");
}

sub startService {
  my ($self, $registryFn, $randomPassword, $databaseName) = @_;

  my $containerName = $self->getContainerName();
  my $initDir = $self->getInitDir();
  my $dataDir = $self->getDataDir();
  my $schemaDefinitionFile = $self->getSchemaDefinitionFile();
  my $chromosomeMapFile = $self->getChromosomeMapFile();
  my $ebi2gusVersion = $self->getEbi2gusVersion();

  my $containerExists = `docker ps -a |grep $containerName`;
  if($containerExists) {
    die "There is an existing container named $containerName";
  }

  my $mysqlServiceCommand = "docker run --name $containerName --health-cmd='mysqladmin ping --silent' -v ${chromosomeMapFile}:/usr/local/etc/chromosomeMap.conf -v ${schemaDefinitionFile}:/usr/local/etc/gusSchemaDefinitions.xml -v ${registryFn}:/usr/local/etc/ensembl_registry.conf -v ${initDir}:/docker-entrypoint-initdb.d -v ${dataDir}:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=${randomPassword} -e MYSQL_DATABASE=${databaseName} veupathdb/ebi2gus:${ebi2gusVersion}";

  my $servicePid = open(SERVICE, "-|", $mysqlServiceCommand) or die "Could not start service: $!";
  
  print "Service Starting....\n";
  sleep(5); # let the service start before checking health

  my $healthCheckCommand = "docker inspect --format='{{json .State.Health.Status}}' $containerName";
  my $healthStatus = `$healthCheckCommand`;
  chomp $healthStatus;

  while($healthStatus ne "\"healthy\"") {
    unless($healthStatus eq "\"starting\"") {
      die "Docker image failed to start up propery:  Health Status = $healthStatus";
    }
    print "Service status = $healthStatus ... \n";    
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
  system("docker stop $containerName");
  system("docker rm $containerName");

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
