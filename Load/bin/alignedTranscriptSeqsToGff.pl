#!/usr/bin/perl

use strict;

use lib $ENV{GUS_HOME} . "/lib/perl";

use DBI;

use GUS::Supported::GusConfig;

use Getopt::Long;

use Data::Dumper;

use Bio::SeqFeature::Generic;
use Bio::Tools::GFF;



my ($help, $isEst, $gusConfig, $outputDirectory, $organismAbbrev, $outputFileBase, $targetExtDbRlsSpec, $queryExtDbRlsSpec);

&GetOptions('query_ext_db_rls_spec=s' => \$queryExtDbRlsSpec,
            'output_directory=s' => \$outputDirectory,
            'gus_config=s' => \$gusConfig,
            'output_file_base=s' => \$outputFileBase,
            'is_est!' => \$isEst,
            'target_ext_db_rls_spec=s' => \$targetExtDbRlsSpec,
            'help!' => \$help

    );

if($help) {
  print STDERR "alignedTranscriptSeqsToGff.pl [--query_ext_db_rls_spec NAME] [--is_est] --output_directory DIR --gus_config CONFIG --output_file_base STRING [--ncbi_tax_id INT] --target_ext_db_rls_spec STRING\n";
  exit;
} 


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


my $queryExternalDatabaseReleaseIds = &getQueryExtDbRlsIds($dbh, $isEst, $queryExtDbRlsSpec);
my $queryExtenralDatabaseString = join(",", @$queryExternalDatabaseReleaseIds);

my $targetExternalDatabaseReleaseId = &getTargetExtDbRls($dbh, $targetExtDbRlsSpec);


my %featureEnds;

my $sql = "SELECT blat.blat_alignment_id,
                  target.source_id as seq_id,
                  etn.source_id as source_id,
                  blat.score,
                  blat.is_reversed,
                  blat.target_start,
                  blat.target_end,
                  blat.percent_identity,
                  blat.tstarts,
                  blat.blocksizes
           FROM dots.BlatAlignment blat,
                dots.ExternalNASequence etn,
                dots.ExternalNASequence target
           WHERE blat.query_na_sequence_id = etn.na_sequence_id
            and blat.target_na_sequence_id = target.na_sequence_id
            AND blat.is_best_alignment = 1
            and blat.target_external_db_release_id = $targetExternalDatabaseReleaseId
            and etn.external_database_release_id in ($queryExtenralDatabaseString)
";

my $sh = $dbh->prepare($sql);
$sh->execute();

while(my ($blatId, $seqId, $id, $score, $isReversed, $start, $end, $pctIdentity, $tstarts, $blockSizes) = $sh->fetchrow_array()) {

  my $strand = $isReversed ? -1 : 1;


  # NOTE:  psl coordinates are zero based half open so we need to add one here!
  my $pslStart = $start + 1;


    my $transcript = Bio::SeqFeature::Generic->new(
        -start        => $pslStart,
        -end          => $end,
        -strand       => $strand,
        -seq_id       => $seqId,
        -primary      => 'veupathdb',
        -source_tag   => 'blat_transcript',
        -tag          => { ID => $blatId, TranscriptId => $id, PercentIdentity => $pctIdentity } );


    print GFF $transcript->gff_string($gffFormat) . "\n";

    my @tstarts = map { s/\s+//g; $_  } split /,/, $tstarts;
    my @blocksizes = map { s/\s+//g; $_ } split /,/, $blockSizes;
    my $counter = 0;
    foreach my $alignStart (@tstarts) {
        my $alignEnd = $alignStart + $blocksizes[$counter];

        # NOTE:  psl coordinates are zero based half open so we need to add one here!
        my $pslAlignStart = $alignStart + 1;


        my $alignment = Bio::SeqFeature::Generic->new(
            -start        => $pslAlignStart,
            -end          => $alignEnd,
            -strand       => $strand,
            -seq_id       => $seqId,
            -primary      => 'veupathdb',
            -source_tag   => 'blat_align',
            -tag          => { ID => $blatId . "_$counter", Parent => $blatId } );

        $counter = $counter + 1;

        print GFF $alignment->gff_string($gffFormat) . "\n";
    }
}

$sh->finish();

close GFF;

system("bgzip $filePath");
system("tabix -p gff ${filePath}.gz");

$sh->finish();
$dbh->disconnect();


sub getTargetExtDbRls {
    my ($dbh, $targetExtDbRlsSpec) = @_;

    my ($name, $version) = split(/\|/, $targetExtDbRlsSpec);

    my $query = &getOneDatasetQuery($name, $version);
    my $ids = &runExtDbRlsQuery($dbh, $query);

    if(scalar @$ids != 1) {
        die "Expected one externaldatabase release id for $name|$version";
    }

    return $ids->[0];
}

sub runExtDbRlsQuery {
    my ($dbh, $query) = @_;

    my $sh = $dbh->prepare($query);
    $sh->execute();

    my @rv;
    while(my ($id) = $sh->fetchrow_array()) {
        push @rv, $id;
    }

    $sh->finish();;

    return \@rv;
}

sub getQueryExtDbRlsIds {
    my ($dbh, $isEst, $externalDatabaseSpec) = @_;

    my ($name, $version) = split(/\|/, $targetExtDbRlsSpec);

    my $query = $isEst ? &getEstDatasetsQuery() : &getOneDatasetQuery($name, $version);

    my $ids = &runExtDbRlsQuery($dbh, $query);


    if(scalar @$ids < 1) {
        die "Expected at least one externaldatabase release id for isEST=$isEst OR dataset=$externalDatabaseSpec";
    }

    return $ids;
}


sub getOneDatasetQuery {
    my ($externalDatabaseName, $externalDatabaseVersion) = @_;

    return "select distinct r.external_database_release_id
FROM sres.externaldatabase d, sres.externaldatabaserelease r
where d.external_database_id = r.external_database_id
and d.name = '$externalDatabaseName'
and r.version like '$externalDatabaseVersion'";
}


sub getEstDatasetsQuery {

    return "SELECT DISTINCT s.external_database_release_id
FROM dots.EXTERNALNASEQUENCE s
   , sres.ONTOLOGYTERM o
WHERE s.SEQUENCE_ONTOLOGY_ID = o.ONTOLOGY_TERM_ID
AND o.name = 'EST'";
}


1;
