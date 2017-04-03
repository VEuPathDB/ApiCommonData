#!/usr/bin/perl

use strict;
use Getopt::Long;

use lib $ENV{GUS_HOME} . "/lib/perl";

use ApiCommonData::Load::MetadataHelper;


# TODO:  ontologyMappingFile is a validation step in the end
my ($help, $ontologyMappingXmlFile, $type, @metadataFiles, $rowExcludeFile, $colExcludeFile, $parentMergedFile, $parentType, $outputFile);

&GetOptions('help|h' => \$help,
	    'type=s' => \$type,
	    'parentType=s' => \$parentType,
            'parentMergedFile=s' => \$parentMergedFile,
            'ontologyMappingXmlFile=s' => \$ontologyMappingXmlFile, 
            'metadataFile=s' => \@metadataFiles,
            'rowExcludeFile=s' => \$rowExcludeFile,
            'colExcludeFile=s' => \$colExcludeFile,
            'outputFile=s' => \$outputFile,
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


my $metadataHelper = ApiCommonData::Load::MetadataHelper->new($type, \@metadataFiles, $rowExcludeFile, $colExcludeFile, $parentMergedFile, $parentType, $ontologyMappingXmlFile);

#my $validator = ApiCommonData::Load::MetadataValidator->new($parentMergedFile, $ontologyMappingXmlFile);

$metadataHelper->merge();
if($metadataHelper->isValid()) {
  $metadataHelper->writeMergedFile($outputFile);
}
else {
  die "ERRORS Found.  Please fix and try again.";
}

# check each row that has a parent matches in parent merged file
# check for "USER ERRORS" in any value; keep record of columns and primary keys
# check that each header/qualifier is handled in the ontologymapping xml.  report new and missing
#unless($validator->isValidFile($outputFile)) {
#  open(FILE, ">$outputFile") or die "Cannot open file $outputFile for writing: $!";
#  close FILE;
#}


sub usage {
  my $msg = shift;

  print STDERR "$msg\n" if($msg);
  die "perl preprocessMetadata.pl --metadataFile fileA.csv --metadataFile fileB.csv --type Dwelling --ontologyMappingXmlFile XML --rowExcludeFile FILE --colExcludeFile FILE";
}
