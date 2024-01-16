#!/usr/bin/perl
use strict;
use File::Basename;
use Getopt::Long;

my ($dir, $help, @files);

&GetOptions(
  'help|h'   => \$help,
  'input_dir=s'        => \$dir,
);

&usage() if ($help);
&usage("input dir is required") unless (-e $dir );


my $f = `find $dir -type f -name *.biopax`;
@files = split(/\n/, $f);
my $noFiles = scalar(@files);
print STDERR "FOUND $noFiles BIOPAX FILES IN $dir\n";

foreach my $biopaxFile (@files) {
  print STDERR "\tConverting ${basename($biopaxFile)}\n";
  my $cmd = "biopaxToRdf.R $biopaxFile $dir";
  `$cmd`;
  my $status = $? >> 8;
  die "Failed with status $status running '$cmd'\n" if $status;
}

print STDERR "\n";

sub usage {
  my ($m) = @_;

  print STDERR "
Convert all biopax files in the input directory to RDF using
the biopaxToRdf.R script.
Usage: convertBiopaxFilesToRDF.pl --input_dir INPUT_DIR
";
  print STDERR "ERROR:  $m\n" if ($m);
  exit(1);
}

1;
