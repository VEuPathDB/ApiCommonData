package ApiCommonData::Load::Plugin::CreateSageTagNormalizationFiles;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use GUS::PluginMgr::Plugin;

use GUS::Model::Study::Study;
use GUS::Model::Study::OntologyEntry;

use GUS::Model::RAD::SAGETag;
use GUS::Model::RAD::SAGETagResult;
use GUS::Model::RAD::Protocol;
use GUS::Model::RAD::ProtocolParam;
use GUS::Model::RAD::LogicalGroup;
use GUS::Model::RAD::LogicalGroupLink;

use GUS::Model::Core::UserInfo;

use GUS::Model::SRes::Contact;

use GUS::ObjRelP::DbiDatabase;

$| = 1;

# ---------------------------------------------------------------------------
# Load Arguments
# ---------------------------------------------------------------------------

sub getArgumentsDeclaration{
  my $argsDeclaration =
    [
     stringArg({name => 'studyName',
              descr => 'Study.Study.name linked to the set of assays that will be analyzed',
              constraintFunc=> undef,
              reqd  => 1,
              isList => 0,
             }),
     stringArg({name => 'assayToDisplayMapping',
              descr => 'ASSAY_NAME_1|DISPLAY_NAME_1,...',
              constraintFunc=> undef,
              reqd  => 0,
              isList => 1,
             }),
     integerArg({name  => 'paramValue',
                 descr => 'value used in the function (raw frequency X paramValue)/total raw frequencies in library',
                 constraintFunc=> undef,
                 reqd  => 1,
                 isList => 0
                }),
     stringArg({name => 'fileDir',
		descr => 'directory path for subdir for this studyName containg all the assay data and cfg files',
		constraintFunc=> undef,
		reqd  => 1,
		isList => 0
	       }),
    ];
  return $argsDeclaration;
}

# ----------------------------------------------------------------------
# Documentation
# ----------------------------------------------------------------------

sub getDocumentation {
  my $purposeBrief = "Creates cfg files and normalized data files for each assay in a Sage Tag frequency study for use by GUS::Supported::Plugin::InsertRadAnalysis.";

  my $purpose = "Generates a cfg and normalized data file for each assay in a SAGE tage frequency study putting the files in a subdir with name=studyName.Files are formatted and appropriate for use by GUS::Supported::Plugin::InsertRadAnalysis.";

  my $tablesAffected = [['RAD::Protocol', 'Row created only if missing'],['RAD::ProtocolParam', 'Row created only if missing'],['RAD::LogicalGroup','One row created per assay'],['RAD::LogicalGroupLink', 'One row created per assay'],['SRes::Contact', 'The researcher or organization who performed this analysis,created only if missing']];

  my $tablesDependedOn = [['SRes::Contact', 'The researcher or organization who performed this analysis'], ['RAD::Protocol',  'The analysis protocol used'], ['Study::OntologyEntry', 'The protocol_type of the protocol used'],['RAD::ProtocolParam', 'The  parameters for the protocol used or for its components']];

  my $howToRestart = "No additional input for restart. Database rows will not be duplicated but all data and cfg files will be rewritten.";

  my $failureCases = "";

  my $notes = "";

  my $documentation = {purpose=>$purpose, purposeBrief=>$purposeBrief, tablesAffected=>$tablesAffected, tablesDependedOn=>$tablesDependedOn, howToRestart=>$howToRestart, failureCases=>$failureCases,notes=>$notes};

  return $documentation;
}

# ----------------------------------------------------------------------
# create and initalize new plugin instance.
# ----------------------------------------------------------------------

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  my $documentation = &getDocumentation();
  my $argumentDeclaration = &getArgumentsDeclaration();


  $self->initialize({requiredDbVersion => 3.5,
		     cvsRevision => '$Revision$',
                     name => ref($self),
                     revisionNotes => '',
                     argsDeclaration => $argumentDeclaration,
                     documentation => $documentation});

  return $self;
}

# ----------------------------------------------------------------------
# run method to do the work
# ----------------------------------------------------------------------

sub run {
  my ($self) = @_;

  $self->logAlgInvocationId();
  $self->logCommit();
  $self->logArgs();

  my $displayNameMap = $self->makeDisplayNameHash();

  my $protocolId = $self->getProtocolId();

  my ($protParamId) = $self->getProtocolParamId($protocolId);

  my $assays = $self->getAssays();

  my $fileSets = $self->makeFiles($protParamId,$assays,$protocolId, $displayNameMap);

  my $resultDescrip = "$fileSets assay cfg and data file sets made";

  $self->setResultDescr($resultDescrip);
  $self->logData($resultDescrip);
}

sub makeDisplayNameHash {
  my ($self) = @_;

  my %rv;

  my $names = $self->getArg('assayToDisplayMapping');

  return unless($names);

  foreach(@$names) {
    my ($assayName, $displayName) = split(/\|/, $_);

    $rv{$assayName} = $displayName;
  }
  return \%rv;
}

