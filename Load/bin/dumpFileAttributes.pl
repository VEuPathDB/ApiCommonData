#!/usr/bin/perl
use strict;
use warnings;

use Getopt::Long;
use DBI;
use CBIL::Util::PropertySet;

## script to dump apidb.fileattributes (all releases) into a tab-delimited file
## in the format loadFileAttributes.pl reads, so a rebuild can carry the history forward

my ($help, $gusConfigFile, $output_file);

&GetOptions('help'            => \$help,
            'gusConfigFile=s' => \$gusConfigFile,
            'output_file=s'   => \$output_file,
    );

if ($help) {
  &usage();
}

&usage("--gusConfigFile is required!") unless ($gusConfigFile);
&usage("gus.config file not found: $gusConfigFile") unless (-e $gusConfigFile);
&usage("--output_file is required!") unless ($output_file);

my @properties = ();
my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);

my $usr = $gusconfig->{props}->{databaseLogin};
my $pwd = $gusconfig->{props}->{databasePassword};
my $dsn = $gusconfig->{props}->{dbiDsn};

my $dbh = DBI->connect($dsn, $usr, $pwd, {AutoCommit => 0, PrintError => 0, RaiseError => 1})
  || die "Couldn't connect to database: " . DBI->errstr;

# one read-only transaction: a consistent snapshot, and no way to write
$dbh->do("SET TRANSACTION READ ONLY");

# column order is the order loadFileAttributes.pl splits each line into
my @columns = qw(file_id filename filepath organism build_num
                 category file_type file_format filesize checksum);

my $sth = $dbh->prepare("SELECT " . join(", ", @columns)
                        . " FROM apidb.fileattributes ORDER BY build_num, file_id");
$sth->execute();

# write to a temp file and rename at the end, so a failed dump never leaves a partial file
my $tmp_file = "$output_file.tmp";
open(my $fh, '>', $tmp_file) || die "Couldn't open $tmp_file: $!";

my $count = 0;
while (my $row = $sth->fetchrow_arrayref) {
  for my $i (0 .. $#columns) {
    my $v = $row->[$i];
    # a NULL, tab or newline would not survive the round trip through the loader
    &fail($fh, $tmp_file, "NULL $columns[$i] in file_id $row->[0]") unless (defined $v);
    &fail($fh, $tmp_file, "tab or newline in $columns[$i] of file_id $row->[0]") if ($v =~ /[\t\n\r]/);
  }
  print $fh join("\t", @$row) . "\n";
  $count++;
}

close($fh) || die "Couldn't close $tmp_file: $!";
$dbh->rollback;
$dbh->disconnect;

rename($tmp_file, $output_file) || die "Couldn't rename $tmp_file to $output_file: $!";

print STDERR "Done. $count rows from apidb.fileattributes written to $output_file.\n";


sub fail {
  my ($fh, $tmp_file, $m) = @_;
  close($fh);
  unlink($tmp_file);
  die "FAILED: $m; no output written.\n";
}

sub usage {
  my $m = shift;
  if ($m) {
    print STDERR "$m\n\n";
  }
  print STDERR "usage:\nperl dumpFileAttributes.pl --gusConfigFile <GUS_CONFIG> --output_file <TAB_FILE>\n";
  # non-zero on an error so a caller sees the failure; --help is not one
  exit($m ? 1 : 0);
}
