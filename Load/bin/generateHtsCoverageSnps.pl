#!/usr/bin/perl
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | absent
  # GUS4_STATUS | RAD.Analysis                   | auto   | absent
  # GUS4_STATUS | ApiDB.Profile                  | auto   | absent
  # GUS4_STATUS | Study.Study                    | auto   | absent
  # GUS4_STATUS | Dots.Isolate                   | auto   | absent
  # GUS4_STATUS | DeprecatedTables               | auto   | absent
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | broken
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

## to be run after all HTS snps have been loaded.  
## Note: the configFile must contain a row for all HTS snp samples on this referenceOrganism

use strict;
use Getopt::Long;
use lib "$ENV{GUS_HOME}/lib/perl";
use GUS::ObjRelP::DbiDatabase;
use GUS::Supported::GusConfig;

my $file; 
my $output = 'coverageSnps.gff';
my $gusConfigFile = $ENV{GUS_HOME} ."/config/gus.config";
my $referenceOrganism;
my $verbose;

&GetOptions("configFile|f=s" => \$file, 
            "gusConfigFile|gc=s"=> \$gusConfigFile,
            "output|o=s"=> \$output,
            "verbose|v!"=> \$verbose,
            "referenceOrganism|r=s"=> \$referenceOrganism,
            );

if (! -e $file && $referenceOrganism){
die <<endOfUsage;
generateCoverageSnps.pl usage:

  generateCoverageSnps.pl --configFile|f <config file with two tab delimited columns (filename\tstrain)> --gusConfigFile|gc <gusConfigFile [\$GUS_HOME/config/gus.config] --referenceOrganism <organism on which SNPs are predicted .. ie aligned to> --output|o <outputFile [coverageSnps.gff]> --verbose!
endOfUsage
}

my $gusConfig = GUS::Supported::GusConfig->new($gusConfigFile);

my $db = GUS::ObjRelP::DbiDatabase->new($gusConfig->getDbiDsn(),
                                         $gusConfig->getDatabaseLogin(),
                                         $gusConfig->getDatabasePassword(),
                                         $verbose, 0, 1,
                                         $gusConfig->getCoreSchemaName()
                                        );

my $dbh = $db->getQueryHandle();

open(O,">$output") || die "unable to open $output for output\n";


my $snpSQL = <<EOSQL;
select sf.source_id as snp_id,s.source_id as seq_id,l.start_min,sf.reference_na,sv.strain,sv.allele
from dots.snpfeature sf, DOTS.seqvariation sv, dots.nalocation l,
SRES.externaldatabase d, SRES.externaldatabaserelease rel,dots.nasequence s
where d.name = 'InsertSnps.pm NGS SNPs INTERNAL'
and rel.external_database_id = d.external_database_id
and sf.external_database_release_id = rel.external_database_release_id
and sf.organism = '$referenceOrganism'
and sv.parent_id = sf.na_feature_id
and l.na_feature_id = sf.na_feature_id
and s.na_sequence_id = sf.na_sequence_id
EOSQL

my %snps;

my $stmt = $dbh->prepare($snpSQL);
$stmt->execute();
my $ct = 0;
print STDERR "Returning rows from snp query\n";
while(my $row = $stmt->fetchrow_hashref()){
  $snps{$row->{SEQ_ID}}->{$row->{START_MIN}}->{id} = $row->{SNP_ID};
  $snps{$row->{SEQ_ID}}->{$row->{START_MIN}}->{ref} = $row->{REFERENCE_NA};
  $snps{$row->{SEQ_ID}}->{$row->{START_MIN}}->{strains}->{$row->{STRAIN}} = $row->{ALLELE}; ##could be multiple alleles but doesn't matter as not adding any new ones if there is at least one
  $ct++;
  print STDERR "Processed $ct rows\n" if ($verbose && $ct % 10000 == 0);
}

$db->logout();

print STDERR "Identified SNPs on ",scalar(keys%snps)," sequences\n" if $verbose;

open(C, "$file") || die "unable to open config file $file\n";
my %newSnps;
while(<C>){
  chomp;
  my($f,$strain) = split("\t",$_);
  next unless $strain;
  open(F, "$f") || die "unable to open file $file\n";
  print STDERR "Processing file $f for strain $strain\n";
  my $ctLines = 0;
  my $ctSnps = 0;
  while(<F>){
    next if /^Chrom\s+Position/;
    $ctLines++;
    print STDERR "$f: Processed $ctLines\n" if ($verbose && $ctLines % 100000 == 0);
    chomp;
    my @tmp = split("\t",$_);
    next if (!$snps{$tmp[0]}->{$tmp[1]} || $snps{$tmp[0]}->{$tmp[1]}->{strains}->{$strain});
    ##snp here and not present in this strain .... only add if like reference as already processed for snps 
    my $reference = $snps{$tmp[0]}->{$tmp[1]}->{ref};
    print STDERR "WARNING: $tmp[0]:$tmp[1] - reference alleles not same ($tmp[2] - $reference)\n" unless $tmp[2] eq $reference;
    next if $tmp[3] ne $reference;
#    print STDERR "Identified coverage snp $tmp[0]:$tmp[1] for $strain\n" if $verbose;
    $ctSnps++;
    $newSnps{$tmp[0]}->{$tmp[1]}->{ref} = $reference;
    $newSnps{$tmp[0]}->{$tmp[1]}->{id} = $snps{$tmp[0]}->{$tmp[1]}->{id};
    push(@{$newSnps{$tmp[0]}->{$tmp[1]}->{strains}},"$strain:$tmp[3]:".&getCoverage(\@tmp).":".&getPercent(\@tmp).":$tmp[9]:");
#    last if $ctSnps >= 100;
  }
  close F;
}

##now print out the gff file ...
my $ctsnps = 0;
foreach my $seqid (keys(%newSnps)){
  foreach my $loc (sort{$a <=> $b}keys(%{$newSnps{$seqid}})){
    $ctsnps++;
    my @alleles = @{$newSnps{$seqid}->{$loc}->{strains}};
    my $snpid = $newSnps{$seqid}->{$loc}->{id};
    print O "$seqid\tNGS_SNP\tSNP\t$loc\t$loc\t.\t+\t.\tID $snpid; Allele \"".join("\" \"",@alleles)."\";\n";
  }
}
print STDERR "Coverage SNPs: Added strains to $ctsnps SNPs\n";

close O;

sub getCoverage {
  my($line) = @_;
  return $line->[4] + $line->[5];
}

sub getPercent {
  my($line) = @_;
  chop $line->[6];
  return $line->[2] eq $line->[3] ? 100 - $line->[6] : $line->[6];
}
