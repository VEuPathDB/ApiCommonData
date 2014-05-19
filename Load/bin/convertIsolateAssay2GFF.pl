#!/usr/bin/perl

use strict;
use DBI;
use lib "$ENV{GUS_HOME}/lib/perl";
use CBIL::Util::PropertySet;
use Getopt::Long;

my ($gusConfigFile,$inputFile,$outputFile,$isolateType);

&GetOptions( "gusConfigFile=s" => \$gusConfigFile,
             "inputFile=s"     => \$inputFile,
             "outputFile=s"    => \$outputFile,
             "isolateType=s"   => \$isolateType,
           );

$gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config" unless($gusConfigFile);

unless(-e $gusConfigFile) {
  print STDERR "gus.config file not found! \n";
  exit;
} 

=usage

perl convertIsolateAssay2GFF.pl --inputFile /home/hwang/workflows/PlasmoDB/miniflow_test/data/pfal3D7/organismSpecificNoAlias/SNPs/pfal3D7_SNP_Broad3KGenotyping_test_RSRC/isolateSNPs.txt --outputfile /home/hwang/workflows/PlasmoDB/miniflow_test/data/pfal3D7/organismSpecificNoAlias/SNPs/pfal3D7_SNP_Broad3KGenotyping_test_RSRC/isolateSNPs.gff --isolateType 3k_chip

example inputFile
/eupath/data/EuPathDB/manualDelivery/PlasmoDB/pfal3D7/SNP/Broad3KGenotyping/2008-06-13/final/isolateSNPs.txt

example outputFile gff
/eupath/data/EuPathDB/manualDelivery/PlasmoDB/pfal3D7/SNP/Broad3KGenotyping/2008-06-13/final/isolateSNPs.gff

example isolateType
barcode, 3k_chip and hd_array
=cut

my @properties = ();
my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);

my $usr = $gusconfig->{props}->{databaseLogin};
my $pwd = $gusconfig->{props}->{databasePassword};
my $dsn = $gusconfig->{props}->{dbiDsn};

my $dbh = DBI->connect($dsn, $usr, $pwd) ||  die "Couldn't connect to database: " . DBI->errstr;
$dbh->{RaiseError} = 1;
$dbh->{AutoCommit} = 0;

my $sql = <<EOSQL;
SELECT etn.source_id, nal.start_min, nal.end_max 
FROM   dots.snpfeature snp, dots.nalocation nal, dots.externalnasequence etn
WHERE snp.na_feature_id = nal.na_feature_id
  AND snp.na_sequence_id = etn.NA_SEQUENCE_ID
  AND snp.source_id = ?
EOSQL

my $sth = $dbh->prepare($sql);
my @strains;

open (OUT, ">$outputFile");
open (F, $inputFile);
while(<F>) {
  chomp;
  next if /^#/;
  next if /^(Origin|Source|Note|Identifier)/i;

  if(/^Strain/i) {
    @strains = split /\t/, $_; 
    shift @strains;
    next;
  }   

  my @snps = split /\t/, $_; 
  my $id = shift @snps;
  $id =~ s/\s//g;
  @snps = map { $_ =~ s/\s//g; $_ } @snps;

  $sth->execute($id);
  my ($seqid, $start, $stop) = $sth->fetchrow_array;

  next unless $seqid;
  print OUT "$seqid\tBroad\t$isolateType\t$start\t$stop\t.\t.\t.\tID $id". "_". "$isolateType; Allele ";

  my $count = 0;
  foreach my $snp (@snps) {
    my $strain = $strains[$count];
    next unless $snp;
    print OUT "\"$strain:$snp\" ";
    $count++;
  }

  print OUT "\n";
}

close OUT;
close F;
$sth->finish;
$dbh->disconnect