sub getProtocolId {
  my ($self) = @_;

  my $ontologyEntry = GUS::Model::Study::OntologyEntry->new({
                           "value" => 'total_intensity_normalization_single',
			   "category" => 'DataTransformationProtocolType',
			   });

  if (!$ontologyEntry->retrieveFromDB()){
    $ontologyEntry->submit();
    $self->log("Submitted entry for Study.OntologyEntry: value => 'total_intensity_normalization_single', category => 'DataTransformationProtocolType'");
  }

  my $ontologyEntryId = $ontologyEntry->getOntologyEntryId();

  my $protocol = GUS::Model::RAD::Protocol->new({
                      'protocol_type_id'=>$ontologyEntryId,
		      'name'=>'Normalization of SAGE tag frequencies to a target total intensity',
                      'protocol_description'=>'For each raw frequency in library X, the normalized frequency is computed by TG * raw frequency / total raw frequencies in library X, where TG is the target total intensity.',
		      });

  if (! $protocol->retrieveFromDB()) {
    $protocol->submit();
  }

  my $protocolId = $protocol->getId();

  return $protocolId;
}

sub getProtocolParamId {
  my ($self,$protocolId) = @_;

  my $ontologyEntry = GUS::Model::Study::OntologyEntry->new({
                           "value" => 'positive_float',
			   "category" => 'DataType',
			   });

  if (!$ontologyEntry->retrieveFromDB()){
    $ontologyEntry->submit();
    $self->log("Submitted entry for Study.OntologyEntry: value => 'positive_float', category => 'DataType'");
  }

  my $ontologyEntryId = $ontologyEntry->getOntologyEntryId();


  my $protocolParam = GUS::Model::RAD::ProtocolParam->new({
				       'data_type_id'=>$ontologyEntryId,
				       'name'=>'target total intensity',
				       'protocol_id'=>$protocolId,
				       });

  if (! $protocolParam->retrieveFromDB()) {
    $protocolParam->submit();
  }

  my $protocolParamId = $protocolParam->getId();

  return ($protocolParamId,$protocolId) ;
}

sub getAssays {
  my ($self) = @_;

  my $studyName = $self->getArg('studyName');

  my $study = GUS::Model::Study::Study->new({'name'=>$studyName});

  if (! $study->retrieveFromDB()) {
    $self->error("There is no Study.Study with name =  $studyName\n");
  }

  my @studyAssay = $study->getChildren('GUS::Model::RAD::StudyAssay',1);

  if (@studyAssay < 1) {
    $self->error("There are no Rad.StudyAssay rows for Study.Study.name =  $studyName\n");
  }

  my @assays;

  foreach my $stAss (@studyAssay) {
    my $ass = $stAss->getParent('GUS::Model::RAD::Assay', 1);

    push(@assays,$ass);
  }

  return \@assays;
}

sub makeFiles {
  my ($self,$protocolParamId,$assays,$protocolId, $displayNameMap) = @_;

  my $fileSets;

  foreach my $ass (@$assays) {

    my $assName = $ass->getName();

    my $logicalGroup = $self->makeLogicalGroup($ass, $displayNameMap);
    my $logicalGroupId = $logicalGroup->getId();

    my ($tagFreqs,$total) = $self->getTagFreqs($ass);

    $self->makeDataFile($ass,$tagFreqs,$total);

    $self->makeCfgFile($protocolParamId,$logicalGroupId,$ass,$protocolId);

    $fileSets++;
  }

  return $fileSets;
}

sub makeLogicalGroup {
  my ($self,$ass, $displayNameMap) = @_;

  my $assName = $ass->getName();

  my $name;
  if($displayNameMap->{$assName}) {
    $name = $displayNameMap->{$assName};
  }
  else {
    my $studyName = $self->getArg('studyName');

    $name = $studyName . "_" . $assName;
  }

  my $logicalGroup = GUS::Model::RAD::LogicalGroup->new({'name'=>$name,'category'=>'quantification'});

  $logicalGroup->retrieveFromDB();

  my $logicalGroupLink = $logicalGroup->getChild('GUS::Model::RAD::LogicalGroupLink',1) ? $logicalGroup->getChild('GUS::Model::RAD::LogicalGroupLink') : $self->makeLogicalGroupLink ($ass);

  $logicalGroup->addChild($logicalGroupLink);

  $logicalGroup->submit();

  return $logicalGroup;
}

sub makeLogicalGroupLink {
  my ($self,$ass) = @_;

  my $assId = $ass->getId();

  my $tableId = $ass->getTableIdFromTableName('GUS::Model::RAD::Assay');

  my $logicalGroupLink = GUS::Model::RAD::LogicalGroupLink->new({'row_id'=>$assId,'table_id'=>$tableId});

  $logicalGroupLink->retrieveFromDB();

  return $logicalGroupLink;
}

