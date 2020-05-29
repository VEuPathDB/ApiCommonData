#!/usr/bin/perl

use strict;
use JSON;
use Getopt::Long;
use GUS::Model::SRes::Taxon;
use GUS::Model::SRes::TaxonName;
use GUS::Supported::GusConfig;


## TODO, better to ignore null record

my ($organismAbbrev, $gusConfigFile, $outputFileName, $outputFileDir, $help);

&GetOptions('organismAbbrev=s' => \$organismAbbrev,
            'gusConfigFile=s' => \$gusConfigFile,
            'outputFileName=s' => \$outputFileName,
            'outputFileDir=s' => \$outputFileDir,
            'help|h' => \$help
            );

&usage() if ($help);
&usage("Missing a Required Argument") unless (defined $organismAbbrev);

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

my $extDbRlsId = getPrimaryExtDbRlsIdFormOrgAbbrev ($organismAbbrev);

my ($species, $strain) = getSpeciesStrainInfo ($organismAbbrev);
my ($organismFullName, $ncbiTaxonId) = getOrganismFullNameFromAbbrev ($organismAbbrev);
my $component = getComponentName ($organismAbbrev);

my $ebiOrganismName = getEbiOrganismName ($organismAbbrev);
my ($accessionNumber, $genebuildVersion) = getInfoFromPresenter ($organismAbbrev);
my $assemblyVersion;

#my $karyotypeBands = getCentromereInfo($extDbRlsId);
#my $ebiSeqRegionName = getEbiSeqRegionName($extDbRlsId);


