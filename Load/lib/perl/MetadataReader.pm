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

sub getAncillaryData { $_[0]->{_ancillary_data} }
sub setAncillaryData { $_[0]->{_ancillary_data} = $_[1] }

sub cleanAndAddDerivedData {}

sub readAncillaryInputFile {
  die "Ancillary File provided bun no method implemented to read it.";
}

sub applyAncillaryData {
  die "Ancillary File provided bun no method implemented to use it.";
}

sub seen {
  my ($ar, $v) = @_;

  foreach(@$ar) {
    return 1 if($_ eq $v);
  }
  return 0;
}


sub clean {
  my ($self, $ar) = @_;

  for(my $i = 0; $i < scalar @$ar; $i++) {
    my $v = $ar->[$i];

    if($v =~ /^(\")(.*)(\")$/ || $v =~ /^(\')(.*)(\')$/) {
      $ar->[$i] = $2;
    }
  }
  return $ar;
}

sub adjustHeaderArray { 
  my ($self, $ha) = @_;

  return $ha;
}

sub skipIfNoParent { return 0; }

sub getDelimiter { 
  my ($self, $header, $guessDelimter) = @_;

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
  my ($class, $metadataFile, $rowExcludes, $colExcludes, $parentParsedOutput, $ancillaryInputFile) = @_;

  my $self = bless {}, $class;

  $self->setMetadataFile($metadataFile);
  $self->setRowExcludes($rowExcludes);
  $self->setColExcludes($colExcludes);
  $self->setParentParsedOutput($parentParsedOutput);

  if(-e $ancillaryInputFile) {

    my $ancillaryData = $self->readAncillaryInputFile($ancillaryInputFile);

    $self->setAncillaryData($ancillaryData);
  }

  return $self;
}


sub splitLine {
  my ($self, $delimiter, $line) = @_;

  my @a = split($delimiter, $line);

  return wantarray ? @a : \@a;
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

  my @headers = $self->splitLine($delimiter, $header);

  my $headersAr = $self->adjustHeaderArray(\@headers);

  $headersAr = $self->clean($headersAr);



  my $parsedOutput = {};

  while(<FILE>) {
    $_ =~ s/\n|\r//g;

    my @values = $self->splitLine($delimiter, $_);
    my $valuesAr = $self->clean(\@values);

    my %hash;
    for(my $i = 0; $i < scalar @$headersAr; $i++) {
      my $key = lc($headersAr->[$i]);
      my $value = lc($valuesAr->[$i]);

      # TODO: move this to PRISM class clean method
      next if($value eq '[skipped]');

      $hash{$key} = $value if(defined $value);
    }

    my $primaryKey = $self->makePrimaryKey(\%hash);
    my $parent = $self->makeParent(\%hash);

    next if($self->skipIfNoParent() && !$parent);

    my $parentPrefix = $self->getParentPrefix(\%hash);
    my $parentWithPrefix = $parentPrefix . $parent;

    $hash{'__PARENT__'} = $parentWithPrefix unless($parentPrefix && $parentWithPrefix eq $parentPrefix);

    next unless($primaryKey); # skip rows that do not have a primary key
    next if($rowExcludes->{$primaryKey});

    $primaryKey = $self->getPrimaryKeyPrefix(\%hash) . $primaryKey;

    $self->cleanAndAddDerivedData(\%hash);

    foreach my $key (keys %hash) {
      next if($colExcludes->{$fileBasename}->{$key} || $colExcludes->{'__ALL__'}->{$key});
      next unless defined $hash{$key}; # skip undef values
      next if($hash{$key} eq '');

      next if(&seen($parsedOutput->{$primaryKey}->{$key}, $hash{$key}));

      push @{$parsedOutput->{$primaryKey}->{$key}}, $hash{$key};
    }

  }

  close FILE;

  my $rv = {};

  foreach my $primaryKey (keys %$parsedOutput) {

    foreach my $key (keys %{$parsedOutput->{$primaryKey}}) {

      my @values = @{$parsedOutput->{$primaryKey}->{$key}};

      for(my $i = 0; $i < scalar @values; $i++) {
        my $value = $values[$i];

        my $newKey = $i == 0 ? $key : "${key}_$i";
        $rv->{$primaryKey}->{$newKey} = $values[$i];
      }
    }
  }


  $self->setParsedOutput($rv);
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

use Data::Dumper;

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


sub cleanAndAddDerivedData {
  my ($self, $hash) = @_;

  # if($hash->{malariacat} eq "negative blood smear") {
  #   if($hash->{lamp} eq 'positive') {
  #     $hash->{malariacat} = "Sub-microscopic parasitemia";    
  #   }
  #   elsif($hash->{lamp} eq "negative") {
  #     $hash->{malariacat} = "Negative blood smear and negative LAMP";    
  #   }
  #   else {
  #     $hash->{malariacat} = "Negative blood smear and LAMP not done";
  #   }
  # }

  my @symptomsAndSigns = (['abdominalpain', 'apainduration'],
                          ['anorexia', 'aduration'],
                          ['cough', 'cduration'],
                          ['diarrhea', 'dduration'],
                          ['fatigue', 'fmduration'],
                          ['fever', 'fduration'],
                          ['headache', 'hduration'],
                          ['jaundice', 'jduration'],
                          ['jointpains', 'djointpains'],
                          ['muscleaches', 'mduration'],
                          ['seizure', 'sduration'],
                          ['vomiting', 'vduration']
      );


  foreach my $ar(@symptomsAndSigns) {
    my $ss = $ar->[0];
    my $dur = $ar->[1];

    $hash->{$dur} = '0' if($hash->{$ss} eq '0' || lc($hash->{$ss}) eq 'no');
  }


  if($hash->{anymalaria} != 1) {
    $hash->{complicatedmalaria} = undef;
  }

  if($hash->{complicatedmalaria} != 1) {
    $hash->{cmcategory} = undef;
  }

  foreach my $key (keys %$hash) {
    if($key =~ /^med\d*code$/) {

      # these 3 are the malaria ones
      if($hash->{$key} eq '40' || $hash->{$key} eq '41' || $hash->{$key} eq '50') {

        my $newKey = $key . "_malaria";

        $hash->{$newKey} = $hash->{$key};

        delete $hash->{$key};
      }
    }
  }



}


1;

package ApiCommonData::Load::MetadataReader::PrismSampleReader;
use base qw(ApiCommonData::Load::MetadataReader);

use strict;

use ApiCommonData::Load::MetadataReader;

use Date::Manip qw(Date_Init ParseDate UnixDate);

use File::Basename;


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

    if($pk =~ /\w\w(\d)-/i) {
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

use Data::Dumper;


sub cleanAndAddDerivedData {
  my ($self, $hash) = @_;

  if($hash->{date}) {
    $hash->{collectiondate} = $hash->{date};
  }
  else {
    $hash->{collectiondate} = $hash->{collectionmonthyear};
  }
}


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


package ApiCommonData::Load::MetadataReader::HbgdReader;
use base qw(ApiCommonData::Load::MetadataReader);

use strict;


use Data::Dumper;

sub clean {
  my ($self, $ar) = @_;

  my $clean = $self->SUPER::clean($ar);

  for(my $i = 0; $i < scalar @$clean; $i++) {

    my $v = $clean->[$i];

    if(lc($v) eq 'na') {
      $clean->[$i] = undef;
    }
  }
  return $clean;

}

sub adjustHeaderArray { 
  my ($self, $ha) = @_;

  my @headers = map { $_ =~ s/\"//g; $_;} @$ha;

  unless($headers[0] eq "PRIMARY_KEY") {
    unshift @headers, "R_PRIMARY_KEY";
  }
  return \@headers;
}

1;

package ApiCommonData::Load::MetadataReader::HbgdSitesReader;
use base qw(ApiCommonData::Load::MetadataReader::HbgdReader);

use strict;


sub makePrimaryKey {
  my ($self, $hash) = @_;

  return $hash->{siteid};
}

sub makeParent {}


1;

package ApiCommonData::Load::MetadataReader::HbgdDwellingReader;
use base qw(ApiCommonData::Load::MetadataReader::HbgdReader);

use strict;

use Data::Dumper;

sub makeParent {
  return undef;
}

sub makePrimaryKey {
  my ($self, $hash) = @_;

  if($hash->{"primary_key"}) {
    return uc $hash->{"primary_key"};
  }

  return $hash->{subjid};
}

sub getPrimaryKeyPrefix {
  my ($self, $hash) = @_;

  unless($hash->{"primary_key"}) {
    return "HBGDHH_";
  }

  return "";
}


sub cleanAndAddDerivedData {
  my ($self, $hash) = @_;

  my $country = $hash->{country};
  my $citytown = $hash->{citytown};

  if($citytown) {
    $country = "united republic of tanzania" if($country eq "tanzania, united republic of");

    my $ucCountry = join(" ", map { length($_) > 2 ? ucfirst : $_ } split(/\s+/, $country));
    my $ucCityTown = join(" ", map { length($_) > 2 ? ucfirst : $_ } split(/\s+/, $citytown)) . ", $ucCountry";

    $hash->{citytown} = $ucCityTown;
  }
}


1;



package ApiCommonData::Load::MetadataReader::HbgdSSReader;
use base qw(ApiCommonData::Load::MetadataReader::HbgdDwellingReader);

use strict;

use ApiCommonData::Load::MetadataReader;


sub readAncillaryInputFile {
  my ($self, $file) = @_;

  my %rv;

  open(FILE, $file) or die "Cannot open file $file for reading:$!";

  my $header = <FILE>;
  $header =~s/\n|\r//g;

  my $delimiter = $self->getDelimiter($header);
  my @headers = split($delimiter, $header);
  my $headersAr = $self->adjustHeaderArray(\@headers);
  $headersAr = $self->clean($headersAr);

  my ($prevSubjid, %firstAgedays);

  while(<FILE>) {
    $_ =~ s/\n|\r//g;

    my @values = split($delimiter, $_);
    my $valuesAr = $self->clean(\@values);

    my %hash;
    for(my $i = 0; $i < scalar @$headersAr; $i++) {
      my $header = $headersAr->[$i];
      my $value = $valuesAr->[$i];

      $hash{$header} = $value;
    }

    my $subjid = $hash{subjid};
    my $agedays = $hash{agedays};

    # newsubjid
    if($subjid ne $prevSubjid) {
      $firstAgedays{$subjid} = $agedays;
    }

    if($firstAgedays{$subjid} == $agedays) {
      if($hash{ssstresc} ne "") {
        $rv{$subjid}->{$hash{sstestcd}} = $hash{ssstresc};
      }
      else {
        $rv{$subjid}->{$hash{sstestcd}} = $hash{ssstresn};
        $rv{$subjid}->{$hash{sstestcd}} .= " " . $hash{ssstresu} if($hash{ssstresu});
      }
    }
    $prevSubjid = $subjid;
  }

  return \%rv;
}


sub cleanAndAddDerivedData {
  my ($self, $hash) = @_;

  my $ancillaryData = $self->getAncillaryData();

  my $subjid = $hash->{subjid};

  my $ssData = $ancillaryData->{$subjid};

  foreach my $key(keys %$ssData) {
    next if($key eq '__PARENT__' || $key eq 'primary_key');

    my $value = $ssData->{$key};

    $hash->{$key} = $value;
  }
}



1;

package ApiCommonData::Load::MetadataReader::HbgdParticipantSitesReader;
use base qw(ApiCommonData::Load::MetadataReader::HbgdDwellingReader);

use strict;

use ApiCommonData::Load::MetadataReader;

sub readAncillaryInputFile {
  my ($self, $file) = @_;

  my $sitesReader = ApiCommonData::Load::MetadataReader::HbgdSitesReader->new($file, undef, undef, undef, undef);  
  return $sitesReader->read();
}



sub cleanAndAddDerivedData {
  my ($self, $hash) = @_;

  my $ancillaryData = $self->getAncillaryData();

  my $siteid = $hash->{siteid};

  my $site = $ancillaryData->{$siteid};
  foreach my $key(keys %$site) {
    next if($key eq '__PARENT__' || $key eq 'primary_key');

    my $value = $site->{$key};

    $hash->{$key} = $value;
  }
}


1;



package ApiCommonData::Load::MetadataReader::HbgdParticipantReader;
use base qw(ApiCommonData::Load::MetadataReader::HbgdReader);

use strict;


sub getParentPrefix {
  my ($self, $hash) = @_;

  unless($hash->{"parent"}) {
    return "HBGDHH_";
  }
  return "";


}

sub makeParent {
  my ($self, $hash) = @_;

  if($hash->{parent}) {
    return $hash->{parent};
  }

  return $hash->{subjid};
}

sub makePrimaryKey {
  my ($self, $hash) = @_;


  if($hash->{"primary_key"}) {
    return $hash->{"primary_key"};
  }

  return $hash->{subjid};
}

sub getPrimaryKeyPrefix {
  my ($self, $hash) = @_;


  unless($hash->{"primary_key"}) {
    return "HBGDP_";
  }

  return "";
}


1;

package ApiCommonData::Load::MetadataReader::HbgdEventReader;
use base qw(ApiCommonData::Load::MetadataReader::HbgdReader);

use strict;

use File::Basename;


sub eventType {
  my ($self) = @_;


  if($self->{_event_type}) {
    return $self->{_event_type};
  }

  my $rv;

  my $metadataFile = $self->getMetadataFile();

  my $baseMetaDataFile = basename $metadataFile;


  if($baseMetaDataFile eq 'episodes.txt' || $baseMetaDataFile eq 'DAILY.txt') {
    $rv = "DE";
  }
  elsif($baseMetaDataFile eq 'ANTHRO.txt') {
    $rv = "V";
  }
  else {
    $rv = "TR";
  }

  $self->{_event_type} = $rv;

  return $rv;
}



sub cleanAndAddDerivedData {
  my ($self, $hash) = @_;

  my $eventType = $self->eventType();

  my %eventTypes = ( "DE" => "Diarrhea Episode",
                     "V" => "Anthropometry",
                     "TR" => "Laboratory Test",
      );

  # Event Type
  $hash->{event_type} = $eventTypes{$eventType};

  # MB File
  if($hash->{mbstresc}) {
    my $value = $hash->{mbstresc};
    my $key = $hash->{mbtestcd};

    if($value eq 'positive') {
      $value = 'yes';
    }

    $hash->{$key} = $value;



#    $hash->{$key."_mbspec"} = $hash->{mbspec};
#    $hash->{$key."_mbmethod"} = $hash->{mbmethod};
  }

  # LB File
  if($hash->{lbstresn}) {
    my $value = $hash->{lbstresn};
    my $key = $hash->{lbtestcd};


    if($hash->{'lbspec'} eq 'plasma') {
      $hash->{'lbspec'} = 'blood';
    }

    $hash->{$key} = $value;
#    $hash->{$key."_lbspec"} = $hash->{lbspec};
  }


  # GF File
  if($hash->{gfstresc}) {
    $hash->{'specimentype'} = 'stool';
  }

}


sub getParentPrefix {
  my ($self, $hash) = @_;

  unless($hash->{"parent"}) {
    return "HBGDP_";
  }
  return "";
}

sub makeParent {
  my ($self, $hash) = @_;

  if($hash->{parent}) {
    return $hash->{parent};
  }

  return $hash->{subjid};
}

sub makePrimaryKey {
  my ($self, $hash) = @_;

  if($hash->{"primary_key"}) {
    return $hash->{"primary_key"};
  }

  # no events after 2 years
  return undef if($hash->{agedays} > 745);

  return $hash->{subjid} . "_" . $hash->{agedays};
}

sub getPrimaryKeyPrefix {
  my ($self, $hash) = @_;

  unless($hash->{"primary_key"}) {
    return "HBGD_" . $self->eventType() . "_";
  }
  return "";
}


1;


package ApiCommonData::Load::MetadataReader::HbgdDailyReader;
use base qw(ApiCommonData::Load::MetadataReader::HbgdEventReader);

use strict;
use ApiCommonData::Load::MetadataReader;


sub read {
  my ($self) = @_;

  my $metadataFile = $self->getMetadataFile();

  open(FILE, $metadataFile) or die "Cannot open file $metadataFile for reading: $!";

  my $rv = {};

  my $header = <FILE>;
  $header =~s/\n|\r//g;

  my $delimiter = $self->getDelimiter($header);
  my @headers = split($delimiter, $header);
  my $headersAr = $self->adjustHeaderArray(\@headers);
  $headersAr = $self->clean($headersAr);

  my $parsedOutput = {};

  my ($prevSubjid, $prevDay, %episode);

  while(<FILE>) {
    $_ =~ s/\n|\r//g;

    my @values = split($delimiter, $_);
    my $valuesAr = $self->clean(\@values);

    my %hash;
    for(my $i = 0; $i < scalar @$headersAr; $i++) {
      my $key = lc($headersAr->[$i]);
      my $value = lc($valuesAr->[$i]);

      $hash{$key} = $value;
    }

    my $diarfl = $hash{"diarfl"};

    if($hash{subjid} ne $prevSubjid || !$diarfl) {
      if($prevDay) {

        my $primaryKeyPrefix = $self->getPrimaryKeyPrefix(\%episode);
        my $primaryKey = $self->makePrimaryKey(\%episode);

        $primaryKey = $primaryKeyPrefix . $primaryKey;

        my %episodeCopy = %episode;
        $episodeCopy{bldstlfl} = 0 unless($episodeCopy{bldstlfl});
        $episodeCopy{numls} = 0 unless($episodeCopy{numls});
        $episodeCopy{avg_numls} = 0 unless($episodeCopy{avg_numls});
        
        $rv->{$primaryKey} = \%episodeCopy;
      }

      %episode = ();
    }

    if($diarfl) {

      if(!$prevDay) {
        $episode{agedays} = $hash{agedays};
        $episode{subjid} = $hash{subjid};
      }


      $episode{duration}++;
      $episode{bldstlfl}++ if($hash{bldstlfl});
      $episode{numls} = $episode{numls} + $hash{numls};
      $episode{avg_numls} = $episode{numls} / $episode{duration};
    }

#          'subjid' => '1',
#          'agedays' => '20',
#          'diarfl' => '0',
#         'bldstlfl' => '0',
#          'numls' => '0'



    $prevDay = $hash{diarfl};
    $prevSubjid = $hash{subjid};
  }

  if($prevDay) {
    my $primaryKeyPrefix = $self->getPrimaryKeyPrefix(\%episode);
    my $primaryKey = $self->makePrimaryKey(\%episode);

    $primaryKey = $primaryKeyPrefix . $primaryKey;

    my %episodeCopy = %episode;
    $episodeCopy{bldstlfl} = 0 unless($episodeCopy{bldstlfl});
    $episodeCopy{numls} = 0 unless($episodeCopy{numls});
    $episodeCopy{avg_numls} = 0 unless($episodeCopy{avg_numls});

    $rv->{$primaryKey} = \%episodeCopy;
  }

  $self->setParsedOutput($rv);
}




1;





