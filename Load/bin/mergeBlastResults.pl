#!/usr/bin/perl

use strict;
use warnings;

use lib "$ENV{GUS_HOME}/lib/perl";
use Getopt::Long qw(GetOptions);


=pod

=head1 Purpose

This script will take Blast similarity in "Brian Brunk" Format which has been split into small chunks and merge them back together.

=cut


my $inputFile;
my $outputFile;
my $verbose;

GetOptions("verbose!"           => \$verbose,
	   "inputFile=s"        => \$inputFile,
	   "outputFile=s"       => \$outputFile,
          );

&usage("Must Specify input and output files") unless ($inputFile && $outputFile);
&usage("Input file $inputFile does not exist") unless (-e $inputFile);

my $adjustedFile = &_adjustCoordinates($inputFile);


#---------------------------------------------------------------

sub _adjustCoordinates {
  my ($inputFile) = @_;

  my ($offset, $fh, $prevId);
  my %seenId;

  open (RESULTS, "< $inputFile") or die "Couldn't open $inputFile for reading: $!\n";

  while(<RESULTS>){
    chomp;

    if (/^\>(\S+)/){
      my $id = $1;
      $id =~ s/\.(\d+)//;
      $offset = $1 - 1;

      $fh = &_getFh($id, $prevId, $fh);

      print $fh "$id\n" unless($seenId{$id});
      $seenId{$id} = 1;
    }
    if (/Sum/){
      my @sim = split(':', $_);

      $sim[6] += $offset;
      $sim[7] += $offset;

      my $sum = join(':', @sim);
      print $fh "$sum\n";
    }
    if (/HSP/){
      my @hsp = split(':', $_);
      $hsp[9] += $offset;
      $hsp[10] += $offset;

      my $hsp = join(':', @hsp);
      print $fh "$hsp\n";
    }
  }
  close (RESULTS);
}


sub usage {
  my ($msg) = @_;

  print STDERR "$msg\n" if($msg);
  print STDERR "usage:  perl mergeBlastResults.pl --inputFile <FILENAME> --outputFile <FILENAME> [--verbose]\n";
  exit(0);
}

sub _getFh {
  my ($id, $prevId, $fh) = @_;

  if(!$fh) {
    open(FILE, ">> $id") || die "Cannot open $id file for writing: $!";
  }
  elsif($id eq $prevId) {
    return($fh);
  }
  else {
    close($fh);
    open(FILE, ">> $id") || die "Cannot open file $id for writing";
  }
  return(\*FILE);
}

1;