my %organismDetails = (#'project_id' => $items[2],
			'species' => {
				       'scientific_name' => $species,
				       'strain' => $strain,
				       'production_name' => $ebiOrganismName,
				       'taxonomy_id' => $ncbiTaxonId
				      },
			'BRC4' => {
				   'component' => $component,
				   'organism_abbrev' => $organismAbbrev
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
				       'accession' => $accessionNumber,
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

#if ($providerUrl && $items[12]) {
#  $organismDetails{provider}{url} = $providerUrl;
#  $organismDetails{provider}{name} = $items[12];
#} elsif (!$providerUrl && $items[12]) {
#  $organismDetails{provider}{url} = "https://veupathdb.org";
#  $organismDetails{provider}{name} = $items[12];
#}

if ($organismAbbrev eq "gassAWB" || $organismAbbrev eq "gassBGS" || $organismAbbrev eq "gassEP15"
    || $organismAbbrev eq "gassA2DH" || $organismAbbrev eq "gassAAS175"
    || $organismAbbrev eq "gassBGS_B" || $organismAbbrev eq "gassBBAH15c1"
) {
  $organismDetails{species}{taxonomy_id} = 5740;
}

if ($organismDetails{species}{taxonomy_id} == "") {
  $organismDetails{species}{taxonomy_id} = getNcbiTaxonIdFromOrganismName($organismDetails{species}{scientific_name});
}

$organismDetails{species}{taxonomy_id} += 0;

if ($organismDetails{assembly}{accession} !~ /^GCA_/i && $organismDetails{assembly}{accession} !~ /^GCF_/i
   ) {
  $organismDetails{assembly}{accession} = "";
}

$organismDetails{assembly}{version} = 1 if ($organismDetails{assembly}{version} == 0);


my $json = encode_json \%organismDetails;

my $outputFileName = $organismAbbrev . "_genome.json" unless($outputFileName);
if ($outputFileDir) {
  $outputFileName = "\./" . $outputFileDir. "\/". $outputFileName;
}
open (OUT, ">$outputFileName") || die "cannot open $outputFileName file to write.\n";

print OUT "$json\n";

close OUT;

$dbh->disconnect();

###########
sub getComponentName {
  my ($abbrev) = @_;

  my $sql = "select PROJECT_NAME from apidb.organism where abbrev='$abbrev'
            ";

  my $stmt = $dbh->prepareAndExecute($sql);

  my ($component);
  while (my ($name) = $stmt->fetchrow_array()) {
    $component = $name if ($name);
  }

  return $component;
}

sub getEbiOrganismName {
  my ($abbrev) = @_;

  my $extDbName = $abbrev. "_primary_genome_RSRC";

  my $sql = "select prop.value
             from APIDBTUNING.datasetpresenter dp, APIDBTUNING.DATASETPROPERTY prop
             where dp.DATASET_PRESENTER_ID=prop.DATASET_PRESENTER_ID and prop.PROPERTY='ebiOrganismName'
             and dp.name='$extDbName'
            ";

  my $stmt = $dbh->prepareAndExecute($sql);

  my ($ebiOrganismName);
  while (my ($name) = $stmt->fetchrow_array()) {
    $ebiOrganismName = $name if ($name);
  }

  return $ebiOrganismName;
}

sub getInfoFromPresenter {
  my ($abbrev) = @_;

  my $extDbName = $abbrev. "_primary_genome_RSRC";

  my $sql = "select h.GENOME_SOURCE, h.GENOME_VERSION, h.ANNOTATION_SOURCE, h.ANNOTATION_VERSION
             from apidbtuning.datasetpresenter p, apidbtuning.DATASETHISTORY h
             where p.DATASET_PRESENTER_ID=h.DATASET_PRESENTER_ID and p.name='$extDbName'
            ";

  my $stmt = $dbh->prepareAndExecute($sql);

  my ($accession, $geneVersion);
  while (my ($gSource, $gVersion, $aSource, $aVersion) = $stmt->fetchrow_array()) {
    $accession = $gVersion if ($gSource =~ /insdc/i);
    $geneVersion = $aVersion if ($aSource =~ /insdc/i);
  }

  return $accession, $geneVersion;
}

sub getOrganismFullNameFromAbbrev {
  my ($abbrev) = @_;

  my $sql = "select tn.NAME, t.NCBI_TAX_ID
             from apidb.organism o, SRES.TAXON t, SRES.TAXONNAME tn
             where t.TAXON_ID=tn.TAXON_ID and t.TAXON_ID=o.TAXON_ID
             and tn.NAME_CLASS like 'scientific name' and o.ABBREV='$abbrev'
            ";

  my $stmt = $dbh->prepareAndExecute($sql);

  my ($fullName, $ncbiTaxId);
  while (my ($name, $taxId) = $stmt->fetchrow_array()) {
    $fullName = $name if ($name);
    $ncbiTaxId = $taxId if ($taxId);
  }

  return $fullName, $ncbiTaxId;
}

sub getSpeciesStrainInfo {
  my ($abbrev) = @_;
  my ($fullName) = getOrganismFullNameFromAbbrev ($abbrev);

  my @items = split (/\s+/, $fullName);
  my $genus = shift @items;
  my $species = shift @items;
  $species = $genus . " " . $species;

  my $strain = join (" ", @items);
  $strain = optimizedStrain ($strain);

  return $species, $strain;
}

sub optimizedStrain {
  my ($strain) = @_;

  $strain =~ s/isolate//i;
  $strain =~ s/strain//i;
  $strain =~ s/breed//i;
  $strain =~ s/str\.//i;
  $strain =~ s/\///g;
  $strain =~ s/^\s+//;
  $strain =~ s/\s+$//;

  return $strain;
}

sub getStrainFromFullName {
}

sub getPrimaryExtDbRlsIdFormOrgAbbrev {
  my ($abbrev) = @_;

  my $extDb = $abbrev. "_primary_genome_RSRC";

  my $extDbRls = getExtDbRlsIdFromExtDbName ($extDb);

  return $extDbRls;
}

sub getExtDbRlsIdFromExtDbName {
  my ($extDbRlsName) = @_;

  my $sql = "select edr.external_database_release_id
             from sres.externaldatabaserelease edr, sres.externaldatabase ed
             where ed.name = '$extDbRlsName'
             and edr.external_database_id = ed.external_database_id";
  my $stmt = $dbh->prepareAndExecute($sql);
  my @rlsIdArray;

  while ( my($extDbRlsId) = $stmt->fetchrow_array()) {
      push @rlsIdArray, $extDbRlsId;
    }

  die "No extDbRlsId found for '$extDbRlsName'" unless(scalar(@rlsIdArray) > 0);

  die "trying to find unique extDbRlsId for '$extDbRlsName', but more than one found" if(scalar(@rlsIdArray) > 1);

  return @rlsIdArray[0];

}


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
A script to generate genome.json file by query database. Only working for database loaded by ebi3gus.

Usage: perl generateGenomeJsonFromDatabase.pl --organismAbbrev pfalCD01

where:
  --organismAbbrev: required, eg. pfal3D7
  --outputFileDir: optional, default is the current dir
  --outputFileName: optional, default is organismAbbrev_genome.json
  --gusConfigFile: optional, default is \$GUS_HOME/config/gus.config

";
}
