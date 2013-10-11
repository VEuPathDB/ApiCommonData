package ApiCommonData::Load::Plugin::InsertStudyMetaData;

@ISA = qw(GUS::PluginMgr::Plugin);

use GUS::Model::Study::BioMaterialCharacteristic;
use GUS::Model::Study::OntologyEntry;
use GUS::Model::Study::Study;
use GUS::Model::Study::BioSample;
use GUS::Model::RAD::StudyBioMaterial;
use GUS::Model::ApiDB::ProfileSet;
use GUS::Model::ApiDB::ProfileElementName;
# ----------------------------------------------------------------------

use strict;
use GUS::PluginMgr::Plugin;

use Data::Dumper;

my $argsDeclaration =
  [
   stringArg({name           => 'studyName',
            descr          => 'Study Name - Fail if not retrieved',
            reqd           => 1,
            constraintFunc => undef,
            isList         => 0, }),

   stringArg({name           => 'studyExtDbRlsSpec',
            descr          => 'External Database Spec (external_database_name|external_database_version) for the study. In the case of Hts_Snps, this is related to the the experiment , in the case of array type experiments, this is related to the profile_set.',
            reqd           => 0,
            constraintFunc => undef,
            isList         => 0, }),


   stringArg({name           => 'sampleExtDbRlsSpec',
            descr          => 'External Database Spec to be associated with sample(s)',
            reqd           => 0,
            constraintFunc => undef,
            isList         => 0, }),

   stringArg({name           => 'sampleId',
            descr          => 'A sample row can be identified by either the first column or one of the data file columns.  if provided, only data from matching rows will be loaded',
            reqd           => 0,
            constraintFunc => undef,
            isList         => 0, }),

   stringArg({name           => 'sampleExtDbRlsSpecTemplate',
            descr          => 'used for SnpSamples. this template contains a macro for the sample name. when the sample name is substituted into the template, this will be used to look up the sample and add the ext db rls id to study.biosample',
            reqd           => 0,
            constraintFunc => undef,
            isList         => 0, }),
			
   booleanArg({ name  => 'isProfile',
		  descr => 'If true, require an exact match in apidb.profileElementName from a profileset related to the studyExtDbRlsSpec',
		  constraintFunc => undef,
		  reqd           => 0,
		  isList         => 0 }),
      
    
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

  my $studyExtDbRlsSpec = $self->getArg('studyExtDbRlsSpec');
  my $sampleExtDbRlsSpec = $self->getArg('sampleExtDbRlsSpec');
  my $isProfile = $self->getArg('isProfile');
  my $studyExtDbRlsId;
  
  unless($studyExtDbRlsSpec || $sampleExtDbRlsSpec) {
 	$self->error("External database release spec must be provided for the study or the samples");
  }
  
  $studyExtDbRlsId = $self->getExtDbRlsId($studyExtDbRlsSpec) if $studyExtDbRlsSpec;
  my $sampleExtDbRlsSpecTemplate = $self->getArg('sampleExtDbRlsSpecTemplate');
  
  my $useTemplate = $sampleExtDbRlsSpecTemplate ? 1 : 0;
  
 
  if($sampleExtDbRlsSpecTemplate && $sampleExtDbRlsSpec) {
	$self->error("sampleExtDbRlsSpec cannot be used with sampleExtDbRlsSpecTemplate please provided one or the other");
  }
  
  my $studyName = $self->getArg('studyName');
  my $study;
  if($studyExtDbRlsId) {
	$study = GUS::Model::Study::Study->new(
		                           {name => $studyName,
	                                external_database_release_id => $studyExtDbRlsId,	
								   }); 
  }
   else {
    $study = GUS::Model::Study::Study->new(
		                           {name => $studyName
								   }); 
  }
  
  unless($study->retrieveFromDB()) {
    $self->error("Could not retrieve study $studyName from db.");   
  }
  my $profileElementNames=[];
 
  if($isProfile) {
    my $samplesSql = "Select Distinct Pen.Name From Apidb.Profileelementname Pen, Apidb.Profileset Ps Where 
Ps.External_Database_Release_Id = $studyExtDbRlsId";

    my $dbh = $self->getQueryHandle();
    my $stmt = $dbh->prepareAndExecute($samplesSql);

    while(my $profileElementName = $stmt->fetchrow_array()){
      push(@$profileElementNames,$profileElementName);
	} 
  }
  unless (scalar @$profileElementNames) { 
    $self->userError("No samples retrieved for the study external database release spec, please check to make sure that a profile set was load with the external database release id $studyExtDbRlsId.");
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

    if((!$sampleId) ||  ($sampleId && $self->isSampleIdRow($rowAsHash, $sampleId))){
        $self->processRow($rowAsHash, $study, $studyExtDbRlsId, $useTemplate, $profileElementNames, $sampleExtDbRlsSpecTemplate,);
      $count++;
	  }
	  elsif($sampleExtDbRlsSpec) {
		$self->processRow($rowAsHash, $study, $studyExtDbRlsId, $useTemplate, $profileElementNames, $sampleExtDbRlsSpec,);
		$count++;
	  }
	  else {
		$self->processRow($rowAsHash, $study, $studyExtDbRlsId, $useTemplate, $profileElementNames, 0);
		$count++;
	  }

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
  my ($self, $rowAsHash, $study, $studyExtDbRlsId, $useTemplate, $profileElementNames,  $sampleExtDbRlsSpec,) = @_;
  my $sampleName;
  foreach my $key (keys %$rowAsHash) {
	my ($header, $index) = split(/\|/, $key);
	my $value = $rowAsHash->{$key};

	if($header =~ /source name/i) {
		$sampleName = $value;
		last;
	}
  }
  if($useTemplate){
	$sampleExtDbRlsSpec=~s/\@SAMPLE_NAME\@/$sampleName/;
  }
  my $bioSample;
  my $sampleExtDbRlsId = '';
  if($sampleExtDbRlsSpec){
    my $sampleExtDbRlsId = $self->getExtDbRlsId($sampleExtDbRlsSpec) or 
      $self->error("Sample external database Release ID not found for $sampleName with External database release spec $sampleExtDbRlsSpec");
  }
  if ($sampleExtDbRlsId){
    $bioSample = $self->makeBioSample($rowAsHash, $sampleName, $studyExtDbRlsId, $profileElementNames, $sampleExtDbRlsId,);
  }
  else {
    $bioSample = $self->makeBioSample($rowAsHash, $sampleName, $studyExtDbRlsId, $profileElementNames, undef);
  }
  my $studyBioMaterial = GUS::Model::RAD::StudyBioMaterial->new({});

  $studyBioMaterial->setParent($study);
  $studyBioMaterial->setParent($bioSample);

  $bioSample->submit();
}

sub makeBioSample {
  my ($self, $rowAsHash, $sampleName,  $studyExtDbRlsId, $profileElementNames, $sampleExtDbRlsId,) = @_;
          
  	if (scalar @$profileElementNames >=1 ){
	    $self->userError("No sample $sampleName found for this experiment, please check your input file.") unless ( grep( $sampleName, @$profileElementNames ) );
	}

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

  my $bioSample = GUS::Model::Study::BioSample->new({name => $sourceName, 
                                                     source_id => $sourceId,
                                                     description => $description,
                                                     external_database_release_id => $sampleExtDbRlsId,
                                                    });
  
  foreach(@characteristics) {
    $_->setParent($bioSample);
  }

  return $bioSample;
}


sub makeCharacteristic {
  my ($self, $header, $value) = @_;

  my $category;

  if($header =~ /characteristics \[(.+)\]/i) {
    $category = $1;
    print STDERR "$category\n";
  }
  else {
    $self->error("Characteristic header malformed:  $header");
  }

  my $oe;
  my $alt_oe;
  my $characteristic;
  # unless($value=~/^(\d+\.?\d*|\.\d+)$/) {
  #       $oe = GUS::Model::Study::OntologyEntry->new({value => $value,
  #                                                 category => $category});

  #       $oe->retrieveFromDB();
	
  #   $characteristic = GUS::Model::Study::BioMaterialCharacteristic->new({});
  # }
  # else {

    my $oeSql = "With BMCT As (
                        Select Distance, Id, Parent_Id,lower(Category) as category, lower(Value) as value 
                        From (
                            Select level + 0 as distance, Oe.Ontology_Entry_Id as id, Oe.Parent_Id, Oe.Category, Oe.Value
                            From Study.Ontologyentry oe Start With Category = 'BioMaterialCharacteristics'
                            Connect By Prior Value = Category
                            Order By Parent_Id, Id
                         )
                      ),
                      Existing As (
                        Select Distinct Ontology_Entry_Id As Id, Parent_Id, Category, Value 
                        From Study.Ontologyentry
                        Where lower(Category) = lower('$category')
                        And lower(Value) = lower('$value')
                      ),
                      New_Value as (
					    Select Distinct Id, Parent_Id, Category, Bmct.value
						From ( select value,
							          Max(bmct.distance) As distance
							   From Bmct
                               Group By Value
					    ) Sub, Bmct
					    Where lower(Sub.Value)=lower('$category')
						  And Sub.Distance = Bmct.Distance
						  and sub.value = bmct.value
                   )
		   Select Distinct Nvl(Existing.Id,New_Value.Id) as id
		     From Existing, New_Value
                    Where New_Value.Id = Existing.Id (+)";

    my $dbh = $self->getQueryHandle();
    my $stmt = $dbh->prepareAndExecute($oeSql);
    my $oe_id = $stmt->fetchrow_array();

  my $default_category =  'OntologyEntry';

  $oe = GUS::Model::Study::OntologyEntry->new({ontology_entry_id => $oe_id,});
  $characteristic = GUS::Model::Study::BioMaterialCharacteristic->new({value => $value});
 
    $oe->retrieveFromDB() or $self->error("failed for the Characteristic $category, please validate this you Sample file categories agree with the loaded ontology");
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
           'Study.BioSample',
     );
}

1;






