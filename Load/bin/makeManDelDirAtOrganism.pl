#!/usr/bin/perl

use strict;
## usage: a script to create all directories after organismAbbrev in the manual delivery directory

my @dir_name= ("quantitativeMassSpec","proteinMicroarray","bindingSites","cellularLocation","chipChip","chipSeq","comparativeGenomics","dbxref","dnaSeq","epitope","EST","function","genePrediction","genome","genomeFeature","interaction","isolate","massSpec","microarrayExpression","microarrayPlatform","mRNA","phenotype","phylogeny","reagent","rnaSeq","sageTag","SNP","structure","alias","comment");
foreach my $each_dir (@dir_name)
{
       mkdir( $each_dir ) || print $!;
       print $each_dir . "\s HAS BEEN CREATED!\n";
}
