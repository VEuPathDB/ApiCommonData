#!/usr/bin/env perl
use strict;
use warnings;

use lib "$ENV{GUS_HOME}/lib/perl";

use DBI;

use Getopt::Long;

use GUS::Supported::GusConfig;

use File::Basename;

use Data::Dumper;

my $EXTDB_NAME_SUFFIX = "_Mercator_synteny";

my ($pairDir, $gusConfigFile, $outputFile);
&GetOptions('pairDir=s' => \$pairDir,
            'gusConfigFile=s' => \$gusConfigFile,
            'outputFile=s' => \$outputFile
    );

open(OUT, ">$outputFile") or die "Cannot open output file $outputFile for writing: $!";


my $gusconfig = GUS::Supported::GusConfig->new($gusConfigFile);

my $dsn = $gusconfig->getDbiDsn();
my $login = $gusconfig->getDatabaseLogin();
my $password = $gusconfig->getDatabasePassword();

my $dbh = DBI->connect($dsn, $login, $password, {RaiseError => 1}) or die DBI->errstr;

my $sql = "select d.name
from sres.externaldatabase d
  inner join sres.externaldatabaserelease r
     on d.external_database_id = r.external_database_id
where d.name like '%_$EXTDB_NAME_SUFFIX'";

my $sh = $dbh->prepare($sql);
$sh->execute();

my %existingDatabaseNames;

while(my ($dbName) = $sh->fetchrow_array()) {
  $dbName =~ s/$EXTDB_NAME_SUFFIX//;
  $existingDatabaseNames{$dbName} = 1;
}
$sh->finish();
$dbh->disconnect();

########################################################################################

print Dumper \%existingDatabaseNames;

opendir(my $dh, $pairDir) or die "Could not open '$pairDir' for reading: $!\n";

while (my $d = readdir($dh)) {
  next if $d =~ /^\.{1,2}$/; # Skip '.' and '..'
  if(-d "$pairDir/$d") {
    print OUT $d . "\n" unless($existingDatabaseNames{$d});
  }
}
closedir($dh);

1;
