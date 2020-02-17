#!/usr/bin/perl
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | broken
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | fixed
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
  # GUS4_STATUS | dots.gene                      | manual | fixed
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

use strict;
use lib "$ENV{GUS_HOME}/lib/perl";
use DBI;
use CBIL::Util::PropertySet;
use Getopt::Long;

use GUS::Community::GeneModelLocations;
use Bio::Tools::GFF;
use Bio::SeqFeature::Generic;

use Data::Dumper;

#----------------Get UID and PWD/ database handle---------------

my ($verbose,$gusConfigFile,$organismAbbrev,$outputFile);

&GetOptions("gusConfigFile=s" => \$gusConfigFile,
            "organismAbbrev=s" => \$organismAbbrev,
	    "outputFile=s" => \$outputFile);


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

my $dbh = DBI->connect($dsn, $u, $pw) ||  die "Couldn't connect to database: " . DBI->errstr;
$dbh->{RaiseError} = 1;
$dbh->{AutoCommit} = 0;

my $extDbRlsIds = &lookupExtDbRlsFromOrganismAbbrev("protein_coding%", $organismAbbrev, $dbh);


my $GFFFile = "$outputFile";
my $GFFString = new  Bio::Tools::GFF(-file => ">$GFFFile",  -gff_version => 3);


foreach my $extDbRlsId (@$extDbRlsIds) {
  my $geneModelLocations = GUS::Community::GeneModelLocations->new($dbh, $extDbRlsId, 1);

  foreach my $geneSourceId (@{$geneModelLocations->getAllGeneIds()}) {
    my $features = $geneModelLocations->bioperlFeaturesFromGeneSourceId($geneSourceId);

    foreach my $feature(@$features) {
      $GFFString->write_feature($feature);
    }
  }

}


$GFFString->close();

$dbh->disconnect;

unless(-s $GFFFile) {
  print STDERR "GFF file is empty! \n";
  exit;
}

sub lookupExtDbRlsFromOrganismAbbrev {
  my ($sequenceOntology, $organismAbbrev, $dbh) = @_;



  my $query = "select distinct gf.external_database_release_id
from apidb.organism o
   , dots.genefeature gf
   , dots.nasequence s
   , sres.ontologyterm ot
where o.taxon_id = s.taxon_id
and s.na_sequence_id = gf.na_sequence_id
and gf.sequence_ontology_id = ot.ontology_term_id
and ot.name like ?
and o.abbrev = ?";

  my $qh = $dbh->prepare($query);
  $qh->execute($sequenceOntology, $organismAbbrev);

  my @rv;

  while(my ($extDbRls) = $qh->fetchrow_array()) {
    push @rv, $extDbRls;
  }

  return \@rv;
}

1;
