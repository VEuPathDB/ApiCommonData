#!/usr/bin/perl
## Downloads biopax level 3 files from trypanocyc or leishcyc via web services from a list of available pathways in xml format. A list of all available pathways is obtained using: 
## wget 'http://vm-trypanocyc.toulouse.inra.fr/TRYPANO/xmlquery?[x:x<-trypano^^pathways]&detail=none' -q -O - | grep -v "class='true'" | sed 's/'\''/'\"'/g'> pathwayList.xml

use strict;
use warnings;

use LWP::Simple;
use URI::Escape;

my $pathwayXml = shift;
my $databaseName = shift;

die "Usage: downloadPathwayBiopaxFiles.pl <path to pathway Xml File> <databaseName>\n Database name must be 'TrypanoCyc' or 'LeishCyc'.\n" unless $pathwayXml && $databaseName;

my $organism;
if (lc $databaseName eq 'trypanocyc') {
    $organism = 'TRYPANO'
} elsif (lc $databaseName eq 'leishcyc') {
    $organism = 'LEISH'
} else {
    die "Database name must be 'TrypanoCyc' or 'LeishCyc'\n";
}

my $urlBase = "http://vm-trypanocyc.toulouse.inra.fr/$organism/pathway-biopax?type=3&object=";

open(XML, "<$pathwayXml") or die "Cannot open pathway xml file $pathwayXml\n$!\n";

while (<XML>) {
    chomp;
    /frameid=\"(.+)\"/;
    if ($1) {
        my $url = $urlBase.uri_escape($1);
        my $response = getstore($url, "$1.biopax");
        die "Error: $response when getting from $url\n" unless is_success($response);
    }
}
exit;
