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

# Get the NCBI taxon ID for the organism
my $taxonId = &getTaxonId($dbh, $organismAbbrev);
unless ($taxonId) {
    die "ERROR: Could not find taxon ID for organism abbreviation: $organismAbbrev\n";
}

print STDERR "Found organism '$organismAbbrev' with taxon ID: $taxonId\n";

# Get pseudogenes from the tuning tableg

&getAndWritePseudogenes($dbh, $taxonId, $outputFile);


$dbh->disconnect();

exit(0);

###############################################################################
# Subroutines
###############################################################################

sub getTaxonId {
    my ($dbh, $abbrev) = @_;

    my $sql = "SELECT o.taxon_id
               FROM apidb.organism o 
               WHERE o.abbrev = ?";

    my $sth = $dbh->prepare($sql);
    $sth->execute($abbrev);

    my ($ncbiTaxonId) = $sth->fetchrow_array();
    $sth->finish();

    return $ncbiTaxonId;
}

sub getAndWritePseudogenes {
    my ($dbh, $taxonId, $outputFile) = @_;

    # Write results to output file
    open(my $out, '>', $outputFile) or die "Cannot open output file '$outputFile' for writing: $!\n";

    
    my @results;

    my $soTerm = "pseudogene";
    
    # Query to get pseudogenes from the gene attributes tuning table
    my $sql = "select gf.source_id
from dots.genefeature gf
inner join dots.nasequence s on gf.na_sequence_id = s.na_sequence_id
inner join sres.ontologyterm ot on gf.sequence_ontology_id = ot.ontology_term_id
where s.taxon_id = ?
and ot.name = ?";


    my $sth = $dbh->prepare($sql);
    $sth->execute($taxonId, $soTerm);

    my $count;
    while (my ($pseudogene)= $sth->fetchrow_array()) {
      print $out $pseudogene . "\n";
      $count++;
    }

    $sth->finish();

    close($out);

    print STDERR "Successfully wrote $count pseudogenes to $outputFile\n";
}

sub usage {
    print STDERR <<USAGE;

Dump pseudogenes for a given organism to a tab-delimited file.

Usage:
  dumpPseudogenes.pl --outputFile <file> --organismAbbrev <abbrev> [--gusConfigFile <file>]

Required Arguments:
  --outputFile        Output file path for pseudogene data (tab-delimited)
  --organismAbbrev    Organism abbreviation (e.g., 'pfal3D7', 'tgonME49')

Optional Arguments:
  --gusConfigFile     Path to gus.config file (default: \$GUS_HOME/config/gus.config)
  --help              Show this help message

Output Format:
  Tab-delimited file with columns:
    source_id

Examples:
  dumpPseudogenes.pl --outputFile output.txt --organismAbbrev tgonME49 --gusConfigFile /path/to/gus.config

USAGE
    exit(1);
}
