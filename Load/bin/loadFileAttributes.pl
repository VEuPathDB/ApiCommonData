#!/usr/bin/perl
use strict;
use warnings;

use Getopt::Long;
use DBI;
use CBIL::Util::PropertySet;

## script to load data from a tab-limited file into apidb.fileattributes

my ($help, $gusConfigFile, $input_file);

&GetOptions('help'          => \$help,
            'gusConfigFile=s' => \$gusConfigFile,
            'input_file=s'    => \$input_file,
    );

if ($help) {
  &usage();
  exit;
}

unless ($gusConfigFile) {
  &usage("--gusConfigFile is required!");
  exit;
}

unless (-e $gusConfigFile) {
  &usage("gus.config file not found: $gusConfigFile");
  exit;
}

unless ($input_file) {
  &usage("--input_file is required!");
  exit;
}

unless (-e $input_file) {
  &usage("Input file not found: $input_file");
  exit;
}

my @properties = ();
my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);

my $usr = $gusconfig->{props}->{databaseLogin};
my $pwd = $gusconfig->{props}->{databasePassword};
my $dsn = $gusconfig->{props}->{dbiDsn};

# the whole file is one transaction: it commits only if every row went in
my $dbh = DBI->connect($dsn, $usr, $pwd, {AutoCommit => 0, PrintError => 0, RaiseError => 0})
  || die "Couldn't connect to database: " . DBI->errstr;

my $sql = q{INSERT INTO apidb.fileattributes
              (file_id, filename, filepath, organism, build_num,
               category, file_type, file_format, filesize, checksum)
            VALUES (?,?,?,?,?,?,?,?,?,?)};

my $sth = $dbh->prepare($sql) || die "Couldn't prepare statement: " . $dbh->errstr;

open(my $fh, '<', $input_file) || die "Couldn't open $input_file: $!";

my $count = 0;
my $skipped = 0;
while (my $line = <$fh>) {
  chomp $line;
  next unless $line;
  my ($file_id, $filename, $filepath, $organism, $build_num,
      $category, $file_type, $file_format, $filesize, $checksum) = split(/\t/, $line);

  # carry on past a rejected row so one run reports every bad row; the
  # savepoint keeps the transaction usable after the failed insert
  $dbh->do("SAVEPOINT row_insert") || die "Couldn't set savepoint: " . $dbh->errstr;
  unless ($sth->execute($file_id, $filename, $filepath, $organism, $build_num,
                        $category, $file_type, $file_format, $filesize, $checksum)) {
    print STDERR "SKIPPED $file_id (line $.): " . $sth->errstr . "\n";
    $dbh->do("ROLLBACK TO SAVEPOINT row_insert") || die "Couldn't roll back to savepoint: " . $dbh->errstr;
    $skipped++;
    next;
  }
  $dbh->do("RELEASE SAVEPOINT row_insert") || die "Couldn't release savepoint: " . $dbh->errstr;

  $count++;
  print STDERR "$count rows loaded\n" if ($count % 500 == 0);
}

close($fh);
$sth->finish;

# all or nothing, so a failed load leaves no partial release behind
if ($skipped) {
  $dbh->rollback;
  $dbh->disconnect;
  print STDERR "FAILED. $skipped row(s) SKIPPED; rolled back, nothing loaded into apidb.fileattributes.\n";
  exit 1;
}

$dbh->commit || die "Couldn't commit: " . $dbh->errstr;
$dbh->disconnect;

print STDERR "Done. $count rows inserted into apidb.fileattributes.\n";


sub usage {
  my $m = shift;
  if ($m) {
    print STDERR "$m\n\n";
  }
  print STDERR "usage:\nperl loadFileAttributes.pl --gusConfigFile <GUS_CONFIG> --input_file <TAB_FILE>\n";
  exit;
}
