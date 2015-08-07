#!/usr/bin/perl

use strict;
use lib "$ENV{GUS_HOME}/lib/perl/";

use DBI;
use DBD::Oracle;
use Getopt::Long;

use CBIL::Util::PropertySet;
use GUS::Community::GeneModelLocations;

# Possible TODO is to add the fasta sequence for transcript, cds, protein (wdkReportMaker includes options for these BUT we are not planning on using the wdkReportMaker for GUS4)

my ($help, $gusConfigFile, $extDbRlsId, $outputFile);
&GetOptions('help|h' => \$help,
            'gusConfigFile=s' => \$gusConfigFile,
            'extDbRlsId=s' => \$extDbRlsId,
            'outputFile=s' => \$outputFile,
    );

##Create db handle
if(!$gusConfigFile) {
  $gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config";
}

&usage("Config file $gusConfigFile does not exist.") unless -e $gusConfigFile;

my @properties;
my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);

my $dbiDsn = $gusconfig->{props}->{dbiDsn};
my $dbiUser = $gusconfig->{props}->{databaseLogin};
my $dbiPswd = $gusconfig->{props}->{databasePassword};

my $dbh = DBI->connect($dbiDsn, $dbiUser, $dbiPswd) or die DBI->errstr;
$dbh->{RaiseError} = 1;
$dbh->{AutoCommit} = 0;

open(GFF, "> $outputFile") or die "Cannot open file $outputFile For writing: $!";

my $geneAnnotations = {};
my $transcriptAnnotations = {};
my $ncbiTaxId;
my $sequenceLengths = {};

my $sql = "select s.source_id as sequence_source_id, s.length, t.gene_source_id, t.gene_product, t.source_id as transcript_source_id, t.transcript_product, t.ncbi_tax_id, t.ec_numbers, t.annotated_go_id_function, t.annotated_go_id_component,t.annotated_go_id_process 
                   from apidbtuning.transcriptattributes t, dots.nasequence s, sres.externaldatabaserelease r, sres.externaldatabase d
                   where t.na_sequence_id = s.na_sequence_id
                    and r.external_database_release_id = ?
                    and r.external_database_id = d.external_database_id
                    and r.version = t.external_db_version
                    and d.name = t.external_db_name";
my $sh = $dbh->prepare($sql);
$sh->execute($extDbRlsId);
while(my ($sequenceSourceId, $sequenceLength, $geneSourceId, $geneProduct, $transcriptSourceId, $transcriptProduct, $ncbi, $ecNumbers, @goIds) = $sh->fetchrow_array()) {
  $ncbiTaxId = $ncbi if($ncbi);

  $geneAnnotations->{$geneSourceId} = {gene_product => $geneProduct,
                                       ncbi_tax_id => $ncbiTaxId,
  };

  $transcriptAnnotations->{$transcriptSourceId} = {transcript_product => $transcriptProduct,
                                   ec_numbers => $ecNumbers,
                                   go_ids => join(",",  grep(defined, @goIds))
  };
  $sequenceLengths->{$sequenceSourceId} = $sequenceLength;
}

my $geneModelLocations = GUS::Community::GeneModelLocations->new($dbh, $extDbRlsId, 1);


print GFF "##gff-version 3\n";
print GFF "##species http://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?id=$ncbiTaxId\n" if($ncbiTaxId);

foreach(sort keys %$sequenceLengths) {
  my $length = $sequenceLengths->{$_};

  print GFF "##sequence-region $_ 1 $length\n";
}

foreach my $geneSourceId (@{$geneModelLocations->getAllGeneIds()}) {
  my $features = $geneModelLocations->bioperlFeaturesFromGeneSourceId($geneSourceId);

  foreach my $feature (@$features) {
    $feature->source_tag("EuPathDB");
    foreach my $extraTag ("NA_FEATURE_ID", "NA_SEQUENCE_ID", "PARENT_NA_FEATURE_ID", "AA_FEATURE_ID", "AA_SEQUENCE_ID") {
      $feature->remove_tag($extraTag) if($feature->has_tag($extraTag));
    }

    if($feature->primary_tag eq 'gene') {
      $feature->add_tag_value("description", $geneAnnotations->{$geneSourceId}->{gene_product});
    }

    if($feature->primary_tag eq 'mRNA') {
      my ($transcriptId) = $feature->get_tag_values("ID");

      my $product = $transcriptAnnotations->{$transcriptId}->{transcript_product};
      my $ecNumbers = $transcriptAnnotations->{$transcriptId}->{ec_numbers};
      my $goIds = $transcriptAnnotations->{$transcriptId}->{go_ids};

      $feature->add_tag_value("description", $product) if($product);
      $feature->add_tag_value("Note", $ecNumbers) if($ecNumbers);
      $feature->add_tag_value("Ontology_term", $goIds) if($goIds);
    }

    print GFF $feature->gff_string . "\n";
  }
}

$dbh->disconnect();
close GFF;

1;
