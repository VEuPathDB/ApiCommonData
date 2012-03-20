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

my $sql = "select distinct v.term from apidb.isolatevocabulary v where v.type = 'geographic_location' order by v.term";

my $sth = $dbh->prepareAndExecute($sql);

my $xml = new XML::Simple;

while(my $country = $sth->fetchrow_array) {
  my $link = "http://maps.googleapis.com/maps/api/geocode/xml?address=$country&sensor=false";
  print "$link\n";
  my $tmp_file = "/tmp/tmp_country.xml";
  my $cmd = "curl '$link' > $tmp_file";
  system($cmd);
  my $data = $xml->XMLin("$tmp_file");
  my $lat = $data->{result}->{geometry}->{location}->{lat};
  my $lng = $data->{result}->{geometry}->{location}->{lng};
  my $address = $data->{result}->{formatted_address};
  print "$address | $lat | $lng\n";
  system("rm -f $tmp_file");
}

$sth->finish;
$dbh->disconnect;
