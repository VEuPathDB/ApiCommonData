#!/usr/bin/perl

use strict;
use Getopt::Long qw(GetOptions);

=pod

=head1 what_does_this_do?

Reads a directory of .laj files (output files from blastz) and converts
into a "Brian Brunk" Blast Similarities Format.  ie a format which will be
read by the plugin GUS::Supported::Plugin::InsertBlastSimilarities

=cut


my $dirname;
my $outfile;
my $verbose;

GetOptions("verbose!"         => \$verbose,
           "dirname=s"        => \$dirname,
           "outfile=s"        => \$outfile,
          );

unless (-e $dirname && $outfile) {
  die "usage:  perl parseBlastzLav.pl --dirname <DIR>";
}

opendir(DIR, $dirname) || die "Cannot open directory $dirname for reading: $!";
open(OUT, "> $outfile") || die "Cannot open file $outfile for writing: $!";

while(my $fn = readdir(DIR)) {
  next if $fn =~ /^\.\.?$/;
  next if $fn !~ /\.laj$/;

  $fn = $dirname . "/". $fn;

  my $lavList = LavSimilarity::parseFromFile($fn);
  &_processLav($fn, $lavList, \*OUT);
}

close(OUT);
closedir(DIR);

# ----------------------------------------------------------------------

sub _processLav {
  my ($fn, $lavList, $out) = @_;

  my ($numSubjects, $querySourceId) = &_getSubjAndSourceId($fn, $lavList);
  print $out ">".$querySourceId." ($numSubjects subjects)\n";

  foreach my $lav (@$lavList) {

    my $s = $lav->getS();
    my $queryReversed = $s->{queryReversed};
    my $subjectReversed = $s->{subjectReversed};

    my $isReversed;
    if($queryReversed == $subjectReversed) {
      $isReversed = 1;
    }
    else {
      $isReversed = 0;
    }

    my $h = $lav->getH();
    my $subjectSourceId = $h->{subjectSourceId};

    foreach my $a (@{$lav->getA()}) {
      my @hsps;
      my $score = $a->{'s'}->[0];

      my $queryStart   = $a->{b}->[0];
      my $subjectStart = $a->{b}->[1];

      my $queryEnd     = $a->{e}->[0];
      my $subjectEnd   = $a->{e}->[1];

      my $n = 1;
      foreach my $l (@{$a->{l}}) {
        my $queryStart       = $l->[0];
        my $subjectStart     = $l->[1];
        my $queryEnd         = $l->[2];
        my $subjectEnd       = $l->[3];
        my $percentIdentical = $l->[4] / 100;

        my $matchLength = $queryEnd - $queryStart + 1;

        #These are the same for DNA!!
        my $numberIdentical = sprintf("%d", $matchLength * $percentIdentical);
        my $numberPositive  = sprintf("%d", $matchLength * $percentIdentical);

        my $hsp = ["HSP$n", $subjectSourceId, $numberIdentical, $numberPositive, $matchLength, undef, undef,
                   $subjectStart, $subjectEnd, $queryStart, $queryEnd, $isReversed, undef];

        push(@hsps, $hsp);
        $n++;
      }
      my $sum = &_calculateSum(\@hsps, $score, $queryStart, $queryEnd, $subjectStart, $subjectEnd, $isReversed, $subjectSourceId);

      &_writeToFile(\@hsps, $sum, $out);
    }
  }
}

# ----------------------------------------------------------------------

sub _getSubjAndSourceId {
  my ($fn, $lavList) = @_;

  my ($numberOfSubjects, $sourceId);

    foreach my $lav (@$lavList) {
      if($sourceId && $lav->getH()->{querySourceId} ne $sourceId) {
        die "Cannot Distinguish Unique SourceId for file $fn: $!";
      } else {
        $sourceId = $lav->getH()->{querySourceId};
      }
      foreach my $a (@{$lav->getA()}) {
        $numberOfSubjects++;
      }
    }
  return($numberOfSubjects, $sourceId);
}

# ----------------------------------------------------------------------

