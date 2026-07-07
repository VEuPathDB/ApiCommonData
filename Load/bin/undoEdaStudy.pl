#!/usr/bin/perl

use strict;
use warnings;
use lib "$ENV{GUS_HOME}/lib/perl";

use Getopt::Long;
use GUS::Supported::GusConfig;
use ApiCommonData::Load::InstallEdaStudyFromArtifacts;

my (@extDbRlsSpec, $gusConfigFile, $help);

&GetOptions(
    "extDbRlsSpec=s" => \@extDbRlsSpec,
    "gusConfigFile=s" => \$gusConfigFile,
    "help|h"         => \$help,
);

&usage() if $help || scalar @extDbRlsSpec == 0 || !$gusConfigFile;

die "gus.config file '$gusConfigFile' does not exist\n" unless -e $gusConfigFile;

my $gusconfig = GUS::Supported::GusConfig->new($gusConfigFile);

my ($host, $port, $dbname);
my $dsn = $gusconfig->getDbiDsn();
my ($dbi, $platform, $dbnameFull) = split(':', $dsn);

foreach my $pair (split(";", $dbnameFull)) {
    my ($key, $value) = split("=", $pair);
    if (lc $key eq 'port')   { $port   = $value }
    if (lc $key eq 'host')   { $host   = $value }
    if (lc $key eq 'dbname') { $dbname = $value }
}
$port //= 5432;

my $login    = $gusconfig->getDatabaseLogin();
my $password = $gusconfig->getDatabasePassword();

my $installer = ApiCommonData::Load::InstallEdaStudyFromArtifacts->new({
    DB_HOST     => $host,
    DB_PORT     => $port,
    DB_NAME     => $dbname,
    DB_PLATFORM => 'Postgres',
    DB_USER     => $login,
    DB_PASS     => $password,
    DB_SCHEMA   => 'EDA',
    DATA_FILES  => 'NA',
    INPUT_DIR   => 'NA',
    EXTERNAL_DATABASE_RLS_SPECS => \@extDbRlsSpec,
});

$installer->uninstallDataFromExternalDatabase();


sub usage {
    print STDERR "Usage: undoEdaStudy.pl --extDbRlsSpec <name|version> [--extDbRlsSpec <name|version> ...] --gusConfigFile <path>\n";
    print STDERR "\n";
    print STDERR "  --extDbRlsSpec   External database release spec (format: 'DbName|Version'). May be specified multiple times.\n";
    print STDERR "  --gusConfigFile  Path to gus.config (required)\n";
    exit 1;
}
