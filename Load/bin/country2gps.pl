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
  # GUS4_STATUS | Dots.Isolate                   | auto   | broken
  # GUS4_STATUS | DeprecatedTables               | auto   | absent
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^
use strict;
use lib "$ENV{GUS_HOME}/lib/perl";

use XML::Simple;
use Getopt::Long;
use GUS::Supported::GusConfig;
use GUS::ObjRelP::DbiDatabase;

my ($gusConfigFile, $verbose);
&GetOptions("gusConfigFile=s" => \$gusConfigFile,
            "verbose!"        => \$verbose);

die "usage: country2gsp --gusConfigFile <string> --verbose\n" unless $gusConfigFile;

my $gusconfig = GUS::Supported::GusConfig->new($gusConfigFile);

my $db = GUS::ObjRelP::DbiDatabase->new($gusconfig->getDbiDsn(),
                                        $gusconfig->getDatabaseLogin(),
                                        $gusconfig->getDatabasePassword(),
                                        $verbose,0,1,
                                        $gusconfig->getCoreSchemaName());

my $dbh = $db->getQueryHandle(0);

my $sql = "select distinct v.isolate_vocabulary_id, v.term from apidb.isolatevocabulary v where v.type = 'geographic_location' order by v.term";

my $sth = $dbh->prepareAndExecute($sql);

my $xml = new XML::Simple;

open(OUT, ">country_list");

print OUT "isolate_vocabulary_id|country|formatted_address|lat|lng\n";

while(my ($isolate_vocabulary_id, $country) = $sth->fetchrow_array) {
  my $html_addr = $country;
  $html_addr =~ s/\s/%20/g;
  $html_addr =~ s/'/\\'/g;
  my $link = "http://maps.googleapis.com/maps/api/geocode/xml?address=$html_addr&sensor=false";
  print "$link\n";
  my $tmp_file = "/tmp/tmp_country.xml";
  my $cmd = "curl \"$link\" > $tmp_file";
  system($cmd);
  my $data = $xml->XMLin("$tmp_file");
  my $lat = $data->{result}->{geometry}->{location}->{lat};
  my $lng = $data->{result}->{geometry}->{location}->{lng};
  print OUT "$isolate_vocabulary_id|$country|$lat|$lng\n";
  system("rm -f $tmp_file");
  sleep(2);
}

$sth->finish;
$dbh->disconnect;
