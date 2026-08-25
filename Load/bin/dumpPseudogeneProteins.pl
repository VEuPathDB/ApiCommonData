#!/usr/bin/env perl

use strict;
use warnings;
use lib "$ENV{GUS_HOME}/lib/perl";

use Getopt::Long;
use DBI;
use DBD::Pg;
use GUS::Supported::GusConfig;

my ($outputFile, $organismAbbrev, $gusConfigFile, $help);

&GetOptions(
    'outputFile=s' => \$outputFile,
    'organismAbbrev=s' => \$organismAbbrev,
    'gusConfigFile=s' => \$gusConfigFile,
    'help|h' => \$help
);

if ($help) {
    &usage();
}

unless ($outputFile && $organismAbbrev) {
    print STDERR "ERROR: Missing required arguments\n\n";
    &usage();
}

# Use default gus.config if not provided
$gusConfigFile = "$ENV{GUS_HOME}/config/gus.config" unless ($gusConfigFile);

# Read GUS config file
my $gusConfig = GUS::Supported::GusConfig->new($gusConfigFile);

# Get database connection parameters
my $login = $gusConfig->getDatabaseLogin();
my $password = $gusConfig->getDatabasePassword();
my $dbiDsn = $gusConfig->getDbiDsn();

# Connect to database
my $dbh = DBI->connect($dbiDsn, $login, $password, {
    RaiseError => 1,
    AutoCommit => 0,
    PrintError => 0
}) or die "Cannot connect to database: " . DBI->errstr;

&getAndWritePseudogeneProteins($dbh, $organismAbbrev, $outputFile);

$dbh->disconnect();

exit(0);

###############################################################################
# Subroutines
###############################################################################

sub getAndWritePseudogeneProteins {
    my ($dbh, $organismAbbrev, $outputFile) = @_;

    open(my $out, '>', $outputFile) or die "Cannot open output file '$outputFile' for writing: $!\n";

    # A gene is treated as a pseudogene if its feature name is flagged
    # ('pseudogene...') or its is_pseudo column is set -- matches both
    # conventions in use across organisms in this schema. Every translated
    # protein belonging to such a gene is a pseudogene protein.
    my $sql = "SELECT taas.source_id AS protein_source_id
FROM   apidb.organism o
       JOIN dots.nasequence ns            ON ns.taxon_id       = o.taxon_id
       JOIN dots.genefeature gf           ON gf.na_sequence_id = ns.na_sequence_id
       JOIN dots.transcript t             ON t.parent_id       = gf.na_feature_id
       JOIN dots.translatedaafeature taaf ON taaf.na_feature_id = t.na_feature_id
       JOIN dots.translatedaasequence taas ON taas.aa_sequence_id = taaf.aa_sequence_id
WHERE  o.abbrev = ?
  AND  (lower(gf.name) LIKE 'pseudogene%' OR COALESCE(gf.is_pseudo, 0) = 1)";

    my $sth = $dbh->prepare($sql);
    $sth->execute($organismAbbrev);

    my $count = 0;
    while (my ($proteinSourceId) = $sth->fetchrow_array()) {
        print $out $proteinSourceId . "\n";
        $count++;
    }

    $sth->finish();

    close($out);

    print STDERR "Successfully wrote $count pseudogene protein(s) to $outputFile\n";
}

sub usage {
    print STDERR <<USAGE;

Dump the source_ids of every translated protein belonging to a pseudogene,
for a given organism, to a file (one id per line).

Usage:
  dumpPseudogeneProteins.pl --outputFile <file> --organismAbbrev <abbrev> [--gusConfigFile <file>]

Required Arguments:
  --outputFile        Output file path for pseudogene protein source_ids
  --organismAbbrev    Organism abbreviation (e.g., 'pfal3D7', 'tgonME49')

Optional Arguments:
  --gusConfigFile     Path to gus.config file (default: \$GUS_HOME/config/gus.config)
  --help              Show this help message

Examples:
  dumpPseudogeneProteins.pl --outputFile pseudogeneProteins.txt --organismAbbrev pfal3D7 --gusConfigFile /path/to/gus.config

USAGE
    exit(1);
}
