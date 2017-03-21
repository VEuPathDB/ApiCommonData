#!/usr/bin/perl

use strict;
use Getopt::Long;

use lib $ENV{GUS_HOME} . "/lib/perl";

use ApiCommonData::Load::MetadataHelper;
#use ApiCommonData::Load::MetadataValidator;

use Data::Dumper;

# TODO:  ontologyMappingFile is a validation step in the end
my ($help, $ontologyMappingXmlFile, $type, @metadataFiles, $rowExcludeFile, $colExcludeFile, $parentMergedFile);



&GetOptions('help|h' => \$help,
	    'type=s' => \$type,
            'parentMergedFile=s' => \$parentMergedFile,
            'ontologyMappingXmlFile=s' => \$ontologyMappingXmlFile, 
            'metadataFile=s' => \@metadataFiles,
            'rowExcludeFile=s' => \$rowExcludeFile,
            'colExcludeFile=s' => \$colExcludeFile,
    );

&usage() if($help);

unless(scalar @metadataFiles > 0) {
  &usage("Must Provide at least one meta data file");
}

foreach(@metadataFiles) {
  &usage("Metadata file $_ does not exist") unless(-e $_);
}

&usage("Type cannot be null") unless(defined $type);

if($rowExcludeFile) {
  &usage("File $rowExcludeFile does not exist") unless(-e $rowExcludeFile);
}

if($colExcludeFile) {
  &usage("File $colExcludeFile does not exist") unless(-e $colExcludeFile);
}

if($parentMergedFile) {
  &usage("File $parentMergedFile does not exist") unless(-e $parentMergedFile);
}


my $metadataHelper = ApiCommonData::Load::MetadataHelper->new($type, \@metadataFiles, $rowExcludeFile, $colExcludeFile);

$metadataHelper->merge();


#my $validator = ApiCommonData::Load::MetadataValidator->new($metadataHelper, $parentMergedFile, $ontologyMappingXmlFile);

#$validator->validate();

$metadataHelper->writeMergedFile();

sub usage {
  my $msg = shift;

  print STDERR "$msg\n" if($msg);
  die "perl preprocessMetadata.pl --metadataFile fileA.csv --metadataFile fileB.csv --type Dwelling --ontologyMappingXmlFile XML --rowExcludeFile FILE --colExcludeFile FILE";
}
