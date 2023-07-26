#!/usr/bin/env perl

use strict;
use warnings;
use lib "$ENV{GUS_HOME}/lib/perl";
use Getopt::Long;
use GUS::ObjRelP::DbiDatabase;
use GUS::Supported::GusConfig;

# get parameter values
my ($variationFile, $gusConfigFile);

&GetOptions("variationFile=s" => \$variationFile,
            "gusConfig=s" => \$gusConfigFile
    );

my $gusConfig = GUS::Supported::GusConfig->new($gusConfigFile);

my $db = GUS::ObjRelP::DbiDatabase->new($gusConfig->getDbiDsn(),
                                         $gusConfig->getDatabaseLogin(),
                                         $gusConfig->getDatabasePassword(),
                                         0, 0, 1,
                                         $gusConfig->getCoreSchemaName()
    );

my $dbh = $db->getQueryHandle();

my ($outputFile);

open($outputFile, "> ./variationFeatureFinal.dat") or die "Cannot open file variationFeatureFinal for writing: $!";

open(my $data, '<', $variationFile) || die "Could not open file $variationFile: $!";
while (my $line = <$data>) {
    chomp $line;
    my ($location, $geneNaFeatureId, $sourceId, $referenceStrain, $referenceNa, $referenceAa, $hasNonsynonymousAllele, $majorAllele, $minorAllele, $majorAlleleCount, $minorAlleleCount, $majorProduct, $minorProduct, $distinctStrainCount, $distinctAlleleCount, $hasCodingMutation, $totalAlleleCount, $hasStopCodon, $refCodon, $referenceAAFull) = split(/\t/, $line);
    my $naFeatureId = &queryNaFeatureId($dbh, $geneNaFeatureId);
    my $naSequenceId = &queryNaSequenceId($dbh, $sourceId);
    print $outputFile "$location\t$naFeatureId\t$naSequenceId\t$sourceId\t$referenceStrain\t$referenceNa\t$hasNonsynonymousAllele\t$majorAllele\t$minorAllele\t$majorAlleleCount\t$minorAlleleCount\t$majorProduct\t$minorProduct\t$distinctStrainCount\t$distinctAlleleCount\t$hasCodingMutation\t$totalAlleleCount\t$hasStopCodon\t$refCodon\n";
}

close $outputFile;
close $data;

sub queryNaFeatureId {
    my ($dbh, $geneNaFeatureId) = @_;
   
    my $nafeatureid;
 
    if ($geneNaFeatureId) {
        my $sql = "select t.na_feature_id from dots.transcript t where t.source_id = '$geneNaFeatureId'";

        my $sh = $dbh->prepare($sql);
        $sh->execute();

        $nafeatureid = $sh->fetchrow_array();

        $sh->finish();
        die "Could not find na_feature_id for source_id: $geneNaFeatureId" unless($nafeatureid);
    }
    return $nafeatureid;
}


sub queryNaSequenceId {
    my ($dbh, $sourceid) = @_;

    my $sql = "select s.na_sequence_id from dots.naSequence s where s.source_id = '$sourceid'";

    my $sh = $dbh->prepare($sql);
    $sh->execute();

    my ($nasequenceid) = $sh->fetchrow_array();

    $sh->finish();
    die "Could not find na_sequence_id for source_id: $sourceid" unless($nasequenceid);

    return $nasequenceid;
}
