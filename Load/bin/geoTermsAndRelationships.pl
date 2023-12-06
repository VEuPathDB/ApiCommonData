#!/usr/bin/perl

use strict;

use lib "$ENV{GUS_HOME}/lib/perl";

use File::Basename;

use Getopt::Long;

use ApiCommonData::Load::StudyUtils;

my ($outputType, $ontologyTermsFile, $ontologyRelationshipsFile);
&GetOptions('output_type=s' => \$outputType,
            'ontology_terms=s' => \$ontologyTermsFile,
            'ontology_relationships=s' => \$ontologyRelationshipsFile,
    );

my %geoTerms;

$geoTerms{${ApiCommonData::Load::StudyUtils::latitudeSourceId}} = 'latitude';
$geoTerms{${ApiCommonData::Load::StudyUtils::longitudeSourceId}} = 'longitude';
while(my ($geohash, $prec) = each %${ApiCommonData::Load::StudyUtils::GEOHASH_PRECISION}) {
    $geoTerms{$geohash} = "GEOHASH $prec";
}

if($outputType eq 'term') {
    foreach my $sourceId (keys %geoTerms) {
        print "$sourceId\t$geoTerms{$sourceId}\n";
    }

}
elsif($outputType eq 'relationship') {

    my $parent;

    open(REL, $ontologyRelationshipsFile) or die "Cannot open file $ontologyRelationshipsFile for reading: $!";
    my %children;
    while(<REL>) {
        chomp;
        my @a = split(/\t/, $_);
        $children{$a[0]} = 1;
    }
    close REL;

    open(TERM, $ontologyTermsFile) or die "Cannot open file $ontologyTermsFile for reading: $!";
    while(<TERM>) {
        chomp;
        my @a = split(/\t/, $_);
        my $possibleParent = $a[0];

        next if($children{$possibleParent});

        if($parent) {
            die "Multiple Roots found for Attribute Graph:  $possibleParent and $parent";
        }
        $parent = $possibleParent;
    }
    close TERM;

    foreach my $geohash (keys %geoTerms) {
        print $geohash  . "\tsubClassOf\t" . $parent . "\n";;
    }
}
else {
    die "output_type must be either 'term' or 'relationship'";
}
