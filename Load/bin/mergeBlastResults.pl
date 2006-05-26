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

      $fh = &_getFh($id, $prevId, $fh, $inputFile, \%seenId);

      print $fh ">$id\n" unless($seenId{$id});
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


sub _removeDuplicates{
  my ($file) = @_;
  my $discard;
  my %similarities;
  my $id;
  my $sum;

  open (TEMP, "< $file") or die "Couldn't open $file for reading: $!\n";

  while(my $line = <TEMP>){
    chomp $line;

    if($similarities{$line}){
      while ($line = <TEMP>){
	last if ($line =~ /Sum/);
      }
	chomp $line;
    }

    if ($line =~ /^\>(\S+)/){
      my $id = $1;
    }

    if ($line =~ /Sum/){
      my @sumLine = split(':', $line);

      if($similarities{$line}->{subjectId} == $sumLine[1] && $similarities{$line}->{queryStart} == $sumLine[6]){

	if ($sumLine[7] > $similarities{$line}->{queryEnd}){

	  delete $similarities{$line};
	  $similarities{$line} = ({'subjectId' => $sumLine[1],
				   'queryStart' => $sumLine[6],
				   'queryEnd' => $sumLine[7],
				  });

	  $discard = 0;

	}else{
	  $discard = 1;
	  next;
	}

      }elsif($similarities{$sumLine[1]}->{queryEnd} == $sumLine[7]){

	if ($sumLine[6] < $similarities{$sumLine[1]}->{queryStart}){

#	  print "Start1: $similarities{$sumLine[1]}->{queryStart}\n";
#	  print "heldSum1: $similarities{$sumLine[1]}->{sum}\n";

	  $similarities{$sumLine[1]}->{queryStart} = $sumLine[6];
	  $similarities{$sumLine[1]}->{sum} = $line;
	  $discard = 0;
#	  print "Start2: $similarities{$sumLine[1]}->{queryStart}\n";
#	  print "heldSum2: $similarities{$sumLine[1]}->{sum}\n";

	}else{
#	  print "I will be discarded\n";
	  $discard = 1;
	  next;
	}
      }else{
	$similarities{$line} = ({'subjectId' => $sumLine[1],
				 'queryStart' => $sumLine[6],
				 'queryEnd' => $sumLine[7],
				});
	$discard = 0;

      }
#print "LINE: $_\n";
    }

    if ($line =~ /HSP/ && $discard == 0){
#      print "I will be kept: $_\n";
    }

  }

  close (TEMP);
}


sub usage {
  my ($msg) = @_;

  print STDERR "$msg\n" if($msg);
  print STDERR "usage:  perl mergeBlastResults.pl --inputFile <FILENAME> --outputFile <FILENAME> [--verbose]\n";
  exit(0);
}

sub _getFh {
  my ($id, $prevId, $fh, $inputFile, $seen) = @_;

  $inputFile =~ s/\/[a-zA-Z0-9_\.]+$/\/$id/;

  print STDERR "WARNING: FILE $id already exists\n" if(!$seen->{$id} && -e $inputFile);

  if(defined($prevId) && $id eq $prevId) {
    return($fh);
  }
  else {
    close($fh) unless(!$fh);
    open(FILE, ">> $inputFile") || die "Cannot open file $id for writing";
  }
  return(\*FILE);
}


1;
