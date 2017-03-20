package ApiCommonData::Load::MetadataHelper;

use strict;

use ApiCommonData::Load::MetadataReader;

sub getReaders { $_[0]->{_readers} }
sub setReaders { $_[0]->{_readers} = $_[1] }

sub getDistinctQualifiers { $_[0]->{_distinct_qualifiers} }
sub setDistinctQualifiers { $_[0]->{_distinct_qualifiers} = $_[1] }

sub getMergedOutput { $_[0]->{_merged_output} }
sub setMergedOutput { $_[0]->{_merged_output} = $_[1] }

sub new {
  my ($class, $type, $metadataFiles, $rowExcludeFile, $colExcludeFile) = @_;

  my $self = bless {}, $class;

  my $rowExcludes = &readRowExcludeFile($rowExcludeFile);
  my $colExcludes = &readColExcludeFile($colExcludeFile);

  my @readers;
  foreach my $metadataFile (@$metadataFiles) {
    my $readerClass = "ApiCommonData::Load::MetadataReader::" . $type . "Reader";

   my $reader = eval {
     $readerClass->new($type, $metadataFile, $rowExcludes, $colExcludes);
   };
    die $@ if $@;

    push @readers, $reader;
  }

  $self->setReaders(\@readers);

  return $self;
}

sub merge {
  my ($self) = @_;

  my $readers = $self->getReaders();

  my $mergedOutput = {};
  my %distinctQualifiers;

  foreach my $reader (@$readers) {
    $reader->read();

    my $parsedOutput = $reader->getParsedOutput();

    foreach my $pk (keys %$parsedOutput) {
      my $qualifiersHash = $parsedOutput->{$pk};

      foreach my $qualifier (keys %$qualifiersHash) {
        my $value = $qualifiersHash->{$qualifier};

        push @{$mergedOutput->{$pk}->{$qualifier}}, $value if($value);
        $distinctQualifiers{$qualifier}++ unless($qualifier eq '__PARENT__');
      }
    }
  }

  $self->setMergedOutput($mergedOutput);
  $self->setDistinctQualifiers(\%distinctQualifiers);
}


# this is a one column file (no header) of primary keys to exclude
sub readRowExcludeFile {
  my $file = shift;

  my %hash;

  if($file) {
    open(FILE, $file) or die "cannot open file $file for reading:$!";

    while(<FILE>) {
      chomp;

      $hash{$_}++;
    }
    close FILE;
  }
  return \%hash;
}

sub readColExcludeFile {
  my $file = shift;

  my %hash;

  if($file) {
    open(FILE, $file) or die "cannot open file $file for reading:$!";

    while(<FILE>) {
      chomp;

      my @a = split(/\t/, $_);

      my $file = $a[0];
      my $col = $a[1];

      $hash{$file}->{$col} = 1;
    }
    close FILE;
  }

  return \%hash;

}


sub writeMergedFile {
  my ($self) = @_;

  my $distinctQualifiers = $self->getDistinctQualifiers();
  my $mergedOutput = $self->getMergedOutput();

  my @qualifiers = keys %$distinctQualifiers;

  print "PRIMARY_KEY\tPARENT\t" . join("\t", @qualifiers) . "\n";

  foreach my $pk (keys %$mergedOutput) {
    my $qualifiersHash = $mergedOutput->{$pk};
    my $parent = $qualifiersHash->{'__PARENT__'};

    my @qualifierValues = map { &getDistinctLowerCaseValues($qualifiersHash->{$_})  } @qualifiers;

    print "$pk\t$parent\t" . join("\t", @qualifierValues) . "\n";
  }

}

sub getDistinctLowerCaseValues {
  my ($a) = @_;

  my %seen;
  foreach(@$a) {
    $seen{$_}++;
  }

  my $rv = join('|', keys(%seen));

  if(scalar(keys(%seen)) > 1) {
    $rv = "USER_ERROR_$rv";
  }

  return $rv;
}



1;
