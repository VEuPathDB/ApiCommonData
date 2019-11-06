#!/usr/bin/perl

## a simple script to read from gff3 file, check gff3 format and gene model,
## then sort and output to a gff3 file

use strict;

use lib "$ENV{GUS_HOME}/lib/perl";
use Getopt::Long;
use CBIL::Util::Utils;
use ApiCommonData::Load::BioperlTreeUtils qw{makeBioperlFeature};
use ApiCommonData::Load::AnnotationUtils;
use ApiCommonData::Load::Unflattener;
use Bio::Tools::GFF;

my ($inputFileOrDir, $fastaInputFile, $outputFileDir, $outputGffFileName,
    $printReportFeatureQualifiers, $organismGeneticCode, $specialGeneticCode,
    $help);

&GetOptions('inputFileOrDir=s' => \$inputFileOrDir,
	    'fastaInputFile=s' => \$fastaInputFile,
	    'outputFileDir=s' => \$outputFileDir,
	    'outputGffFileName=s' => \$outputGffFileName,
	    'organismGeneticCode=s' => \$organismGeneticCode,
	    'specialGeneticCode=s' => \$specialGeneticCode,
	    'printReportFeatureQualifiers=s' => \$printReportFeatureQualifiers,
	    'help|h' => \$help
	    );
&usage() if ($help);
&usage("Missing a Required Argument") unless (defined $inputFileOrDir && $outputGffFileName);
if (!$organismGeneticCode && $specialGeneticCode) {
  die "\nMissing a Required Argument: --organismGeneticCode is required when --specialGeneticCode is presented.\n\n";
}

if (!$outputFileDir) {
  $outputFileDir = ".";
}

# read from gff3
my $bioperlFeatures = ApiCommonData::Load::AnnotationUtils::readFeaturesFromGff($inputFileOrDir);

# write to gff3
#&writeFeaturesToGff($bioperlFeatures, $outputGffFileName);

my $bioperlFeaturesNested = ApiCommonData::Load::AnnotationUtils::nestGeneHierarchy($bioperlFeatures);

my $bioperlFeaturesFlatted = ApiCommonData::Load::AnnotationUtils::flatGeneHierarchySortBySeqId($bioperlFeaturesNested);

# output reportFeatureQualifiers
my (%featureCounts, %qualifierCounts);
if ($printReportFeatureQualifiers =~ /^y/i) {
  &printReportFeatureQualifiers($bioperlFeaturesNested);
}

# verify feature location
ApiCommonData::Load::AnnotationUtils::verifyFeatureLocation ($bioperlFeaturesNested);

# check gff3 file format
ApiCommonData::Load::AnnotationUtils::checkGff3Format ($bioperlFeaturesFlatted);
ApiCommonData::Load::AnnotationUtils::checkGff3FormatNestedFeature ($bioperlFeaturesNested);

my $codonTable = $organismGeneticCode;  ## TODO: need to pass in codon_table
ApiCommonData::Load::AnnotationUtils::checkGff3GeneModel ($bioperlFeaturesNested, $fastaInputFile, $codonTable, $specialGeneticCode);

# write to a new gff3 output file
if ($outputGffFileName) {
  ApiCommonData::Load::AnnotationUtils::writeFeaturesToGffBySeqId ($bioperlFeaturesFlatted, $outputGffFileName);
}

################
sub printReportFeatureQualifiers {
  my ($feature) = @_;

  foreach my $feat (@{$feature}) {
    processFeature($feat, "root");
  }

  foreach my $feature (sort keys %featureCounts) {
    foreach my $parent (sort keys %{$featureCounts{$feature}}) {
      print "$feature:$parent ($featureCounts{$feature}{$parent})\n";
#      if (!$summary) {
        foreach my $qualifier (sort keys %{$qualifierCounts{$feature}{$parent}}) {
          print "  $qualifier ($qualifierCounts{$feature}{$parent}{$qualifier})\n";
        }
        print "\n";
#      }
    }
  }

}

sub processFeature {
  my ($bioperlFeature, $parent) = @_;

  my $type = $bioperlFeature->primary_tag();
  $featureCounts{$type}{$parent}++;
  foreach my $qualifier ($bioperlFeature->get_all_tags()) {
    $qualifierCounts{$type}{$parent}{$qualifier}++;
  }

  ## check if the bioperlFeature coordinates is negative 
  if ($bioperlFeature->location->start < 0 || $bioperlFeature->location->end < 0) {
    my ($cId) = $bioperlFeature->get_tag_values('ID') if ($bioperlFeature->has_tag('ID'));
    die "Unreason coordinates found at $type $cId: " . $bioperlFeature->location->start . " ... " . $bioperlFeature->location->end . "\n";
  }

  for my $subFeature ($bioperlFeature->get_SeqFeatures()) {
    processFeature($subFeature, $type);
  }

}




sub usage {
  die
"
A script to read a gff3 file, check gff3 format and gene model, then sort and write to another gff3 file
  gene: or pseudogene, required
  transcript: mRNA, tRNA, rRNA, pseudogenic_transcript and ect, required
  exon: or pseudogenic_exon, required
  CDS: optional

Usage: gff3ToGff3 --inputFileOrDir genome.gff3 --outputGffFileName genome.gff3.sorted

where:
  --inputFileOrDir: required, the annotation file name or directory containing annotation files
  --fastaInputFile: required if check gene model, fasta sequence file that go with the input GFF3 file
  --outputFileDir: optional, the directory name for output file
  --outputGffFileName: required, output file name
  --printReportFeatureQualifiers: optional, Yes|No
  --organismGeneticCode: required if check gene model, numerical value that can get from NCBI taxonomy.
                         The default is 1
  --specialGeneticCode: special genetic code for mitochondrial and plastid sequence, eg. Pf_M76611|4,Pf3D7_API_v3|11
                        It has to be provided together with --organismGeneticCode. Otherwise it will be ignored

";
}

