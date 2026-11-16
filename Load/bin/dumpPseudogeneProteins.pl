#!/usr/bin/env perl

use strict;
use warnings;
use lib "$ENV{GUS_HOME}/lib/perl";

use Getopt::Long;
use DBI;
use DBD::Pg;
use GUS::Supported::GusConfig;

my ($outputFile, $organismAbbrev, $proteinsFile, $gusConfigFile, $help);

&GetOptions(
    'outputFile=s' => \$outputFile,
    'organismAbbrev=s' => \$organismAbbrev,
    'proteinsFile=s' => \$proteinsFile,
    'gusConfigFile=s' => \$gusConfigFile,
    'help|h' => \$help
);

if ($help) {
    &usage();
}

unless ($outputFile && $organismAbbrev && $proteinsFile) {
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

&getAndWritePseudogeneProteins($dbh, $organismAbbrev, $proteinsFile, $outputFile);

$dbh->disconnect();

exit(0);

###############################################################################
# Subroutines
###############################################################################

sub getAndWritePseudogeneProteins {
    my ($dbh, $organismAbbrev, $proteinsFile, $outputFile) = @_;

    # Pseudogenes are no longer loaded into the database at all (no genefeature
    # flagged 'pseudogene', no transcript with is_pseudo set) -- so there's no
    # DB-side flag left to query for. Instead, treat any protein present in the
    # annotated-proteins fasta but absent from the organism's actual set of
    # loaded, translated proteins as a leftover pseudogene-derived sequence and
    # mark it for removal. This also catches AnnotatedProteins.fsa entries not
    # backed by any loaded gene for other reasons, not just pseudogenes.
    my %fastaProteinIds;
    open(my $fastaFh, '<', $proteinsFile) or die "Cannot open proteins fasta '$proteinsFile': $!\n";
    while (my $line = <$fastaFh>) {
        if ($line =~ /^>(\S+)/) {
            $fastaProteinIds{$1} = 1;
        }
    }
    close($fastaFh);

    my $sql = "SELECT taas.source_id AS protein_source_id
FROM   apidb.organism o
       JOIN dots.nasequence ns            ON ns.taxon_id       = o.taxon_id
       JOIN dots.genefeature gf           ON gf.na_sequence_id = ns.na_sequence_id
       JOIN dots.transcript t             ON t.parent_id       = gf.na_feature_id
       JOIN dots.translatedaafeature taaf ON taaf.na_feature_id = t.na_feature_id
       JOIN dots.translatedaasequence taas ON taas.aa_sequence_id = taaf.aa_sequence_id
WHERE  o.abbrev = ?";

    my $sth = $dbh->prepare($sql);
    $sth->execute($organismAbbrev);

    while (my ($proteinSourceId) = $sth->fetchrow_array()) {
        delete $fastaProteinIds{$proteinSourceId};
    }

    $sth->finish();

    open(my $out, '>', $outputFile) or die "Cannot open output file '$outputFile' for writing: $!\n";

    my $count = 0;
    foreach my $proteinSourceId (sort keys %fastaProteinIds) {
        print $out $proteinSourceId . "\n";
        $count++;
    }

    close($out);

    print STDERR "Successfully wrote $count protein(s) with no loaded gene to $outputFile\n";
}

sub usage {
    print STDERR <<USAGE;

Dump the source_ids of every protein present in an organism's annotated-proteins
fasta that has no corresponding loaded, translated gene in the database, to a
file (one id per line). Pseudogenes are no longer loaded into the database, so
this is now how leftover pseudogene-derived proteins (and any other proteins in
the fasta with no backing gene) are identified for removal.

Usage:
  dumpPseudogeneProteins.pl --outputFile <file> --organismAbbrev <abbrev> --proteinsFile <fasta> [--gusConfigFile <file>]

Required Arguments:
  --outputFile        Output file path for unmatched protein source_ids
  --organismAbbrev    Organism abbreviation (e.g., 'pfal3D7', 'tgonME49')
  --proteinsFile      Annotated-proteins fasta file to check against the database

Optional Arguments:
  --gusConfigFile     Path to gus.config file (default: \$GUS_HOME/config/gus.config)
  --help              Show this help message

Examples:
  dumpPseudogeneProteins.pl --outputFile pseudogeneProteins.txt --organismAbbrev pfal3D7 --proteinsFile AnnotatedProteins.fsa --gusConfigFile /path/to/gus.config

USAGE
    exit(1);
}
