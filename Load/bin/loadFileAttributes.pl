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

my $dbh = DBI->connect($dsn, $usr, $pwd) || die "Couldn't connect to database: " . DBI->errstr;

my $sql = q{INSERT INTO apidb.fileattributes
              (file_id, filename, filepath, organism, build_num,
               category, file_type, file_format, filesize, checksum)
            VALUES (?,?,?,?,?,?,?,?,?,?)};

my $sth = $dbh->prepare($sql) || die "Couldn't prepare statement: " . $dbh->errstr;

open(my $fh, '<', $input_file) || die "Couldn't open $input_file: $!";

my $count = 0;
while (my $line = <$fh>) {
  chomp $line;
  next unless $line;
  my ($file_id, $filename, $filepath, $organism, $build_num,
      $category, $file_type, $file_format, $filesize, $checksum) = split(/\t/, $line);

  $sth->execute($file_id, $filename, $filepath, $organism, $build_num,
                $category, $file_type, $file_format, $filesize, $checksum)
    || die "Couldn't execute insert for $file_id: " . $sth->errstr;

  $count++;
  print STDERR "$count rows loaded\n" if ($count % 500 == 0);
}

close($fh);
$sth->finish;
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
