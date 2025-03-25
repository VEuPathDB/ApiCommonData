#!/usr/bin/perl
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | absent
  # GUS4_STATUS | RAD.Analysis                   | auto   | absent
  # GUS4_STATUS | ApiDB.Profile                  | auto   | absent
  # GUS4_STATUS | Study.Study                    | auto   | absent
  # GUS4_STATUS | Dots.Isolate                   | auto   | absent
  # GUS4_STATUS | DeprecatedTables               | auto   | absent
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

use strict;
use lib "$ENV{GUS_HOME}/lib/perl";
use Getopt::Long;
use IO::File;
use DBI;
use CBIL::Util::PropertySet;

use GUS::Community::GeneModelLocations;

use Data::Dumper;

my ($geneExtDbSpec,$aefExtDbSpec,$aefSense,$outputFile,$delimiter,$gusConfigFile);

&GetOptions('aefExtDbSpec=s' => \$aefExtDbSpec,
            'geneExtDbSpec=s' => \$geneExtDbSpec,
            'aefSense=s' =>\$aefSense,
            'outputFile=s' =>\$outputFile,
            'delimiter=s' => \$delimiter,
            'gusConfigFile=s' => \$gusConfigFile,
           );

die "ERROR: Please provide a valid External Database Spec ('name|version') for the Array Element Features"  unless ($aefExtDbSpec);
die "ERROR: Please provide a valid External Database Spec ('name|version') for Gene Features" unless ($geneExtDbSpec);
die "ERROR: Please provide a valid sense/direction ('sense','anitsense' or 'either') for the Array Element Features" unless (lc($aefSense) eq 'sense' || lc($aefSense) eq 'antisense' || lc($aefSense) eq 'either' );
die "ERROR: Please provide a valid delimiter ('\\t', ',') for the Array Element Features" unless $delimiter eq '\t' || $delimiter eq ',';

$gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config" unless($gusConfigFile);

unless(-e $gusConfigFile) {
  print STDERR "gus.config file not found! \n";
  exit;
}


my @properties = ();
my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);

my $u = $gusconfig->{props}->{databaseLogin};
my $pw = $gusconfig->{props}->{databasePassword};
my $dsn = $gusconfig->{props}->{dbiDsn};
my $dbh = DBI->connect($dsn, $u, $pw) or die DBI::errstr;
#----------------------------------------------------------------------
my $geneExtDbRlsId = getDbRlsId($geneExtDbSpec);
my $aefExtDbRlsId = getDbRlsId($aefExtDbSpec);


my $geneModelLocations = GUS::Community::GeneModelLocations->new($dbh, $geneExtDbRlsId, 1);


my $geneSourceIds = $geneModelLocations->getAllGeneIds();

my %exonLocations;

foreach my $geneSourceId (@$geneSourceIds) {
  my $geneModelHash = $geneModelLocations->getGeneModelHashFromGeneSourceId($geneSourceId);
  my $sequenceSourceId = $geneModelHash->{na_sequence_id};

  foreach my $exonSourceId (keys %{$geneModelHash->{exons}}) {

    my $exon = $geneModelHash->{exons}->{$exonSourceId};    

    my $isReversed = $exon->{strand} == -1 ? 1 : 0;
    my $exonLocation = [$geneSourceId, $exon->{start}, $exon->{end}, $isReversed ];

    push @{$exonLocations{$sequenceSourceId}}, $exonLocation;
  }
}

my %sortedExonLocations;

foreach my $sequenceSourceId (keys %exonLocations) {
  my @sortedExons = sort {$a->[1] <=> $b->[1]} @{$exonLocations{$sequenceSourceId}};

  push @{$sortedExonLocations{$sequenceSourceId}}, @sortedExons;
}

print STDERR "Extracting Array Element Features.....\n";

my $aefSql = "select rl.na_sequence_id
     , rl.reporter_location_id as source_id
     , r.source_id as name
     , rl.reporter_start
     , rl.reporter_end
     , rl.ON_REVERSE_STRAND
from platform.ArrayDesign rs
   , platform.reporter r
   , PLATFORM.REPORTERLOCATION rl
where rs.external_database_release_id = $aefExtDbRlsId
and rs.REPORTER_SET_ID = r.REPORTER_SET_ID
and rl.REPORTER_ID = r.REPORTER_ID
";

my $sth = $dbh->prepare($aefSql);

$sth->execute || die "Could not execute SQL statement!";

my %reporters;

while( my ($naSeqId, $sourceId, $name, $start, $end, $isReversed) = $sth->fetchrow_array() ){
  push @{$reporters{$naSeqId}}, [$name, $start, $end, $isReversed];
} 

open (mapFile, ">$outputFile");

$delimiter = "\t" if ($delimiter ne ",");

foreach my $sequenceSourceId (keys %sortedExonLocations) {
  my %geneMap;

  foreach my $exonLoc (@{$sortedExonLocations{$sequenceSourceId}}) {
    my $geneSourceId = $exonLoc->[0];
    my $exonStart = $exonLoc->[1];
    my $exonEnd = $exonLoc->[2];
    my $exonIsReversed = $exonLoc->[3];

    foreach my $reporter (@{$reporters{$sequenceSourceId}}) {
      my $probeName = $reporter->[0];
      my $probeStart = $reporter->[1];
      my $probeEnd = $reporter->[2];
      my $probeIsReversed = $reporter->[3];
      
      if ($exonIsReversed) {
        next if(($aefSense eq 'sense' && $probeIsReversed == 0) || ($aefSense eq 'antisense' && $probeIsReversed == 1));
      } 
      else {
        next if(($aefSense eq 'sense' && $probeIsReversed == 1) || ($aefSense eq 'antisense' && $probeIsReversed == 0));
      }

      if($probeStart < $exonEnd && $probeEnd > $exonStart) {
        push @{$geneMap{$geneSourceId}}, $probeName;
      }
    }
  }

  foreach my $gene (keys %geneMap) {
    my @probes = @{$geneMap{$gene}};
    next if(scalar @probes < 1);
    print mapFile "$gene\t" . join ("$delimiter", @probes) . "\n";
  }
}


$dbh->disconnect();

sub getDbRlsId {

  my ($extDbRlsSpec) = @_;

  my ($extDbName, $extDbRlsVer) = &getExtDbInfo($extDbRlsSpec);

  my $stmt = $dbh->prepare("select dbr.external_database_release_id from sres.externaldatabaserelease dbr,sres.externaldatabase db where db.name = ? and db.external_database_id = dbr.external_database_id and dbr.version = ?");

  $stmt->execute($extDbName,$extDbRlsVer);

  my ($extDbRlsId) = $stmt->fetchrow_array();

  return $extDbRlsId;
}

sub getExtDbInfo {
  my ($extDbRlsSpec) = @_;
  if ($extDbRlsSpec =~ /(.+)\|(.+)/) {
    my $extDbName = $1;
    my $extDbRlsVer = $2;
    return ($extDbName, $extDbRlsVer);
  } else {
    die("Database specifier '$extDbRlsSpec' is not in 'name|version' format");
  }
}
#my $endTime = time();
#print("Done. Time: $endTime\n");
