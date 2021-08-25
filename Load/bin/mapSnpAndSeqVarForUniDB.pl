#!/usr/bin/perl

use strict;
use lib "$ENV{GUS_HOME}/lib/perl";

use DBI;
use DBD::Oracle;
use Getopt::Long;

use GUS::Supported::GusConfig;

use File::Basename;


use ApiCommonData::Load::SnpUtils;
use ApiCommonData::Load::Fifo;

use Data::Dumper;

my $SEQVAR_DAT_FILE = "SeqvarCache.dat";
my $SEQVAR_CTL_FILE_PATH = "loader/loadSequenceVariations.ctl";

my $SNP_DAT_FILE = "snpFeature.dat";
my $SNP_CTL_FILE_PATH = "loader/loadSNP.ctl";

my $WORKFLOWS_DIR = "/eupath/data/EuPathDB/workflows";

my ($help, $projectName, $workflowVersion, $loaderDir, $databaseOrig, $gusConfigFile);

&GetOptions('help|h' => \$help,
            'project_name=s' => \$projectName,
            'workflow_version=s' => \$workflowVersion,
            'loader_dir=s' => \$loaderDir,
            'database_orig=s' => \$databaseOrig,
            "gus_config_file=s" => \$gusConfigFile,
            );



if($help) {
  print STDERR "usage mapSnpAndSeqVarForUniDB.pl --project_name=s --workflow_version=s --loader_dir=<DIR> --database_orig=s [--gus_config_file=<FILE>]\n";
}


my $gusconfig = GUS::Supported::GusConfig->new($gusConfigFile);

my $DBI_DSN = $gusconfig->getDbiDsn();

my $DBI_USER = $gusconfig->getDatabaseLogin();
my $DBI_PASS = $gusconfig->getDatabasePassword();

my $dbh = DBI->connect($DBI_DSN, $DBI_USER, $DBI_PASS) or die DBI->errstr;
$dbh->{RaiseError} = 1;
$dbh->{AutoCommit} = 0;

$DBI_DSN =~ s/dbi\:Oracle\://;

my $idMap = {};

my $columnMap = &columnMapForFiles();

foreach my $fn (glob "$WORKFLOWS_DIR/$projectName/$workflowVersion/data/*/SNPs_HTS/${SNP_DAT_FILE}") {
  my ($organismAbbrev) = $fn =~ /$workflowVersion\/data\/(.+)\/SNPs_HTS\//;
  my $dataDir = dirname $fn;

  print STDERR "Begin Loading for $organismAbbrev\n";

  my $snpCtlFile = "$dataDir/$SNP_CTL_FILE_PATH";
  my $seqVarCtlFile = "$dataDir/$SEQVAR_CTL_FILE_PATH";

  &addIdMappingForOrganism($idMap, $organismAbbrev, $databaseOrig, $dbh);

  &loadSnpFile("$dataDir/$SNP_DAT_FILE", $snpCtlFile, $idMap, $loaderDir, $columnMap, $organismAbbrev);
  &loadSeqVarFile("$dataDir/$SEQVAR_DAT_FILE", $seqVarCtlFile, $idMap, $loaderDir, $columnMap, $organismAbbrev);

  $idMap = {};
}

$dbh->disconnect();

sub columnMapForFiles {
  my @varColumns = ApiCommonData::Load::SnpUtils::variationFileColumnNames();
  my @snpColumns = ApiCommonData::Load::SnpUtils::snpFileColumnNames();

  my %rv;

  my $i = 0;
  foreach(@varColumns) {
    $rv{'var'}{$_} = $i++;
  }

   my $i = 0;
   foreach(@snpColumns) {
     $rv{'snp'}{$_} = $i++;
   }

  return \%rv;
}


sub addIdMappingForOrganism {
  my ($idMap, $organismAbbrev, $databaseOrig, $dbh) = @_;

  print STDERR "Getting ID Mappings\n";

  &addNASequenceIds($idMap, $organismAbbrev, $databaseOrig, $dbh);

  &addGeneFeatureIds($idMap, $organismAbbrev, $databaseOrig, $dbh);

  &addProtocolAppNodeIds($idMap, $databaseOrig, $dbh);

  &addExternalDatabaseReleaseIds($idMap, $databaseOrig, $dbh);
}

sub addNASequenceIds {
  my ($idMap, $organismAbbrev, $databaseOrig, $dbh) = @_;

  my $tableName = 'DoTS::NASequenceImp';

  my $sql = "select primary_key, primary_key_orig
from apidb.databasetablemapping m
   , dots.nasequence s
   , apidb.organism o
where m.table_name = '${tableName}'
and m.database_orig = '${databaseOrig}'
and m.primary_key = s.na_sequence_id
and s.taxon_id = o.taxon_id
and o.abbrev = '${organismAbbrev}'
and s.subclass_view != 'SplicedNASequence'
UNION
select primary_key, primary_key_orig
from apidb.databasetablemapping m
   , dots.nasequence s
   , sres.externaldatabaserelease r
   , sres.externaldatabase d
where m.table_name = '${tableName}'
and m.database_orig = '${databaseOrig}'
and m.primary_key = s.na_sequence_id
and s.external_database_release_id = r.external_database_release_id
and r.external_database_id = d.external_database_id
and d.name like '%SNPSample_RSRC'
";
  
  &addRows($tableName, $dbh, $sql, $idMap);
}
sub addGeneFeatureIds{
  my ($idMap, $organismAbbrev, $databaseOrig, $dbh) = @_;

  my $tableName = 'DoTS::NAFeatureImp';

  my $sql = "select primary_key, primary_key_orig
from apidb.databasetablemapping m
   , dots.genefeature gf
   , dots.nasequence s
   , apidb.organism o
where m.table_name = '${tableName}'
and m.database_orig = '${databaseOrig}'
and m.primary_key = gf.na_feature_id
and gf.na_sequence_id = s.na_sequence_id
and s.taxon_id = o.taxon_id
and o.abbrev = '${organismAbbrev}'";

  &addRows($tableName, $dbh, $sql, $idMap);

}

