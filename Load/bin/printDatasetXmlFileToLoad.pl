#!/usr/bin/perl

use Getopt::Long;
use strict;
use lib "$ENV{GUS_HOME}/lib/perl";

use DBI;
use DBD::Oracle;
use CBIL::Util::PropertySet;

my (
    $projectName,
    $excelFile,
    $organismAbbrev,
    $organismNameForFiles,
    $organismFullName,
    $strainAbbrev,
    $orthomclAbbrev,
    $ncbiTaxonId,
    $speciesNcbiTaxonId,
    $genomeSource,
    $genomeVersion,
    $isAnnotatedGenome,
    $annotationIncludesTRNAs,
    $isReferenceStrain,
    $referenceStrainOrganismAbbrev,
    $isFamilyRepresentative,
    $familyRepOrganismAbbrev,
    $familyNcbiTaxonIds,
    $familyNameForFiles,
    $haveChromosome,
    $haveSupercontig,
    $haveContig,

    $help);

&GetOptions(
	    'projectName=s' => \$projectName,
	    'organismAbbrev=s' => \$organismAbbrev,
	    'excelFile=s' => \$excelFile,
            'organismNameForFiles=s' => \$organismNameForFiles,
            'organismFullName=s' => \$organismFullName,
            'strainAbbrev=s' => \$strainAbbrev,
            'orthomclAbbrev=s' => \$orthomclAbbrev,
            'ncbiTaxonId=s' => \$ncbiTaxonId,
	    'speciesNcbiTaxonId' => \$speciesNcbiTaxonId,
	    'genomeSource' => \$genomeSource,
	    'genomeVersion' => \$genomeVersion,
	    'isAnnotatedGenome' => \$isAnnotatedGenome,
	    'annotationIncludesTRNAs' => \$annotationIncludesTRNAs,
	    'isReferenceStrain' => \$isReferenceStrain,
	    'referenceStrainOrganismAbbrev' => \$referenceStrainOrganismAbbrev,
	    'isFamilyRepresentative' => \$isFamilyRepresentative,
	    'familyRepOrganismAbbrev' => \$familyRepOrganismAbbrev,
	    'familyNcbiTaxonIds' => \$familyNcbiTaxonIds,
	    'familyNameForFiles' => \$familyNameForFiles,


	    'help|h' => \$help,
	    );
&usage() if($help);
&usage("Missing a Required Argument") unless(defined $projectName && $organismAbbrev && $excelFile);

my (%excelInfo, @excelColumn, $orgAbbrevColumn);
my $count = 0;
open (EXL, "$excelFile") || die "can not open Excel File to read\n";
while (<EXL>) {
  chomp;
  my @items = split (/\t/, $_);

  if ($count == 0) {
    foreach my $i (0..$#items) {
      $excelColumn[$i] = $items[$i];  ## get the info of head line
      if ($items[$i] eq "organismAbbrev" ) {  ## get the column # for organismAbbrev
	$orgAbbrevColumn = $i;
      }
    }
  } else {
    foreach my $i (0..$#items) { ## get the info of whole spreadsheet
      $excelInfo{$items[$orgAbbrevColumn]}{$excelColumn[$i]} = $items[$i];
    }
  }
  $count++;
}
close;
$excelInfo{$organismAbbrev}{"publicOrganismAbbrev"} = $excelInfo{$organismAbbrev}{"organismAbbrev"};


print STDERR "\$count = $count\n";
 
foreach my $j (0..$#excelColumn) {
  print STDERR "$j, $excelColumn[$j]\n";
}

foreach my $k (sort keys %excelInfo) {
  foreach my $kk (sort keys %{$excelInfo{$k}}) {
    print STDERR "$k, $kk, $excelInfo{$k}{$kk}\n";
  }
}

my $xmlDir = "xmlFile/";
mkdir("$xmlDir") unless -e "$xmlDir";
my $projFile = $xmlDir . $projectName. "_". $organismAbbrev. ".xml";
my $orgFile = $xmlDir. $organismAbbrev. ".xml";

open (PO, ">$projFile") || die "can not open file to write\n";

printHeaderLine();
printRegularLine (\%excelInfo, $organismAbbrev, "organismAbbrev");
print PO "    <prop name=\"projectName\">\$\$projectName\$\$</prop>\n";
printRegularLine (\%excelInfo, $organismAbbrev, "ncbiTaxonId");
printRegularLine (\%excelInfo, $organismAbbrev, "publicOrganismAbbrev");
printRegularLine (\%excelInfo, $organismAbbrev, "organismFullName");
printRegularLine (\%excelInfo, $organismAbbrev, "organismNameForFiles");
printRegularLine (\%excelInfo, $organismAbbrev, "speciesNcbiTaxonId");
printTrueOrFalseLine (\%excelInfo, $organismAbbrev, "isReferenceStrain");

printRegularLine (\%excelInfo, $organismAbbrev, "referenceStrainOrganismAbbrev");
printTrueOrFalseLine (\%excelInfo, $organismAbbrev, "isAnnotatedGenome");
printTrueOrFalseLine (\%excelInfo, $organismAbbrev, "hasTemporaryNcbiTaxonId", $excelInfo{$organismAbbrev}{'ncbiTaxonId'});

printRegularLine (\%excelInfo, $organismAbbrev, "orthomclAbbrev");
printRegularLine (\%excelInfo, $organismAbbrev, "strainAbbrev");
printRegularLine (\%excelInfo, $organismAbbrev, "genomeSource");
printRegularLine (\%excelInfo, $organismAbbrev, "taxonHierarchyForBlastxFilter");

