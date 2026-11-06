#!/usr/bin/perl

# Builds the synteny GFF for one reference organism and indexes it with tabix,
# for JBrowse 2 to serve as a track of subtrack lanes -- one lane per genome
# syntenic to the reference, plus the reference's own genes.
#
# Reads only. Every statement it issues is a SELECT (or the cursor over one), so
# it needs no write privilege of any kind, not even a temporary one.
#
# Writes <outputDir>/<organismAbbrev>.synteny.gff3.gz and its .tbi.

use strict;

use lib "$ENV{GUS_HOME}/lib/perl";

use DBI;
use Getopt::Long;
use File::Spec;
use File::Temp qw/tempfile/;

use JSON;

use GUS::Supported::GusConfig;

my ($help, $gusConfigFile, $organismAbbrev, $outputDir, $sqlFile, $verbose);
&GetOptions('help|h' => \$help,
            'gusConfigFile=s' => \$gusConfigFile,
            'organismAbbrev=s' => \$organismAbbrev,
            'outputDir=s' => \$outputDir,
            'sqlFile=s' => \$sqlFile,
            'verbose!' => \$verbose,
    );

&usage() if $help;
&usage("--organismAbbrev is required") unless $organismAbbrev;

$outputDir = '.' unless defined $outputDir;
&usage("output directory $outputDir does not exist") unless -d $outputDir;

# The built SQL, which the build copies into GUS_HOME alongside everything else.
$sqlFile = "$ENV{GUS_HOME}/lib/sql/syntenyGff.sql" unless $sqlFile;
die "cannot read sql file $sqlFile\n" unless -r $sqlFile;

for my $tool ('bgzip', 'tabix', 'sort') {
  system("command -v $tool > /dev/null 2>&1") == 0
    or die "$tool is not on PATH\n";
}

my $gusconfig = GUS::Supported::GusConfig->new($gusConfigFile);

my $dbh = DBI->connect($gusconfig->getDbiDsn(),
                       $gusconfig->getDatabaseLogin(),
                       $gusconfig->getDatabasePassword())
  or die DBI->errstr;
$dbh->{RaiseError} = 1;
$dbh->{AutoCommit} = 0;

# An unknown abbreviation would otherwise produce a valid, empty GFF, which is
# the kind of output that is noticed several steps later.
my ($sequenceCount) = $dbh->selectrow_array(
  "select count(*) from webready.genomicseqattributes_p where org_abbrev = ?",
  undef, $organismAbbrev);
die "no sequences for organismAbbrev '$organismAbbrev'\n" unless $sequenceCount;
print STDERR "$organismAbbrev: $sequenceCount sequences\n";


my $sql = do { local (@ARGV, $/) = $sqlFile; <> };
$sql =~ s/;\s*\z//;          # a cursor takes a query, not a statement

my $gz = File::Spec->catfile($outputDir, "$organismAbbrev.synteny.gff3.gz");

# Written to a temp file and moved into place, so an interrupted run leaves no
# half-written .gz for a later step to pick up as finished.
my ($fh, $tmp) = tempfile("$organismAbbrev.synteny.XXXXXX",
                          DIR => $outputDir, SUFFIX => '.gff3', UNLINK => 1);
print $fh "##gff-version 3\n";

# Through a cursor, in batches. A plain execute() would be simpler, but libpq
# materializes the whole result before handing back the first row, so a genome
# of this size would sit in client memory as several hundred megabytes of text
# on a machine that is also running the rest of the workflow. The cursor caps
# that at FETCH_SIZE rows. It needs AutoCommit off, which is set above.
use constant FETCH_SIZE => 50_000;
use constant SOURCE => 'VEuPathDB_synteny';

print STDERR "$organismAbbrev: querying\n" if $verbose;
$dbh->do("declare syntenyGffCursor no scroll cursor for $sql", undef,
         $organismAbbrev);

my $json = JSON->new();
my $features = 0;
while (1) {
  my $rows = $dbh->selectall_arrayref("fetch " . FETCH_SIZE
                                      . " from syntenyGffCursor");
  last unless @$rows;
  for my $row (@$rows) {
    my ($seqid, $type, $start, $end, $strand, $attrs) = @$row;
    print $fh join("\t", $seqid, SOURCE, $type, $start, $end,
                   '.', $strand, '.', &gffAttributes($json, $attrs)), "\n";
  }
  $features += scalar @$rows;
  print STDERR "  $features\n" if $verbose;
}
$dbh->do("close syntenyGffCursor");
close($fh);

die "no synteny features for '$organismAbbrev'\n" unless $features;
print STDERR "$organismAbbrev: $features features\n";

$dbh->disconnect();

# The SQL already orders by (seqid, start, end). Sorting again makes the file
# correct however the plan came back, which matters because tabix accepts an
# unsorted file and only misbehaves later, on query.
my $cmd = "(grep '^#' $tmp; grep -v '^#' $tmp | sort -k1,1 -k4,4n -k5,5n)"
        . " | bgzip > $gz.tmp";
system($cmd) == 0 or die "sort/bgzip failed\n";
rename("$gz.tmp", $gz) or die "cannot move $gz.tmp into place: $!\n";
system("tabix -f -p gff $gz") == 0 or die "tabix failed\n";

print STDERR "$gz\n$gz.tbi\n";

# GFF3 column 9, from the flat [key, value, ...] array the query returns.
#
# Everything the format reserves is percent-encoded: `%` first, or it would
# re-encode the escapes introduced below it; `;` and `=` which separate the
# attributes and their keys; `,` which separates values WITHIN an attribute and
# is the one that actually occurs here, in thousands of gene products such as
# "erythrocyte membrane protein 1, PfEMP1"; `&` which the spec reserves; and the
# tab and newline that separate columns and records.
#
# An attribute whose value is null is omitted rather than written as `key=`: the
# query coalesces the free-text fields to '' where an empty value is meaningful,
# so a null that reaches here means the attribute does not apply to this feature
# -- an `ID` for a part whose `na_feature_id` the database does not record, say.
sub gffAttributes {
  my ($json, $attrs) = @_;

  my @pairs = @{$json->decode($attrs)};
  my @out;
  while (@pairs) {
    my $key = shift @pairs;
    my $value = shift @pairs;
    next unless defined $value;
    $value =~ s/%/%25/g;
    $value =~ s/;/%3B/g;
    $value =~ s/=/%3D/g;
    $value =~ s/&/%26/g;
    $value =~ s/,/%2C/g;
    $value =~ s/\t/%09/g;
    $value =~ s/\n/%20/g;
    push(@out, "$key=$value");
  }
  return join(';', @out);
}

sub usage {
  my ($msg) = @_;
  print STDERR "$msg\n\n" if $msg;
  print STDERR <<"USAGE";
usage: makeSyntenyGff.pl --organismAbbrev <abbrev> [options]

  --organismAbbrev <abbrev>  the reference organism (required)
  --outputDir <dir>          where to write (default: .)
  --gusConfigFile <file>     default: \$GUS_HOME/config/gus.config
  --sqlFile <file>           default: \$GUS_HOME/lib/sql/syntenyGff.sql
  --verbose

Writes <outputDir>/<organismAbbrev>.synteny.gff3.gz and its .tbi index.
USAGE
  exit($msg ? 1 : 0);
}
