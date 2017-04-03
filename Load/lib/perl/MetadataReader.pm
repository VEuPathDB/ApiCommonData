package ApiCommonData::Load::MetadataReader;

use strict;

use File::Basename;

sub getParentParsedOutput { $_[0]->{_parent_parsed_output} }
sub setParentParsedOutput { $_[0]->{_parent_parsed_output} = $_[1] }

sub getMetadataFile { $_[0]->{_metadata_file} }
sub setMetadataFile { $_[0]->{_metadata_file} = $_[1] }

sub getRowExcludes { $_[0]->{_row_excludes} }
sub setRowExcludes { $_[0]->{_row_excludes} = $_[1] }

sub getColExcludes { $_[0]->{_col_excludes} }
sub setColExcludes { $_[0]->{_col_excludes} = $_[1] }

sub getParsedOutput { $_[0]->{_parsed_output} }
sub setParsedOutput { $_[0]->{_parsed_output} = $_[1] }

sub getNestedReaders { $_[0]->{_nested_readers} }
sub setNestedReaders { $_[0]->{_nested_readers} = $_[1] }

sub getDelimiter { 
  return qr/,|\t/;
}

sub new {
  my ($class, $metadataFile, $rowExcludes, $colExcludes, $parentParsedOutput) = @_;

  my $self = bless {}, $class;

  $self->setMetadataFile($metadataFile);
  $self->setRowExcludes($rowExcludes);
  $self->setColExcludes($colExcludes);
  $self->setParentParsedOutput($parentParsedOutput);

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

      $hash{$key} = $value if(defined $value);
    }

    my $primaryKey = $self->makePrimaryKey(\%hash);
    my $parent = $self->makeParent(\%hash);

    my $parentPrefix = $self->getParentPrefix();
    my $parentWithPrefix = $parentPrefix . $parent;

    $hash{'__PARENT__'} = $parentWithPrefix unless($parentPrefix && $parentWithPrefix eq $parentPrefix);

    next unless($primaryKey); # skip rows that do not have a primary key
    next if($rowExcludes->{$primaryKey});

    $primaryKey = $self->getPrimaryKeyPrefix() . $primaryKey;

    my %filteredHash; 
    foreach my $key (keys %hash) {
      next if($colExcludes->{$fileBasename}->{$key} || $colExcludes->{'__ALL__'}->{$key});
      $filteredHash{$key} = $hash{$key};
    }

    $parsedOutput->{$primaryKey} = \%filteredHash;
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
use ApiCommonData::Load::MetadataReader;

use Date::Manip qw(Date_Init ParseDate UnixDate);

use File::Basename;

sub getClinicalVisitMapper { $_[0]->{_clinical_visit_mapper} }
sub setClinicalVisitMapper { $_[0]->{_clinical_visit_mapper} = $_[1] }

sub new {
  my ($class, $metadataFile, $rowExcludes, $colExcludes, $clinicalVisitsParsedOutput, $clinicalVisitMapper) = @_;

  my $self = bless {}, $class;

  $self->setMetadataFile($metadataFile);
  $self->setRowExcludes($rowExcludes);
  $self->setColExcludes($colExcludes);
  $self->setParentParsedOutput($clinicalVisitsParsedOutput);

  unless($clinicalVisitMapper) {
    foreach my $uniqueid (keys %$clinicalVisitsParsedOutput) {
      my $participant = $clinicalVisitsParsedOutput->{$uniqueid}->{'id'};
      my $date = $clinicalVisitsParsedOutput->{$uniqueid}->{'date'};


      if($date) {
        my $formattedDate = &formatDate($date);

        my $key = "$participant.$formattedDate";
      
        $clinicalVisitMapper->{$key} = $uniqueid;
      }
      else {
        print STDERR "No Date for Clinical Visit with Participant = $participant\n";
      }
    }
  }
  $self->setClinicalVisitMapper($clinicalVisitMapper);

  return $self;
}


