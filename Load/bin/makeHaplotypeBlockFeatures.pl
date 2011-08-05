#!/usr/bin/perl

use strict;
use IO::File;
use Getopt::Long;

my ($help, $mapFile, $microstatGff, $outputGff);

&GetOptions('help|h' => \$help,
            'mapFile=s' => \$mapFile,
            'microstatGff=s' => \$microstatGff,
            'outputGff=s' => \$outputGff,
           );
 
unless(-e $microstatGff && $mapFile && $outputGff) {
  print STDERR "usage:  perl makeHaplotypeBlockFeatures.pl  --mapFile  <Microsatellites-Centimorgan mapping file> --microstatGff  <a GFF file containing the microsatellite features used for constructing the physical map>    --outputGff  <Output file to print the GFF features to>\n";
  exit;
}




my (%IdChrMap, %cMorgan);

open (mapFile,$mapFile);
while (<mapFile>) {   

   my @elements = split(/\t/,$_);
   chomp(@elements);

   next unless ($elements[1] =~ /G/ || $elements[3] ne ".");

   $cMorgan{$elements[1]} = $elements[3];
   
   if ($elements[4] < 10) {
       $IdChrMap{$elements[1]} = "Pf3D7_0".$elements[4];
      } else {
       $IdChrMap{$elements[1]} = "Pf3D7_".$elements[4];
      }
}
close(mapFile);


my %chrLength = ('psu|Pf3D7_14' => 3291871,
                 'psu|Pf3D7_13' => 2895605,
                 'psu|Pf3D7_12' => 2271478,
                 'psu|Pf3D7_11' => 2038337,
                 'psu|Pf3D7_10' => 1687655,
                 'psu|Pf3D7_09' => 1541723,
                 'psu|Pf3D7_07' => 1501717,
                 'psu|Pf3D7_08' => 1419563,
                 'psu|Pf3D7_06' => 1418244,
                 'psu|Pf3D7_05' => 1343552,
                 'psu|Pf3D7_04' => 1204112,
                 'psu|Pf3D7_03' => 1060087,
                 'psu|Pf3D7_02' => 947102,
                 'psu|Pf3D7_01' => 643292);



my (%fwdCood,%revCood,%strand);

open (gffFile, $microstatGff);
while (<gffFile>){
  chomp;
  my $gffLine = $_;
  my @elements = split(/\t/,$gffLine);
  my $chromID = $elements[0];

  my @geoID = split(/ /, $elements[8]);
  $geoID[1] =~ s/;//g;

  next unless (exists $IdChrMap{$geoID[1]});

  $fwdCood{$chromID}{$geoID[1]} = $elements[3];
  $revCood{$chromID}{$geoID[1]} = $elements[4];
  $strand{$chromID}{$geoID[1]} = $elements[6];
}
close(gffFile);




my (%conservativeStart, %conservativeEnd, %liberalStart, %liberalEnd, %haplotypeCMorgan);
my ($consrvStart,$consrvEnd,$featureCount,$prevChrVal,$prevCMorgan);

$featureCount = 0;

foreach my $chromosome (sort keys %fwdCood){

  foreach my $stsId (sort {$fwdCood{$chromosome}{$a} <=> $fwdCood{$chromosome}{$b} } (keys %{ $fwdCood{$chromosome} })) {

     if ($prevCMorgan ne $cMorgan{$stsId}) {
        $haplotypeCMorgan{$chromosome}{$featureCount} = $cMorgan{$stsId};
        $conservativeStart{$chromosome}{$featureCount} = $fwdCood{$chromosome}{$stsId};
        $liberalStart{$chromosome}{$featureCount} = $consrvEnd+1;
        
        if ($featureCount > 0) {
          $conservativeEnd{$prevChrVal}{$featureCount-1} = $consrvEnd;
          $liberalEnd{$prevChrVal}{$featureCount-1} = $fwdCood{$chromosome}{$stsId} - 1;
        }
       $featureCount++;
     }
     
     $consrvStart = $fwdCood{$chromosome}{$stsId};
     $prevCMorgan = $cMorgan{$stsId};
     $prevChrVal = $chromosome;
     $consrvEnd = $revCood{$chromosome}{$stsId};
  }
  $liberalEnd{$prevChrVal}{$featureCount-1} = $chrLength{$prevChrVal};
  $conservativeEnd{$prevChrVal}{$featureCount-1} = $consrvEnd; 
  $featureCount = 0;
  $consrvEnd = 0;
}


open (outGff, ">$outputGff");
foreach my $chromosome (sort keys %conservativeStart){
  foreach my $centiMorgan (sort {$conservativeStart{$chromosome}{$a} <=> $conservativeStart{$chromosome}{$b} } (keys %{ $conservativeStart{$chromosome} })) {
print (outGff "$chromosome\tFerdigLab\thaplotype_block\t$conservativeStart{$chromosome}{$centiMorgan}\t$conservativeEnd{$chromosome}{$centiMorgan}\t.\t.\t.\tStart_Min $liberalStart{$chromosome}{$centiMorgan}; End_Max \t$liberalEnd{$chromosome}{$centiMorgan}; CentiMorgan $haplotypeCMorgan{$chromosome}{$centiMorgan}\n");
  }
}
