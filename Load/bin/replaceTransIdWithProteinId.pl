#!/usr/bin/perl

# a script to replace transcript ID with protein ID for ECAssociations file

use strict;
use lib "$ENV{GUS_HOME}/lib/perl";
use Getopt::Long;

use Data::Dumper;
use FileHandle;
use HTTP::Date;

use DBI;
use DBD::Oracle;
use CBIL::Util::PropertySet;


my ($verbose, $help, $organismAbbrev, $extDbName, $extDbRlsVer, $ecFile, $extDbRlsId);

&GetOptions('verbose' => \$verbose,
            'help|h' => \$help,
	    'organismAbbrev=s' => \$organismAbbrev,
            'extDbName=s' => \$extDbName,
	    'extDbRlsVer=s' => \$extDbRlsVer,
	    'ecFile=s' => \$ecFile,
           );

&usage() if($help);

&usage("Missing Required Argument") unless (defined ($organismAbbrev && $extDbRlsVer) );

my $gusConfigFile = "$ENV{GUS_HOME}/config/gus.config";
my @properties = ();
my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);
my $u = $gusconfig->{props}->{databaseLogin}; 
my $pw = $gusconfig->{props}->{databasePassword}; 
my $dsn = $gusconfig->{props}->{dbiDsn}; 
my $dbh = DBI->connect($dsn, $u, $pw) or die DBI::errstr;
$dbh->{RaiseError} = 1;
$dbh->{LongTruncOk} = 1;

## get the extDbRlsId
if (!$extDbName && $organismAbbrev) {
  $extDbName = $organismAbbrev."_primary_genome_RSRC";
}

my $sql = <<SQL;
             select edr.external_database_release_id from sres.externaldatabase ed, sres.externaldatabaserelease edr 
where ed.external_database_id=edr.external_database_id and ed.name like '$extDbName' and edr.version='$extDbRlsVer'
SQL

my $stmt = $dbh->prepare($sql);
$stmt->execute();
($extDbRlsId) = $stmt->fetchrow_array();
print STDERR "For $organismAbbrev, get extDbRlsId=$extDbRlsId\n";
$stmt->finish();

## get the transcript id to protein id mapping file
my $cmd = "gusExtractSequences --outputFile transcToProtMapping.txt --idSQL 'select t.SOURCE_ID, ta.SOURCE_ID from dots.transcript t, DOTS.TRANSLATEDAAFEATURE ta where t.NA_FEATURE_ID=ta.NA_FEATURE_ID and ta.EXTERNAL_DATABASE_RELEASE_ID=$extDbRlsId' --noSequence";
print STDERR "run...$cmd\n";
system($cmd);
print STDERR "done\nstart replacing...\n";


## replace the id
my (%protIds);
open (IN, "transcToProtMapping.txt") || die "can not open transcToProtMapping.txt file to read\n";
while (<IN>) {
  chomp;
  next if ($_ =~ /^\s*$/);

  my @items = split (/\s/, $_);
  $items[0] =~ s/^>//g;
  $items[0] =~ s/^\s+//;
  $items[0] =~ s/\s+$//;
  $items[1] =~ s/^\s+//;
  $items[1] =~ s/\s+$//;

  $protIds{$items[0]} = $items[1];
}
close IN;


open (EC, $ecFile) || die "can not open ecFile to read\n";
while (<EC>) {
  chomp;
  next if ($_ =~ /^\s*$/);
  my @val = split (/\s/, $_);
  foreach my $i (0..$#val) {
    $val[$i] =~ s/^\s+//;
    $val[$i] =~ s/\s$//;
  }

  if ($protIds{$val[0]}) {
    $val[0] = $protIds{$val[0]};
  } else {
    print STDERR "do not find protein id for transcript: $val[0]\n";
  }

  print "$val[0]\t$val[1]\n";
}
close EC;


sub usage {
  die
"
a script to replace transcript ID with protein ID for ECAssociations file
Usage: replaceTransIdWithProteinId.pl --organismAbbrev aflaNRRL3357 --extDbRlsVer 2015-06-02 --ecFile ec.txt > ../final/ec.txt

NOTE: the GUS_HOME should point to the instance that the annotation has been loaded

where
  --organismAbbrev: the organism Abbrev in the table apidb.organism
  --extDbName: the external database name for loading genome and annoation
  --extDbRlsVer: the external database release version for loading genome and annotation
  --ecFile: the ec file that need to replace id

";
}
