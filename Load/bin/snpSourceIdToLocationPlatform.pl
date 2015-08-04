#!/usr/bin/perl

use strict;

use lib "$ENV{GUS_HOME}/lib/perl";

use ApiCommonData::Load::VariationFileReader;

use Getopt::Long;

my ($inputFile, $platform, $outputFile);

&GetOptions("inputFile=s"=> \$inputFile,
            "outputFile=s"=> \$outputFile,
            "platform=s" => \$platform,
    );


unless(-e $inputFile) {
  &usage("input file $inputFile does not exist");
}

unless($platform && $outputFile) {
  &usage("Platform and outputFile required");
}

open(OUT, "> $outputFile") or die "Cannot open output file $outputFile for writing: $!";


my @filters = ();
my $reader = ApiCommonData::Load::VariationFileReader->new($inputFile, \@filters, qr/\t/);

while($reader->hasNext()) {
  my $variations = $reader->nextSNP() ; 

  my $rep = $variations->[0];

  print OUT $rep->{snp_source_id} . "\t" . $rep->{sequence_source_id} . "\t" . $rep->{location} . "\t" . $platform . "\n";
}

close OUT;


sub usage {
  my $msg = shift;

  print STDERR $msg . "\n";
  die "usage:  snpSourceIdToLocationPlatform.pl --inputFile <FILE> --platform=s";
}