sub getTagFreqs {
  my ($self,$ass) = @_;

  my $assId = $ass->getId();

  my $dbh = $self->getQueryHandle();

  my $stmt = $dbh->prepareAndExecute("select q.quantification_id from rad.acquisition a, rad.quantification q  where a.assay_id = $assId and a.acquisition_id = q.acquisition_id");

  my ($quantificationId) = $stmt->fetchrow_array() || $self->error("Unable to select for quantification_id for assay_id = $assId\n");

  $stmt -> finish();

  $stmt = $dbh->prepareAndExecute("select composite_element_id, tag_count from rad.sagetagresult where quantification_id = $quantificationId");

  my %tagCount;

  my $total;

  while (my($compElemId,$count) = $stmt->fetchrow_array()) {
    $tagCount{$compElemId} = $count;
    $total += $count;
  }

  return (\%tagCount,$total);
}


sub makeDataFile {
  my ($self,$ass,$tagCount,$total) = @_;

  my $assName = $ass->getName();

  my $studyName = $self->getArg('studyName');

  $studyName =~ s/\s/_/g;
  $studyName =~ s/[\(\)]//g;

  my $fileDir = $self->getArg('fileDir') . "/" . $studyName;

  `mkdir -p $fileDir`;

  my $file = $assName . '.dat';

  open (FILE,">$fileDir/$file") || $self->error ("Can't open $fileDir/$file for writing\n");

  print FILE "row_id\tfloat_value\n";

  my $paramValue = $self->getArg('paramValue');

  foreach my $compElemId (keys %$tagCount) {
    my $value = ($tagCount->{$compElemId} * $paramValue)/$total;
    print FILE "$compElemId\t$value\n";
  }

  close FILE;
}

sub makeCfgFile {
  my ($self,$protParamId,$logicalGroupId,$ass,$protocolId) = @_;

  my $assName = $ass->getName();

  my $studyName = $self->getArg('studyName');

  my $paramValue = $self->getArg('paramValue');

  $studyName =~ s/\s/_/g;

  my $fileDir = $self->getArg('fileDir') . "/" . $studyName;

  my $file = $assName . '.cfg';

  open (FILE,">$fileDir/$file") || $self->error ("Can't open $fileDir/$file for writing\n");

  my $contact = $self->getContactForUser();
  my $operatorId = $contact->getId();

  my $date = `date +%Y-%m-%d`;
  chomp($date);

  print FILE <<XX;
  table\tRAD.SAGETag
  operator_id\t$operatorId
  protocol_id\t$protocolId
  analysis_date\t$date
  protocol_param_id1\t$protParamId
  logical_group_id1\t$logicalGroupId
  protocol_param_value1\t$paramValue
XX
}

#sub getContactId {
#  my ($self) = @_;

#  my $contactHash;

#  if(defined $self->getArg('contact')->[0])  {  $contactHash->{name}=$self->getArg('contact')->[0];}
#  if(defined $self->getArg('contact')->[1])  {  $contactHash->{first}=$self->getArg('contact')->[1];}
#  if(defined $self->getArg('contact')->[2])  {  $contactHash->{last}=$self->getArg('contact')->[2];}

#  my $contact = GUS::Model::SRes::Contact->new($contactHash);

#  if ($contact) {
#    $self->log("Obtained contact object\n");
#  }
#  else {
#    $self->userError("Unable to obtain contact object\n");
#  }

#  if (! $contact->retrieveFromDB()) {

#    $contact->submit();
#  }

#  my $contactId = $contact->getId();

#  return $contactId
#}

sub getContactForUser {
  my ($self) = @_;

  my $database;
  unless($database = GUS::ObjRelP::DbiDatabase->getDefaultDatabase()) {
    $self->error("Required Default DbiDatabase not provided by the Plugin");
  }

  my $userId = $database->getDefaultUserId;

  my $userInfo = GUS::Model::Core::UserInfo->new({user_id => $userId});

  unless($userInfo->retrieveFromDB()) {
    $self->error("User Id [$userId] is not valid");
  }

  my $contact;
  if(my $contactId = $userInfo->getContactId()) {
    $contact = GUS::Model::SRes::Contact->new({contact_id => $contactId});

    unless($contact->retrieveFromDB()) {
      $self->error("Contact Id [$contactId] is not valid");
    }
  }
  else {
    my $first = $userInfo->getFirstName();
    my $last = $userInfo->getLastName();
    my $full = $first . " " . $last;

    $contact = GUS::Model::SRes::Contact->new({first => $first,
                                               last => $last,
                                              });

    unless($contact->retrieveFromDB()) {
      $contact->setName($full);
      $contact->submit();
    }
  }

  return $contact;
}



1;
