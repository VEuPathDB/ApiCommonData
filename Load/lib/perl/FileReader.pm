package ApiCommonData::Load::FileReader;

=pod

=head2 ApiCommonData::Load::FileReader

=over 4

=item Description

Simple File Reader which allows the user to Peek Ahead one line.  The $file you provide to the new method is passed directly to open so it can be a pipe like:   "zcat -c file.gz|"

=item Usage

my $reader = ApiCommonData::Load::FileReader->new($file, $filters, $delimiter);

while($reader->hasNext()) {
    my $line = $reader->nextLine() ;
    my $peek = $reader->getPeek();

    # OR if you'd like these as lists; (line split on delimiter)
    #    my @lineArray = $reader->nextLine();
    #    my @peek = $reader->getPeek();
    ...
}

=back

=cut


use strict;

sub getFile {$_[0]->{_file}}
sub setFile {$_[0]->{_file} = $_[1]}

sub getFh {$_[0]->{_fh}}
sub setFh {$_[0]->{_fh} = $_[1]}

sub getFilters {$_[0]->{_filters}}
sub setFilters {$_[0]->{_filters} = $_[1]}

sub getPeekLine {$_[0]->{_peek_line}}
sub setPeekLine {$_[0]->{_peek_line} = $_[1]}

sub getPeekLineAsArray {$_[0]->{_peek_line_as_array}}
sub setPeekLineAsArray {$_[0]->{_peek_line_as_array} = $_[1]}

sub getDelimiter {$_[0]->{_delimiter}}
sub setDelimiter {$_[0]->{_delimiter} = $_[1]}

sub getPeek {
  my ($self) = @_;

  return wantarray ? @{$self->getPeekLineAsArray()} : $self->getPeekLine();
}

sub new {
  my ($class, $file, $filters, $delimiter) = @_;

  my $self = bless {}, $class;

  $self->setFile($file);
  $self->setFilters($filters);

  if($delimiter) {
    $self->setDelimiter($delimiter);
  }
  else {
    $self->setDelimiter(qr//);
  }

  my ($fh);
  open($fh, $file) or die "Cannot open file $file for reading: $!";

  $self->setFh($fh);

  $self->processNext();

  unless($self->getPeek()) {
    die "Input File Should Contain at least one Row";
  }

  return $self;
}

# this skips empty lines; can override to skip lines as needed (skip based on filters for example)
sub skipLine {
  my ($self, $line, $fh) = @_;

  return !$line;
}

sub readNextLine {
  my ($self, $fh) = @_;

  # handle empty lines or whatever
  while(!eof($fh)) {
    my $line = readline($fh);
    chomp($line);

    my $delimiter = $self->getDelimiter();
    my @a = split(/$delimiter/, $line);

    next if($self->skipLine($line, \@a, $fh));

    return($line, \@a);
  }
  return(undef, []);
}

sub hasNext {
  my ($self) = @_;

  if($self->getPeek()) {
    return 1;
  }

  $self->closeFileHandle();
  return 0;
}


sub closeFileHandle {
  my ($self) = @_;

  my $fh = $self->getFh();

  close $fh;
}


# this is the one which will be called by users
sub nextLine {
  my ($self) = @_;

  return undef unless($self->hasNext());

  my $line = $self->getPeek();
  my @lineAsArray = $self->getPeek();

  $self->processNext();

  return wantarray ? @lineAsArray : $line;
}

sub processNext {
  my ($self) = @_;

  my $fh = $self->getFh();
  my ($line, $lineAsArray) = $self->readNextLine($fh);

  $self->setPeekLineAsArray($lineAsArray);
  $self->setPeekLine($line);
}


1;

