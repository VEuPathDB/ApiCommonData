#!/usr/bin/perl

## this script contain all special requirements that EBI wants for gff3

use strict;

## 1. adjust CDS coords for pseudogenic_transcript to truncate to the 1st stop codon
## 2. remove three_prime_UTR and five_prime_UTR for pseudogenic_transcript
## 3. change CDS ID to use the protein_id instead


use lib "$ENV{GUS_HOME}/lib/perl";
use Getopt::Long;
use CBIL::Util::Utils;
use ApiCommonData::Load::BioperlTreeUtils qw{makeBioperlFeature};
use ApiCommonData::Load::AnnotationUtils;
use ApiCommonData::Load::Unflattener;
use Bio::Tools::GFF;

my ($inputFileOrDir, $proteinFile, $outputFileDir, $outputGffFileName,
    $help);

&GetOptions('inputFileOrDir=s' => \$inputFileOrDir,
            'proteinFile=s' => \$proteinFile,
            'outputFileDir=s' => \$outputFileDir,
            'outputGffFileName=s' => \$outputGffFileName,
            'help|h' => \$help
            );
&usage() if ($help);
&usage("Missing a Required Argument") unless (defined $inputFileOrDir && $outputGffFileName);

if (!$outputFileDir) {
  $outputFileDir = ".";
}

my (%pSeqs, %pLength, $pId);

open (PT, "$proteinFile") || die "can not open proteinFile to read\n";
while (<PT>) {
  chomp;
  if ($_ =~ /^>(.+)/) {
    $pId = $1;
  } else {
    $pSeqs{$pId} .= $_;
  }
}
close PT;

foreach my $k (sort keys %pSeqs) {
  $pLength{$k} = length($pSeqs{$k}) * 3 + 3;
#  print ">$k $pLength{$k}\n$pSeqs{$k}\n" if ($k eq "NCLIV_007220-t26_1-p1" || $k eq "NCLIV_008940-t26_1-p1" 
#					     || $k eq "NCLIV_017911-t26_1-p1" || $k eq "NCLIV_038021-t26_1-p1"
#					     || $k eq "NCLIV_047911-t26_1-p1" || $k eq "NCLIV_051560-t26_1-p1"
#					     || $k eq "NCLIV_060741-t26_1-p1" || $k eq "NCLIV_066150-t26_1-p1"
#					     || $k eq "NCLIV_051561-t26_1-p1" || $k eq "NCLIV_060740-t26_1-p1");
}

# read from gff3
my $bioperlFeatures = ApiCommonData::Load::AnnotationUtils::readFeaturesFromGff($inputFileOrDir);

my $bioperlFeaturesNested = ApiCommonData::Load::AnnotationUtils::nestGeneHierarchy($bioperlFeatures);

