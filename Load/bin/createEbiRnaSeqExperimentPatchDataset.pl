#!/usr/bin/perl

use strict;
use Cwd;

my $usage =<<EOL;

This script creates dataset xml for ebiRnaSeqExperimentPatch.

%>createEbiRnaSeqExperimentPatchDataset.pl file_with_ebiRNASeq_patch_ids file_with_ebiOrganismName

Output will be dataset xml
EOL

my $file = shift or die $usage;
my $file_with_ebiOrganismName = shift or die $usage;
my $ebiVersion = "build_49";
my $version = "01-2020";
open R, $file_with_ebiOrganismName;
while(<R>){
chomp;
  open R1, "$_.xml";
  open R2, ">$_.xml.new";
  while (<R1>) {
  if (eof) { last; } else { print R2; };
  } 
}
close(R);
close(R1);
close(R2);

open S, $file;
while(<S>) {
  chomp;
  my ($ebiOrganismName, $expName, $isStrandSpecific) = split /\t/, $_;
  $isStrandSpecific = lc $isStrandSpecific;
  open O1, ">>$ebiOrganismName.xml.new";
print O1 <<EOL;
<dataset class="ebiRnaSeqExperimentPatch">
     <prop name="projectName">\$\$projectName\$\$</prop>
     <prop name="organismAbbrev">\$\$organismAbbrev\$\$</prop>
     <prop name="name">$expName</prop>
     <prop name="version">$version</prop>
     <prop name="isStrandSpecific">$isStrandSpecific</prop>
     <prop name="ebiOrganismName">$ebiOrganismName</prop>
     <prop name="ebiVersion">$ebiVersion</prop>
</dataset>
EOL
close(O1);
}
close(S);

open R, $file_with_ebiOrganismName;
while(<R>){
chomp;
  open R1, "$_.xml.new";
  open R2, ">$_.xml";
  while (<R1>) {
  if (eof) { print R2 "</dataset>\n</datasets>\n"; } else { print R2; };
  }
}
close(R);
close(R1);
close(R2);
