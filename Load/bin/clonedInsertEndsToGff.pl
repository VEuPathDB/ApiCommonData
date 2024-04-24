#!/usr/bin/perl

use strict;

use lib $ENV{GUS_HOME} . "/lib/perl";

use DBI;

use GUS::Supported::GusConfig;

use Getopt::Long;

use Data::Dumper;

use Bio::SeqFeature::Generic;
use Bio::Tools::GFF;

my ($help, $externalDatabaseName, $gusConfig, $outputDirectory, $sourceIdField, $sourceIdJoiningRegex, $spanLengthCutoff, $includeMultipleSpans, $organismAbbrev, $outputFileBase);

&GetOptions('external_database_name=s' => \$externalDatabaseName,
            'output_directory=s' => \$outputDirectory,
            'source_id_field=s' => \$sourceIdField,
            'source_id_joining_regex=s' => \$sourceIdJoiningRegex,
            'span_length_cutoff=i' => \$spanLengthCutoff,
            'include_multiple_spans=s' => \$includeMultipleSpans,
            'gus_config=s' => \$gusConfig,
            'output_file_base=s' => \$outputFileBase
    );


chdir $outputDirectory;

my $filePath = "${outputFileBase}.gff";

# write output sorted as needed by tabix
open(GFF, "|-", "sort -k1,1 -k4,4n >$filePath" );

my $gffFormat = Bio::Tools::GFF->new(-gff_version => 3);

my $config = GUS::Supported::GusConfig->new($gusConfig);

my $login       = $config->getDatabaseLogin();
my $password    = $config->getDatabasePassword();
my $dbiDsn      = $config->getDbiDsn();

my $dbh = DBI->connect($dbiDsn, $login, $password) or die DBI->errstr;
$dbh->{RaiseError} = 1;
$dbh->{AutoCommit} = 0;

my %featureEnds;

my $sql = "SELECT blat.blat_alignment_id feature_id,
                  etn.source_id name,
                  etn.${sourceIdField} as source_id,
                  blat.score,
                  blat.target_start startm,
                  blat.target_end end,
                  blat.percent_identity,
                  target.source_id
           FROM dots.BlatAlignment blat,
                dots.ExternalNASequence etn,
                dots.ExternalNASequence target,
                sres.EXTERNALDATABASE ed,
                sres.EXTERNALDATABASERELEASE edr
           WHERE blat.query_na_sequence_id = etn.na_sequence_id
            and blat.target_na_sequence_id = target.na_sequence_id
            AND blat.is_best_alignment = 1
            AND (blat.target_end - blat.target_start ) < $spanLengthCutoff
            AND ('true' = '$includeMultipleSpans' OR blat.number_of_spans =1)
            AND ed.external_database_id=edr.external_database_id
            AND edr.external_database_release_id = etn.external_database_release_id
            AND ed.name = '$externalDatabaseName'
";

my $sh = $dbh->prepare($sql);
$sh->execute();

while(my ($featureId, $name, $sourceId, $score, $start, $end, $percentIdentity, $sequenceSourceId) = $sh->fetchrow_array()) {

    my ($parent) = $sourceId =~ /$sourceIdJoiningRegex/;

#    print $sourceId . "\t" . $parent . "\n";

    if($featureEnds{$parent}) {
        $featureEnds{$parent}->{start} = $start if($start < $featureEnds{$parent}->{start});
        $featureEnds{$parent}->{end} = $end if($end > $featureEnds{$parent}->{end});
    }
    else {
        $featureEnds{$parent}->{start} = $start;
        $featureEnds{$parent}->{end} = $end;
        $featureEnds{$parent}->{sequence_source_id} = $sequenceSourceId;
    }

    push @{$featureEnds{$parent}->{clone_end}}, [$featureId, $name, $sourceId, $score, $start, $end, $percentIdentity];
}

$sh->finish();

foreach my $region (keys %featureEnds) {
    my $endPair = $featureEnds{$region};

    my $pair = Bio::SeqFeature::Generic->new(
        -start        => $endPair->{start},
        -end          => $endPair->{end},
        -seq_id       => $endPair->{sequence_source_id},
        -primary      => 'veupathdb',
        -source_tag   => 'read_pair',
        -tag          => { ID => $region ,
        } );

    print GFF $pair->gff_string($gffFormat) . "\n";

    foreach my $endAr (@{$endPair->{clone_end}}) {

        my $featureId = $endAr->[0];
        my $name = $endAr->[1];
        my $sourceId = $endAr->[2];
        my $score = $endAr->[3];
        my $start = $endAr->[4];
        my $end = $endAr->[5];
        my $percentIdentity = $endAr->[6];

        my $endFeature = Bio::SeqFeature::Generic->new(
            -start        => $start,
            -end          => $end,
            -seq_id       => $endPair->{sequence_source_id},
            -primary      => 'veupathdb', # -primary_tag is a synonym
            -source_tag   => 'clone_end',
            -display_name => $name,
            -score        => $score,
            -tag          => { percent_identity => $percentIdentity,
                               ID => $sourceId ,
                               Parent => $region,
            } );

        print GFF $endFeature->gff_string($gffFormat) . "\n";
    }
}

close GFF;

system("cp $filePath tmp.gff");

system("bgzip $filePath");
system("tabix -p gff ${filePath}.gz");
system("mv tmp.gff $filePath");

$sh->finish();
$dbh->disconnect();

1;
