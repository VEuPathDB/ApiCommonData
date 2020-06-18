#!/usr/bin/perl

use strict;
use JSON;
use Getopt::Long;
use GUS::Model::SRes::Taxon;
use GUS::Model::SRes::TaxonName;
use GUS::Supported::GusConfig;


## TODO, better to ignore null record

my ($genomeSummaryFile, $organismAbbrev, $gusConfigFile, $outputFileName, $outputFileDir, $help);

&GetOptions('organismAbbrev=s' => \$organismAbbrev,
            'genomeSummaryFile=s' => \$genomeSummaryFile,
            'gusConfigFile=s' => \$gusConfigFile,
            'outputFileName=s' => \$outputFileName,
            'outputFileDir=s' => \$outputFileDir,
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
if ($outputFileDir) {
  $outputFileName = "\./" . $outputFileDir. "\/". $outputFileName;
}
open (OUT, ">$outputFileName") || die "cannot open $outputFileName file to write.\n";

open (IN, "$genomeSummaryFile") || die "can not open $genomeSummaryFile to read.\n";
while (<IN>) {
  chomp;
  my @items = split (/\t/, $_);

  my $providerUrl = getProviderUrlFromGenomeSource($items[12]);
  my $genebuildVersion;
  if ($items[19] == 1) {
    $genebuildVersion = $items[20] ? $items[20] : $items[14];
  }
  my $assemblyVersion = $items[16];
  $assemblyVersion =~ s/(\S+)\.(\d)/$2/;
  $assemblyVersion += 0;  ## change string to integer


  if ($items[1] eq $organismAbbrev) {
    %organismDetails = (#'project_id' => $items[2],
			'species' => {
#                                      'organismAbbrev' => $items[1],
#				       'BRC4_organism_abbrev' => $items[1],
				       'scientific_name' => $items[3]." ".$items[4],
				       'strain' => $items[5],
				       'taxonomy_id' => $items[11]
				      },
			'BRC4' => {
				   'component' => $items[2],
				   'organism_abbrev' => $items[1]
				   },
#			'provider' => {
#				       'url' => $providerUrl,
#				       'name' => $items[12]
#				       },
#			'genebuild' => {
#					'version' => $genebuildVersion,
#					'start_date' => $genebuildVersion
#					},
			'assembly' => {
				       'accession' => $items[16],
				       'version' => $assemblyVersion
				       }
			);

    ## only has genebuild if is_annotated = 1
    if ($genebuildVersion) {
      $organismDetails{genebuild}{version} = $genebuildVersion;
      $organismDetails{genebuild}{start_date} = $genebuildVersion;
    }

    $organismDetails{assembly}{accession} =~ s/^\s+//;
    $organismDetails{assembly}{accession} =~ s/\s+$//;

    if ($providerUrl && $items[12]) {
      $organismDetails{provider}{url} = $providerUrl;
      $organismDetails{provider}{name} = $items[12];
    } elsif (!$providerUrl && $items[12]) {
      $organismDetails{provider}{url} = "https://veupathdb.org";
      $organismDetails{provider}{name} = $items[12];
    }

    if ($organismAbbrev eq "gassAWB" || $organismAbbrev eq "gassBGS" || $organismAbbrev eq "gassEP15"
	|| $organismAbbrev eq "gassA2DH" || $organismAbbrev eq "gassAAS175"
	|| $organismAbbrev eq "gassBGS_B" || $organismAbbrev eq "gassBBAH15c1"
       ) {
      $organismDetails{species}{taxonomy_id} = 5740;
    }
  }
}
close IN;


if ($organismDetails{species}{taxonomy_id} == "") {
  $organismDetails{species}{taxonomy_id} = getNcbiTaxonIdFromOrganismName($organismDetails{species}{scientific_name});
}
$organismDetails{species}{taxonomy_id} += 0;

if ($organismDetails{assembly}{accession} =~ /n\/a/i || $organismDetails{assembly}{accession} =~ /note/i
    || $organismDetails{assembly}{accession} =~ /\?\?/i || $organismDetails{assembly}{accession} =~ /exist/i
   ) {
  $organismDetails{assembly}{accession} = "";
}

$organismDetails{assembly}{version} = 1 if ($organismDetails{assembly}{version} == 0);


my $json = encode_json \%organismDetails;
#my $json = encode_json (array_filter((array) \%organismDetails, 'is_not_null'));
#json_encode(array_filter((array) $object, 'is_not_null'));

#$json = del(.[][] | select(. == null));

print OUT "$json\n";

close OUT;

$dbh->disconnect();

###########
sub getProviderUrlFromGenomeSource {
  my ($genomeSource) = @_;
  $genomeSource = lc($genomeSource);

  my %urls = (
	      aspgd => "http://www.aspgd.org",
	      broad => "https://www.broadinstitute.org",
	      cgd => "http://www.candidagenome.org/download",
	      ensembl => "https://ensembl.org",
	      jcvi => "https://www.jcvi.org",
	      jgi => "https://jgi.doe.gov",
	      liverpool => "https://www.liverpool.ac.uk",
	      pombase => "https://www.pombase.org",
	      ucsf => "https://www.ucsf.edu",
	      ubc => "https://www.ubc.ca",
	      ulaval => "https://www.ulaval.ca",
	      genedb => "https://www.genedb.org",
	      sanger => "ftp://ftp.sanger.ac.uk/pub/project/pathogens",
	      gb => "https://www.ncbi.nlm.nih.gov/assembly",
	      wittwer => "https://www.babs.admin.ch/",
	      painlab => "https://www.kaust.edu.sa",
	      kissingerlab => "https://www.uga.edu",
	      widmerlab => "https://www.tufts.edu",
	      stukenbrocklab => "http://web.evolbio.mpg.de/envgen/",
	      hammondkosacklab => "https://www.rothamsted.ac.uk",
	      saskatchewan => "http://www.cs.usask.ca",
	      hampllab => "https://biol.uw.edu.pl/pl/index.php",
	      norgrenlab => "https://www.unmc.edu",
	      birdlab => "https://www.ncsu.edu",
	      dieterichlab => "https://www.age.mpg.de",
	      parkinsonlab => "https://www.utoronto.ca",
	      jcarltonlab => "https://www.nyu.edu",
	      flegontovlab => "https://www.bc.cas.cz",
	      yurchenkolab => "https://www.paru.cas.cz",
	      lukeslab => "https://www.paru.cas.cz",
	      requenalab => "http://leish-esp.cbm.uam.es",
	      beverleylab => "http://beverleylab.wustl.edu",
	      hertzfowlerlab => "https://www.ufmg.br",
	      siegellab => "https://para.vetmed.uni-muenchen.de",
	      anderssonlab => "https://www.crick.ac.uk",
	      franzen => "https://ki.se",
	      tarletonlab => "https://www.uga.edu",
	      schnaufer => "https://www.ed.ac.uk/biology/immunology-infection",
	      gemo => "http://genome.jouy.inra.fr/gemo/",
	      msu => "https://msu.edu",
	      gencode => "https://www.gencodegenes.org",
	      refseq => "https://www.ncbi.nlm.nih.gov/refseq/",
	      genbank => "https://www.ncbi.nlm.nih.gov/assembly"
	      );

  return $urls{$genomeSource};
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

Usage: perl generateGenomeJson.pl --genomeSummaryFile GenomeSummary.txt --organismAbbrev pfalCD01

where:
  --organismAbbrev: required, eg. pfal3D7
  --genomeSummaryFile: required, the txt file that include all genome info that loaded in EuPathDB
  --outputFileName: optional, default is organismAbbrev_genome.json
  --gusConfigFile: optional, default is \$GUS_HOME/config/gus.config

";
}