sub addProtocolAppNodeIds {
  my ($idMap, $databaseOrig, $dbh) = @_;

  my $tableName = 'Study::ProtocolAppNode';

  my $sql = "select primary_key, primary_key_orig
from STUDY.protocolappnode pan
   , apidb.databasetablemapping m
where pan.name like '%(Sequence Variation)'
and m.primary_key = pan.protocol_app_node_id
and m.database_orig = '${databaseOrig}'
and m.table_name = '${tableName}'";

  &addRows($tableName, $dbh, $sql, $idMap);
}
sub addExternalDatabaseReleaseIds {
  my ($idMap, $databaseOrig, $dbh) = @_;

  my $tableName = 'SRes::ExternalDatabaseRelease';

  my $sql = "select primary_key, primary_key_orig
from apidb.databasetablemapping m
where m.database_orig = '${databaseOrig}'
and m.table_name = '${tableName}'";

  &addRows($tableName, $dbh, $sql, $idMap);
}

sub addRows {
  my ($tableName, $dbh, $sql, $idMap) = @_;

  my $sh = $dbh->prepare($sql);
  $sh->execute();

  while(my ($pk, $pkOrig) = $sh->fetchrow_array()) {
    $idMap->{$tableName}->{$pkOrig} = $pk;
  }
  $sh->finish();
}





sub loadSeqVarFile {
  my ($inputFile, $ctlFile, $idMap, $loaderDir, $columnMap, $organismAbbrev) = @_;

  print STDERR "Loading ApiDB.SequenceVariations\n";

  my $varFile = "$loaderDir/var_${organismAbbrev}.dat";
  my $logFile = "$loaderDir/var_${organismAbbrev}.log";

  my $sqlloaderString = "sqlldr ${DBI_USER}/${DBI_PASS}\@${DBI_DSN} data=$varFile control=$ctlFile log=$logFile rows=25000 direct=TRUE";

  my $fifo = ApiCommonData::Load::Fifo->new($varFile, undef, undef, $logFile);
  my $pid = $fifo->attachReader($sqlloaderString);

  my $fh = $fifo->attachWriter();

  open(FILE, $inputFile) or die "Cannot open input file $inputFile for reading: $!";

  while(<FILE>) {
    chomp;
    my @a = split(/\t/, $_);

    my $columnsToMap = [['external_database_release_id', 'SRes::ExternalDatabaseRelease'],
                        ['na_sequence_id', 'DoTS::NASequenceImp'],
                        ['ref_na_sequence_id', 'DoTS::NASequenceImp'],
                        ['snp_external_database_release_id', 'SRes::ExternalDatabaseRelease'],
                        ['protocol_app_node_id', 'Study::ProtocolAppNode']
        ];
        
    foreach(@$columnsToMap) {
      my $column = $_->[0];
      my $table = $_->[1];
      
      my $index = $columnMap->{'var'}->{$column};
      die "Could not map seqVar column $column" unless(defined $index);

      my $orig = $a[$index];
      if($orig) {
        $a[$index] = $idMap->{$table}->{$orig};
        die "Could not map identifier for table $table:   $orig" unless(defined $a[$index]);
      }
    }

    print $fh join("\t", @a) . "\n";
  }

  close FILE;

  $fifo->cleanup();



}

sub loadSnpFile {
  my ($inputFile, $ctlFile, $idMap, $loaderDir, $columnMap, $organismAbbrev) = @_;

  print STDERR "Loading ApiDB.SNP\n";

  my $snpFile = "$loaderDir/snp_${organismAbbrev}.dat";
  my $logFile = "$loaderDir/snp_${organismAbbrev}.log";

  my $sqlloaderString = "sqlldr ${DBI_USER}/${DBI_PASS}\@${DBI_DSN} data=$snpFile control=$ctlFile log=$logFile rows=25000 direct=TRUE";

  my $fifo = ApiCommonData::Load::Fifo->new($snpFile, undef, undef, $logFile);
  my $pid = $fifo->attachReader($sqlloaderString);

  my $fh = $fifo->attachWriter();

  open(FILE, $inputFile) or die "Cannot open input file $inputFile for reading: $!";

  while(<FILE>) {
    chomp;
    my @a = split(/\t/, $_);


    my $columnsToMap = [['external_database_release_id', 'SRes::ExternalDatabaseRelease'],
                        ['na_sequence_id', 'DoTS::NASequenceImp'],
                        ['gene_na_feature_id', 'DoTS::NAFeatureImp'],
        ];
    
    foreach(@$columnsToMap) {
      my $column = $_->[0];
      my $table = $_->[1];

      my $index = $columnMap->{'snp'}->{$column};
      die "Could not map snp column $column" unless(defined $index);

      my $orig = $a[$index];
      if($orig) {
        $a[$index] = $idMap->{$table}->{$orig};
        die "Could not map identifier for table $table:   $orig" unless(defined $a[$index]);
      }
    }

    print $fh join("\t", @a) . "\n";
  }

  close FILE;

  $fifo->cleanup();
}

1;


