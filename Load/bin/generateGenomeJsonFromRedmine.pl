#!/usr/bin/perl

## generate genome json file passed to EBI
## using either genomeSummaryFile from google sheet or redmine output

use strict;
use JSON;
use Getopt::Long;
use GUS::Model::SRes::Taxon;
use GUS::Model::SRes::TaxonName;
use GUS::Supported::GusConfig;


## TODO, better to ignore null record

my ($genomeSummaryFile, $redmineFile, $organismAbbrev, $gusConfigFile, $outputFileName, $outputFileDir, $component, $help);

&GetOptions('organismAbbrev=s' => \$organismAbbrev,
            'genomeSummaryFile=s' => \$genomeSummaryFile,
            'redmineFile=s' => \$redmineFile,
            'gusConfigFile=s' => \$gusConfigFile,
            'outputFileName=s' => \$outputFileName,
            'outputFileDir=s' => \$outputFileDir,
            'component=s' => \$component,
            'help|h' => \$help
            );

&usage() if ($help);
&usage("Missing a Required Argument") unless (defined $organismAbbrev && $component && ($genomeSummaryFile || $redmineFile));



$gusConfigFile = "$ENV{GUS_HOME}/config/gus.config" unless ($gusConfigFile);
my $verbose;
my $gusconfig = GUS::Supported::GusConfig->new($gusConfigFile);

my $db = GUS::ObjRelP::DbiDatabase->new($gusconfig->getDbiDsn(),
                                        $gusconfig->getDatabaseLogin(),
                                        $gusconfig->getDatabasePassword(),
                                        $verbose,0,1,
                                        $gusconfig->getCoreSchemaName()
                                       );
my $dbh = $db->getQueryHandle();


my %organismDetails;
my $outputFileName = $organismAbbrev . "_genome.json" unless($outputFileName);
if ($outputFileDir) {
  $outputFileName = "\./" . $outputFileDir. "\/". $outputFileName;
}
open (OUT, ">$outputFileName") || die "cannot open $outputFileName file to write.\n";

my ($species, $strain, $geneBuildVersion, $ncbiTaxonId, $accession, $accessionVersion);

if ($genomeSummaryFile) {
  ($species, $strain, $geneBuildVersion, $ncbiTaxonId, $accession) = getOrganismInformation($organismAbbrev, $genomeSummaryFile);
} elsif ($redmineFile) {
  ($species, $strain, $geneBuildVersion, $ncbiTaxonId, $accession) = getInformationFromRedmine($organismAbbrev, $redmineFile);
} else {
  die "missing required argument: --genomeSummaryFile $genomeSummaryFile OR --redmineFile $redmineFile\n";
}

$accessionVersion = getAccessionVersionFromAccession ($accession);

#my $accession = getAccessionFromRedmine ($organismAbbrev, $redmineFile); ## not working yet

%organismDetails = (
		    'species' => {
#				  'BRC4_organism_abbrev' => $organismAbbrev,
				  'scientific_name' =>  $species,
				  'strain' => $strain,
				  'taxonomy_id' => $ncbiTaxonId
				  },
		    'BRC4' => {
			       'component' => $component,
			       'organism_abbrev' => $organismAbbrev
			       },
#		    'genebuild' => {
#				    'version' => $geneBuildVersion,
#				    'start_date' => $geneBuildVersion
#				    },
		    'assembly' => {
				   'accession' => $accession,
				   'version' => $accessionVersion
				   }
		    );

## genebuild
if ($geneBuildVersion) {
  $organismDetails{genebuild}{version} = $geneBuildVersion;
  $organismDetails{genebuild}{start_date} = $geneBuildVersion;
}

## INSDC accession number
$organismDetails{assembly}{accession} =~ s/^\s+//;
$organismDetails{assembly}{accession} =~ s/\s+$//;

if ($organismDetails{assembly}{accession} =~ /n\/a/i || $organismDetails{assembly}{accession} =~ /note/i
    || $organismDetails{assembly}{accession} =~ /\?\?/i || $organismDetails{assembly}{accession} =~ /exist/i
   ) {
  $organismDetails{assembly}{accession} = "";
}
$organismDetails{assembly}{version} = 1 if ($organismDetails{assembly}{version} == 0);
$organismDetails{assembly}{version} += 0; ## change string to integer