sub _calculateSum {
  my ($hsps, $score, $queryStart, $queryEnd, $subjectStart, $subjectEnd, $isReversed, $subjectSourceId) = @_;

  my $totalMatches = scalar(@$hsps);
  my ($totalMatchLength, $totalIdentical, $totalPositive);

  foreach my $hsp (@$hsps) {
    $totalIdentical = $totalIdentical + $hsp->[2];
    $totalPositive = $totalPositive + $hsp->[3];
    $totalMatchLength = $totalMatchLength + $hsp->[4];

  }

  my $sum = ["Sum", $subjectSourceId, $score, undef, $subjectStart, $subjectEnd, 
             $queryStart, $queryEnd, $totalMatches, $totalMatchLength, 
             $totalIdentical, $totalPositive, $isReversed, undef ];

  return($sum);
}

# ----------------------------------------------------------------------

sub _writeToFile {
  my ($hsps, $sum, $out) = @_;

  print $out "   ".join(':', @$sum)."\n";

  foreach my $hsp (@$hsps) {
    print $out "    ".join(':', @$hsp)."\n";
  }
  return(1);
}


#=====================================================================

package LavSimilarity;

=pod

=head1 LavSimilarity

Small Inner class to handle the parsing of .laj files

=cut

sub new {
  my ($class) = @_;
  my $self = bless {}, $class;

  return $self;
}

# ----------------------------------------------------------------------

sub parseFromFile {
  my ($fn) = @_;

  open(FILE, $fn) || die "Cannot open lav file $fn for reading: $!";

  my @lavList;
  my $lav;

  while(<FILE>) {
    chomp;

    if((/^\#:lav/ || /^\#:eof/) && $lav) {
      push(@lavList, $lav);
      $lav = LavSimilarity->new();
    }
    elsif(/^\#:lav/) {
      $lav = LavSimilarity->new();
    }
    elsif(/s {/) {
      $lav->_setS(\*FILE);
    }
    elsif(/d {/) {
      $lav->_setD(\*FILE);
    }
    elsif(/h {/) {
      $lav->_setH(\*FILE);
    }
    elsif(/a {/) {
      $lav->_setA(\*FILE);
    }
    elsif(/m {/ || /x {/) {
      $lav->_skip(\*FILE);
    }
    else {
      print STDERR "WARNING:  Unknown input: $_\n";
    }
  }
  return(\@lavList);
}

# ----------------------------------------------------------------------

sub getS {$_[0]->{S}}
sub getD {$_[0]->{D}}
sub getH {$_[0]->{H}}
sub getA {$_[0]->{A}}

# ----------------------------------------------------------------------

sub _setS {
  my ($self, $fh) = @_;

  my $args = {};
  my $line;

  my @tmp;
  until($line eq '}') {
    $line = <$fh>;
    chomp($line);

    next if($line eq '}');
    my (@num) = split(' ', $line);
    push(@tmp, \@num);
  }
  my ($queryArrayRef, $subjectArrayRef) = @tmp;
  $args->{queryArrayRef} = $queryArrayRef;
  $args->{subjectArrayRef} = $subjectArrayRef;

  $args->{queryReversed} = $queryArrayRef->[3];
  $args->{subjectReversed} = $subjectArrayRef->[3];

  $self->{S} = $args;
}

# ----------------------------------------------------------------------

sub _setD {
  my ($self, $fh) = @_;

  my $args;

  my $line = <$fh>;
  chomp($line);

  $args->{cmd_ln} = $line;

  until($line =~ /\#:lav/ || $line =~ /\#:eof/) {
    $line = <$fh>;
  }

  $self->{D} = $args;
}

# ----------------------------------------------------------------------

sub _setH {
  my ($self, $fh) = @_;

  my $args;

  chomp(my $line = <$fh>);
  ($args->{querySourceId}) = $line =~ m/^\s+">(\S+)/;

  chomp($line = <$fh>);
  ($args->{subjectSourceId}) = $line =~  m/^\s+">(\S+)/;

  die "Expected query and subject only for h stanza: $!" if(<$fh> ne "}\n"); 

  $self->{H} = $args;
}

# ----------------------------------------------------------------------

sub _setA {
  my ($self, $fh) = @_;

  my $args;
  my $line;

  until($line eq '}') {
    $line = <$fh>;
    chomp($line);

    next if($line eq '}');
    my ($letter, @rest) = split(' ', $line);

    if($letter eq 'l') {
      push(@{$args->{$letter}}, \@rest);
    }
    else {
      $args->{$letter} = \@rest;
    }
  }

  push(@{$self->{A}}, $args);
}

# ----------------------------------------------------------------------

sub _skip {
  my ($self, $fh) = @_;

  my $line;

  until($line eq '}') {
    $line = <$fh>;
    chomp($line);
  }
}

#=====================================================================

1;
