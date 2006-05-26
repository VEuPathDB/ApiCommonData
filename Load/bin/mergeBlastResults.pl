#!/usr/bin/perl

use strict;
use warnings;

use lib "$ENV{GUS_HOME}/lib/perl";
use Getopt::Long qw(GetOptions);
use File::Basename;

use Data::Dumper;

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

#&_adjustCoordinates($inputFile);
#my $dirname = File::Basename::dirname($inputFile);


my $similarities = &_parseFile($inputFile);
&_removeDuplicates($similarities);

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

sub _parseFile {
  (my $file) = @_;

  my %seen;
  my $similarities = {};
  my ($id, $subjectId);

  open (TEMP, "< $file") or die "Couldn't open $file for reading: $!\n";

  while(my $line = <TEMP>){
    chomp $line;

    while($seen{$line}) {
      while ($line = <TEMP>){
        chomp($line);
        last if ($line =~ /Sum/);
      }
      last if(!$line);
    }
    last if(!$line);

    if ($line =~ /^\>(\S+)/){
      $id = $1;
    }
    elsif ($line =~ /Sum/) {
      $seen{$line} = 1;

      my @sim = split(':', $line);
      my $queryStart = $sim[6];
      my $queryEnd = $sim[7];

      my $subjectStart = $sim[4];
      my $subjectEnd = $sim[5];

      $subjectId = $sim[1];
      my $blastResult = BlastResult->new($queryStart, $queryEnd, $subjectStart, $subjectEnd, $line);

      push(@{$similarities->{$subjectId}}, $blastResult);
    }
    elsif($line =~ /HSP/) {
      my $last = scalar(@{$similarities->{$subjectId}}) - 1;
      $similarities->{$subjectId}->[$last]->addHsp($line);
    }
    else {
      die "Invalid line $line: $!";
    }
  }
  close(TEMP);
  return($similarities);
}


sub _removeDuplicates {
  my ($similarities) = @_;

  foreach my $subjects (keys(%$similarities)) {
    next if(scalar(@{$similarities->{$subjects}}) == 1);
    my $newBlastResults = [];

    while(my $blatResult = pop(@{$similarities->{$subjects}})) {
      if(&_isKeeper($blastResult, $similarities->{$subjects})) {
        push(@{$newBlastResults}, $blastResult);
      }






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

  close (TEMP);
}

sub _isKeeper {
  my ($blastResult, $ar) = @_;

  my $newAr = [];

  foreach my $result (@$ar) {
    my $rsQueryEnd = $result->getQueryEnd();
    my $rsQueryStart = $result->getQueryStart();
    my $rsSubjectStart = $result->getSubjectStart();
    my $rsSubjectEnd = $result->getSubjectEnd();

    my $brQueryEnd = $blastResult->getQueryEnd();
    my $brQueryStart = $blastResult->getQueryStart();
    my $brSubjectStart = $blastResult->getSubjectStart();
    my $brSubjectEnd = $blastResult->getSubjectEnd();

    if($brQueryStart == $rsQueryStart && $brSubjectStart == $rsSubjectStart) {
      if($resultQueryEnd > $brQueryEnd) {
        return(0);
      }
      else {
        
      }
    }

    
  }
  

}



sub usage {
  my ($msg) = @_;

  print STDERR "$msg\n" if($msg);
  print STDERR "usage:  perl mergeBlastResults.pl --inputFile <FILENAME> --outputFile <FILENAME> [--verbose]\n";
  exit(0);
}

sub _getFh {
  my ($id, $prevId, $fh, $inputFile, $seen) = @_;

  my $newId = $id . ".bbf";

  $inputFile =~ s/\/[a-zA-Z0-9_\.]+$/\/$newId/;

  print STDERR "WARNING: Appending to FILE $id which already exists\n" if(!$seen->{$id} && -e $inputFile);

  if(defined($prevId) && $id eq $prevId) {
    return($fh);
  }
  else {
    close($fh) unless(!$fh);
    open(FILE, ">> $inputFile") || die "Cannot open file $id for writing";
  }
  return(\*FILE);
}

#==================================================================

package BlastResult;

sub new {
  my ($class, $queryStart, $queryEnd, $subjectStart, $subjectEnd, $sumline) = @_;

  unless($queryStart || $queryEnd || $sumline) {
    die "Invalad BlastResult: qs=$queryStart, qe=$queryEnd, sumline=$sumline";
  }
  my $args = { _query_start => $queryStart,
               _query_end => $queryEnd,
               _subj_start => $subjectStart,
               _subj_end => $subjectEnd,
               _sum_line => $sumline,
               _hsps => [],
               };

  my $self = bless $args, $class;

  return $self;
}

sub getQueryStart {$_[0]->{_query_start}}
sub getQueryEnd   {$_[0]->{_query_end}}
sub getSubjectStart {$_[0]->{_subj_start}}
sub getSubjectEnd   {$_[0]->{_subj_end}}
sub getSumLine    {$_[0]->{_sum_line}}
sub getHsps       {$_[0]->{_hsps}}

sub addHsp {
  my ($self, $hspLine) = @_;

  die "Invalid hsp line: $hspLine" unless($hspLine =~ /HSP/);

  push(@{$self->getHsps}, $hspLine);
}


1;