## ncbi Taxon Id
if ($organismDetails{species}{taxonomy_id} == "") {
  $organismDetails{species}{taxonomy_id} = getNcbiTaxonIdFromOrganismName($organismDetails{species}{scientific_name});
}
$organismDetails{species}{taxonomy_id} += 0;  ## change string to integer

## provider
($organismDetails{provider}{url}, $organismDetails{provider}{name}) = getProviderUrlAndName($organismDetails{assembly}{accession});

my $json = encode_json \%organismDetails;

print OUT "$json\n";

close OUT;

$dbh->disconnect();



###########
sub getInformationFromRedmine {
  my ($abbrev, $inFile) = @_;

  my ($project, $isAnnot, $organismName, $species, $strain, $acce);
  open (IN, "$inFile") || die "can not open inFile to read\n";
  while (<IN>) {
    chomp;
    my @items = split (/\,/, $_);

    foreach my $i (0..$#items) {
      $items[$i] =~ s/^\s+//;
      $items[$i] =~ s/\s+$//;
    }
    $project = $items[1];
    $isAnnot = ($items[2] =~ /sequence and annotation/i) ? 1 : 0;
    $organismName = $items[3];
    $acce = $items[4];
  }
  close IN;
  return $acce;
}

sub getAccessionVersionFromAccession {
  my ($acce) = @_;

  my $assemblyVersion = $acce;
  $assemblyVersion =~ s/(\S+)\.(\d)/$2/;
  $assemblyVersion = 1 if ($assemblyVersion == 0);
  $assemblyVersion = 1 if (!$acce);

  return $assemblyVersion;
}

sub getProviderUrlAndName {
  my ($acce) = @_;

  my ($url, $name);
  if ($acce) {
    $url = "https://www.ncbi.nlm.nih.gov/assembly";
    $name = "genbank";
  } else {
    $url = "https://veupathdb.org";
    $name = "TODO";
  }

  return $url, $name;
}

sub getOrganismInformation {
  my ($abbrev, $infoFile) = @_;

  my ($organismName, $species, $strain, $geneVersion, $ncbiTaxonId, $acce);
  open (IN, "$infoFile") || die "can not open $infoFile to read\n";
  while (<IN>) {
    chomp;
    my @items = split (/\t/, $_);
    if ($items[2] eq $abbrev) {
      $organismName = $items[0];
      $geneVersion = $items[9] if ($items[1] =~ /^y/i);
      $ncbiTaxonId = (length($items[6]) < 10) ? $items[6] : $items[7];
      $acce = $items[31];
    }
  }
  close IN;

  my @organismArray = split (/\s+/, $organismName);
  my $species = shift @organismArray;
  $species = $species . " " . shift @organismArray;
  $strain = join (" ", @organismArray);
  $strain =~ s/\s*strain\s*//i;

  return $species, $strain, $geneVersion, $ncbiTaxonId, $acce;
}

sub getNcbiTaxonIdFromOrganismName {
  my ($orgnaismName) = @_;

  my $taxonName = GUS::Model::SRes::TaxonName->new({name=>$orgnaismName,name_class=>'scientific name'});
  $taxonName->retrieveFromDB 
    || die "The organism name '$orgnaismName' provided on the command line or as a regex is not found in the database";

  my $taxonId = $taxonName->getTaxonId();
  my $taxon = GUS::Model::SRes::Taxon->new ({taxon_id=>$taxonId});
  $taxon->retrieveFromDB || die "The taxon_id '$taxonId' is not found in the database\n";

  return $taxon->getNcbiTaxId();
}


sub usage {
  die
"
A script to generate genome.json file that required by EBI

Usage: perl generateGenomeJson.pl --genomeSummaryFile GenomeSummary.txt --organismAbbrev pfalCD01 --component PlasmoDB

where:
  --organismAbbrev: required, eg. pfal3D7
  --genomeSummaryFile: required, the txt file that include all genome info that loaded in EuPathDB
  --component: required if genomeSummaryFile presents
  --redmineFile: required, the tabl delimited file export from redmine
  --outputFileName: optional, default is organismAbbrev_genome.json
  --gusConfigFile: optional, default is \$GUS_HOME/config/gus.config

";
}
