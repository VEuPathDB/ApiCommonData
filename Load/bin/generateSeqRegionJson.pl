#!/usr/bin/perl

use strict;
use JSON;
use Getopt::Long;

use DBI;
use DBD::Oracle;
#use CBIL::Util::PropertySet;
use GUS::Supported::GusConfig;
use GUS::ObjRelP::DbiDatabase;
use GUS::Model::ApiDB::Organism;


my ($organismAbbrev, $gusConfigFile, $outputFileName, $help);

&GetOptions('organismAbbrev=s' => \$organismAbbrev,
#            'genomeSummaryFile=s' => \$genomeSummaryFile,
            'gusConfigFile=s' => \$gusConfigFile,
            'outputFileName=s' => \$outputFileName,
            'help|h' => \$help
            );

&usage() if ($help);
&usage("Missing a Required Argument") unless (defined $organismAbbrev);

$gusConfigFile = "$ENV{GUS_HOME}/config/gus.config" unless ($gusConfigFile);
my $gusconfig = GUS::Supported::GusConfig->new($gusConfigFile);

my $verbose;
my $db = GUS::ObjRelP::DbiDatabase->new($gusconfig->getDbiDsn(),
                                        $gusconfig->getDatabaseLogin(),
                                        $gusconfig->getDatabasePassword(),
                                        $verbose,0,1,
                                        $gusconfig->getCoreSchemaName()
                                       );
my $dbh = $db->getQueryHandle();


my $outputFileName = $organismAbbrev . "_seq_region.json" unless($outputFileName);
open (OUT, ">$outputFileName") || die "cannot open $outputFileName file to write.\n";

print OUT "[";
my $extDbRlsId = getExtDbRlsIdFormOrgAbbrev ($organismAbbrev);

print STDERR "\$extDbRlsId = $extDbRlsId\n";

my $sql = "    select source_id, SEQUENCE_TYPE, LENGTH
               from apidbtuning.genomicseqattributes
               where EXTERNAL_DATABASE_RELEASE_ID=$extDbRlsId
               and is_top_level = 1";

my $stmt = $dbh->prepare($sql);
$stmt->execute();

my (%seqRegions, $c);
while (my ($seqSourceId, $seqType, $seqLen) = $stmt->fetchrow_array()) {

  %seqRegions = (
		 'name' => $seqSourceId,
		 'coord_system_level' => $seqType,
		 'length' => $seqLen,
		 );

  my $synonyms = getSeqAliasesFromSeqSourceid($seqSourceId);
  if ($synonyms) {
    $seqRegions{synonyms} = \@{$synonyms};
  }

  my $geneticCode = getGeneticCodeFromOrganismAbbrev($organismAbbrev, $seqType);
  if ($geneticCode != 1) {
    $seqRegions{codon_table} = $geneticCode;
  }

  my $json = encode_json \%seqRegions;
  ($c < 1) ? print OUT "$json" : print OUT ",$json";
  $c++;
}

$stmt->finish();

print OUT "]";

close OUT;

$dbh->disconnect();


q{
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
					'functional_annotation_source' => $items[22],
					'functional_annotation_version' => $items[23]
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


#my $json = encode_json (array_filter((array) \%organismDetails, 'is_not_null'));
#json_encode(array_filter((array) $object, 'is_not_null'));

#$json = del(.[][] | select(. == null));
};


###########
sub getExtDbRlsIdFormOrgAbbrev {
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

sub getGeneticCodeFromOrganismAbbrev {
  my ($organismAbbrev, $seqType) = @_;

  my $organismInfo = GUS::Model::ApiDB::Organism->new({'abbrev' => $organismAbbrev});
  $organismInfo->retrieveFromDB();
  my $projectName = $organismInfo->getProjectName();

  my $sql;
  if ($seqType =~ /api/i) {
    ## due to no plastid genetic code availabe in db,
    ## checked ncbi taxonomy, all plas- and piro- are 11, and toxo- is 4
    ## manually code here
    if ($projectName =~ /^piro/i || $projectName =~ /^plas/i) {
      return "11";
    } elsif ($projectName =~ /^toxo/) {
      return "4";
    } else {
      die "can not decide apicoplast genetic code \n";
    }
  } elsif ($seqType =~ /mito/i) {
    $sql = "select gt.NCBI_GENETIC_CODE_ID
             from apidb.organism o, sres.taxon ta, SRES.GENETICCODE gt
             where o.TAXON_ID=ta.TAXON_ID and ta.MITOCHONDRIAL_GENETIC_CODE_ID=gt.GENETIC_CODE_ID
             and o.ABBREV like '$organismAbbrev'";
  } else {
    $sql = "select gt.NCBI_GENETIC_CODE_ID
            from apidb.organism o, sres.taxon ta, SRES.GENETICCODE gt
            where o.TAXON_ID=ta.TAXON_ID and ta.GENETIC_CODE_ID=gt.GENETIC_CODE_ID
            and o.ABBREV like '$organismAbbrev'";
  }
  my $stmt = $dbh->prepareAndExecute($sql);

  my @geneticCodes;
  while (my ($geneticCode) = $stmt->fetchrow_array()) {
    push @geneticCodes, $geneticCode;
  }
  die "No geneticCode found for '$organismAbbrev'" unless (scalar(@geneticCodes) > 0);
  die "More than one geneticCode found for '$organismAbbrev'" if (scalar (@geneticCodes) > 1);

  $stmt->finish();

  return @geneticCodes[0];
}

sub getSeqAliasesFromSeqSourceid {
  my ($sourceId) = @_;

  my $aliases;
  my $sql = "select df.PRIMARY_IDENTIFIER 
             from DOTS.NASEQUENCE ns, SRes.DbRef df, DoTS.DbRefNASequence dns
             where ns.NA_SEQUENCE_ID=dns.NA_SEQUENCE_ID and dns.DB_REF_ID=df.DB_REF_ID
             and ns.SOURCE_ID like '$sourceId'";

  my $stmt = $dbh->prepareAndExecute($sql);

  while (my ($alias) = $stmt->fetchrow_array()) {
    push @{$aliases}, $alias;
  }

  $stmt->finish();

  return $aliases;
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
A script to generate seq_region.json file that required by EBI

Usage: perl generateSeqRegionJson.pl --organismAbbrev pfalCD01

where:
  --organismAbbrev: required, eg. pfal3D7
  --outputFileName: optional, default is organismAbbrev_genome.json
  --gusConfigFile: required, it should point to a inc- instance due to query apidbtuning.genomicseqattributes table
                   default is \$GUS_HOME/config/gus.config

";
}
