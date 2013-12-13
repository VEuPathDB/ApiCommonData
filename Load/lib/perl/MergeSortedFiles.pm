package ApiCommonData::Load::MergeSortedFiles;

use strict;

#--------------------------------------------------------------------------------

## probably you will need to override this w/ something interesting
sub wantFirstLine {
  my ($self) = @_;

  my $firstLine = $self->getFirstLine();
  my $secondLine = $self->getSecondLine();

  return $firstLine le $secondLine
}

# this skips empty lines; can override to skip lines as needed
sub skipLine {
  my ($self, $line, $fh) = @_;

  return !$line;
}

#--------------------------------------------------------------------------------

sub getFile1 {$_[0]->{_file_1}}
sub setFile1 {$_[0]->{_file_1} = $_[1]}

sub getFile2 {$_[0]->{_file_2}}
sub setFile2 {$_[0]->{_file_2} = $_[1]}

sub getCurrentLine {$_[0]->{_current_line}}
sub setCurrentLine {$_[0]->{_current_line} = $_[1]}

sub getPeek {
  my ($self) = @_;

  return $self->getCurrentLine();
}

sub getFirstLine {$_[0]->{_first_line}}
sub setFirstLine {$_[0]->{_first_line} = $_[1]}

sub getSecondLine {$_[0]->{_second_line}}
sub setSecondLine {$_[0]->{_second_line} = $_[1]}

sub getFirstFh {$_[0]->{_first_fh}}
sub setFirstFh {$_[0]->{_first_fh} = $_[1]}

sub getSecondFh {$_[0]->{_second_fh}}
sub setSecondFh {$_[0]->{_second_fh} = $_[1]}

sub getFile1Fh {$_[0]->{_file1_fh}}
sub setFile1Fh {$_[0]->{_file1_fh} = $_[1]}

sub readingFile1Fh {
  my ($self, $fh) = @_;

  return $self->getFile1Fh() eq $fh;
}

sub readingFile2Fh {
  my ($self, $fh) = @_;

  return $self->getFile1Fh() ne $fh;
}

sub getFilters {$_[0]->{_filters}}
sub setFilters {$_[0]->{_filters} = $_[1]}

#--------------------------------------------------------------------------------

sub new {
  my ($class, $file1, $file2, $filters) = @_;

  my $self = bless {}, $class;

  $self->setFile1($file1);
  $self->setFile2($file2);

  $self->setFilters($filters);

  my ($file1Fh, $file2Fh);
  open($file1Fh, $file1) or die "Cannot open file $file1 for reading: $!";
  open($file2Fh, $file2) or die "Cannot open file $file2 for reading: $!";

  $self->setFile1Fh($file1Fh);

  my $file1Line = $self->readNextLine($file1Fh);
  my $file2Line = $self->readNextLine($file2Fh);

  unless($file1Line || $file2Line) {
    die "One of the 2 input files must contain at least one row.";
  }

  $self->setFirstLine($file1Line);
  $self->setFirstFh($file1Fh);
  $self->setSecondLine($file2Line);
  $self->setSecondFh($file2Fh);

  my $currentLine = $self->processNextMerge();
  $self->setCurrentLine($currentLine);

  return $self;
}

sub readNextLine {
  my ($self, $fh) = @_;

  # handle empty lines or whatever
  while(!eof($fh)) {
    my $line = readline($fh);
    chomp($line);

    next if($self->skipLine($line, $fh));

    return $line;
  }

  return undef;
}

sub merge {
  my ($self) = @_;

  my $firstFh = $self->getFirstFh();
  my $secondFh = $self->getSecondFh();

  my $firstLine = $self->getFirstLine();
  my $secondLine = $self->getSecondLine();

  my $rv;

  if($self->wantFirstLine()) {
    $rv = $firstLine;
  }

  else {
    $self->setFirstLine($secondLine);
    $self->setFirstFh($secondFh);
    $self->setSecondLine($firstLine);
    $self->setSecondFh($firstFh);

    $rv = $secondLine;
  }

  my $fh = $self->getFirstFh();
  $firstLine= $self->readNextLine($fh);
  $self->setFirstLine($firstLine);

  return $rv;
}


sub hasNext {
  my ($self) = @_;

  if($self->getCurrentLine()) {
    return 1;
  }

  $self->closeFileHandles();
  return 0;
}

sub closeFileHandles {
  my ($self) = @_;

  my $fh1 = $self->getFirstFh();
  my $fh2 =  $self->getSecondFh();

  close $fh1;
  close $fh2;
}

sub processNextMerge {
  my ($self) = @_;

  my $firstFh = $self->getFirstFh();
  my $secondFh = $self->getSecondFh();

  my $firstLine = $self->getFirstLine();
  my $secondLine = $self->getSecondLine();

  my $nextLine;
  if(!$firstLine) {
    $nextLine = $secondLine;
    $self->setSecondLine($self->readNextLine($secondFh));
  }
  elsif(!$secondLine) {
    $nextLine = $firstLine;
    $self->setFirstLine($self->readNextLine($firstFh));

  }
  else {
    $nextLine = $self->merge();
  }

  return $nextLine;
}


# this is the one which will be called by users
sub nextLine {
  my ($self) = @_;

  my $rv = $self->getCurrentLine();

  unless($rv) {
    die "Cannot call nextLine after all lines have been read";
  }

  my $newCurrentLine = $self->processNextMerge();

  $self->setCurrentLine($newCurrentLine);

  return $rv;
}


1;

package ApiCommonData::Load::MergeSortedFiles::SeqVarCache;
use base qw(ApiCommonData::Load::MergeSortedFiles);

sub getSequenceIndex { return 0 }
sub getLocationIndex { return 1 }
sub getStrainIndex { return 2 }


sub wantFirstLine {
  my ($self) = @_;

  my $sequenceIndex = $self->getSequenceIndex();
  my $locationIndex = $self->getLocationIndex();;

  my $firstLine = $self->getFirstLine();
  my $secondLine = $self->getSecondLine();

  my @a = split(/\t/, $firstLine);
  my @b = split(/\t/, $secondLine);

  return $a[$sequenceIndex] lt $b[$sequenceIndex] || ($a[$sequenceIndex] eq $b[$sequenceIndex] && $a[$locationIndex] <= $b[$locationIndex])
}

sub skipLine {
  my ($self, $line, $fh) = @_;

  return 1 unless($line);
  return 0 if($self->readingFile1Fh($fh));

  my $strainIndex = $self->getStrainIndex();

  my $filters = $self->getFilters();
  my @a = split(/\t/, $line);

  foreach(@$filters) {
    if($a[$strainIndex] eq $_) {
      return 1;
    }
  }
  return 0;
}

sub nextSNP {
  my ($self) = @_;

  my @rv;

  my $sequenceIndex = $self->getSequenceIndex();
  my $locationIndex = $self->getLocationIndex();

  my $isSameGroup = 1;

  while($isSameGroup) {
    last unless($self->hasNext());

    my $line = $self->nextLine();
    my $peekLine = $self->getPeek();

    my @a = split(/\t/, $line);
    my @b = split(/\t/, $peekLine);

    my $sequenceId = $a[$sequenceIndex];
    my $peekSequenceId = $b[$sequenceIndex];

    my $location = $a[$locationIndex];
    my $peekLocation = $b[$locationIndex];

    unless($sequenceId eq $peekSequenceId && $peekLocation == $location) {
      $isSameGroup = 0;
    }
    push @rv, $line;
  }
  return \@rv;
}



1;
