#!/usr/bin/perl

## perl getEbiSeqRegionJsonMakeChrMap.pl --organismAbbrev pbraBolivianI --buildNumber build_62 --database PlasmoDB --ftpUser ****** --ftpPassword ******* --outputFileDir final

use Getopt::Long;
use strict;
use lib "$ENV{GUS_HOME}/lib/perl";

use DBI;
use DBD::Oracle;
use CBIL::Util::PropertySet;
use CBIL::Util::Utils;
use ApiCommonData::Load::NCBIToolsUtils;
use JSON;


my ($organismAbbrev,
    $buildNumber,
    $database,
    $ftpUser,
    $ftpPassword,
    $outputFileDir,
     $help);

&GetOptions(
            'organismAbbrev=s' => \$organismAbbrev,
            'buildNumber=s' => \$buildNumber,
            'database=s' => \$database,
            'ftpUser=s' => \$ftpUser,
            'ftpPassword=s' => \$ftpPassword,
            'outputFileDir=s' => \$outputFileDir,
            'help|h' => \$help,
            );
&usage() if($help);
&usage("Missing a Required Argument") unless(defined $organismAbbrev && $buildNumber && $database);

$buildNumber = "build_".$buildNumber if ($buildNumber =~ /^\d+$/);  ## in case pass the build number value only

my $seqRegionFile = $organismAbbrev . "_seq_region.json";

unless (-e $seqRegionFile) {
  my $initFtpSite = "ftp://ftp-private.ebi.ac.uk/EBIout/";
  my $finalFtpSite = $initFtpSite. $buildNumber . "\/metadata\/" . $database . "\/" . $organismAbbrev . "\/" . $seqRegionFile;
  print STDERR "\$finalFtpSite = $finalFtpSite\n";

  my $getCmd = "wget --ftp-user $ftpUser --ftp-password $ftpPassword $finalFtpSite";
  `$getCmd`;
}

## seqRegionJson2ChrMap.pl stomoxys_calcitrans_seq_region.json > ../final/chromosomeMap.txt
my $makeCmd = "seqRegionJson2ChrMap.pl $seqRegionFile > $outputFileDir/chromosomeMap.txt";
`$makeCmd`;


#######
sub usage {
  die
"
Usage: getEbiSeqRegionJsonMakeChrMap.pl

where
  --organismAbbrev: required, organism abbreviation
  --buildNumber: required, eg 60, or build_60, build_61
  --database: required, eg PlasmoDB, VectorBase
  --ftpUser: required, EBI ftp user name
  --ftpPassword: required, EBI ftp password
  --outputFileDir: directory for output, default is the current dir

";
}

