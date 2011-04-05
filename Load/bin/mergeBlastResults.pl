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

if(-e $outputFile) {
  print STDERR "WARNING:  Appending to an already existing MainResult File: $outputFile";
}
open(OUT, ">> $outputFile") || die "Cannot open outputFile $outputFile for writing";

&_adjustCoordinates($inputFile);
my $dirname = File::Basename::dirname($inputFile);

opendir(DIR, $dirname) || die "Cannot open directory $dirname for reading: $!";

while(my $fn = readdir(DIR)) {
  next if($fn !~ /\.bbf$/);
  my ($name) = $fn =~ /(.+)\.bbf$/;

  $fn = "$dirname/$fn";
  my $similarities = &_parseFile($fn);

  $similarities = &_removeDuplicates($similarities);
  my $subjectCount = &_getTotalSubjectCount($similarities);

  print OUT ">$name ($subjectCount subjects)\n";
  foreach my $subjects (keys(%$similarities)) {
    foreach my $blastResult (@{$similarities->{$subjects}}) {
      print OUT $blastResult->toString();
    }
  }
  #Clean up temporary files...
  system("rm $fn");
}

#---------------------------------------------------------------

=pod

=item C<_adjustCoordinates>

Reads through the inputFile one time and corrects the querystart 
and queryend coordinate...creates many output files (one per query_id)

B<Parameters:>

$inputFile(string): Complete Dataset

B<Return type:> C<void> 

=cut

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
    elsif (/Sum/){
      my @sim = split(':', $_);

      $sim[6] += $offset;
      $sim[7] += $offset;

      my $sum = join(':', @sim);
      print $fh "$sum\n";
    }
    elsif (/HSP/){
      my @hsp = split(':', $_);
      $hsp[9] += $offset;
      $hsp[10] += $offset;

      my $hsp = join(':', @hsp);
      print $fh "$hsp\n";
    }
    else {
      die "Invalid line in input file: $_";
    }
  }
  close (RESULTS);
}

#---------------------------------------------------------------

=pod

=item C<_parseFile>

Input one file containing all data for one query.  Will parse into a 
data structure.

B<Parameters:>

$file(string): Complete Dataset

B<Return type:> C<hashref>

key=subject_id, value=arrayref of BlastResult Objects

=cut

sub _parseFile {
  (my $file) = @_;

  my %seen;
  my $similarities = {};
  my ($id, $subjectId);

  open (TEMP, "< $file") or die "Couldn't open $file for reading: $!\n";

  while(my $line = <TEMP>){
    chomp $line;

    # Remove complete duplicates...
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

#---------------------------------------------------------------

=pod

=item C<_removeDuplicates>

Read through data structure and remove those which have the 
same queryStart or query end but shorter length.

B<Parameters:>

$similarities(hashref): key=subject_id, value=arrayref of BlastResult objects

B<Return type:> C<hashref>

Updated key=subject_id, value=arrayref of BlastResult Objects

=cut

sub _removeDuplicates {
  my ($similarities) = @_;

  foreach my $subjects (keys(%$similarities)) {
    next if(scalar(@{$similarities->{$subjects}}) == 1);

    my $newBlastResults = [];

    while(my $blastResult = pop(@{$similarities->{$subjects}})) {
      if(&_isKeeper($blastResult, $similarities->{$subjects})) {
        push(@{$newBlastResults}, $blastResult);
      }
    }
    push(@{$similarities->{$subjects}}, @$newBlastResults);
  }
  return($similarities);
}

#---------------------------------------------------------------

=pod

=item C<_isKeeper>

Returns true if the blastresult is preffered over any on the array (sets isExcluded for
all those it beat out) and returns false otherwise.

B<Parameters:>

$blastResult(BlastResult): The object to be tested
$ar(arrayRef): An arrayRef containg BlastResult objects to test against

B<Return type:> C<boolean>

=cut

sub _isKeeper {
  my ($blastResult, $ar) = @_;

  return(0) if($blastResult->isExcluded());

  foreach my $result (@$ar) {
    next if $result->isExcluded();

    my $rsQueryEnd = $result->getQueryEnd();
    my $rsQueryStart = $result->getQueryStart();
    my $rsSubjectStart = $result->getSubjectStart();
    my $rsSubjectEnd = $result->getSubjectEnd();

    my $brQueryEnd = $blastResult->getQueryEnd();
    my $brQueryStart = $blastResult->getQueryStart();
    my $brSubjectStart = $blastResult->getSubjectStart();
    my $brSubjectEnd = $blastResult->getSubjectEnd();

    if($brQueryStart == $rsQueryStart && $rsQueryEnd > $brQueryEnd && $rsSubjectStart == $brSubjectStart) {
      return(0);
    }
    if($brQueryStart == $rsQueryStart && $rsQueryEnd < $brQueryEnd && $rsSubjectStart == $brSubjectStart) {
      $result->setExcluded();
    }
    if($brQueryEnd == $rsQueryEnd && $rsQueryStart < $brQueryStart && $rsSubjectEnd == $brSubjectEnd) {
      return(0);
    }
    if($brQueryEnd == $rsQueryEnd && $rsQueryStart > $brQueryStart  && $rsSubjectEnd == $brSubjectEnd) {
      $result->setExcluded();
    }
    if($brQueryEnd == $rsQueryEnd && $rsQueryStart == $brQueryStart &&
          $rsSubjectEnd == $brSubjectEnd  && $rsSubjectStart == $brSubjectStart) {
      die "Query Start and End are equal... should have been excluded in previous step: $!";
    }
  }
  return(1);
}

#---------------------------------------------------------------


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

#---------------------------------------------------------------

sub _getTotalSubjectCount {
  my ($similarities) = @_;

  my $count;

  foreach my $subjects (keys(%$similarities)) {
    foreach my $blastResult (@{$similarities->{$subjects}}) {
      $count++;
    }
  }
  return($count);
}

#---------------------------------------------------------------

sub usage {
  my ($msg) = @_;

  print STDERR "$msg\n" if($msg);
  print STDERR "usage:  perl mergeBlastResults.pl --inputFile <FILENAME> --outputFile <FILENAME> [--verbose]\n";
  exit(0);
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
               _excluded => '',
               _hsps => [],
               };

  my $self = bless $args, $class;

  return $self;
}

sub getQueryStart      {$_[0]->{_query_start}}
sub getQueryEnd        {$_[0]->{_query_end}}
sub getSubjectStart    {$_[0]->{_subj_start}}
sub getSubjectEnd      {$_[0]->{_subj_end}}
sub getSumLine         {$_[0]->{_sum_line}}
sub isExcluded         {$_[0]->{_excluded}}
sub setExcluded        {$_[0]->{_excluded} = 1}

sub getHsps            {$_[0]->{_hsps}}
sub addHsp {
  my ($self, $hspLine) = @_;

  die "Invalid hsp line: $hspLine" unless($hspLine =~ /HSP/);

  push(@{$self->getHsps}, $hspLine);
}



sub toString {
  my ($self) = @_;

  my $s = $self->getSumLine() . "\n";

  foreach my $hsp (@{$self->getHsps()}) {
    $s = $s . $hsp . "\n";
  }
  return($s);
}

1;
