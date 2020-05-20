#!/usr/bin/perl

## usage: perl printEbiGenomeSummaryBaseOnJsonMeta.pl metadataFromEbi.txt vectorbase_orthomcl6_mark.txt > temp.txt

use strict;
use JSON;
use Getopt::Long;
use GUS::Supported::GusConfig;
use ApiCommonData::Load::NCBIToolsUtils;
use Data::Dumper;


my ($genomeSummaryFile, $help);

&GetOptions(
            'genomeSummaryFile=s' => \$genomeSummaryFile,
            'help|h' => \$help
            );

&usage() if ($help);

my ($ebiInput, $ortho6File, $jsonFilesDir) = @ARGV;
$jsonFilesDir = "genomeJsonFiles" if (!$jsonFilesDir);

my %ebiAbbrev;
open (EBI, $ebiInput) || die "can not open $ebiInput to read\n";
while (<EBI>) {
  chomp;
  $ebiAbbrev{$_} = $_;
}
close EBI;

my %organismDetails;

foreach my $ebi (sort keys %ebiAbbrev) {
#  my $jsonFile = "genomeJsonFiles/" . $ebi . "_genome.json";
  my $jsonFile = $jsonFilesDir . "\/" . $ebi . "_genome.json";

  open (IN, $jsonFile) || die "can not open $jsonFile to read\n";
  my $json = <IN>;

  my $text = decode_json($json);

  print STDERR Dumper($text);

  my $genus;
  my ($genus, $species) = split (/\s+/, $text->{species}->{scientific_name});
  my $strain = $text->{species}->{strain};

  my $speciesName = $genus . " " . $species;
  my $organismFullName = $speciesName . " " . $text->{species}->{strain};

  my $abbrev = getOrganismAbbrev ($organismFullName);

  ## special case to deal with Glossina pallidipes iaea
  ## in order to separate with "Glossina palpalis IAEA";
  $abbrev = "gpapIAEA" if ($text->{species}->{scientific_name} eq "Glossina palpalis gambiensis");  ## special case to deal with Glossina pallidipes iaea
  print STDERR "abbrev = $abbrev\n";

  $organismDetails{$abbrev}{organismFullName} = $organismFullName;
  $organismDetails{$abbrev}{organismNameForFiles} = getOrganismNameForFiles ($organismFullName);

  ($genus, $species, $organismDetails{$abbrev}{strainAbbrev}) = getGenusSpeciesStrain ($organismFullName);

  ($organismDetails{$abbrev}{speciesNcbiTaxon}) =
                         ApiCommonData::Load::NCBIToolsUtils::getGeneticCodeFromNcbiTaxonomy($speciesName, "taxonomy");
  ($organismDetails{$abbrev}{ncbiTaxon}) =
                         ApiCommonData::Load::NCBIToolsUtils::getGeneticCodeFromNcbiTaxonomy($organismFullName, "taxonomy");


  $organismDetails{$abbrev}{ifAnnotatedGenome} = ($text->{genebuild}->{version}) ? "Yes" : "No";

  $organismDetails{$abbrev}{orthomclAbbrev} = getOrthomclAbbrevFromOrtho6 ($ortho6File, $abbrev);
  $organismDetails{$abbrev}{isReferenceGenome} = getReferenceGenomeInfo ($ortho6File, $abbrev);

  $organismDetails{$abbrev}{ebiAssemblyName} = $text->{assembly}->{name};
  $organismDetails{$abbrev}{ebiAssemblyVersion} = ($text->{assembly}->{date}) ? $text->{assembly}->{date} : $text->{assembly}->{version};
  $organismDetails{$abbrev}{genbankAccession} = $text->{assembly}->{accession};
  $organismDetails{$abbrev}{genebuildVersion} = $text->{genebuild}->{version};
  $organismDetails{$abbrev}{ebiOrganismName} = $ebi;

#print STDERR "\$genus = \'$genus\', \$species = \'$species\', \$strain = \'$strain\'\n";
#    print STDERR "\$speciesName = $speciesName\n";
#    print STDERR "\$organismFullName = $organismFullName\n";

#    print STDERR "For \'$organismFullName\', get abbrev = $abbrev\n";

#print STDERR "orthomclAbbrev = $organismDetails{$abbrev}{orthomclAbbrev}, isReferenceGenome = $organismDetails{$abbrev}{isReferenceGenome}\n";
}

## print the header line
print "organismFullName\t";
print "isAnnotatedGenome\t";
print "organismAbbrev\t";
print "organismNameForFiles\t";
print "strainAbbrev\t";
print "orthomclAbbrev\t";
print "ncbiTaxonId\t";
print "speciesNcbiTaxonId\t";
print "genomeSource\t";
print "genomeVersion\t";
print "annotationIncludesTRNAs\t";
print "isReferenceStrain\t";
print "referenceStrainOrganismAbbrev\t";
print "isFamilyRepresentative\t";
print "familyRepOrganismAbbrev\t";
print "familyNcbiTaxonIds\t";
print "familyNameForFiles\t";
print "taxonHierarchyForBlastxFilter\t";
print "soTerm\t";
print "haveChromosome\t";
print "haveSupercontig\t";
print "haveContig\t";
print "hasMito\t";
print "hasApicoplast\t";
print "hasProduct\t";
print "hasGO\t";
print "hasEC\t";
print "hasName\t";
print "hasSynonym\t";
print "hasNote\t";
print "ebiOrganismName\t";
print "ebiVersion\t";
print "ebiAssemblyName\t";
print "ebiAssemblyVersion\t";
print "ebiGeneBuildVersion\t";
print "genbankAccession\t";

