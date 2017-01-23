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

## add some constant value
$excelInfo{$organismAbbrev}{"publicOrganismAbbrev"} = $excelInfo{$organismAbbrev}{"organismAbbrev"};
$excelInfo{$organismAbbrev}{'projectName'} = $projectName;


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




##########  start print xml file for organism  ##########

open my $ofh, '>', $orgFile || die "can not open organism xml file to write\n";
print $ofh "<datasets>\n";

printConstantName ($ofh, \%excelInfo, "organismAbbrev");
printConstantName ($ofh, \%excelInfo, "strainAbbrev");
printConstantName ($ofh, \%excelInfo, "referenceStrainOrganismAbbrev");
printConstantName ($ofh, \%excelInfo, "familyRepOrganismAbbrev");
printConstantName ($ofh, \%excelInfo, "projectName");
printConstantName ($ofh, \%excelInfo, "ncbiTaxonId");
printConstantName ($ofh, \%excelInfo, "speciesNcbiTaxonId");
printConstantName ($ofh, \%excelInfo, "genomeVersion");
printConstantName ($ofh, \%excelInfo, "source", "genomeSource");
printConstantName ($ofh, \%excelInfo, "soTerm", "soTerm");  ## not work now, need to add soTerm column to spreadsheet
printConstantName ($ofh, \%excelInfo, "functAnnotVersion", "genomeVersion");  ## not work now, need to add something
printConstantName ($ofh, \%excelInfo, "genomeSource");
print $ofh "\n";

printValidateOrganismInfo($ofh);

printProductNamesClass ($ofh, \%excelInfo) if ($excelInfo{$organismAbbrev}{'hasProduct'} =~ /^y/i);

printGOClass ($ofh, \%excelInfo) if ($excelInfo{$organismAbbrev}{'hasGO'} =~ /^y/i);

printECClass ($ofh, \%excelInfo) if ($excelInfo{$organismAbbrev}{'hasEC'} =~ /^y/i);

printGeneNameClass ($ofh, \%excelInfo) if ($excelInfo{$organismAbbrev}{'hasName'} =~ /^y/i);

printSynonymClass ($ofh, \%excelInfo) if ($excelInfo{$organismAbbrev}{'hasSynonym'} =~ /^y/i);

printCommentClass ($ofh, \%excelInfo, "transcript") if ($excelInfo{$organismAbbrev}{'hasNote'} =~ /^t/i);
printCommentClass ($ofh, \%excelInfo, "gene") if ($excelInfo{$organismAbbrev}{'hasNote'} =~ /^g/i);

print $ofh "</datasets>\n";

close $ofh;




##################### subroutine ###################
sub printGOClass {
  my ($fh, $excelInfoPoint) = @_;
  print $fh "  <dataset class=\"GeneOntologyAssociations\">\n";
  printNameWithDollarSign ($fh, 'projectName');
  printNameWithDollarSign ($fh, 'organismAbbrev');
  printNameWithDollarSign ($fh, 'version', 'functAnnotVersion');
  printNameWithDollarSign ($fh, 'name', 'genomeSource');
  print $fh "  </dataset>\n";
  print $fh "\n";
  return 0;
}

sub printECClass {
  my ($fh, $excelInfoPoint) = @_;
  print $fh "  <dataset class=\"EnzymeCommissionAssociations\">\n";
  printNameWithDollarSign ($fh, 'projectName');
  printNameWithDollarSign ($fh, 'organismAbbrev');
  printNameWithDollarSign ($fh, 'version', 'functAnnotVersion');
  printNameWithDollarSign ($fh, 'name', 'genomeSource');
  print $fh "  </dataset>\n";
  print $fh "\n";
  return 0;
}

sub printCommentClass {
  my ($fh, $excelInfoPoint, $geneOrTrans) = @_;
  print $fh "  <dataset class=\"comments\">\n";
  printNameWithDollarSign ($fh, 'projectName');
  printNameWithDollarSign ($fh, 'organismAbbrev');
  my $commentName = $excelInfoPoint->{$organismAbbrev}->{'genomeSource'} . "_" . $geneOrTrans;
  printNameWithValue ($fh, 'name', $commentName);
  printNameWithDollarSign ($fh, 'version', 'genomeVersion');
  print $fh "  </dataset>\n";
  print $fh "\n";
  return 0;
}

sub printGeneNameClass {
  my ($fh, $excelInfoPoint) = @_;
  print $fh "  <dataset class=\"geneName\">\n";
  printNameWithDollarSign ($fh, 'projectName');
  printNameWithDollarSign ($fh, 'organismAbbrev');
  printNameWithDollarSign ($fh, 'genomeVersion');
  printNameWithDollarSign ($fh, 'version', 'functAnnotVersion');
  printNameWithDollarSign ($fh, 'name', 'genomeSource');
  print $fh "  </dataset>\n";
  print $fh "\n";
  return 0;
}

sub printSynonymClass {
  my ($fh, $excelInfoPoint) = @_;
  print $fh "  <dataset class=\"dbxref_synonym\">\n";
  printNameWithDollarSign ($fh, 'projectName');
  printNameWithDollarSign ($fh, 'organismAbbrev');
  printNameWithDollarSign ($fh, 'version', 'functAnnotVersion');
  printNameWithDollarSign ($fh, 'name', 'genomeSource');
  print $fh "  </dataset>\n";
  print $fh "\n";
  return 0;
}

sub printProductNamesClass {
  my ($fh, $excelInfoPoint) = @_;
  print $fh "  <dataset class=\"productNames\">\n";
  printNameWithDollarSign ($fh, 'projectName');
  printNameWithDollarSign ($fh, 'organismAbbrev');
  printNameWithDollarSign ($fh, 'version', 'functAnnotVersion');
  printNameWithDollarSign ($fh, 'name', 'source');
  print $fh "  </dataset>\n";
  print $fh "\n";
  return 0;
}

sub printValidateOrganismInfo {
  my ($fh, $item) = @_;
  print $fh "  <dataset class=\"validateOrganismInfo\">\n";

  printNameWithDollarSign ($fh, 'projectName');
  printNameWithDollarSign ($fh, 'organismAbbrev');
  printNameWithDollarSign ($fh, 'strainAbbrev');
  printNameWithDollarSign ($fh, 'ncbiTaxonId');
  printNameWithDollarSign ($fh, 'speciesNcbiTaxonId');
  printNameWithDollarSign ($fh, 'genomeVersion');

  print $fh "  </dataset>\n";
  print $fh "\n";
  return 0;
}
sub printNameWithDollarSign {
  ## print <prop name="projectName">$$projectName$$</prop>
  my ($fh, $item, $value) = @_;
  $value = $item if (!$value);
  print $fh "    <prop name=\"$item\">\$\$$value\$\$</prop>\n";
  return 0;
}

sub printNameWithValue {
  ## print <prop name="name">GeneDB_transcript</prop>
  my ($fh, $item, $value) = @_;
  $value = $item if (!$value);
  print $fh "    <prop name=\"$item\">$value</prop>\n";
  return 0;
}

sub printConstantName {
  ## print <constant name="strainAbbrev" value="yoelii17X"/>
  my ($fh, $excelInfoPoint, $item, $value) = @_;
  $value = $item if (!$value);
  print $fh "  <constant name=\"$item\" value=\"$excelInfoPoint->{$organismAbbrev}->{$value}\"\/>\n";
  return 0;
}

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
