#!/usr/bin/perl

use strict;

use Getopt::Long;

use DBI;
use DBD::Oracle;
use lib "$ENV{GUS_HOME}/lib/perl";

use CBIL::Util::PropertySet;

my ($help, $fn, $gusConfig);

&GetOptions('help|h' => \$help,
            'file=s' => \$fn,
            'gus_config=s' => \$gusConfig,
            );

unless(-e $fn) {
  print STDERR "usage:  perl addProductAliasToIsolateFeature.pl --file <ACCESSINOS> [--gus_config <FILE>]\n";
  exit;
}

unless(-d $gusConfig) {
  print STDERR "gus home not found... using default\n";
  $gusConfig = $ENV{GUS_HOME} ."/config/gus.config";
}

my @properties = ();
my $gusconfig = CBIL::Util::PropertySet->new($gusConfig, \@properties, 1);

my $u = $gusconfig->{props}->{databaseLogin};
my $pw = $gusconfig->{props}->{databasePassword};
my $dsn = $gusconfig->{props}->{dbiDsn};

my $dbh = DBI->connect($dsn, $u, $pw) or die DBI::errstr;

my $accessions = &readFile($fn);

my $sql = "select e.source_id, s.na_feature_id
from dots.ISOLATESOURCE s, Dots.EXTERNALNASEQUENCE e
where e.na_sequence_id = s.na_sequence_id
";
my $sh = $dbh->prepare($sql);
$sh->execute();

my $update = "update dots.isolatesource set is_reference = ? where na_feature_id = ?";
my $updateSh = $dbh->prepare($update);

my $count;
while(my ($acc, $id) = $sh->fetchrow_array()) {
  if(&isReference($acc, $accessions)) {
    $updateSh->execute(1,$id);
    $count++;
  }
  else {
    $updateSh->execute(0, $id);
  }
}

print STDERR "Set is reference to true for $count rows in IsolateSource\n";

$updateSh->finish();
$sh->finish();

$dbh->disconnect();


sub isReference {
  my ($acc, $accessions) = @_;

  foreach(@$accessions) {
    return 1 if($_ eq $acc);
  }
  return 0;
}

sub readFile {
  my ($fn) = @_;

  my @accessions;
  open(FILE, $fn) or die "Cannot open file $fn for reading: $!";
 
  while(<FILE>) {
    chomp;

    push(@accessions, $_);
  }

  return \@accessions;
}
