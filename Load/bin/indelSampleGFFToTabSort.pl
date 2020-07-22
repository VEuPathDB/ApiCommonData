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
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | absent
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

use strict;
use Bio::Tools::GFF;
use Getopt::Long;
use File::Basename;

use Cwd qw(cwd);
use Data::Dumper;

my ($snpGff, $outFile, $gffVersion);

&GetOptions("snp_gff=s"=> \$snpGff,
            "out_file=s" => \$outFile,
            "gff_version=i" => \$gffVersion
    );

unless(-e $snpGff && $outFile && $gffVersion) {
  print STDERR "usage: perl snpSampleGFFToTabSort.pl --snp_gff <GFF> --out_file <OUT> --gff_version [INTEGER]\n";
  exit;
}

my $gffIO = Bio::Tools::GFF->new(-file => $snpGff,
                                 -gff_version => $gffVersion
    );

# sort the output file by first 2 colulmns (second column is numeric)
my $DIR = cwd;
open(OUT, "|sort -T $DIR -k 1,1 -k 2,2n > $outFile") or die "Cannot open file $outFile for writing: $!";

while (my $feature = $gffIO->next_feature()) {
  my $snpStart = $feature->location()->start();
  my $snpEnd = $feature->location()->end();

  die "Snp Start and Snp end must be equal" unless($snpStart == $snpEnd);

  my $sequenceId = $feature->seq_id();

  next unless ($sequenceId eq "Pf3D7_02_v3" && $snpStart >= 717000);
  last unless ($snpStart <= 755000);

  my ($snpId) = $feature->get_tag_values('ID');

  my $indelType =  $feature->{_source_tag};

  foreach ($feature->get_tag_values('Allele')) {
    my ($strain, $base, $coverage, $percent, $quality, $pvalue) = split(':', $_);
    if ($indelType eq "deletion") {
	$base = "-".$base;
    } elsif ($indelType eq "insertion") {
	$base = "+".$base;
    } else {
	print "Not an insertion or deletion: $sequenceId\t$snpStart\t$strain\t$base\t$indelType\n";
    }
    next if($base eq 'undefined');
    
    $percent =~ s/%//g;

    print OUT join("\t", ($sequenceId, $snpStart, $strain, $base, $coverage, $percent, $quality, $pvalue, $snpId)) . "\n";
  }
}
close OUT;
$gffIO->close();
if (-z $outFile){
	die "$outFile is empty" unless (-z $snpGff);
}
