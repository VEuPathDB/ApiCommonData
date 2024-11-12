#!/usr/bin/perl

use strict;

use lib $ENV{GUS_HOME} . "/lib/perl";

use DBI;

use GUS::Supported::GusConfig;

use Getopt::Long;

use Data::Dumper;

use Bio::SeqFeature::Generic;
use Bio::Tools::GFF;

my ($help, $isEst, $ncbiTaxId, $queryExternalDatabaseName, $gusConfig, $outputDirectory, $sourceIdField, $organismAbbrev, $outputFileBase, $targetExtDbRlsSpec);

&GetOptions('query_external_database_name=s' => \$queryExternalDatabaseName,
            'output_directory=s' => \$outputDirectory,
            'source_id_field=s' => \$sourceIdField,
            'gus_config=s' => \$gusConfig,
            'output_file_base=s' => \$outputFileBase,
            'is_est' => \$isEst,
            'ncbi_tax_id=i' => \$ncbiTaxId,
            'target_ext_db_rls_spec=s' => \$targetExtDbRlsSpec
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


my $queryExternalDatabaseReleaseIds = &getQueryExtDbRlsIds($dbh, $isEst, $ncbiTaxId, $queryExternalDatabaseName);
my $queryExtenralDatabaseString = join(",", @$queryExternalDatabaseReleaseIds);

my $targetExternalDatabaseReleaseId = &getTargetExtDbRls($dbh, $targetExtDbRlsSpec);


my %featureEnds;

my $sql = "SELECT blat.blat_alignment_id,
                  target.source_id as seq_id
                  etn.source_id as source_id,
                  blat.score,
                  blat.target_start start,
                  blat.target_end end,
                  blat.percent_identity,
                  blat.tstarts,
                  blat.blocksizes
           FROM dots.BlatAlignment blat,
                dots.ExternalNASequence etn,
                dots.ExternalNASequence target,
           WHERE blat.query_na_sequence_id = etn.na_sequence_id
            and blat.target_na_sequence_id = target.na_sequence_id
            and blat._na_sequence_id = target.na_sequence_id
            AND blat.is_best_alignment = 1
            and blat.target_external_db_release_id = $targetExternalDatabaseReleaseId
            and etn.external_database_release_id in ($queryExtenralDatabaseString)
";

my $sh = $dbh->prepare($sql);
$sh->execute();

while(my ($blatId, $seqId, $id, $score, $start, $end, $pctIdentity, $tstarts, $blockSizes) = $sh->fetchrow_array()) {

    my $transcript = Bio::SeqFeature::Generic->new(
        -start        => $start
        -end          => $end
        -seq_id       => $seqId
        -primary      => 'veupathdb',
        -source_tag   => 'blat_transcript',
        -tag          => { ID => $blatId, TranscriptId => $id, PercentIdentity => $pctIdentity } );

    print GFF $transcript->gff_string($gffFormat) . "\n";

    my @tstarts = map { s/\s+//g; $_ - 1 } split /,/, $tstarts;
    my @blocksizes = map { s/\s+//g; $_ } split /,/, $blockSizes;
    my $counter = 0;
    foreach my $alignStart (@tstarts) {
        my $alignEnd = $start + $blocksizes[$counter];


        my $alignment = Bio::SeqFeature::Generic->new(
            -start        => $alignStart
            -end          => $alignEnd
            -seq_id       => $seqId
            -primary      => 'veupathdb',
            -source_tag   => 'blat_align',
            -tag          => { ID => $blatId . "_$counter", Parent => $blatId } );

        $counter = $counter + 1;

        print GFF $alignment->gff_string($gffFormat) . "\n";
    }
}

$sh->finish();

close GFF;

system("cp $filePath tmp.gff");

system("bgzip $filePath");
system("tabix -p gff ${filePath}.gz");
system("mv tmp.gff $filePath");

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
    my ($dbh, $isEst, $ncbiTaxId, $externalDatabaseName) = @_;

    my $query = $isEst ? &getEstDatasetsQuery($ncbiTaxId) : &getOneDatasetQuery($externalDatabaseName, undef);

    my $ids = &runExtDbRlsQuery($dbh, $query);


    if(scalar @$ids < 1) {
        die "Expected at least one externaldatabase release id for ncbitaxid=$ncbiTaxId OR dataset=$externalDatabaseName";
    }

    return $ids;
}


sub getOneDatasetQuery {
    my ($externalDatabaseName, $externalDatabaseVersion) = @_;

    $externalDatabaseVersion = '%' unless($externalDatabaseVersion);


    return "select distinct r.external_database_release_id
FROM sres.externaldatabase d, sres.externaldatabaserelease r
where d.external_database_id = r.external_database_id
and d.name = '$externalDatabaseName'
and r.version like '$externalDatabaseVersion'";
}


sub getEstDatasetsQuery {
    my ($ncbiTaxId) = @_;

    return "SELECT DISTINCT s.external_database_release_id
FROM dots.EXTERNALNASEQUENCE s
   , sres.ONTOLOGYTERM o
   , sres.taxon t
WHERE s.SEQUENCE_ONTOLOGY_ID = o.ONTOLOGY_TERM_ID
AND s.TAXON_ID = t.TAXON_ID
AND t.NCBI_TAX_ID = $ncbiTaxId
AND o.name = 'EST';"
}


1;
