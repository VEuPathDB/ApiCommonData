#!/usr/bin/perl

## a script to remove some question genes from an annotation file
## the question genes listed in a list file, one gene ID one line

use strict;
use Getopt::Long;
use Bio::SeqFeature::Generic;
use ApiCommonData::Load::AnnotationUtils qw{getSeqIO};

my ($inputFile, $questFile, $outputFile, $format, $help);

&GetOptions('inputFile=s' => \$inputFile,
            'format=s' => \$format,
            'questFile=s' => \$questFile,
            'outputFile=s' => \$outputFile,
            'help|h' => \$help,
           );

&usage() if($help);
&usage("Missing a Required Argument") unless(defined $inputFile && $outputFile && $format && $questFile);

my %ignores;
open (QU, "$questFile") || die "can not open $questFile file to read.\n";
while (<QU>) {
  chomp;
  if ($_) {
    $ignores{$_} = 1;
  }
}

my $seq_in = Bio::SeqIO->new ('-file' => "<$inputFile", '-format' => $format);
my $seq_out = Bio::SeqIO->new('-file' => ">$outputFile", '-format' => $format);

while (my $seq = $seq_in->next_seq() ) {

  my @topSeqFeatures = $seq->remove_SeqFeatures;

  foreach my $bioperlFeature ( @topSeqFeatures ) {
    my $type = $bioperlFeature->primary_tag();

    if ($type eq "gene" || $type eq "CDS") {

      my ($id) = $bioperlFeature->get_tag_values('locus_tag') if ($bioperlFeature->has_tag('locus_tag'));
      next if ($ignores{$id});

    }

    ## add $seq to $newSeq
    $seq->add_SeqFeature($bioperlFeature);
  }

  $seq_out->write_seq($seq);
}


sub usage {
  die
"
Usage: perl removeGenesFromAnnotFile.pl --inputFile CYKH01.1.gbff  --outputFile whole_genome.gbf --format genbank --questFile removeGeneLists.txt

where
  --inputFile:  required, the input annotation file
  --format:  required, the input and output file format
  --questFile:  required, the file that have gene IDs that want to be ignored
  --outputFile:  required, the output file name
";
}
