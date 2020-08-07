package ApiCommonData::Load::Plugin::InsertStudyCharacteristics;

@ISA = qw(GUS::PluginMgr::Plugin);
use GUS::PluginMgr::Plugin;
use strict;

use CBIL::ISA::Investigation;
use CBIL::ISA::InvestigationSimple;

use File::Basename;

use GUS::Model::Study::Study;
use GUS::Model::Study::StudyCharacteristic;
use GUS::Model::SRes::OntologyTerm;
use ApiCommonData::Load::OwlReader;
use Text::CSV_XS;

use Digest::SHA qw/sha1_hex/;

use Data::Dumper;

my $argsDeclaration =
  [

   fileArg({name           => 'file',
            descr          => 'study characteristics file',
            reqd           => 1,
        mustExist      => 0,
        format         => '',
            constraintFunc => undef,
            isList         => 0, }),

## may change to ontology, when ontology term 'type' attribute is available in GUS 
   stringArg({name           => 'owlFile',
            descr          => 'classifications owl file',
            reqd           => 0,
            constraintFunc => undef,
            isList         => 0, }),


   stringArg({name           => 'datasetName',
            descr          => 'name of the study',
            reqd           => 0,
            constraintFunc => undef,
            isList         => 0, }),



   booleanArg({name => 'commit',
          descr => 'commit changes',
          reqd => 0,
          constraintFunc => undef,
          isList => 0,
         }),


  ];

my $documentation = { purpose          => "",
                      purposeBrief     => "",
                      notes            => "",
                      tablesAffected   => "",
                      tablesDependedOn => "",
                      howToRestart     => "",
                      failureCases     => "" };

# ----------------------------------------------------------------------
sub getIsReportMode { }

# ----------------------------------------------------------------------

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  $self->initialize({ requiredDbVersion => 4.0,
                      cvsRevision       => 'NA',
                      name              => ref($self),
                      argsDeclaration   => $argsDeclaration,
                      documentation     => $documentation});

  return $self;
}

# ======================================================================

