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


my ($organismAbbrev, $gusConfigFile, $outputFileName, $outputFileDir, $help);

&GetOptions('organismAbbrev=s' => \$organismAbbrev,
#            'genomeSummaryFile=s' => \$genomeSummaryFile,
            'gusConfigFile=s' => \$gusConfigFile,
            'outputFileName=s' => \$outputFileName,
            'outputFileDir=s' => \$outputFileDir,
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
if ($outputFileDir) {
  $outputFileName = "\./". $outputFileDir . "\/" . $outputFileName;
}
open (OUT, ">$outputFileName") || die "cannot open $outputFileName file to write.\n";

my $extDbRlsId = getExtDbRlsIdFormOrgAbbrev ($organismAbbrev);

print STDERR "\$extDbRlsId = $extDbRlsId\n";

my $sql = "    select source_id, SEQUENCE_TYPE, LENGTH
               from apidbtuning.genomicseqattributes
               where EXTERNAL_DATABASE_RELEASE_ID=$extDbRlsId
               and is_top_level = 1";

my $stmt = $dbh->prepare($sql);
$stmt->execute();

my @seqRegionsArray;
while (my ($seqSourceId, $seqType, $seqLen) = $stmt->fetchrow_array()) {

  my %seqRegions = (
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

  push @seqRegionsArray, \%seqRegions;
}

$stmt->finish();

my $json = encode_json \@seqRegionsArray;

print OUT "$json\n";

close OUT;

$dbh->disconnect();


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
