#!/usr/bin/perl

use strict;

## a script that creates all directories under organismAbbrev within the manual delivery directory
## usage: perl makeManDelDirAtOrganism.pl


my @dir_name= ("functAnnotStaging", "organismPatch", "quantitativeMassSpec","proteinMicroarray","bindingSites","cellularLocation","chipChip","chipSeq","comparativeGenomics","dbxref","dnaSeq","epitope","EST","function","genome","genomeFeature","interaction","isolate","massSpec","microarrayExpression","microarrayPlatform","mRNA","phenotype","phylogeny","reagent","rnaSeq","sageTag","SNP","structure","alias","comment");
foreach my $each_dir (@dir_name)
{
       mkdir( $each_dir ) || print $!;
       print $each_dir . "\s HAS BEEN CREATED!\n";
}
