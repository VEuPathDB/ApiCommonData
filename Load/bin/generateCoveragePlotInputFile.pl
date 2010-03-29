#!/usr/bin/perl

use strict;
use Getopt::Long;

my ($extDbSpecs,$sample,$filename);
&GetOptions("extDbSpecs|s=s" => \$extDbSpecs,
            "sample|t=s" => \$sample,
            "filename|mf=s" => \$filename,
            );

die "usage: generateCoveragePlotInputFile.pl 
      --filename|f <filename> 
      --extDbSpecs|s <Db Specs for experiment (required)> 
      --sample <sample name (required)> " unless $extDbSpecs && $sample &&$filename;;

#=======================================================================

my ($extDbName,$extDbRlsVer)=split(/\|/,$extDbSpecs);

my $sql = "select external_database_release_id from sres.externaldatabaserelease d, sres.externaldatabase x where x.name = '${extDbName}' and x.external_database_id = d.external_database_id and d.version = '${extDbRlsVer}'";

my $extDbRlsId= `getValueFromTable --idSQL \"$sql\"`;


 open(F,"$filename") || die "unable to open $filename\n";
  
  while(<F>){
    next if (/^track/);
    chomp;
    my ($source_id,$location,$coverage) = split("\t",$_);
    my $sqlSeq = "select na_sequence_id from dots.NASEQUENCE where source_id='$source_id'";
    my $na_sequence_id=`getValueFromTable --idSQL \"$sqlSeq\"`;
    print "$extDbRlsId\t$sample\t$na_sequence_id\t$location\t$location\t$coverage\t\t\n";
  }
  close F;


