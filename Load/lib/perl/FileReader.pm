package ApiCommonData::Load::FileReader;

use strict;

sub getFile {$_[0]->{_file}}
sub setFile {$_[0]->{_file} = $_[1]}

sub getFh {$_[0]->{_fh}}
sub setFh {$_[0]->{_fh} = $_[1]}

sub getFilters {$_[0]->{_filters}}
sub setFilters {$_[0]->{_filters} = $_[1]}

sub getNextLine {$_[0]->{_next_line}}
sub setNextLine {$_[0]->{_next_line} = $_[1]}

sub getPeek {
  my ($self) = @_;

  return $self->getNextLine();
}

sub new {
  my ($class, $file, $filters) = @_;

  my $self = bless {}, $class;

  $self->setFile($file);
  $self->setFilters($filters);

  my ($fh);
  open($fh, $file) or die "Cannot open file $file for reading: $!";

  $self->setFh($fh);

  my $line = $self->readNextLine($fh);
  $self->setNextLine($line);  

  unless($line) {
    die "The input file must contain at least one row.";
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

    next if($self->skipLine($line, $fh));

    return $line;
  }

  return undef;
}

sub hasNext {
  my ($self) = @_;

  if($self->getNextLine()) {
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

  my $rv = $self->getNextLine();

  unless($rv) {
    die "Cannot call nextLine after all lines have been read";
  }

  my $newNextLine = $self->processNext();

  $self->setNextLine($newNextLine);

  return $rv;
}


sub processNext {
  my ($self) = @_;

  my $fh = $self->getFh();

  return $self->readNextLine($fh);
}


1;