printTrueOrFalseLine (\%excelInfo, $organismAbbrev, "annotationIncludesTRNAs");
printLinesBasedProject ($projectName);

printRegularLine (\%excelInfo, $organismAbbrev, "genomeVersion");
printTrueOrFalseLine (\%excelInfo, $organismAbbrev, "isFamilyRepresentative");
printSpecialFamilyRepLines (\%excelInfo, $organismAbbrev);

printTailerLine();

printRefStrainLines (\%excelInfo, $organismAbbrev);

close PO;



#####################
sub printHeaderLine {
  print PO "  <dataset class=\"organism\">\n";
}
sub printTailerLine {
  print PO "  </dataset>\n";
}

sub printRegularLine {
  my ($excelInfoPoint, $organismAbbrev, $item) = @_;
  print PO "    <prop name=\"$item\">$excelInfoPoint->{$organismAbbrev}->{$item}</prop>\n";
  return 0;
}

sub printTrueOrFalseLine { ## take 3 or 4 arguments depend if need judge based on the value of the 4th argument
  my ($excelInfoPoint, $organismAbbrev, $item, $value) = @_;
  my $tof;

  if ($value) {  ## if there is the 4th argument, print true or false based on the 4th argument
    $tof = ($value =~ /^9/ && length($value) == 10) ? "true" : "false";
  } else {
    $tof = ($excelInfoPoint->{$organismAbbrev}->{$item} =~ /^Y/i ) ? "true" : "false";
  }
  $tof = "true" if ($item eq "annotationIncludesTRNAs" && $excelInfoPoint->{$organismAbbrev}->{'isAnnotatedGenome'} !~ /^Y/i);
  print PO "    <prop name=\"$item\">$tof</prop>\n";
  return 0;
}

sub printSpecialFamilyRepLines { ## print the lines related with familyRepresent based on $isFamilyRepresentative
  my ($excelInfoPoint, $organismAbbrev) = @_;
  my $tof;

  if ($excelInfoPoint->{$organismAbbrev}->{'isFamilyRepresentative'} =~ /^Y/i) {
    print PO "    <prop name=\"familyRepOrganismAbbrev\">$organismAbbrev</prop>\n";
    print PO "    <prop name=\"familyNcbiTaxonIds\">$excelInfoPoint->{$organismAbbrev}->{'familyNcbiTaxonIds'}</prop>\n";
    print PO "    <prop name=\"familyNameForFiles\">$excelInfoPoint->{$organismAbbrev}->{'familyNameForFiles'}</prop>\n";
  } else {
    print PO "    <prop name=\"familyRepOrganismAbbrev\">$excelInfoPoint->{$organismAbbrev}->{'familyRepOrganismAbbrev'}</prop>\n";
    print PO "    <prop name=\"familyNcbiTaxonIds\"></prop>\n";
    print PO "    <prop name=\"familyNameForFiles\"></prop>\n";
  }
  return 0;
}

sub printRefStrainLines { ## print the reference lines based on isReferenceStrain info
  my ($excelInfoPoint, $organismAbbrev) = @_;
  my $tof;
  if ($excelInfoPoint->{$organismAbbrev}->{'isReferenceStrain'} =~ /^Y/i) {
    print PO "\n";
    print PO "  <dataset class=\"referenceStrain\">\n";
    print PO "    <prop name=\"organismAbbrev\">$organismAbbrev</prop>\n";
    $tof = ($excelInfoPoint->{$organismAbbrev}->{'isAnnotatedGenome'} =~ /^Y/i) ? "true" : "false";
    print PO "    <prop name=\"isAnnotatedGenome\">$tof</prop>\n";
    print PO "  </dataset>\n";
  }
  return 0;
}

sub printLinesBasedProject { ## print several lines based on projectname
  my ($projectName) = @_;
  my $tof;
  my $runExportPred =  ($projectName =~ /Plasmo/i) ? "true" : "false";

  my $isHugeGenome = ($projectName =~ /Host/i) ? "true" : "false";

  my $maxIntronSize;
  if ($projectName =~ /Microsporidia/i) {
    $maxIntronSize = 100;
  } elsif ($projectName =~ /Giardia/i) {
    $maxIntronSize = 500;
  } elsif ($projectName =~ /Fungi/i) {
    $maxIntronSize = 1000;
  } elsif ($projectName =~ /Trich/i) {
    $maxIntronSize = 1200;
  } elsif ($projectName =~ /TriTryp/i) {
    $maxIntronSize = 2000;
  } elsif ($projectName =~ /Schisto/i) {
    $maxIntronSize = 30000;
  } elsif ($projectName =~ /Host/i) {
    $maxIntronSize = 750000;
  } else {
    $maxIntronSize = 20000;
  }

  print PO "    <prop name=\"runExportPred\">$runExportPred</prop>\n";
  print PO "    <prop name=\"isHugeGenome\">$isHugeGenome</prop>\n";
  print PO "    <prop name=\"maxIntronSize\">$maxIntronSize</prop>\n";
  return 0;
}

sub usage {
  die
"
Usage: ..
 

where
  --organismAbbrev:    the organism abbrev
  --organismFullName: organism full name
  --soTerm: contig, supercontig, or chromosome
  --regexSourceId: optional, regExp for sequence source id on the defline of the fasta file, only for gff3 format, default is >(\\S+?)(\\|\\w\+\$|\$)

";
}
