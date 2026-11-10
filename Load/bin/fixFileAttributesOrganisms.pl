#!/usr/bin/perl
use strict;
use warnings;

use Getopt::Long;
use DBI;
use CBIL::Util::PropertySet;

## One-time fix of the organism column in a dumped apidb.fileattributes tab file
## (dumpFileAttributes.pl output), before loading it with loadFileAttributes.pl.
##
## The download-file search only finds a row whose organism is the name of a current
## organism (fileQueries.xml: fa.organism = tn.name AND tn.taxon_id = o.taxon_id).
## Rows for renamed download dirs store the old dir name (e.g. Calbicans_SC5314) or an
## old species name instead, so they are never found. For each such row, in order:
##   1. map file: (old organism, dir) -> current organism name (taxonomy renames)
##   2. dir from filepath, letters/digits only, case ignored = a current
##      apidb.organism.name_for_filenames -> that organism's scientific name
##   3. otherwise the row is left as it is
## Only the organism column is ever changed.

my ($help, $gusConfigFile, $input_file, $map_file, $output_file, $changes_file);

&GetOptions('help'            => \$help,
            'gusConfigFile=s' => \$gusConfigFile,
            'input_file=s'    => \$input_file,
            'map_file=s'      => \$map_file,
            'output_file=s'   => \$output_file,
            'changes_file=s'  => \$changes_file,
    );

if ($help) {
  &usage();
}

&usage("--gusConfigFile is required!") unless ($gusConfigFile);
&usage("gus.config file not found: $gusConfigFile") unless (-e $gusConfigFile);
&usage("--input_file is required!") unless ($input_file);
&usage("input file not found: $input_file") unless (-e $input_file);
&usage("map file not found: $map_file") if ($map_file && !-e $map_file);
&usage("--output_file is required!") unless ($output_file);
&usage("--changes_file is required!") unless ($changes_file);
&usage("--output_file must differ from --input_file") if ($output_file eq $input_file);

# column order as written by dumpFileAttributes.pl and read by loadFileAttributes.pl
my $ORGANISM = 3;
my $FILEPATH = 2;
my $NCOLS    = 10;

my @properties = ();
my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);
my $dbh = DBI->connect($gusconfig->{props}->{dbiDsn},
                       $gusconfig->{props}->{databaseLogin},
                       $gusconfig->{props}->{databasePassword},
                       {AutoCommit => 0, PrintError => 0, RaiseError => 1})
  || die "Couldn't connect to database: " . DBI->errstr;
$dbh->do("SET TRANSACTION READ ONLY");

# names the search can find: any taxon name of a current organism
my %visible;
my $sth = $dbh->prepare(q{SELECT DISTINCT tn.name
                          FROM sres.taxonname tn
                          JOIN apidb.organism o ON o.taxon_id = tn.taxon_id});
$sth->execute();
while (my ($name) = $sth->fetchrow_array()) { $visible{$name} = 1; }

# normalized name_for_filenames -> scientific name; a key shared by two organisms is ambiguous
my (%byDir, %ambiguous);
$sth = $dbh->prepare(q{SELECT o.name_for_filenames, tn.name
                       FROM apidb.organism o
                       JOIN sres.taxonname tn ON tn.taxon_id = o.taxon_id
                                             AND tn.name_class = 'scientific name'});
$sth->execute();
while (my ($nff, $sci) = $sth->fetchrow_array()) {
  my $k = &norm($nff);
  if (exists $byDir{$k} && $byDir{$k} ne $sci) { $ambiguous{$k} = 1; }
  $byDir{$k} = $sci;
}
delete $byDir{$_} foreach (keys %ambiguous);

$dbh->rollback;
$dbh->disconnect;

die "No current organisms found; wrong database?\n" unless (%visible && %byDir);

# map file: old_organism <tab> dir <tab> new_organism [<tab> anything]; first line is a header
my %map;
if ($map_file) {
  open(my $mfh, '<', $map_file) || die "Couldn't open $map_file: $!";
  <$mfh>;
  while (my $line = <$mfh>) {
    chomp $line;
    next if ($line =~ /^\s*$/);
    my ($old, $dir, $new) = split(/\t/, $line);
    die "Map line $.: needs old_organism, dir and new_organism\n" unless ($old && $dir && $new);
    die "Map line $.: '$new' is not the name of a current organism\n" unless ($visible{$new});
    die "Map line $.: ($old, $dir) listed twice\n" if (exists $map{"$old\t$dir"});
    $map{"$old\t$dir"} = $new;
  }
  close($mfh);
}

my $tmp_file = "$output_file.tmp";
open(my $in,  '<', $input_file)   || die "Couldn't open $input_file: $!";
open(my $out, '>', $tmp_file)     || die "Couldn't open $tmp_file: $!";
open(my $chg, '>', $changes_file) || die "Couldn't open $changes_file: $!";
print $chg join("\t", qw(file_id build_num dir old_organism new_organism method)) . "\n";

my %count;
my %unmapped;
while (my $line = <$in>) {
  chomp $line;
  my @f = split(/\t/, $line, -1);
  &fail($out, $tmp_file, "line $. has " . scalar(@f) . " columns, expected $NCOLS") unless (@f == $NCOLS);

  my $org = $f[$ORGANISM];
  if ($visible{$org}) {
    $count{kept}++;
  }
  else {
    my ($dir) = $f[$FILEPATH] =~ m{^/common/downloads/release-[^/]+/([^/]+)/};
    &fail($out, $tmp_file, "line $.: can't find the dir in $f[$FILEPATH]") unless (defined $dir);

    my ($new, $method);
    if (my $m = $map{"$org\t$dir"}) {
      ($new, $method) = ($m, 'map_file');
    }
    elsif (my $s = $byDir{&norm($dir)}) {
      ($new, $method) = ($s, 'dir_name');
    }

    if ($new) {
      print $chg join("\t", $f[0], $f[4], $dir, $org, $new, $method) . "\n";
      $f[$ORGANISM] = $new;
      $count{$method}++;
    }
    else {
      $count{unmapped}++;
      $unmapped{"$org\t$dir"}++;
    }
  }
  print $out join("\t", @f) . "\n";
}
close($in);
close($out) || die "Couldn't close $tmp_file: $!";
close($chg) || die "Couldn't close $changes_file: $!";

rename($tmp_file, $output_file) || die "Couldn't rename $tmp_file to $output_file: $!";

my $total = 0;
$total += $_ foreach (values %count);
print STDERR "Done. $total rows written to $output_file.\n";
printf STDERR "  %-10s %8d\n", $_, ($count{$_} || 0) foreach (qw(kept map_file dir_name unmapped));
print STDERR "  ambiguous name_for_filenames keys skipped: " . scalar(keys %ambiguous) . "\n";
print STDERR "  unmapped (organism, dir) pairs: " . scalar(keys %unmapped) . "\n";
print STDERR "Changes listed in $changes_file.\n";


sub norm {
  my $s = lc(shift);
  $s =~ s/[^a-z0-9]//g;
  return $s;
}

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
  print STDERR "usage:\nperl fixFileAttributesOrganisms.pl --gusConfigFile <GUS_CONFIG> --input_file <TAB_FILE> [--map_file <MAP_TSV>] --output_file <FIXED_TAB_FILE> --changes_file <CHANGES_TSV>\n";
  # non-zero on an error so a caller sees the failure; --help is not one
  exit($m ? 1 : 0);
}
