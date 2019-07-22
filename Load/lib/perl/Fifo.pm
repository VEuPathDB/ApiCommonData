package ApiCommonData::Load::Fifo;

use strict;

use Data::Dumper;

use POSIX qw(mkfifo);

=pod

=head2 ApiCommonData::Load::Fifo

=over 4

=item Description

module to manage  a fifo ojbect

=item Usage

my $fifo = ApiCommonData::Load::Fifo->new($fifoName, $mode, $readerProcessString);
my $pid = $fifo->getReaderProcessId();
my $fh = $fifo->attachWriter();

OR

my $fifo = ApiCommonData::Load::Fifo->new($fifoName, $mode);
my $pid = $fifo->attachReader();
my $fh = $fifo->attachWriter();

=back

=cut

# Reader must be connected to fifo first!
sub getReaderProcessId {$_[0]->{_reader_process_id}}
sub setReaderProcessId {$_[0]->{_reader_process_id} = $_[1]}

sub getReaderProcessFileHandle {$_[0]->{_reader_process_file_handle}}
sub setReaderProcessFileHandle {$_[0]->{_reader_process_file_handle} = $_[1]}

sub attachReader {
  my ($self, $processString) = @_;

  # already attached
  if($self->getReaderProcessId()) {
    return $self->getReaderProcessId();
  }

  my $fh;

  my $pid = open($fh, "|-", $processString) or die "Cannot open reader for fifo $processString:  $!";  
  $self->setReaderProcessId($pid);
  $self->setReaderProcessFileHandle($fh);

  return $pid;
}


sub getFifoName {$_[0]->{_fifo_name}}
sub setFifoName {$_[0]->{_fifo_name} = $_[1]}

sub attachWriter {
  my ($self) = @_;
  
  if($self->{_file_handle}) {
    return $self->{_file_handle};
  }

  unless($self->getReaderProcessId()) {
    die "Cannot attach Writer to fifo without first attaching a Reader";
  }

  my $fifoName = $self->getFifoName();

  my $fifoFh;
  open($fifoFh, ">", $fifoName) or die "Could not open named pipe $fifoName for writing: $!";

  $self->{_file_handle} = $fifoFh;

  return $self->{_file_handle};
}

sub getFileHandle {$_[0]->{_file_handle}}


sub new {
  my ($class, $fifoName, $mode, $readerProcessString) = @_;

  $mode = 0700 unless($mode);

  unless(mkfifo($fifoName, $mode)) {
    die "Could not make fifo object $fifoName with mode $mode";
  }

  my $self = bless {}, $class;

  $self->setFifoName($fifoName);

  if($readerProcessString) {
    $self->attachReader($readerProcessString);
  }

  return $self; 
}


sub DESTROY {
  my $self = shift;
  print STDERR "Closing file handles and removing fifo\n";
  my $fifoName = $self->getFifoName();
  my $readerFh = $self->getReaderProcessFileHandle();

  my $fh = $self->getFileHandle();
  close $fh;
  close $readerFh;
  unlink $fifoName;
}

1;
