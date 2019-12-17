#!/usr/bin/perl

use strict;
use Getopt::Long;
use File::Temp qw/ tempfile /;

$/ = "#EOR#\n";
my $FIELD_DELIMITER = "#EOC#\t";

my $databaseName = "core";

my ($help, $containerName, $initDir, $dataDir, $outputDir, $schemaDefinitionFile, $chromosomeMapFile, $datasetName, $datasetVersion, $ncbiTaxId, $ebi2gusVersion);

&GetOptions('help|h' => \$help,
            'container_name=s' => \$containerName,
            'init_directory=s' => \$initDir,
            'mysql_directory=s' => \$dataDir,
            'output_directory=s' => \$outputDir,
            'schema_definition_file=s' => \$schemaDefinitionFile,
            'chromosome_map_file=s' => \$chromosomeMapFile,
            'dataset_name=s' => \$datasetName,
            'dataset_version=s' => \$datasetVersion,
            'ncbi_tax_id=s' => \$ncbiTaxId,
            'ebi2gus_tag=s' => \$ebi2gusVersion,
            );

foreach($initDir,$dataDir,$outputDir) {
  unless(-d $_) {
    &usage();
    die "directory $_ does not exist";
  }
}

foreach($schemaDefinitionFile, $chromosomeMapFile) {
  unless(-e $_) {
    &usage();
    die "file $_ does not exist";
  }
}

foreach($containerName, $datasetName, $datasetVersion, $ncbiTaxId) {
  unless(defined $_) {
    &usage();
    die "container, dataset name and version and ncbi taxonomy are all required";
  }
}

sub usage {
  print "ebiDumper.pl -init_directory=DIR --mysql_directory=DIR --output_directory=DIR --schema_definition_file=FILE --chromosome_map_file=FILE container_name=s dataset_name=s dataset_version=s ncbi_tax_id=s\n";
}


my @alphanumeric = ('a'..'z', 'A'..'Z', 0..9);
my $randomPassword = join '', map $alphanumeric[rand @alphanumeric], 0..8;

my ($registryFh, $registryFn) = tempfile("${containerName}XXXX", UNLINK => 1, SUFFIX => '.conf');

&writeRegistryConf($randomPassword, $databaseName, $registryFh);

my $containerExists = `singularity instance list |grep $containerName`;
if($containerExists) {
  die "There is an existing container named $containerName";
}

my $mysqlServiceCommand = "singularity instance start --bind ${outputDir}:/tmp --bind ${registryFn}:/usr/local/etc/ensembl_registry.conf --bind ${dataDir}:/var/lib/mysql --bind ${initDir}:/docker-entrypoint-initdb.d  docker://veupathdb/ebi2gus $containerName";

system($mysqlServiceCommand) == 0
    or &stopContainerAndDie($containerName, "singularity exec failed: $?");

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

system("singularity exec instance://$containerName dumpGUS.pl -d $datasetName -v $datasetVersion -n $ncbiTaxId") == 0
    or &stopContainerAndDie($containerName, "singularity exec failed: $?");

&stopContainer($containerName);


sub stopContainerAndDie {
  my ($containerName, $msg) = @_;
  &stopContainer($containerName);
  die $msg;
}

sub stopContainer {
  my ($containerName) = @_;

  system("singularity instance stop $containerName") == 0
      or die "singularity stop failed... you may need to stop this container manually [$containerName]: $?";
}

sub writeRegistryConf {
  my ($randomPassword, $databaseName, $registryFh) = @_;

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

1;
