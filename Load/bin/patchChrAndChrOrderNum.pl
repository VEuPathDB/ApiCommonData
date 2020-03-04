#!/usr/bin/perl

use strict;
use lib "$ENV{GUS_HOME}/lib/perl";

use CBIL::Util::PropertySet;
use Getopt::Long;
use DBI;
use DBD::Oracle;

my ($help, $mapFile, $gusConfigFile, $extDbRlsId, $organismAbbrev, $genomeVersion, $sequenceTable);

&GetOptions('help|h' => \$help,
            'chromosomeMapFile=s' => \$mapFile,
            'gusConfigFile=s' => \$gusConfigFile,
            'organismAbbrev=s' => \$organismAbbrev,
            'extDbRlsId=s' => \$extDbRlsId,
            'genomeVersion=s' => \$genomeVersion,
            'sequenceTable=s' => \$sequenceTable,
            );


$gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config" unless($gusConfigFile);
$sequenceTable = "ExternalNaSequence" unless ($sequenceTable);

unless($mapFile && -e $mapFile) {
  die "usage --chromosomeMapFile chromosomeMapFile --sequenceTable 'ExternalNaSequence|VirtualSequence' [--gusConfigFile]\n";
}

my @properties = ();
my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);

my $u = $gusconfig->{props}->{databaseLogin};
my $pw = $gusconfig->{props}->{databasePassword};
my $dsn = $gusconfig->{props}->{dbiDsn};

my $dbh = DBI->connect($dsn, $u, $pw) or die DBI::errstr;
$dbh->{RaiseError} = 1;
$dbh->{AutoCommit} = 0;


my $sql = "update dots.$sequenceTable set chromosome = ?, chromosome_order_num = ?, modification_date=sysdate where source_id = ? and EXTERNAL_DATABASE_RELEASE_ID = $extDbRlsId";
my $sh = $dbh->prepare($sql);

my $error;

open(FILE, $mapFile) or die "Cannot open file $mapFile for reading:$!";
while(<FILE>) {
  chomp;
  my ($sourceIdPrefix, $chrom, $chrOrderNumber) = split(/\t/, $_);

  next unless($chrom);

#  my $sourceId = $organismAbbrev . "_" . $sourceIdPrefix;  ## in the case sourceId = organismAbbrev_2L
  my $sourceId = $sourceIdPrefix;  ## not need add prefix anymore

  $chrOrderNumber = $chrom unless $chrOrderNumber;

  $sh->execute($chrom, $chrOrderNumber, $sourceId);

  my $rowCount = $sh->rows;

  if ($rowCount == 0) { ## if the sourceId = assemblyId_2L
    $sourceId = $genomeVersion . "_" . $sourceIdPrefix;
    $sh->execute($chrom, $chrOrderNumber, $sourceId);
    $rowCount = $sh->rows;
  }

  unless($rowCount == 1) {
    print STDERR "ERROR:  Chrom $sourceId updated $rowCount rows !!!\n";
    $error = 1;
  }
}

if($error) {
  $dbh->rollback();
  die ("Errors!  Rolled back database\n");
}

$dbh->commit;
print STDERR "Update Complete\n";

close FILE;

1;
