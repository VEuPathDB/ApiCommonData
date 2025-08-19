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


my ($organismAbbrev, $gusConfigFile, $outputFileName, $outputFileDir, $ncbiTaxId, $help);

&GetOptions('organismAbbrev=s' => \$organismAbbrev,
#            'genomeSummaryFile=s' => \$genomeSummaryFile,
            'gusConfigFile=s' => \$gusConfigFile,
            'outputFileName=s' => \$outputFileName,
            'outputFileDir=s' => \$outputFileDir,
            'ncbiTaxId=s' => \$ncbiTaxId,
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

my $extDbRlsId = getPrimaryExtDbRlsIdFormOrgAbbrev ($organismAbbrev);

my $karyotypeBands = getCentromereInfo($extDbRlsId);
#my $transposableElement = getTransposableElementInfo($extDbRlsId);

my $ebiSeqRegionName = getEbiSeqRegionName($extDbRlsId);

my $outputFileName = $organismAbbrev . "_seq_region.json" unless($outputFileName);
if ($outputFileDir) {
  $outputFileName = "\./". $outputFileDir . "\/" . $outputFileName;
}
open (OUT, ">$outputFileName") || die "cannot open $outputFileName file to write.\n";


print STDERR "\$extDbRlsId = $extDbRlsId\n";

my $sql = "    select source_id, SEQUENCE_TYPE, LENGTH
               from webready.genomicseqattributes
               where EXTERNAL_DATABASE_RELEASE_ID=$extDbRlsId
               and org_abbrev = '$organismAbbrev'
               and is_top_level = 1";

if ($ncbiTaxId) {
  $sql = "select source_id, SEQUENCE_TYPE, LENGTH from apidbtuning.genomicseqattributes where ncbi_tax_id = $ncbiTaxId and is_top_level = 1";
}

my $stmt = $dbh->prepare($sql);
$stmt->execute();

my @seqRegionsArray;
while (my ($seqSourceId, $seqType, $seqLen) = $stmt->fetchrow_array()) {

  my %seqRegions = (
		 'name' => $seqSourceId,
		 'coord_system_level' => $seqType,
		 'length' => $seqLen,
		 );

  $seqRegions{length} += 0;  ## change string to integer

  $seqRegions{EBI_seq_region_name} = $ebiSeqRegionName->{$seqSourceId} if ($ebiSeqRegionName->{$seqSourceId});
  $seqRegions{BRC4_seq_region_name} = $seqSourceId;

  if ($seqType =~ /mitochondrial_chromosome/i || $seqType =~ /apicoplast_chromosome/i || $seqType =~ /maxicircle/i) {
    $seqRegions{coord_system_level} = "chromosome";
    $seqRegions{location} = $seqType;
  }

  my $synonyms = getSeqAliasesFromSeqSourceid($seqSourceId);
  if ($synonyms) {
    $seqRegions{synonyms} = \@{$synonyms};
  }

  my $geneticCode = getGeneticCodeFromOrganismAbbrev($organismAbbrev, $seqType);
  if ($geneticCode != 1) {
    $seqRegions{codon_table} = $geneticCode;
    $seqRegions{codon_table} += 0;
  }

  ## for some organisms in PlasmoDB
  if ($karyotypeBands->{$seqSourceId}) {
    push @{$seqRegions{karyotype_bands}}, $karyotypeBands->{$seqSourceId};
  }

  ## for tvagG3 in TrichDB and cfasCfCl in TriTrypDB
#  if ($transposableElement->{$seqSourceId}) {
#    $seqRegions{transposableElement} = $transposableElement->{$seqSourceId};
#  }

  ## to correct a random_sequence issue in plas-
  if (($organismAbbrev eq "pyoeyoeliiYM" || $organismAbbrev eq "preiCDC" || $organismAbbrev eq "pknoH" )
      && $seqRegions{coord_system_level} =~ /random_sequence/i) {
    $seqRegions{coord_system_level} = "contig";
  }

  push @seqRegionsArray, \%seqRegions;
  $db->undefPointerCache();
}

$stmt->finish();

my $json = encode_json \@seqRegionsArray;

print OUT "$json\n";

close OUT;

$dbh->disconnect();


###########
sub getEbiSeqRegionName {
  my ($extDbRlsId) = @_;

  my $sql = "select SOURCE_ID, SECONDARY_IDENTIFIER, name from DOTS.EXTERNALNASEQUENCE
             where EXTERNAL_DATABASE_RELEASE_ID=$extDbRlsId
            ";

  my $stmt = $dbh->prepareAndExecute($sql);

  my %ebiSeqName;
  while (my ($seqId, $secondId) = $stmt->fetchrow_array()) {

    $ebiSeqName{$seqId} = $secondId if ($seqId && $secondId);
  }

  return \%ebiSeqName;
}

sub getCentromereInfo {
  my ($extDbRlsId) = @_;

  my $sql = "select ns.SOURCE_ID, m.SOURCE_ID, nl.START_MIN, nl.END_MAX 
             from DOTS.MISCELLANEOUS m, DOTS.NASEQUENCE ns, DOTS.NALOCATION nl
             where ns.NA_SEQUENCE_ID=m.NA_SEQUENCE_ID and m.NA_FEATURE_ID=nl.NA_FEATURE_ID
             and m.name like 'centromere' and m.EXTERNAL_DATABASE_RELEASE_ID=$extDbRlsId
            ";

  my $stmt = $dbh->prepareAndExecute($sql);

  my %centromereInfo;
  while (my ($seqId, $centromereId, $cStart, $cEnd) = $stmt->fetchrow_array()) {

    %{$centromereInfo{$seqId}} = (
			       "name" => $centromereId,
			       "stain" => "ACEN",
			       "structure" => "centromere",
			       "start" => $cStart,
			       "end" => $cEnd
			       );
    ${$centromereInfo{$seqId}}{start} += 0;
    ${$centromereInfo{$seqId}}{end} += 0;
  }

  return \%centromereInfo;
}

sub getTransposableElementInfo {
  my ($extDbRlsId) = @_;

  my $sql = "select ns.SOURCE_ID, te.SOURCE_ID, nl.START_MIN, nl.END_MAX, te.NAME
             from DoTS.TransposableElement te, DOTS.NASEQUENCE ns, DOTS.NALOCATION nl
             where ns.NA_SEQUENCE_ID=te.NA_SEQUENCE_ID and te.NA_FEATURE_ID=nl.NA_FEATURE_ID
             and ns.EXTERNAL_DATABASE_RELEASE_ID=$extDbRlsId";

  my $stmt = $dbh->prepareAndExecute($sql);

  my %teInfo;
  while (my ($seqId, $teId, $teStart, $teEnd, $teName) = $stmt->fetchrow_array()) {

#    %{$teInfo{$seqId}} = (
    my %info =  (
			       "id" => $teId,
			       "start" => $teStart,
			       "end" => $teEnd,
			       "name" => $teName
			       );
    push @{$teInfo{$seqId}}, \%info;
  }

  return \%teInfo;
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

sub getGeneticCodeFromOrganismAbbrev {
  my ($organismAbbrev, $seqType) = @_;

  my $organismInfo = GUS::Model::ApiDB::Organism->new({'abbrev' => $organismAbbrev});
  $organismInfo->retrieveFromDB();
  my $projectName = $organismInfo->getProjectName();

  ## manually set up $projectName for those annotation loaded into EuTestDB
  if ($projectName eq "EuTestDB") {
    if ($organismAbbrev eq "pberANKA"
	|| $organismAbbrev eq "pchachabaudi"
	|| $organismAbbrev eq "pfal3D7"
	|| $organismAbbrev eq "pgal8A"
	|| $organismAbbrev eq "pknoH"
	|| $organismAbbrev eq "pknoA1H1"
	|| $organismAbbrev eq "pmalUG01"
	|| $organismAbbrev eq "povaGH01"
	|| $organismAbbrev eq "preiCDC"
	|| $organismAbbrev eq "prelSGS1-like"
	|| $organismAbbrev eq "pvivP01"
	|| $organismAbbrev eq "pyoeyoelii17X"
	|| $organismAbbrev eq "pfalNF135C10"
	|| $organismAbbrev eq "pfalNF166"
	|| $organismAbbrev eq "pfalNF54"
	|| $organismAbbrev eq "pfal7G8-2019"
	|| $organismAbbrev eq "htarSISKIN1"
       ) {
      $projectName = "PlasmoDB";
    } elsif ( $organismAbbrev eq "mbalATCC30984"
	|| $organismAbbrev eq "nfowTy"
		) {
      $projectName = "AmoebaDB";
    } elsif ( $organismAbbrev eq "bdiv1802A"
	|| $organismAbbrev eq "cfelWinnie"
		) {
      $projectName = "PiroplasmaDB";
    } elsif ( $organismAbbrev eq "cvelCCMP2878"
		) {
      $projectName = "CryptoDB";
    } elsif ( $organismAbbrev eq "ncanLiverpool2019"
	|| $organismAbbrev eq "etenHoughton2021"
	    ) {
      $projectName = "ToxoDB";
    } elsif ( $organismAbbrev eq "treeQM6a2017"
	|| $organismAbbrev eq "ctroMYA3404-2020"
	|| $organismAbbrev eq "rlauRL4"
	|| $organismAbbrev eq "hvasRaceXXXIII"
	|| $organismAbbrev eq "rirrC2"
	|| $organismAbbrev eq "spalSPA8"
	|| $organismAbbrev eq "rirrDAOM181602"
		) {
      $projectName = "FungiDB";
    } elsif ( $organismAbbrev eq "tbruTREU927"
	    || $organismAbbrev eq "tbruLister427_2018"
	    || $organismAbbrev eq "tbruEATRO1125"
	    || $organismAbbrev eq "laetL147"
	    || $organismAbbrev eq "lbraMHOMBR75M2903"
	    || $organismAbbrev eq "tevaSTIB805"
	    || $organismAbbrev eq "lamaPH8"
	    ) {
      $projectName = "TriTrypDB";
    } else {
      die "ERROR: projectName EuTestDB found. Please reset projectName.........\n";
    }
  }

  my $sql;
  if ($seqType =~ /api/i) {
    ## due to no plastid genetic code availabe in db,
    ## checked ncbi taxonomy, all plas- and piro- are 11, and toxo- is 4
    ## manually code here
    if ($projectName =~ /^piro/i || $projectName =~ /^plas/i) {
      return "11";
    } elsif ($projectName =~ /^toxo/i) {
      return "4";
    } else {
      die "ERROR: all plastid should be coded. Something is wrong. Should check here.\n";
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

  my $curSource; 
  while (my ($alias) = $stmt->fetchrow_array()) {
#    if ($alias =~ /^CM/ || $alias =~ /^NC/) {
    if ($alias =~ /^[A-Z]{2}\_?\d{5,6}/ || $alias =~ /^[A-Z]{4}\d{8}/) {
      $curSource = "INSDC";
    } else {
      $curSource = "Community_Symbol";
    }
    my %curAlias = (
		    "source" => $curSource,
		    "name" => $alias
		    );
    push @{$aliases}, \%curAlias;
#    push @{$aliases}, $alias;
  }

  $stmt->finish();

  return $aliases;
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
