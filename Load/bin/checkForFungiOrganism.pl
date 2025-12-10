#!/usr/bin/perl

use warnings;
use strict;
use Data::Dumper;
use lib "$ENV{GUS_HOME}/lib/perl";
use CBIL::Util::PropertySet;
use DBI;

my $projectName = $ARGV[0];
my $taxonId = $ARGV[1];
my $skipIfFile = $ARGV[2];
my $gusConfigFile = $ARGV[3];

my $dbh = &getDbHandle($gusConfigFile);

if ($projectName ne 'FungiDB') {
    system('touch $skipIffile');
}
else {

    my $foundTaxId = &checkParent($taxonId,$dbh);

    if ($foundTaxID ne $taxonId) {
        system('touch $skipIffile');
    }
}

sub checkParent {
    my ($taxonId,$dbh) = @_;
    
    my $query = $dbh->prepare(&checkParentSql($taxonId));

    $query->execute();
    my $taxId = $query->fetchrow_array();

    $query->finish();
    return $taxId;
}

sub checkParentSql {
    my ($taxonId) = @_;
    return "WITH RECURSIVE taxon_tree AS (
    -- Start from the kingdom node (ncbi_tax_id = 4751)
    SELECT
        t.taxon_id,
        t.ncbi_tax_id,
        t.parent_id,
        t.rank
    FROM
        sres.taxon t
    WHERE
        t.ncbi_tax_id = 4751

    UNION ALL

    -- Recursively include all descendants
    SELECT
        c.taxon_id,
        c.ncbi_tax_id,
        c.parent_id,
        c.rank
    FROM
        sres.taxon c
        JOIN taxon_tree p ON c.parent_id = p.taxon_id
)
-- Filter for terminal nodes of interest
SELECT
    ncbi_tax_id
FROM
    taxon_tree
WHERE
    rank IN ('species', 'no rank')
    AND ncbi_tax_id = $taxonId
ORDER BY
    ncbi_tax_id";
}

