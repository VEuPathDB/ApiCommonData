#!/usr/bin/perl

use strict;

use lib $ENV{GUS_HOME} . "/lib/perl";

use Getopt::Long;
use File::Temp qw/ tempfile /;

use DBI;
use DBD::Oracle;

use CBIL::Util::PropertySet;

my $databaseName = "core";

my ($help, $containerName, $initDir, $dataDir, $outputDir, $schemaDefinitionFile, $chromosomeMapFile, $datasetName, $datasetVersion, $ncbiTaxId, $ebi2gusVersion, $projectName, $projectRelease, $gusConfigFile, $organismAbbrev);

&GetOptions('help|h' => \$help,
            'container_name=s' => \$containerName,
            'init_directory=s' => \$initDir,
            'mysql_directory=s' => \$dataDir,
            'output_directory=s' => \$outputDir,
            'schema_definition_file=s' => \$schemaDefinitionFile,
            'chromosome_map_file=s' => \$chromosomeMapFile,
            'dataset_name=s' => \$datasetName,
            'dataset_version=s' => \$datasetVersion,
            'project_name=s' => \$projectName,
            'project_release=s' => \$projectRelease,
            'ncbi_tax_id=s' => \$ncbiTaxId,
            'ebi2gus_tag=s' => \$ebi2gusVersion,
            'gusConfigFile=s' => \$gusConfigFile,
            'organism_abbrev=s' => \$organismAbbrev,
            );

##Create db handle
if(!$gusConfigFile) {
  $gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config";
}

&usage("Config file $gusConfigFile does not exist.") unless -e $gusConfigFile;

my @properties;
my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);

my $dbiDsn = $gusconfig->{props}->{dbiDsn};
my $dbiUser = $gusconfig->{props}->{databaseLogin};
my $dbiPswd = $gusconfig->{props}->{databasePassword};

my $dbh = DBI->connect($dbiDsn, $dbiUser, $dbiPswd) or die DBI->errstr;
$dbh->{RaiseError} = 1;
$dbh->{AutoCommit} = 0;


my $GO_NAME = "GO_RSRC";
my $SO_NAME = "SO_RSRC";
my $GOEVID_NAME = "GO_evidence_codes_RSRC";

my $GO_VERSION = &getDatabaseRelease($dbh, $GO_NAME);
my $GOEVID_VERSION = &getDatabaseRelease($dbh, $GOEVID_NAME);
my $SO_VERSION = &getDatabaseRelease($dbh, $SO_NAME);

$dbh->disconnect();


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

foreach($containerName, $datasetName, $datasetVersion, $ncbiTaxId, $projectName, $projectRelease, $organismAbbrev) {
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

my $mysqlServiceCommand = "singularity instance start --bind ${outputDir}:/tmp --bind ${registryFn}:/usr/local/etc/ensembl_registry.conf --bind ${dataDir}:/var/lib/mysql --bind ${initDir}:/docker-entrypoint-initdb.d  docker://veupathdb/ebi2gus:${ebi2gusVersion} $containerName";

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

system("singularity exec instance://$containerName dumpGUS.pl -d $datasetName -v $datasetVersion -n $ncbiTaxId -r $projectRelease -p $projectName -g '$GO_NAME|$GO_VERSION' -s '$SO_NAME|$SO_VERSION' -l '$GOEVID_NAME|$GOEVID_VERSION' -a $organismAbbrev") == 0
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

sub getDatabaseRelease {
  my ($dbh, $dbName) = @_;

  my $sql = "select r.version 
from sres.externaldatabase d, sres.externaldatabaserelease r 
where d.name = ?
and d.external_database_id = r.external_database_id";

  my $sh = $dbh->prepare($sql);
  $sh->execute($dbName);

  my ($rv) = $sh->fetchrow_array();

  $sh->finish();

  return $rv;
}

1;
