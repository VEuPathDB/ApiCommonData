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
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | broken
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^
use strict;
use lib "$ENV{GUS_HOME}/lib/perl";
use Getopt::Long;
use GUS::ObjRelP::DbiDatabase;
use GUS::Supported::GusConfig;

my $gusConfigFile;
my $organism;
my $path;

&GetOptions( "gusConfigFile=s" => \$gusConfigFile,
             "organism=s"      => \$organism,
             "path=s"          => \$path );

die "usage: getValueFromTable --gusConfigFile [\$GUS_CONFIG_FILE] --organism \"Plasmodium falciparum 3D7\" --path \"absolute path for outputs\" \n" unless $gusConfigFile && $organism && $path;

my $gusconfig = GUS::Supported::GusConfig->new($gusConfigFile);
my @chrs;

my $db = GUS::ObjRelP::DbiDatabase->new($gusconfig->getDbiDsn(),
                                        $gusconfig->getDatabaseLogin(),
                                        $gusconfig->getDatabasePassword(),
                                        0,0,1,
                                        $gusconfig->getCoreSchemaName());


my $dbh = $db->getQueryHandle();

$dbh->{LongReadLen} = 512 * 512 * 1024;
$dbh->{LongTruncOk} = 0;    ### We're happy to truncate any excess

my @chrs = &printGeneticElement($dbh, $organism, $path);

foreach(@chrs) {
  &printFasta($dbh, $_, $path);
  &printPF($dbh, $_, $path);
}

sub printFasta {
  my ($dbh, $chr, $path)  = @_;
  my $sql = "select sequence from webready.GenomicSequenceSequence where source_id = '$chr'"; 
  my $sth = $dbh->prepareAndExecute($sql);
  while(my ($seq) = $sth->fetchrow_array) {
    $seq =~ s/(.{1,60})/$1\n/g;
    open (FSA, ">$path/$chr.fsa");
    print FSA ">$chr\n";
    print FSA $seq;
    close FSA;
  }
  $sth->finish;
}

sub printGeneticElement {
  my ($dbh, $organism, $path) = @_;

  my $sql = "select distinct ga.CHROMOSOME, ga.SEQUENCE_ID from webready.GeneAttributes ga where ga.organism = '$organism' and ga.chromosome is not null order by ga.chromosome";

  my $sth = $dbh->prepareAndExecute($sql);

  open(OUT, '>genetic-elements.dat');
  while(my ($chr, $name, $seq) = $sth->fetchrow_array()){
    push @chrs, $name;
    print OUT <<EOL;
ID\t$name
NAME\tChromosome $chr
TYPE\t:CHRSM
CIRCULAR?\tN
ANNOT-FILE\t$path/$name.pf
SEQ-FILE\t$path/$name.fsa
//
EOL
  }
  close OUT;
  $sth->finish;
  return @chrs;
}

sub printPF {
  my ($dbh, $chr, $path)  = @_;
  open PF, ">$path/$chr.pf";

  my $sql =<<EOL;
SELECT ga.source_id ,
       ga.na_sequence_id ,
       fl.start_min ,
       fl.end_max ,
       ga.product , 
       ga.so_term_name, 
       ga.is_deprecated,
       ga.organism, 
       ga.is_pseudo,
       ga.gene_type,
       ga.ec_numbers,
       ga.name
FROM   webready.GeneAttributes ga, 
       apidb.FeatureLocation fl
WHERE  fl.na_feature_id = ga.na_feature_id
   AND ga.sequence_id = '$chr'
ORDER BY fl.start_min
EOL

  my $sth = $dbh->prepareAndExecute($sql);

  while(my $arr = $sth->fetchrow_arrayref()){
    my($id, $na_seq_id, $start, $end, $product, $so, $deprecated, $organism, $pseudo, $genetype, $ec_number, $name) = @$arr;
     
    my $product_type = 'P';

    if($genetype =~ /rRNA encoding/i) {
      $product_type = 'RRNA';
    } elsif($genetype =~ /tRNA encoding/i) {
      $product_type = 'TRNA';
    } elsif($genetype =~ /non protein coding/i) {
      $product_type = 'P';
    } elsif($genetype =~ /snRNA encoding/i) {
      $product_type = 'MISC-RNA';
    } elsif($genetype =~ /protein coding/i) {
      $product_type = 'P';
    } elsif($genetype =~ /snoRNA encoding/i) {
      $product_type = 'MISC-RNA';
    }

    $product_type = 'PSEUDO' if $pseudo;

    $ec_number =~ s/\(.+\)//;
    $ec_number =~ s/\s+$//g;

    my $pf = "ID\t$id\n";

    $pf .= "NAME\t$id\n"; 
    $pf .= "STARTBASE\t$start\n";
    $pf .= "ENDBASE\t$end\n";
    $pf .= "FUNCTION\t$product\n" if $product;
    $pf .= "PRODUCT-TYPE\t$product_type\n";
    $pf .= "EC\t$ec_number\n" if $ec_number;

    my $sqlGO = "SELECT distinct gts.go_id, gts.go_term_name, gts.evidence_code FROM webready.GoTermSummary gts where gts.source_id = '$id' ORDER BY gts.go_id";

    my $sthGO = $dbh->prepareAndExecute($sqlGO);
    while(my ($goid, $go_term, $evidence) = $sthGO->fetchrow_array){
      $pf .= "GO\t$go_term [goid $goid] [evidence $evidence] [pmid ]\n";
    }

    $sthGO->finish;

    $pf .= "//\n";

    print PF $pf;
  }
  close PF;
  $sth->finish;
}

$dbh->disconnect;