foreach my $gene (@{$bioperlFeaturesNested}) {
  my $seqId = $gene->seq_id;
  my $type = $gene->primary_tag;
  my $id;
  foreach my $transcript ($gene->get_SeqFeatures()) {
    my $tType = $transcript->primary_tag;
    my $tStrand = $transcript->strand;
    if ($tType eq "pseudogenic_transcript") {
      my @exons = $transcript->remove_SeqFeatures;
      my ($pId, %pseudoCdsFeats);
      foreach my $exon (@exons) {
	my $eType = $exon->primary_tag;
	if ($eType eq "CDS") {
	  my ($eId) = $exon->get_tag_values('ID') if ($exon->has_tag('ID'));
	  ($pId = $eId) =~ s/-CDS\d+$//;

	  my $eStart = $exon->start();
	  my $eEnd = $exon->end();
	  #print STDERR "protein $pId, CDS $eId, start=$eStart, end=$eEnd.\n";
	  push @{$pseudoCdsFeats{$pId}}, $exon;
	} elsif ($eType eq "pseudogenic_exon" || $eType eq "exon") {
	  $transcript->add_SeqFeature($exon);
	} else {
	  ## ignore three_prime_UTR and five_prime_UTR
	}
      } # end of foreach my $exon

      my ($doneCds, $cdsOne);
      my $remainCdsLen = $pLength{$pId};
      if ($tStrand == 1) {
	foreach my $pCDS (sort {$a->location->start() <=> $b->location->start()} @{$pseudoCdsFeats{$pId}}) {
	  next if ($doneCds == 1);
	  $cdsOne++;
	  my $cFrame = $pCDS->frame();
	  my $cdsLen = $pCDS->location->end() - $pCDS->location->start() + 1;
	  $remainCdsLen += $pCDS->frame() if ($cdsOne == 1);
	  if ($remainCdsLen > $cdsLen ) {
	    $remainCdsLen -= $cdsLen;
	  } else {
	    my $e = $pCDS->location->start + $remainCdsLen - 1;
	    $doneCds = 1;
	    ($e >= $pCDS->location->start) ? $pCDS->location->end($e) : next;
	  }

	  &renameCdsIdWithProteinId($pCDS);
	  $transcript->add_SeqFeature($pCDS);
	}
      } else {
	my @unSortedCDS;
	foreach my $pCDS (sort {$b->location->start() <=> $a->location->start()} @{$pseudoCdsFeats{$pId}}) {
	  next if ($doneCds == 1);
	  $cdsOne++;
	  my $cFrame = $pCDS->frame();
	  my $cdsLen = $pCDS->location->end() - $pCDS->location->start() + 1;
	  $remainCdsLen += $pCDS->frame() if ($cdsOne == 1);
	  #print STDERR "\$cdsLen = $cdsLen\n\$remainCdsLen=$remainCdsLen\n";
	  if ($remainCdsLen > $cdsLen ) {
	    $remainCdsLen -= $cdsLen;
	    #print STDERR "\$remainCdsLen=$remainCdsLen\n";
	  } else {
	    my $s = $pCDS->location->end() - $remainCdsLen + 1;
	    $doneCds = 1;
	    ($s <= $pCDS->location->end) ? $pCDS->location->start($s) : next;
	  }

	  push @unSortedCDS, $pCDS;
	}

	## resort the truncated CDSs
	foreach my $pCDS (sort {$a->location->start() <=> $b->location->start()} @unSortedCDS ) {
	  &renameCdsIdWithProteinId($pCDS);
	  $transcript->add_SeqFeature($pCDS);
	}
      }

    } # end of if ($tType eq "pseudogenic_transcript")
    else {
      foreach my $exon ($transcript->get_SeqFeatures()) {
	if ($exon->primary_tag eq "CDS") {
	  &renameCdsIdWithProteinId($exon);
	}
      }
    } # end of rename CDS id for non-pseudogene
  }
}

my $bioperlFeaturesFlatted = ApiCommonData::Load::AnnotationUtils::flatGeneHierarchySortBySeqId($bioperlFeaturesNested);

# write to a new gff3 output file
if ($outputGffFileName) {
  ApiCommonData::Load::AnnotationUtils::writeFeaturesToGffBySeqId ($bioperlFeaturesFlatted, $outputGffFileName);
}


#########
sub renameCdsIdWithProteinId {
  my ($feature) = @_;

  my ($cdsId) = $feature->get_tag_values('ID') if ($feature->has_tag('ID'));
  $cdsId =~ s/(\S+)-CDS\d+$/$1/i;
  $feature->remove_tag('ID');
  $feature->add_tag_value('ID', $cdsId);

}


sub usage {
  die
"
A script to modify gff3 file based on what EBI pipeline requires
Usage:  perl modifyGff3BasedEbi.pl --inputFileOrDir nLIV/ncanLIV.gff3 --proteinFile ncanLIV_protein.fa --outputGffFileName ncanLIV.gff3.modified


where:
  --inputFileOrDir: required
  --proteinFile: required
  --outputFileDir: optional, the directory name for output file
  --outputGffFileName: required, output file name

";
}


