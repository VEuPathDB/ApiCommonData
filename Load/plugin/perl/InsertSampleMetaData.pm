package ApiCommonData::Load::Plugin::InsertSampleMetaData;

@ISA = qw(GUS::PluginMgr::Plugin);

use GUS::Model::Study::BioSource;
use GUS::Model::Study::BioMaterialCharacteristic;
use GUS::Model::Study::OntologyEntry;
use GUS::Model::Study::Study;
use GUS::Model::RAD::StudyBioMaterial;
# ----------------------------------------------------------------------

use strict;
use GUS::PluginMgr::Plugin;

my $argsDeclaration =
  [
   stringArg({name           => 'studyName',
            descr          => 'Study Name - Fail if not retrieved',
            reqd           => 1,
            constraintFunc => undef,
            isList         => 0, }),

   stringArg({name           => 'extDbRlsSpec',
            descr          => 'External Database Spec to be associated with sample(s)',
            reqd           => 1,
            constraintFunc => undef,
            isList         => 0, }),

   stringArg({name           => 'sampleId',
            descr          => 'A sample row can be identified by either the first column or one of the data file columns.  if provided, only data from matching rows will be loaded',
            reqd           => 0,
            constraintFunc => undef,
            isList         => 0, }),
            
   fileArg({name           => 'file',
            descr          => 'file for the sample data',
            reqd           => 1,
            mustExist      => 1,
            format         => '',
            constraintFunc => undef,
            isList         => 0, }),
  ];


my $documentation = { purpose          => "",
                      purposeBrief     => "",
                      notes            => "",
                      tablesAffected   => "",
                      tablesDependedOn => "",
                      howToRestart     => "",
                      failureCases     => "" };

# ----------------------------------------------------------------------

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  $self->initialize({ requiredDbVersion => 3.6,
                      cvsRevision       => '$Revision$',
                      name              => ref($self),
                      argsDeclaration   => $argsDeclaration,
                      documentation     => $documentation});

  return $self;
}

# ======================================================================

sub run {
  my ($self) = @_;

 my $extDbRlsSpec = $self->getArg('extDbRlsSpec');
 my $extDbRlsId = $self->getExtDbRlsId($extDbRlsSpec);
 
 my $studyName = $self->getArg('studyName');
 my $study = GUS::Model::Study::Study->new({name => $studyName}); 

  unless($study->retrieveFromDB()) {
    $self->error("Could not retrieve study $studyName from db");   
  }
  
  my $file = $self->getArg('file');
  open(FILE, $file) or $self->error("Cannot open file $file for reading: $!");


  my $sampleId = $self->getArg('sampleId');
  
  my $header = <FILE>;
  chomp $header;

  $self->validateHeader($header);


  my $count = 0;
  while(<FILE>) {
    chomp;

    my $rowAsHash = $self->parseRow($header, $_);

    if(!$sampleId) {
      $self->processRow($rowAsHash, $study, $extDbRlsId);
      $count++;
    }

    if($sampleId && $self->isSampleIdRow($rowAsHash, $sampleId)) {
      $self->processRow($rowAsHash, $study, $extDbRlsId);
      $count++;
    }
  }
  close FILE;


  if($count < 1) {
    $self->userError("No rows processed. Please check your input file.");
  }

 return("Processed $count rows of sample meta data.");
}


sub validateHeader {
  my ($self, $header) = @_;

  my @columns = split(/\t/, $header);

  my @requiredCharacteristics = ('Organism',
                                 'StrainOrLine',
                                 'BioSourceType', #IsolationSource
                                 'Host',
                                 'GeographicLocation',
                                );

  foreach my $r (@requiredCharacteristics) {
    my @found =  map {/Characteristics\s?\[($r)\]/} @columns;
    unless(scalar @found > 0) {
      $self->userError("Required Column [$r] not found in the meta data file");
    }
  }
}


sub processRow {
  my ($self, $rowAsHash, $study, $extDbRlsId) = @_;


  my $bioSource = $self->makeBioSource($rowAsHash, $extDbRlsId);


  my $studyBioMaterial = GUS::Model::RAD::StudyBioMaterial->new({});

  $studyBioMaterial->setParent($study);
  $studyBioMaterial->setParent($bioSource);

  $bioSource->submit();
}


sub makeBioSource {
  my ($self, $rowAsHash, $extDbRlsId) = @_;

  #Source Name     Description     Comment [source_id]     Characteristics [Organism]      Data File 

  my ($sourceName, $description, $sourceId);

  my @characteristics;

  foreach my $key (keys %$rowAsHash) {
    my ($header, $index) = split(/\|/, $key);

    my $value = $rowAsHash->{$key};

    if($header =~ /source name/i) {
      $sourceName = $value;
    }

    if($header =~ /description/i) {
      $description = $value
    }

    if($header =~ /comment \[source_id\]/i) {
      $sourceId = $value;
    }

    if($header =~ /characteristics/i) {
      my $characteristic = $self->makeCharacteristic($header, $value);
      push(@characteristics, $characteristic);
    }
  }

  my $bioSource = GUS::Model::Study::BioSource->new({name => $sourceName, 
                                                     source_id => $sourceId,
                                                     description => $description,
                                                     external_database_release_id => $extDbRlsId,
                                                    });
  
  foreach(@characteristics) {
    $_->setParent($bioSource);
  }

  return $bioSource;
}


sub makeCharacteristic {
  my ($self, $header, $value) = @_;

  my $category;

  if($header =~ /characteristics \[(.+)\]/i) {
    $category = $1;
  }
  else {
    $self->error("Characteristic header malformed:  $header");
  }

  my $categoryOE = GUS::Model::Study::OntologyEntry->new({value => $category,
                                                         category => 'BioMaterialCharacteristics'});

  # if it doesn't already exist... submit it
  unless($categoryOE->retrieveFromDB()) {
    $categoryOE->submit();
  }

  my $oe = GUS::Model::Study::OntologyEntry->new({value => $value,
                                                  category => $category});

  $oe->setParent($categoryOE);
  $oe->retrieveFromDB();
  my $characteristic = GUS::Model::Study::BioMaterialCharacteristic->new({});

  $characteristic->setParent($oe);

  return $characteristic;
}



sub isSampleIdRow {
  my ($self, $rowAsHash, $sampleId) = @_;

  my @searchColumns = ('Source Name', 'Data File');

  foreach my $target (keys %$rowAsHash) {
    my ($header, $index) = split(/\|/, $target);

    foreach my $query (@searchColumns) {
      if(lc($query) eq lc($header) && lc($sampleId) eq lc($rowAsHash->{$target})) {
        return 1;
      }
    }
  }
  return 0;
}




sub parseRow {
  my ($self, $header, $row) = @_;

  my @keys = split(/\t/, $header);
  my @values = split(/\t/, $row);

  unless(scalar @keys == scalar @values) {
    $self->error("Mismatched number of headers and data columns");
  }

  my %rv;

  for(my $i = 0; $i < scalar @keys; $i++) {
    my $header = $keys[$i];
    my $value = $values[$i];
    
    my $key = "$header|$i";

    $rv{$key} = $value;
  }

  return \%rv;
}



sub undoTables {
  my ($self) = @_;

  return ( 'Study.BioMaterialCharacteristic',
           'RAD.StudyBioMaterial',
           'Study.BioSource',
     );
}

1;






