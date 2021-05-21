#!/usr/bin/perl

use strict;
use Cwd;

my $usage =<<EOL;

This script creates dataset xml for ebiRnaSeqExperimentPatch.

%>createEbiRnaSeqExperimentPatchDataset.pl Realigned_RnaSeqExperiments EbiVersion

Output will be dataset xml
EOL

my $Realigned_RnaSeqExperiments = shift or die $usage;
my $ebiVersion = shift or die $usage;
my $datasetDir = $ENV{PROJECT_HOME} . "/ApiCommonDatasets/Datasets/lib/xml/datasets";
print STDERR "$datasetDir\n";
open S, $Realigned_RnaSeqExperiments;
while(<S>) {
  chomp;
  my ($component, $ebiOrganismName, $expName) = split /\t/, $_;
  $expName =~ s/^\s+|\s+$//g;
  open R, "$datasetDir/$component/$ebiOrganismName.xml";
  open O, ">>$datasetDir/$component/$ebiOrganismName.xml.patch";
  while (<R>) {
   chomp;
   if (/$expName/){
	my $version = <R>;
    my $isStrandSpecific = <R>;
chomp($version);
chomp($isStrandSpecific);
print O <<EOL;
  <dataset class="ebiRnaSeqExperimentPatch">
     <prop name="projectName">\$\$projectName\$\$</prop>
     <prop name="organismAbbrev">\$\$organismAbbrev\$\$</prop>
     <prop name="name">$expName</prop>
 $version
 $isStrandSpecific
     <prop name="ebiOrganismName">$ebiOrganismName</prop>
     <prop name="ebiVersion">$ebiVersion</prop>
  </dataset>
EOL
}
}
close(O);
close(R);
}
close(S);

