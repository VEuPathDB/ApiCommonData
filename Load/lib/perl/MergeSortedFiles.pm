package ApiCommonData::Load::MergeSortedFiles;
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | absent
  # GUS4_STATUS | RAD.Analysis                   | auto   | absent
  # GUS4_STATUS | ApiDB.Profile                  | auto   | absent
  # GUS4_STATUS | Study.Study                    | auto   | absent
  # GUS4_STATUS | Dots.Isolate                   | auto   | absent
  # GUS4_STATUS | DeprecatedTables               | auto   | absent
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | absent
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^
use base qw(ApiCommonData::Load::FileReader);

use strict;

#--------------------------------------------------------------------------------

## SUBCLASSES SHOULD override this w/ something interesting
sub wantFirstLine {
  my ($self) = @_;

  my $firstLine = $self->getFirstLine();
  my $secondLine = $self->getSecondLine();

  return $firstLine le $secondLine
}

#--------------------------------------------------------------------------------

sub getFirstLine {$_[0]->{_first_line}}
sub setFirstLine {$_[0]->{_first_line} = $_[1]}

sub getSecondLine {$_[0]->{_second_line}}
sub setSecondLine {$_[0]->{_second_line} = $_[1]}

sub getFirstLineAsArray {$_[0]->{_first_line_as_array}}
sub setFirstLineAsArray {$_[0]->{_first_line_as_array} = $_[1]}

sub getSecondLineAsArray {$_[0]->{_second_line_as_array}}
sub setSecondLineAsArray {$_[0]->{_second_line_as_array} = $_[1]}

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
  my ($class, $file1, $file2, $filters, $delimiter) = @_;

  my $self = bless {}, $class;

  if($delimiter) {
    $self->setDelimiter($delimiter);
  }
  else {
    $self->setDelimiter(qr//);
  }

  $self->setFile($file1);
  $self->setFilters($filters);

  my ($file1Fh, $file2Fh);
  open($file1Fh, $file1) or die "Cannot open file $file1 for reading: $!";
  open($file2Fh, $file2) or die "Cannot open file $file2 for reading: $!";

  $self->setFh($file1Fh);

  my ($file1Line, $file1LineAsArray) = $self->readNextLine($file1Fh);
  my ($file2Line, $file2LineAsArray) = $self->readNextLine($file2Fh);

  unless($file1Line || $file2Line) {
    die "One of the 2 input files must contain at least one row.";
  }

  $self->setFirstLine($file1Line);
  $self->setFirstLineAsArray($file1LineAsArray);
  $self->setFirstFh($file1Fh);

  $self->setSecondLine($file2Line);
  $self->setSecondLineAsArray($file2LineAsArray);
  $self->setSecondFh($file2Fh);

  $self->processNext();

  return $self;
}


sub merge {
  my ($self) = @_;

  my $firstFh = $self->getFirstFh();
  my $secondFh = $self->getSecondFh();

  my $firstLine = $self->getFirstLine();
  my $secondLine = $self->getSecondLine();

  my $firstLineAsArray = $self->getFirstLineAsArray();
  my $secondLineAsArray = $self->getSecondLineAsArray();

  my $rv;
  my $rvAsArray;

  if($self->wantFirstLine()) {
#    print STDERR "KEEP\n";
    $rv = $firstLine;
    $rvAsArray = $firstLineAsArray;
  }

  else {
#    print STDERR "SWITCH\n";
    $self->setFirstLine($secondLine);
    $self->setFirstLineAsArray($secondLineAsArray);
    $self->setFirstFh($secondFh);

    $self->setSecondLine($firstLine);
    $self->setSecondLineAsArray($firstLineAsArray);
    $self->setSecondFh($firstFh);

    $rv = $secondLine;
    $rvAsArray = $secondLineAsArray;
  }

  
  my $fh = $self->getFirstFh();
  ($firstLine, $firstLineAsArray) = $self->readNextLine($fh);

#  print STDERR $firstLine . "\n\n";

  $self->setFirstLine($firstLine);
  $self->setFirstLineAsArray($firstLineAsArray);

  return($rv, $rvAsArray);
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
  my $nextLineAsArray;

  if(!$firstLine) {
    $nextLine = $secondLine;
    $nextLineAsArray = $self->getSecondLineAsArray();

    my ($l, $laa) = $self->readNextLine($secondFh);
    $self->setSecondLine($l);
    $self->setSecondLineAsArray($laa);
  }
  elsif(!$secondLine) {
    $nextLine = $firstLine;
    $nextLineAsArray = $self->getFirstLineAsArray();

    my ($l, $laa) = $self->readNextLine($firstFh);
    $self->setFirstLine($l);
    $self->setFirstLineAsArray($laa);
  }
  else {
    ($nextLine, $nextLineAsArray) = $self->merge();
  }

  $self->setPeekLineAsArray($nextLineAsArray);
  $self->setPeekLine($nextLine);
}




1;

