#!/usr/bin/perl

use strict;

use Getopt::Long;

my ($help, $dir, $delimiter);

&GetOptions('help|h' => \$help,
            'gpr_directory=s' => \$dir,
            'delimiter=s' => \$delimiter,
           );

$dir = "." unless($dir);
$delimiter = "." unless($delimiter);

if($help) {
  print STDERR "preprocessGprDirectory.pl [--gpr_directory <DIR>] [--delimter \".\"]\n";
  exit;
}

opendir(DIR, $dir) or die "Cannot open directory $dir for reading: $!";

while(my $fn = readdir(DIR)) {
  next unless($fn =~ /\.gpr$/);

  my $start = 0;
  my $isHeader = 0;

  my $out = $fn;
  $out =~ s/\.gpr/.txt/;

  open(GPR, $fn) or die "Cannot open file $fn for reading: $!";
  open(OUT, ">$out") or die "Cannot open file $out for writing: $!";

  while(<GPR>) {
    chomp;

    if(/Block/) {
      $start = 1;
      $isHeader = 1;
      print OUT "U_ID\t$_\n";
    }

    next unless($start);

    my @a = split(/\t/, $_);

    # UID is Block ROw column
    my $uid = $a[0] . $delimiter . $a[2].  $delimiter . $a[1];

    print OUT "$uid\t$_\n" unless($isHeader);

    $isHeader = 0;
  }

  close GPR;
  close OUT;
}

close DIR;

