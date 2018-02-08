#!/usr/bin/perl

use strict;
use Getopt::Long;

use lib $ENV{GUS_HOME} . "/lib/perl";

use ApiCommonData::Load::MetadataHelper;

use CBIL::Util::PropertySet;

# TODO:  ontologyMappingFile is a validation step in the end
my ($help, $ontologyMappingXmlFile, $type, @metadataFiles, $rowExcludeFile, $colExcludeFile, $parentMergedFile, $parentType, $outputFile, $ancillaryInputFile, $packageName, $propFile, $valueMappingFile, $ontologyOwlFile, $dateObfuscationFile);

my $ONTOLOGY_MAPPING_XML_FILE = "ontologyMappingXmlFile";
my $TYPE = "type";
my $PARENT_TYPE = "parentType";
my $PARENT_MERGED_FILE = "parentMergedFile";
my $METADATA_FILE = "metadataFile";
my $ROW_EXCLUDE_FILE = "rowExcludeFile";
my $COL_EXCLUDE_FILE = "colExcludeFile";
my $OUTPUT_FILE = "outputFile";
my $ANCILLARY_INPUT_FILE = "ancillaryInputFile";
my $PACKAGE_NAME = "packageName";

my $VALUE_MAPPING_FILE = "valueMappingFile";
my $ONTOLOGY_OWL_FILE = "ontologyOwlFile";
my $DATE_OBFUSCATION_FILE = "dateObfuscationFile";

&GetOptions('help|h' => \$help,
            'propFile=s' => \$propFile,
	    "$TYPE=s" => \$type,
	    "$PARENT_TYPE=s" => \$parentType,
            "$PARENT_MERGED_FILE=s" => \$parentMergedFile,
            "$ONTOLOGY_MAPPING_XML_FILE=s" => \$ontologyMappingXmlFile, 
            "$METADATA_FILE=s" => \@metadataFiles,
            "$ROW_EXCLUDE_FILE=s" => \$rowExcludeFile,
            "$COL_EXCLUDE_FILE=s" => \$colExcludeFile,
            "$OUTPUT_FILE=s" => \$outputFile,
            "$ANCILLARY_INPUT_FILE=s" => \$ancillaryInputFile,
            "$PACKAGE_NAME=s" => \$packageName,
            "$VALUE_MAPPING_FILE=s" => \$valueMappingFile,
            "$ONTOLOGY_OWL_FILE=s" => \$ontologyOwlFile,
            "$DATE_OBFUSCATION_FILE=s" => \$dateObfuscationFile,
    );



if(-e $propFile) {
  my @properties;
  my $properties = CBIL::Util::PropertySet->new($propFile, \@properties, 1);

  $type ||= $properties->{props}->{$TYPE};
  $parentType ||= $properties->{props}->{$PARENT_TYPE};
  $parentMergedFile ||= $properties->{props}->{$PARENT_MERGED_FILE};

  $rowExcludeFile ||= $properties->{props}->{$ROW_EXCLUDE_FILE};
  $colExcludeFile ||= $properties->{props}->{$COL_EXCLUDE_FILE};
  $outputFile ||= $properties->{props}->{$OUTPUT_FILE};
  $ancillaryInputFile ||= $properties->{props}->{$ANCILLARY_INPUT_FILE};
  $packageName ||= $properties->{props}->{$PACKAGE_NAME};

  $ontologyMappingXmlFile ||= $properties->{props}->{$ONTOLOGY_MAPPING_XML_FILE};

  $ontologyOwlFile ||= $properties->{props}->{$ONTOLOGY_OWL_FILE};
  $valueMappingFile ||= $properties->{props}->{$VALUE_MAPPING_FILE};
  $dateObfuscationFile ||= $properties->{props}->{$DATE_OBFUSCATION_FILE};

  unless(scalar @metadataFiles > 0) {
    my $metadataFileString = $properties->{props}->{$METADATA_FILE};
    @metadataFiles = split(/\s*,\s*/, $metadataFileString);
  }
}

&usage() if($help);

unless(scalar @metadataFiles > 0) {
  &usage("Must Provide at least one meta data file");
}

foreach(@metadataFiles) {
  &usage("Metadata file $_ does not exist") unless(-e $_);
}

unless($outputFile) {
  &usage("outputFile not specified");
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




unless($packageName) {
  $packageName = "ApiCommonData::Load::MetadataReader";
}

my $metadataHelper = ApiCommonData::Load::MetadataHelper->new($type, \@metadataFiles, $rowExcludeFile, $colExcludeFile, $parentMergedFile, $parentType, $ontologyMappingXmlFile, $ancillaryInputFile, $packageName);

#my $validator = ApiCommonData::Load::MetadataValidator->new($parentMergedFile, $ontologyMappingXmlFile);

$metadataHelper->merge();
if($metadataHelper->isValid()) {
  $metadataHelper->writeMergedFile($outputFile);
}
else {
  die "ERRORS Found.  Please fix and try again.";
}

if(-e $ontologyMappingXmlFile && -e $valueMappingFile && -e $ontologyOwlFile) {
  $metadataHelper->writeInvestigationTree($ontologyMappingXmlFile, $valueMappingFile, $dateObfuscationFile, $ontologyOwlFile, $outputFile);
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

#TODO:  fix error message here
  die "perl preprocessMetadata.pl --metadataFile fileA.csv --metadataFile fileB.csv --type Dwelling --ontologyMappingXmlFile XML --rowExcludeFile FILE --colExcludeFile FILE";
}
