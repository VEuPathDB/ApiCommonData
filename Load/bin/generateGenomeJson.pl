#!/usr/bin/perl

use strict;
use JSON;
use Getopt::Long;
use GUS::Model::SRes::Taxon;
use GUS::Model::SRes::TaxonName;
use GUS::Supported::GusConfig;


## TODO, better to ignore null record

my ($genomeSummaryFile, $organismAbbrev, $gusConfigFile, $outputFileName, $help);

&GetOptions('organismAbbrev=s' => \$organismAbbrev,
            'genomeSummaryFile=s' => \$genomeSummaryFile,
            'gusConfigFile=s' => \$gusConfigFile,
            'outputFileName=s' => \$outputFileName,
            'help|h' => \$help
            );

&usage() if ($help);
&usage("Missing a Required Argument") unless (defined $organismAbbrev && $genomeSummaryFile);


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
open (OUT, ">$outputFileName") || die "cannot open $outputFileName file to write.\n";

open (IN, "$genomeSummaryFile") || die "can not open $genomeSummaryFile to read.\n";
while (<IN>) {
  chomp;
  my @items = split (/\t/, $_);

  if ($items[1] eq $organismAbbrev) {
    %organismDetails = ('project_id' => $items[2],
			'species' => {
				       'organismAbbrev' => $items[1],
				       'scientific_name' => $items[3]." ".$items[4],
				       'strain' => $items[5],
				       'taxonomy_id' => $items[11]
				      },
			'provider' => {
				       'url' => $items[29],
				       'genome_source' => $items[12],
				       'genome_version' => $items[14]
				       },
			'genebuild' => {
					'structural_annotation_source' => $items[21],
					'structural_annotation_version' => $items[20],
#					'functional_annotation_source' => $items[22],
#					'functional_annotation_version' => $items[23]
					},
			'assembly' => {
				       'accession' => $items[16],
				       'version' => $items[15],
				       'WGS_project' => $items[17],
				       'BioProject' => $items[18],
				       'organellar' => $items[27]
				       }
			);
  }
}
close IN;

$organismDetails{provider}{url} =~ s/wget\s*//;

$organismDetails{genebuild}{structural_annotation_source} = $organismDetails{provider}{genome_source}
  if ($organismDetails{genebuild}{structural_annotation_source} == "");
$organismDetails{genebuild}{structural_annotation_version} = $organismDetails{provider}{genome_version}
  if ($organismDetails{genebuild}{structural_annotation_version} == "");

if ($organismDetails{assembly}{version} == "") {
  $organismDetails{assembly}{version} = $organismDetails{assembly}{accession};
  $organismDetails{assembly}{version} =~ s/(\S+)\.(\d)/$2/;
}

if ($organismDetails{species}{taxonomy_id} == "") {
  $organismDetails{species}{taxonomy_id} = getNcbiTaxonIdFromOrganismName($organismDetails{species}{scientific_name});
}


my $json = encode_json \%organismDetails;
#my $json = encode_json (array_filter((array) \%organismDetails, 'is_not_null'));
#json_encode(array_filter((array) $object, 'is_not_null'));

#$json = del(.[][] | select(. == null));

print OUT "$json\n";

close OUT;

$dbh->disconnect();

###########
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

Usage: perl generateGenomeJson.pl --genomeSummaryFile GenomeSummary.txt --organismAbbrev pfalCD01

where:
  --organismAbbrev: required, eg. pfal3D7
  --genomeSummaryFile: required, the txt file that include all genome info that loaded in EuPathDB
  --outputFileName: optional, default is organismAbbrev_genome.json
  --gusConfigFile: optional, default is \$GUS_HOME/config/gus.config

";
}