print "\n";

my $c = 0;
foreach my $k (sort keys %organismDetails) {
  $c++;

  if (!$organismDetails{$k}{ncbiTaxon}) {
    $organismDetails{$k}{ncbiTaxon} = generateTempNcbiTaxonId ($c);
  }

  print "$organismDetails{$k}{organismFullName}\t";
  print "$organismDetails{$k}{ifAnnotatedGenome}\t";
  print "$k\t";
  print "$organismDetails{$k}{organismNameForFiles}\t";
  print "$organismDetails{$k}{strainAbbrev}\t";
  print "$organismDetails{$k}{orthomclAbbrev}\t";
  print "$organismDetails{$k}{ncbiTaxon}\t";
  print "$organismDetails{$k}{speciesNcbiTaxon}\t";

  print "VectorBase\t";      ##  print "$organismDetails{$k}{genomeSource}\t";
  print "$organismDetails{$k}{ebiAssemblyName}\t";        ## print "$organismDetails{$k}{genomeVersion}\t";
  print "Yes\t";   ## always set yes for organisms from VB: "$organismDetails{$k}{annotationIncludesTRNAs}\t";
  print "$organismDetails{$k}{isReferenceGenome}\t";

  ($organismDetails{$k}{isReferenceGenome} =~ /^y/i) ? print "$k\t" : print "\t";  ## referenceStrainOrganisAbbrev

  print "\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t"; ## total 17 tabs

  print "$organismDetails{$k}{ebiOrganismName}\t";  ## ebiOrganismName
  print "build_47\t";  ## ebiVersion always build_47 on Dec. 2019
  print "$organismDetails{$k}{ebiAssemblyName}\t";  ## ebiAssemblyName, for presenter
  print "$organismDetails{$k}{ebiAssemblyVersion}\t";  ## ebiAssemblyVersion, for presenter
  print "$organismDetails{$k}{genebuildVersion}\t";  ## ebiGenebuildVersion, for presenter
  print "$organismDetails{$k}{genbankAccession}\t";  ## genbankAccession, for presenter
  print "\n";
}

###########

sub getOrthomclAbbrevFromOrtho6 {
  my ($inFile, $abbrev) = @_;

  my $orthoAbbrev;
  open (IN, $inFile) || die "can not open $inFile to read\n";
  while (<IN>) {
    chomp;
    my @items = split (/\t/, $_);
#    print STDERR "\'$items[1]\', \'$items[2]\', \'$abbrev\'\n";
    if ($items[2] eq $abbrev) {
    print STDERR "inside subroutin, \'$items[1]\', \'$items[2]\', \'$abbrev\'\n";
      $orthoAbbrev = $items[1];
    print STDERR "inside subroutin, orthoAbbrev = $orthoAbbrev\n";
    }
  }
  close IN;
  return $orthoAbbrev;
}

sub getReferenceGenomeInfo {
  my ($inFile, $abbrev) = @_;

  my $isReferenceGenome;
  open (IN, $inFile) || die "can not open $inFile to read\n";
  while (<IN>) {
    chomp;
    my @items = split (/\t/, $_);
    if ($items[2] eq $abbrev) {
      $isReferenceGenome = ($items[3] == 1) ? "Yes" : "No";
    }
  }
  close IN;
  return $isReferenceGenome;
}


sub getOrganismAbbrev {
  my ($fullName) = @_;

  my ($genus, $species, $strainAbbrev) = getGenusSpeciesStrain ($fullName);

  my $abbrev = lc(substr($genus, 0, 1)).substr($species, 0, 3).$strainAbbrev;
#  my $organismNameForFiles = substr($genus, 0, 1).$species.$strainAbbrev;

  return $abbrev;
}

sub getOrganismNameForFiles {
  my ($fullName) = @_;

  my ($genus, $species, $strainAbbrev) = getGenusSpeciesStrain ($fullName);

  my $organismNameForFiles = substr($genus, 0, 1).$species.$strainAbbrev;

  return $organismNameForFiles;
}

sub getOrthomclAbbrev {
  my ($fullName) = @_;

  my ($genus, $species, $strainAbbrev) = getGenusSpeciesStrain ($fullName);

  my $orthomclAbbrev = lc(substr($genus, 0, 1)).substr($species, 0, 3);

  return $orthomclAbbrev;
}

sub getGenusSpeciesStrain {
  my ($fullName) = @_;

  my @words = split (/\s+/, $fullName);

  my $abbrev;
  my $genus = shift @words;
  $genus =~ s/^\[//;
  $genus =~ s/\]$//;
  my $species = shift @words;
  my $strainAbbrev = join ('', @words);
  $strainAbbrev =~ s/isolate//i;
  $strainAbbrev =~ s/strain//i;
  $strainAbbrev =~ s/breed//i;
  $strainAbbrev =~ s/str\.//i;
  $strainAbbrev =~ s/\///g;
  $strainAbbrev =~ s/\'//g;
  #$strainAbbrev =~ s/\./\-/g;

  return ($genus, $species, $strainAbbrev);
}

sub generateTempNcbiTaxonId {
  my ($c) = @_;

  my $tempNcbiTaxonId = 9900000000 + $c;

  return $tempNcbiTaxonId;
}


sub usage {
  die
"
A script to generate a tab delimited file that can be used to generate dataset xml file and presenter file

Usage: perl printEbiGenomeSummaryBaseOnJsonMeta.pl metadataFromEbi.txt vectorbase_orthomcl6_mark.txt

where:
  --genomeSummaryFile: required, the txt file that include all genome info that loaded in EuPathDB

";
}
