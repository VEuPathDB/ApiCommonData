package ApiCommonData::Load::MergeSortedFiles;
use base qw(ApiCommonData::Load::FileReader);

use strict;

#--------------------------------------------------------------------------------

## probably you will need to override this w/ something interesting
sub wantFirstLine {
  my ($self) = @_;

  my $firstLine = $self->getFirstLine();
  my $secondLine = $self->getSecondLine();

  return $firstLine le $secondLine
}


#--------------------------------------------------------------------------------

sub getFile2 {$_[0]->{_file_2}}
sub setFile2 {$_[0]->{_file_2} = $_[1]}

#--------------------------------------------------------------------------------

sub getFirstLine {$_[0]->{_first_line}}
sub setFirstLine {$_[0]->{_first_line} = $_[1]}

sub getSecondLine {$_[0]->{_second_line}}
sub setSecondLine {$_[0]->{_second_line} = $_[1]}

sub getFirstFh {$_[0]->{_first_fh}}
sub setFirstFh {$_[0]->{_first_fh} = $_[1]}

sub getSecondFh {$_[0]->{_second_fh}}
sub setSecondFh {$_[0]->{_second_fh} = $_[1]}

#--------------------------------------------------------------------------------

sub readingFile1Fh {
  my ($self, $fh) = @_;

  return $self->getFh() eq $fh;
}

sub readingFile2Fh {
  my ($self, $fh) = @_;

  return $self->getFh() ne $fh;
}

#--------------------------------------------------------------------------------
# @OVERRIDE
sub new {
  my ($class, $file1, $file2, $filters) = @_;

  my $self = bless {}, $class;

  $self->setFile($file1);
  $self->setFile2($file2);

  $self->setFilters($filters);

  my ($file1Fh, $file2Fh);
  open($file1Fh, $file1) or die "Cannot open file $file1 for reading: $!";
  open($file2Fh, $file2) or die "Cannot open file $file2 for reading: $!";

  $self->setFh($file1Fh);

  my $file1Line = $self->readNextLine($file1Fh);
  my $file2Line = $self->readNextLine($file2Fh);

  unless($file1Line || $file2Line) {
    die "One of the 2 input files must contain at least one row.";
  }

  $self->setFirstLine($file1Line);
  $self->setFirstFh($file1Fh);
  $self->setSecondLine($file2Line);
  $self->setSecondFh($file2Fh);

  my $nextLine = $self->processNext();
  $self->setNextLine($nextLine);

  return $self;
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

# @OVERRIDE
sub closeFileHandle {
  my ($self) = @_;
  $self->closeFileHandles(); 
}

sub closeFileHandles {
  my ($self) = @_;

  my $fh1 = $self->getFirstFh();
  my $fh2 =  $self->getSecondFh();

  close $fh1;
  close $fh2;
}

# @OVERRIDE
sub processNext {
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

    my $variation = $self->variation($line);

    push @rv, $variation;
  }
  return \@rv;
}


sub variation {
  my ($self, $line) = @_;

  my ($sequenceId, $location, $strain, $base, $coverage, $percent, $quality, $pvalue, $externalDatabaseReleaseId, $matchesReference, $product, $positionInCds) = split(/\t/, $line);

  my $rv = {'sequence_source_id' => $sequenceId,
            'location' => $location,
            'strain' => $strain,
            'base' => $base,
            'coverage' => $coverage,
            'percent' => $percent,
            'quality' => $quality,
            'pvalue' => $pvalue,
            'external_database_release_id' => $externalDatabaseReleaseId,
            'matches_reference' => $matchesReference,
            'product' => $product,
            'position_in_cds' => $positionInCds,
  };
  return $rv;
}


1;
