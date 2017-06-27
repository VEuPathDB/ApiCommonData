package ApiCommonData::Load::MetadataReader;

use strict;

use File::Basename;

use Data::Dumper;

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

sub skipIfNoParent { return 0; }

sub getDelimiter { 
  my ($self, $header) = @_;

  if($header) {
    if($header =~ /\t/) {
      return qr/\t/;
    }
    else {
      return qr/,/;
    }
  }

  die "Must provide header row to determine the delimiter OR override this function";
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



  my $colExcludes = $self->getColExcludes();
  my $rowExcludes = $self->getRowExcludes();

  my $fileBasename = basename $metadataFile;

  open(FILE, $metadataFile) or die "Cannot open file $metadataFile for reading: $!";

  my $header = <FILE>;
  $header =~s/\n|\r//g;

  my $delimiter = $self->getDelimiter($header);

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

    next if($self->skipIfNoParent() && !$parent);

    my $parentPrefix = $self->getParentPrefix();
    my $parentWithPrefix = $parentPrefix . $parent;

    $hash{'__PARENT__'} = $parentWithPrefix unless($parentPrefix && $parentWithPrefix eq $parentPrefix);

    next unless($primaryKey); # skip rows that do not have a primary key
    next if($rowExcludes->{$primaryKey});

    $primaryKey = $self->getPrimaryKeyPrefix(\%hash) . $primaryKey;

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

  if($hash->{"primary_key"}) {
    return $hash->{"primary_key"};
  }

  return $hash->{hhid};
}

sub getPrimaryKeyPrefix {
  my ($self, $hash) = @_;

  unless($hash->{"primary_key"}) {
    return "HH";
  }
  return "";
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

  if($hash->{"primary_key"}) {
    return $hash->{"primary_key"};
  }

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

  if($hash->{parent}) {
    return $hash->{parent};
  }
  
  return $hash->{id};
}

sub makePrimaryKey {
  my ($self, $hash) = @_;

  if($hash->{"primary_key"}) {
    return $hash->{"primary_key"};
  }

  return $hash->{uniqueid};
}

1;

package ApiCommonData::Load::MetadataReader::PrismSampleReader;
use base qw(ApiCommonData::Load::MetadataReader);

use strict;

use ApiCommonData::Load::MetadataReader;

use Date::Manip qw(Date_Init ParseDate UnixDate);

use File::Basename;

use Data::Dumper;

sub skipIfNoParent { return 1; }

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

      # not sure why can't just grab the primarykey here??
#    my $clinicalVisitPrimaryKey = $clinicalVisitsParsedOutput->{$uniqueid}->{'primary_key'} 
      my $participant = $clinicalVisitsParsedOutput->{$uniqueid}->{'__PARENT__'}; # the parent of the clinical visit is the participant
      my $date = $clinicalVisitsParsedOutput->{$uniqueid}->{'date'};
      my $admitdate = $clinicalVisitsParsedOutput->{$uniqueid}->{'admitdate'};
      my $dischargedate = $clinicalVisitsParsedOutput->{$uniqueid}->{'dischargedate'};

      my $hasDate;

      if($date) {
        my $formattedDate = &formatDate($date);
        my $key = "$participant.$formattedDate";

        $clinicalVisitMapper->{$key} = $uniqueid;
      }

      if($admitdate) {
        my $formattedDate = &formatDate($admitdate);
        my $key = "$participant.$formattedDate";
        $clinicalVisitMapper->{$key} = $uniqueid;
      }

      if($dischargedate) {
        my $formattedDate = &formatDate($dischargedate);
        my $key = "$participant.$formattedDate";
        $clinicalVisitMapper->{$key} = $uniqueid;
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
  
  if($hash->{randomnumber}) {
    return $hash->{subjectid}  . $hash->{randomnumber};
  }
  return undef;
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
  
  if($hash->{fp_barcode} && $hash->{fp_barcode} !~ /^SKIP/i ) {
    return $hash->{subjectid}  . $hash->{fp_barcode};
  }
  return undef;
}

1;

package ApiCommonData::Load::MetadataReader::PrismSampleReader::BC;
use base qw(ApiCommonData::Load::MetadataReader::PrismSampleReader);

use strict;

sub makePrimaryKey {
  my ($self, $hash) = @_;

  if($hash->{bc_barcode} && $hash->{bc_barcode} !~ /^SKIP/i ) {
    return $hash->{subjectid}  . $hash->{bc_barcode};
  }
  return undef;
}

1;

package ApiCommonData::Load::MetadataReader::PrismSampleReader::P1;
use base qw(ApiCommonData::Load::MetadataReader::PrismSampleReader);

use strict;

sub makePrimaryKey {
  my ($self, $hash) = @_;

  if($hash->{p1_barcode} && $hash->{p1_barcode} !~ /^SKIP/i ) {
    return $hash->{subjectid}  . $hash->{p1_barcode};
  }
  return undef;
}

1;

package ApiCommonData::Load::MetadataReader::PrismSampleReader::P2;
use base qw(ApiCommonData::Load::MetadataReader::PrismSampleReader);

use strict;

sub makePrimaryKey {
  my ($self, $hash) = @_;

  if($hash->{p2_barcode} && $hash->{p2_barcode} !~ /^SKIP/i ) {
    return $hash->{subjectid}  . $hash->{p2_barcode};
  }
  return undef;
}


1;


