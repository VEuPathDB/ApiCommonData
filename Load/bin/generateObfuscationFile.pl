#!/usr/bin/perl

use strict;

use warnings;

use Data::Dumper;

use Getopt::Long;

use File::Temp qw/tempfile/;

use File::Copy qw/move/;

my ($dataDirectory, $adjustmentsFile, $help,);
my $obfuscationFactor = 7;

&GetOptions('help|h' => \$help,
            'adjustments_file=s' => \$adjustmentsFile,
            'data_directory=s' => \$dataDirectory,
           );


#&usage() if($help);

die "adjustments_file and data_directory are required attributes" unless (defined $adjustmentsFile && defined $dataDirectory);
sub generateAdjustmentFactor {
  my ($obfuscationFactor) = @_;
  my $direction = int (rand(2)) ? 1 : -1;
  my $magnitude = 1 + int(rand($obfuscationFactor));
  return $direction * $magnitude;
}

my $adjustmentFactorHash = {};
if (-e $adjustmentsFile) {
  open(ADJ, "<$adjustmentsFile") or die "unable to open file $adjustmentsFile:$!";
  foreach my $line (<ADJ>) {
    next unless $line =~ m/\w/;
    $line =~ s/\n|\r//g;
    my ($id,$value) = split(/\t/,$line);
    $adjustmentFactorHash->{$id} = $value;
  }
  close ADJ;
  print STDERR scalar(keys %{$adjustmentFactorHash})." Before\n";
}

die "$dataDirectory is not a valid directory. A valid directory is required" unless(-d $dataDirectory);

opendir(DATADIR, $dataDirectory) or die "unable to open directory $dataDirectory: $!";

while (my $file = readdir(DATADIR)) {
  my $file = "$dataDirectory/$file";
  $file =~s/\/+/\//g;
  next unless (-e $file);
  open (DATA, "<$file") or die "unable to open file $file in data directory $dataDirectory: $!";
  #Discard header line
  <DATA>;
  foreach my $line (<DATA>) {
    next unless $line =~ m/\w/;
    $line =~ s/\n|\r//g;
    my ($id) = split(/\t/,$line);
    unless (defined $adjustmentFactorHash->{$id}) {
      $adjustmentFactorHash->{$id} = &generateAdjustmentFactor($obfuscationFactor);
    }
  }
}

my @outputLines;

foreach my $key (sort keys(%$adjustmentFactorHash)) {
  my $outLine = "$key\t".$adjustmentFactorHash->{$key};
  push (@outputLines, $outLine);
}

open(ADJ, ">$adjustmentsFile") or die "unable to open file $adjustmentsFile for writing : $!";

print ADJ join("\n", @outputLines);



1;


