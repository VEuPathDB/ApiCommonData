#!/usr/bin/perl
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