sub read {
  my ($self) = @_;

  my $metadataFile = $self->getMetadataFile();
  my $baseMetaDataFile = basename $metadataFile;

  if($baseMetaDataFile eq "Prism_samples.txt" && ref($self) eq "ApiCommonData::Load::MetadataReader::PrismSampleReader") {

    my $colExcludes = $self->getColExcludes();
    my $rowExcludes = $self->getRowExcludes();
    my $parentParsedOutput = $self->getParentParsedOutput();
    my $clinicalVisitMapper = $self->getClinicalVisitMapper();

    my $fp = ApiCommonData::Load::MetadataReader::PrismSampleReader::FP->new($metadataFile, $rowExcludes, $colExcludes, $parentParsedOutput, $clinicalVisitMapper);
    $fp->read();
    $fp->addSpecimenType();

    my $bc = ApiCommonData::Load::MetadataReader::PrismSampleReader::BC->new($metadataFile, $rowExcludes, $colExcludes, $parentParsedOutput, $clinicalVisitMapper);
    $bc->read();
    $bc->addSpecimenType();

    my $p1 = ApiCommonData::Load::MetadataReader::PrismSampleReader::P1->new($metadataFile, $rowExcludes, $colExcludes, $parentParsedOutput, $clinicalVisitMapper);
    $p1->read();
    $p1->addSpecimenType();

    my $p2 = ApiCommonData::Load::MetadataReader::PrismSampleReader::P2->new($metadataFile, $rowExcludes, $colExcludes, $parentParsedOutput, $clinicalVisitMapper);
    $p2->read();
    $p2->addSpecimenType();

    $self->setNestedReaders([$fp, $bc, $p1, $p2]);
  }

  # this will handle tororo file && each call above
  else{
    $self->SUPER::read();
  }

}

sub addSpecimenType {
  my ($self) = @_;

  my $parsedOutput = $self->getParsedOutput();

  my $types = {"3" => "Plasma",
               "4" => "Filter Paper",
               "5" => "Pellet",
               "6" => "Buffy Coat",
  };


  foreach my $pk (keys %$parsedOutput) {

    if($pk =~ /cj(\d)-/i) {
      my $type = $types->{$1};

      if($type) {
        $parsedOutput->{$pk}->{specimentype} = $type;
      }
      else {
        die "No Type for sample $pk\n";
      }
    }
  }
}



sub formatDate {
  my ($date) = @_;

  Date_Init("DateFormat=non-US"); 
  my $formattedDate = UnixDate(ParseDate($date), "%Y-%m-%d");

  unless($formattedDate) {
    die "Date Format not supported for $date\n";
  }

  return $formattedDate;
}



sub makeParent {
  my ($self, $hash) = @_;

  my $mapper = $self->getClinicalVisitMapper();

  my $metadataFile = $self->getMetadataFile();
  my $baseMetaDataFile = basename $metadataFile;

  my $date;
  if($baseMetaDataFile eq "Prism_tororo.txt") {
    $date = $hash->{date};
  }
  elsif($baseMetaDataFile eq "Prism_samples.txt") {
    $date = $hash->{reqdate};
  }
  else {
    die "File $baseMetaDataFile not handled for makeParent Method";
  }

  my $participant = $hash->{subjectid};
  if($date) {
    my $formattedDate = &formatDate($date);
    
    my $key = "$participant.$formattedDate";
    return $mapper->{$key};
  }

  my $primaryKey = $self->makePrimaryKey($hash);
  die "No Date found for Sample $primaryKey (Participant ID=$participant)\n";

}

# Default is for the tororo file
sub makePrimaryKey {
  my ($self, $hash) = @_;

  my $metadataFile = $self->getMetadataFile();
  my $baseMetaDataFile = basename $metadataFile;

  return $hash->{randomnumber};
}


1;


package ApiCommonData::Load::MetadataReader::PrismLightTrapReader;
use base qw(ApiCommonData::Load::MetadataReader);

use strict;

sub makePrimaryKey {
  my ($self, $hash) = @_;

  return $hash->{uniqueid};
}


sub makeParent {
  my ($self, $hash) = @_;

  return $hash->{hhid};
}

sub getParentPrefix {
  my ($self, $hash) = @_;

  return "HH";
}

1;


package ApiCommonData::Load::MetadataReader::PrismSampleReader::FP;
use base qw(ApiCommonData::Load::MetadataReader::PrismSampleReader);

use strict;

sub makePrimaryKey {
  my ($self, $hash) = @_;

  return $hash->{fp_barcode};
}

1;

package ApiCommonData::Load::MetadataReader::PrismSampleReader::BC;
use base qw(ApiCommonData::Load::MetadataReader::PrismSampleReader);

use strict;

sub makePrimaryKey {
  my ($self, $hash) = @_;

  return $hash->{bc_barcode};
}

1;

package ApiCommonData::Load::MetadataReader::PrismSampleReader::P1;
use base qw(ApiCommonData::Load::MetadataReader::PrismSampleReader);

use strict;

sub makePrimaryKey {
  my ($self, $hash) = @_;

  return $hash->{p1_barcode};
}

1;

package ApiCommonData::Load::MetadataReader::PrismSampleReader::P2;
use base qw(ApiCommonData::Load::MetadataReader::PrismSampleReader);

use strict;

sub makePrimaryKey {
  my ($self, $hash) = @_;

  return $hash->{p2_barcode};
}


1;