sub run {
  my ($self) = @_;
  my $file = $self->getArg('file');
  unless ( -e $file ){ $self->log("$file not found, nothing to do"); return 0 }
  #my $ontology = $self->getArg('ontology');
  my $owlFile = $self->getArg('owlFile');
  my $datasetName = $self->getArg('datasetName');
  my $commit = $self->getArg('commit');

  my $cfg = $self->readConfig($file,$datasetName);

printf STDERR Dumper $cfg;
  unless (0 < keys %$cfg){ $self->log("$datasetName not found in $file, nothing to do"); return 0 }

  # fetch all 
  
  my %name2study;
  
  my $sql = <<SQL;
  SELECT ed.name NAME, s1.study_id study_id, s1.external_database_release_id
  FROM study.study s1
  LEFT JOIN study.study s0 ON s1.INVESTIGATION_ID=s0.STUDY_ID
  LEFT JOIN sres.EXTERNALDATABASERELEASE edr ON s1.EXTERNAL_DATABASE_RELEASE_ID=edr.EXTERNAL_DATABASE_RELEASE_ID
  LEFT JOIN sres.EXTERNALDATABASE ed ON edr.EXTERNAL_DATABASE_ID=ed.EXTERNAL_DATABASE_ID
  WHERE s0.STUDY_ID!=s1.STUDY_ID
SQL

  my $dbh = $self->getQueryHandle();
  
  my $results = $self->selectHashRef($dbh,$sql);
  
  my $studyId = $results->{$datasetName}->{STUDY_ID};
  
  unless ($studyId){
    printf STDERR ("Study %s not found. Loaded:\n%s\n", $datasetName, Dumper $results);
    return -1; # fail
  }
  
  $sql = <<SQL;
  SELECT pan.TYPE_ID TYPE_ID,count(1) COUNT
  FROM study.studylink sl
  LEFT JOIN study.PROTOCOLAPPNODE pan ON sl.PROTOCOL_APP_NODE_ID=pan.PROTOCOL_APP_NODE_ID
  WHERE sl.study_id=?
  GROUP BY pan.TYPE_ID
SQL
  
  $results = $self->selectHashRef($dbh,$sql,[$studyId]);
  
  ################## read OWL ############################################################
  # may replace this with fetching from DB #
  my $owl = ApiCommonData::Load::OwlReader->new($owlFile);
  my $it = $owl->execute('classifications');
  my %valueTerms;    # Study.StudyCharacteristic.VALUE_ID
  my %validValues;    # Study.StudyCharacteristic.VALUE_ID
  my %variableTerms; # Study.StudyCharacteristic.QUALIFIER_ID
  my %variableLabels;
  my %valueLabels;
  while (my $row = $it->next) {
    my $uri = $row->{entity}->as_hash()->{iri}|| $row->{entity}->as_hash()->{URI};
    my $sid = $owl->getSourceIdFromIRI($uri);
    die "Cannot get source id from $uri" unless $sid;
    my $pid;
    if($row->{parent}){
      $uri = $row->{parent}->as_hash()->{iri}|| $row->{parent}->as_hash()->{URI};
      next unless($uri);
      $pid = $owl->getSourceIdFromIRI($uri);
    }
    else{
      $pid = "";
    }
    my $label = $row->{label}->as_hash()->{literal};
    my $type = $row->{type} ? $row->{type}->as_hash()->{literal} : "";
    if($type eq 'value'){
      $valueTerms{$pid} ||= {};
      $valueTerms{uc($label)} = $sid;
      $validValues{$pid}->{uc($label)} = $sid;
      $valueLabels{uc($label)} = $label;
    }
    else {
      $variableTerms{uc($label)} = $sid;
      $variableLabels{$sid} = $label;
    }
    
  }
  # print Dumper \%valueTerms;
  # print Dumper \%variableTerms;
  ########################################################################################
  # 'type' attribute is not currently loaded into SRes.OntologySynonym,so  we must use the OWL file
  # If we do load it, then we can switch to using GUS::Model
  # 
  # my $edObj = GUS::Model::SRes::ExternalDatabase->new({name => $ontology});
  # unless($edObj->retrieveFromDB()){ die "$ontology has not been loaded" }
  # my $edrObj = GUS::Model::SRes::ExternalDatabaseRelease->new({external_database_id => $edObj->getExternalDatabaseId()});
  # 
  # my @terms = GUS::Model::SRes::OntologySynonym->new({external_database_release_id => $edrObj->getExternalDatabaseReleaseId()});
  # 
  ########################################################################################
  
  
  my @derived;
  my %qualifierIds;
  my %valueIds;
  my @rows;
  my @decodedRows;
  while( my ($k, $values) = each %{$cfg}){
    ###
    $k = uc($k);
    my $qualifierSourceId = $variableTerms{$k}; 
    unless($qualifierSourceId){
      printf STDERR ("INVALID classification: %s\n", $k);
      next;
    }
    my $ot = GUS::Model::SRes::OntologyTerm->new({source_id => $qualifierSourceId});
    if($ot->retrieveFromDB){
      printf STDERR ("Ready: %s %s\n", $ot->getName, $ot->getSourceId);
      $qualifierIds{$qualifierSourceId} = $ot->getId();
    }
    else{
      printf STDERR ("%s (%s) not found\n", $k, $qualifierSourceId);
    }
    ###
    foreach my $v ( @$values ){
      $valueLabels{uc($v)} ||= $v;
      $v = uc($v);
      if($validValues{$qualifierSourceId}){
        my $valueSourceId = $validValues{$qualifierSourceId}->{$v}; 
        unless($valueSourceId){
          printf STDERR ("\t\tINVALID value for %s(%s) %s\nValid values: %s\n",
            $k,$qualifierSourceId, $v, join(",",sort keys %{$validValues{$qualifierSourceId}}));
          next;
        }
        my $ov = GUS::Model::SRes::OntologyTerm->new({source_id => $valueSourceId});
        if($ov->retrieveFromDB){
          printf STDERR ("\tReady: %s %s\n", $ov->getName, $ov->getSourceId);
          $valueIds{$valueSourceId} = $ov->getId();
          push(@rows, [$studyId,$qualifierIds{$qualifierSourceId}, $valueIds{$valueSourceId},$valueLabels{$v}]);
          push(@decodedRows, [$datasetName, $qualifierSourceId, $variableLabels{$qualifierSourceId}, $valueSourceId,$valueLabels{$v}]);
        }
        else{
          printf STDERR ("\t\t%s (%s) not found, time to reload classifications ontology\n", $v, $valueSourceId);
          exit;
        }
      }
      elsif (defined($v) && $v ne "") { # derived or free text
        push(@rows, [$studyId,$qualifierIds{$qualifierSourceId},"",$valueLabels{$v}]);
        push(@decodedRows, [$datasetName,$qualifierSourceId, $variableLabels{$qualifierSourceId}, "",$valueLabels{$v}]);
        printf ("\tReady: %s (free text)\n", $valueLabels{$v});
      }
#     else {
#       push(@derived,$qualifierSourceId);
#     }
    }
  }
  
  # my @cols = qw/STUDY_ID QUALIFIER_ID VALUE_ID VALUE/;
  # printf("%s\n", join("\t", @cols ));
  # printf("%s\n", join("\t", @{$_})) for @rows;
  
  my $prefix = "APIDBTUNING.D" . substr(sha1_hex($datasetName),0,10);
  printf STDERR ("%s\t%s\n",$datasetName,$prefix);
  
  
  ### count all types
  $sql = "SELECT PAN_TYPE_SOURCE_ID, COUNT(1) COUNT FROM ${prefix}PanRecord GROUP BY PAN_TYPE_SOURCE_ID";
  # $sql = "select ot.source_id SOURCE_ID, count(1) COUNT from study.studylink sl left join study.protocolappnode pan on sl.protocol_app_node_id=pan.protocol_app_node_id left join sres.ontologyterm ot on pan.type_id=ot.ontology_term_id where sl.study_id=$study_id group by ot.source_id";
  my $materialTypeCounts = $self->selectHashRef($dbh,$sql);
  # printf STDERR "Material types:\n" . Dumper $materialTypeCounts;
  
  
  ### number of subtypes to subtract
  $sql = "SELECT  INPUT_PAN_TYPE_SOURCE_ID, COUNT(1) COUNT FROM ${prefix}PanIO where INPUT_PAN_TYPE_SOURCE_ID=OUTPUT_PAN_TYPE_SOURCE_ID GROUP BY INPUT_PAN_TYPE_SOURCE_ID";
  my $subTypeCounts = $self->selectHashRef($dbh,$sql);
  # printf STDERR "Sub types:\n" . Dumper $subTypeCounts;
  
  ### make count corrections
  foreach my $sourceId (keys %$subTypeCounts){
    $materialTypeCounts->{$sourceId}->{COUNT} -= $subTypeCounts->{$sourceId}->{COUNT};
  }
  
# my %counterSourceIds = (
#   EUPATH_0000327 => 'EUPATH_0000327', # entomology collections
#   OMIABIS_0001011 => 'EUPATH_0000096', # participants
#   EUPATH_0000774 => 'EUPATH_0000738', # observations
#   EUPATH_0000775 => 'EUPATH_0000609', # samples
#   EUPATH_0000773 => 'PCO_0000024', # households
# );
# my %subCounterSourceIds = (EUPATH_0000776 => 'PCO_0000024');
# # EUPATH_0000776 household observations
# 
# foreach my $derivedSourceId (keys %counterSourceIds){
#   unless($counterSourceIds{$derivedSourceId}){
#     printf STDERR ("Derived: no match for %s\n", $derivedSourceId);
#     next;
#   }
#   my $count = $materialTypeCounts->{$counterSourceIds{$derivedSourceId}}->{COUNT};
#   $count ||= $subTypeCounts->{$counterSourceIds{$derivedSourceId}}->{COUNT};
#   push(@rows, [$studyId,$qualifierIds{$derivedSourceId},"",$count]);
#   push(@decodedRows, [$datasetName,$derivedSourceId, $variableLabels{$derivedSourceId}, "",$count]);
# }
# foreach my $derivedSourceId (keys %subCounterSourceIds){
#   next unless $subTypeCounts->{$subCounterSourceIds{$derivedSourceId}};
#   my $count = $subTypeCounts->{$subCounterSourceIds{$derivedSourceId}}->{COUNT};
#   next unless $count;
#   push(@rows, [$studyId,$qualifierIds{$derivedSourceId},"",$count]);
#   push(@decodedRows, [$datasetName,$derivedSourceId, $variableLabels{$derivedSourceId}, "",$count]);
# }
  
  if($commit){
    my $rownum = 0;
    foreach my $row (@rows){
      unless($row->[1]){ # qualifier_id cannot be null
        printf STDERR ("ERROR in row: %s\nQualifier ID not found\nreload ontology\n", join(",",@{$decodedRows[$rownum]}));
        $rownum++;
        next;
      }
      
      my %data = (
        #row_user_id => $userId, row_alg_invocation_id => $algInvocationId,
         study_id => $row->[0], qualifier_id => $row->[1], value_id => $row->[2], value => $row->[3]);
      my $sc = GUS::Model::Study::StudyCharacteristic->new(\%data);
      # $sc->retrieveFromDB();
      # $sc->setValue($row->[3]);
      $sc->submit;
      $rownum++;
    }
  }
  else {
    printf("%s\n", join("\t", qw/study qualifierId label valueId value/));
    foreach my $row (@decodedRows){
      printf("%s\n", join("\t", @$row));
    }
    printf("\n%s\n", join("\t", qw/study_id qualifier_id value_id value/));
    foreach my $row (@rows){
      printf("%s\n", join("\t", @$row));
    }
  }



}

