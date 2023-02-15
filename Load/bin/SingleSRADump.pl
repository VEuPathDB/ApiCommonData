#!/usr/bin/perl 

use strict; 
use lib "$ENV{GUS_HOME}/lib/perl";
use CBIL::Util::Sra;
use Getopt::Long;

my($isPairedEnd,$sampleId);

&GetOptions("isPairedEnd|q!" => \$isPairedEnd, 
            'sampleId=s' => \$sampleId,
            'apiKey=s' => \$apiKey,
            );

my @tmp;
foreach my $s (split(/,\s*/,$sampleId)){
    push(@tmp,$s);
}

&getFastqForSampleIds(\@tmp,"$sampleId","$sampleId.paired",0,$isPairedEnd ? 1 : 0, $apiKey);
