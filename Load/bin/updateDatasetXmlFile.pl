#!/usr/bin/env perl
use strict;
use warnings;
use XML::LibXML;

## usage: updateDatasetXmlFile.pl fileName.xml 2025-10-30

my ($file, $new_version) = @ARGV;

my $parser = XML::LibXML->new();
my $doc    = $parser->parse_file($file);

# List of dataset classes to update
my @targets = qw(
  dbxref_gene2Entrez
  dbxref_gene2Uniprot
  dbxref_gene2PubmedFromNcbi
);

foreach my $class (@targets) {
    for my $node ($doc->findnodes("//dataset[\@class='$class']/prop[\@name='version']")) {
        $node->removeChildNodes();                # clear current text
        $node->appendText($new_version);          # set new value
    }
}

# Save file (pretty print)
$doc->toFile($file, 1);

print "Updated version for targeted datasets to $new_version\n";
