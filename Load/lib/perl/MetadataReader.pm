package ApiCommonData::Load::MetadataReader;

use strict;

use File::Basename;

use Data::Dumper;

sub getType { $_[0]->{_type} }
sub setType { $_[0]->{_type} = $_[1] }

sub getMetadataFile { $_[0]->{_metadata_file} }
sub setMetadataFile { $_[0]->{_metadata_file} = $_[1] }

sub getRowExcludes { $_[0]->{_row_excludes} }
sub setRowExcludes { $_[0]->{_row_excludes} = $_[1] }

sub getColExcludes { $_[0]->{_col_excludes} }
sub setColExcludes { $_[0]->{_col_excludes} = $_[1] }

sub getParsedOutput { $_[0]->{_parsed_output} }
sub setParsedOutput { $_[0]->{_parsed_output} = $_[1] }

sub getDelimiter { 
  return qr/,|\t/;
}

sub new {
  my ($class, $type, $metadataFile, $rowExcludes, $colExcludes) = @_;

  my $self = bless {}, $class;

  $self->setMetadataFile($metadataFile);
  $self->setType($type);
  $self->setRowExcludes($rowExcludes);
  $self->setColExcludes($colExcludes);

  return $self;
}


sub read {
  my ($self) = @_;

  my $metadataFile = $self->getMetadataFile();
  my $delimiter = $self->getDelimiter();

  my $colExcludes = $self->getColExcludes();
  my $rowExcludes = $self->getRowExcludes();

  my $fileBasename = basename $metadataFile;

  open(FILE, $metadataFile) or die "Cannot open file $metadataFile for reading: $!";

  my $header = <FILE>;
  $header =~s/\n|\r//g;

  my @headers = split($delimiter, $header);

  my $parsedOutput = {};

  while(<FILE>) {
    $_ =~ s/\n|\r//g;

    my @values = split($delimiter, $_);

    my %hash;
    for(my $i = 0; $i < scalar @headers; $i++) {
      my $key = lc($headers[$i]);
      my $value = lc($values[$i]);

      next if($value eq '[skipped]');
      next if($colExcludes->{$fileBasename}->{$key} || $colExcludes->{'__ALL__'}->{$key});

      $hash{$key} = $value if($value);
    }

    my $primaryKey = $self->makePrimaryKey(\%hash);
    my $parent = $self->makeParent(\%hash);

    my $parentPrefix = $self->getParentPrefix();
    my $parentWithPrefix = $parentPrefix . $parent;

    $hash{'__PARENT__'} = $parentWithPrefix unless($parentPrefix && $parentWithPrefix eq $parentPrefix);

    next unless($primaryKey); # skip rows that do not have a primary key
    next if($rowExcludes->{$primaryKey});

    $primaryKey = $self->getPrimaryKeyPrefix() . $primaryKey;

    $parsedOutput->{$primaryKey} = \%hash;
  }

  close FILE;

  $self->setParsedOutput($parsedOutput);
}


sub makePrimaryKey {
  die "SUBCLASS must override makePrimaryKey method";
} 
sub makeParent {
  die "SUBCLASS must override makeParent method";
}

sub getPrimaryKeyPrefix {
  return undef;
}

sub getParentPrefix {
  return undef;
}


1;

package ApiCommonData::Load::MetadataReader::PrismDwellingReader;
use base qw(ApiCommonData::Load::MetadataReader);

use strict;

sub makeParent {
  return undef;
}

sub makePrimaryKey {
  my ($self, $hash) = @_;

  return $hash->{hhid};
}

sub getPrimaryKeyPrefix {
  my ($self, $hash) = @_;

  return "HH";
}


1;

package ApiCommonData::Load::MetadataReader::PrismParticipantReader;
use base qw(ApiCommonData::Load::MetadataReader);

use strict;

sub makeParent {
  my ($self, $hash) = @_;

  return $hash->{hhid};
}

sub makePrimaryKey {
  my ($self, $hash) = @_;

  return $hash->{id};
}

sub getParentPrefix {
  my ($self, $hash) = @_;

  return "HH";
}


1;

package ApiCommonData::Load::MetadataReader::PrismClinicalVisitReader;
use base qw(ApiCommonData::Load::MetadataReader);

use strict;

sub makeParent {
  my ($self, $hash) = @_;

  return $hash->{id};
}

sub makePrimaryKey {
  my ($self, $hash) = @_;

  return $hash->{uniqueid};
}

1;

package ApiCommonData::Load::MetadataReader::PrismSampleReader;
use base qw(ApiCommonData::Load::MetadataReader);

use strict;

# @override
sub read {


}


1;


package ApiCommonData::Load::MetadataReader::PrismLightTrapReader;
use base qw(ApiCommonData::Load::MetadataReader);

use strict;


1;