# ======================================================================

sub selectHashRef {
  my ($self, $dbh, $sql, $args) = @_;
  my $sth = $dbh->prepare($sql);
  if(defined($args)){ $sth->execute(@$args) }
  else { $sth->execute() }
  my @cols = @{$sth->{NAME}}; 
# printf STDERR ("%s\n", join(", ", @cols));
  return $sth->fetchall_hashref($cols[0]);
}

sub readConfig {
# Not using  CBIL::Config::PropertySet because it doesn't handle variables with spaces
  my ($self, $file, $datasetName) = @_;
  my $csv = Text::CSV_XS->new({ binary => 1, sep_char => ",", quote_char => '"', allow_loose_quotes => 1 }) or die "Cannot use CSV: ".Text::CSV_XS->error_diag ();  
  my @fields;
  open(FH, "<$file") or die "$file $!\n";
  my $line = <FH>;
  if($csv->parse($line)) {
    @fields = $csv->fields();
  }
  my %data;
  while(my $line = <FH>){
    next if $line =~ /^[\w\r\l\n,]*$/;
    $csv->parse($line);
    my @row = $csv->fields();
    if($datasetName eq $row[0]){
      @data{@fields} = @row;
      last;
    }
  }
  close(FH);
  foreach my $k (keys %data){
    $data{$k} =~ s/^\s*|\s*$//g;
    my @values = split(/\s*;\s*/, $data{$k});
    $data{$k} = \@values;
  }
  return \%data;
}

sub undoTables {
  my ($self) = @_;

  return (
    'Study.StudyCharacteristic',
     );
}
1;

