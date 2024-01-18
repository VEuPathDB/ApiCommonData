#!/usr/bin/perl
use strict;

use Digest::MD5;
use Getopt::Long;
use RDF::Trine;
use File::Basename qw/basename dirname/;


my ($help, $owlFile);

&GetOptions(
  'help|h'    => \$help,
  'owlFile=s'=> \$owlFile,
);

&usage() if ($help);
&usage("owl file is required") unless (-e $owlFile );


my $dbFile = "$owlFile.sqlite";
my $md5File = "$owlFile.md5";

my $name = basename ($dbFile);

my $model = RDF::Trine::Model->new(
  RDF::Trine::Store::DBI->new(
    $name,
    "dbi:SQLite:dbname=$dbFile",
    '',  # no username
    '',  # no password
  ),
);

my $parser = RDF::Trine::Parser->new('rdfxml');
$parser->parse_file_into_model(undef, $owlFile, $model);

print STDERR $model->size . " RDF statements parsed\n";

my $ctx = Digest::MD5->new;
open(my $fh, $owlFile);
$ctx->addfile($fh);
my $md5 = $ctx->hexdigest();
close($fh);
open(FH, ">$md5File") or die "Cannot write $md5File:$!\n";
print FH "$md5\n";
close(FH);

sub usage {
  my ($m) = @_;

  print STDERR "
Parse an Owl file into a sqlite RDF store in the same directory.
Usage: parseOwlFileToDBFile.pl --owlFile OWL_FILE
";
  print STDERR "ERROR:  $m\n" if ($m);
  exit(1);
}

1;
