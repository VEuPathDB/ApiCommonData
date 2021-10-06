package ApiCommonData::Load::Plugin::InsertStudyCharacteristics;

@ISA = qw(GUS::PluginMgr::Plugin ApiCommonData::Load::Plugin::ParameterizedSchema);
use strict;
use warnings;
use GUS::PluginMgr::Plugin;
use ApiCommonData::Load::Plugin::ParameterizedSchema;

use File::Basename;

use GUS::Model::SRes::OntologyTerm;
use ApiCommonData::Load::OwlReader;
use Text::CSV_XS;
use Config::Std;

use Digest::SHA qw/sha1_hex/;

use Data::Dumper;


my $SCHEMA = '__SCHEMA__'; # must be replaced with real schema name
my @UNDO_TABLES = qw(
  StudyCharacteristic
);
my @REQUIRE_TABLES = qw(
  Study
  StudyCharacteristic
);

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
   stringArg({name           => 'schema',
            descr          => 'GUS::Model schema for entity tables',
            reqd           => 1,
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
  $self->{_require_tables} = \@REQUIRE_TABLES;
  $self->{_undo_tables} = \@UNDO_TABLES;
  return $self;
}

# ======================================================================

sub run {
  my ($self) = @_;

  ## ParameterizedSchema
  $self->requireModelObjects();
  $self->resetUndoTables(); # for when logRowsInserted() is called after loading
  $SCHEMA = $self->getArg('schema');
  ## 

  my $file = $self->getArg('file');
  unless ( -e $file ){ $self->log("$file not found, nothing to do"); return 0 }
  #my $ontology = $self->getArg('ontology');
  my $owlFile = $self->getArg('owlFile');
  my $datasetName = $self->getArg('datasetName');
  my $commit = $self->getArg('commit');

  my $cfg = $self->readConfig($file,$datasetName);

  unless (0 < keys %$cfg){ $self->log("$datasetName not found in $file, nothing to do"); return 0 }

  # fetch all 
  
  my $sql = "
SELECT e2.name, s.STUDY_ID 
FROM $SCHEMA.STUDY s 
LEFT JOIN sres.EXTERNALDATABASERELEASE e ON s.EXTERNAL_DATABASE_RELEASE_ID =e.EXTERNAL_DATABASE_RELEASE_ID 
LEFT JOIN sres.EXTERNALDATABASE e2 ON e.EXTERNAL_DATABASE_ID =e2.EXTERNAL_DATABASE_ID 
ORDER BY e2.modification_date desc";

  my $dbh = $self->getQueryHandle();
  
  my $results = $self->selectHashRef($dbh,$sql);
  
  my $studyId = $results->{$datasetName}->{STUDY_ID};
  
  unless ($studyId){
    printf STDERR ("Study %s not found. Loaded:\n%s\n", $datasetName, Dumper $results);
    return -1; # fail
  }
  
  my @oldCharacteristics;
  my $study = $self->getGusModelClass('Study')->new({study_id => $studyId});
  if($study->retrieveFromDB()){
    @oldCharacteristics = $study->getChildren($self->getGusModelClass('StudyCharacteristic'),1);
    foreach my $sch (@oldCharacteristics){
      my $id = $sch->getStudyCharacteristicId();
      my $invoId = $sch->getRowAlgInvocationId();
      print STDERR "Ready to Delete STUDY_CHARACTERISTIC_ID: $id, ROW_ALG_INVOCATION_ID $invoId\n";
    }
  }
  
  ################## read OWL ############################################################
  # may replace this with fetching from DB #
  my $owl = ApiCommonData::Load::OwlReader->new($owlFile);
  my $it = $owl->execute('classifications');
  my %valueTerms;    # Study.StudyCharacteristic.VALUE_ONTOLOGY_TERM_ID
  my %validValues;    # Study.StudyCharacteristic.VALUE
  my %variableTerms; # Study.StudyCharacteristic.attribute_ID
  my %variableLabels;
  my %valueLabels;
  while (my $row = $it->next) {
    my $uri = $row->{entity}->as_hash()->{iri}|| $row->{entity}->as_hash()->{URI};
    my $sid = $owl->getSourceIdFromIRI($uri);
    die "Cannot get source id from $uri" unless $sid;
    my $pid;
    if($row->{parent}){
      $uri = $row->{parent}->as_hash()->{iri}|| $row->{parent}->as_hash()->{URI};
      if($uri){
        $pid = $owl->getSourceIdFromIRI($uri);
      }
      else { $pid = "" }
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
  
  my @derived;
  my %attributeIds;
  my %valueIds;
  my @rows;
  my @decodedRows;
  my $help_msg = 0;
  while( my ($k, $values) = each %{$cfg}){
    ###
    $k = uc($k);
    my $attributeSourceId = $variableTerms{$k}; 
    unless($attributeSourceId){
      printf STDERR ("INVALID classification: %s\n", $k);
      $help_msg = 1;
      next;
    }
    my $ot = GUS::Model::SRes::OntologyTerm->new({source_id => $attributeSourceId});
    if($ot->retrieveFromDB){
      printf STDERR ("Ready: %s %s\n", $ot->getName, $ot->getSourceId);
      $attributeIds{$attributeSourceId} = $ot->getId();
    }
    else{
      printf STDERR ("%s (%s) not found\n", $k, $attributeSourceId);
    }
    ###
    foreach my $v ( @$values ){
      $valueLabels{uc($v)} ||= $v;
      $v = uc($v);
      if($validValues{$attributeSourceId}){
        my $valueSourceId = $validValues{$attributeSourceId}->{$v}; 
        unless($valueSourceId){
          printf STDERR ("\t\tINVALID value for %s(%s) %s\nValid values: %s\n",
            $k,$attributeSourceId, $v, join(",",sort keys %{$validValues{$attributeSourceId}}));
          next;
        }
        my $ov = GUS::Model::SRes::OntologyTerm->new({source_id => $valueSourceId});
        if($ov->retrieveFromDB){
          printf STDERR ("\tReady: %s %s\n", $ov->getName, $ov->getSourceId);
          $valueIds{$valueSourceId} = $ov->getId();
          push(@rows, [$studyId,$attributeIds{$attributeSourceId}, $valueIds{$valueSourceId},$valueLabels{$v}]);
          push(@decodedRows, [$datasetName, $attributeSourceId, $variableLabels{$attributeSourceId}, $valueSourceId,$valueLabels{$v}]);
        }
        else{
          printf STDERR ("\t\t%s (%s) not found, time to reload classifications ontology\n", $v, $valueSourceId);
          exit;
        }
      }
      elsif (defined($v) && $v ne "") { # derived or free text
        # deal with hyperlinks
        if($v =~ /^.*\s+HTTP/i){
          my ($linkname,$url) = ($valueLabels{$v} =~ /^(.*)\s+(http.*)$/);
          my $link = sprintf("<a target='_blank' href='%s'>%s</a>", $url, $linkname);
          push(@rows, [$studyId,$attributeIds{$attributeSourceId},"",$link]);
          push(@decodedRows, [$datasetName,$attributeSourceId, $variableLabels{$attributeSourceId}, "",$valueLabels{$v}]);
        }
        else {
          push(@rows, [$studyId,$attributeIds{$attributeSourceId},"",$valueLabels{$v}]);
          push(@decodedRows, [$datasetName,$attributeSourceId, $variableLabels{$attributeSourceId}, "",$valueLabels{$v}]);
          printf ("\tReady: %s (free text)\n", $valueLabels{$v});
        }
      }
    }
  }
  
  if($commit){
    my $rownum = 0;
    foreach my $row (@rows){
      unless($row->[1]){ # attribute_id cannot be null
        if(defined($decodedRows[$rownum]) && ref($decodedRows[$rownum])){
          printf STDERR ("ERROR in row: %s\nattribute ID not found\nreload ontology\n", join(",",@{$decodedRows[$rownum]}));
        }
        else{
          printf STDERR ("ERROR in row %d: %s\n", $rownum, Dumper($row)); 
        }
        $rownum++;
        next;
      }
      
      my %data = (
        #row_user_id => $userId, row_alg_invocation_id => $algInvocationId,
         study_id => $row->[0], attribute_id => $row->[1], value_ontology_term_id => $row->[2], value => $row->[3]);
      my $sc = $self->getGusModelClass('StudyCharacteristic')->new(\%data);
      # $sc->retrieveFromDB();
      # $sc->setValue($row->[3]);
      $sc->submit;
      $rownum++;
    }
    ## Clean up old rows
    foreach my $sch (@oldCharacteristics){
      my $id = $sch->getStudyCharacteristicId();
      $sch->removeFromDB();
      print STDERR "Deleted STUDY_CHARACTERISTIC_ID: $id\n";
    }
  }
  else {
    printf("%s\n", join("\t", qw/study attributeId label valueId value/));
    foreach my $row (@decodedRows){
      printf("%s\n", join("\t", @$row));
    }
    printf("\n%s\n", join("\t", qw/study_id attribute_id value_ontology_term_id value/));
    foreach my $row (@rows){
      printf("%s\n", join("\t", @$row));
    }
  }
  if($help_msg){
    printf STDERR ("Invalid classification labels were found. Valid labels (in uppercase, matching is case-insensitive):\n%s", Dumper \%variableTerms);
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
  my ($self, $file, $datasetName) = @_;
  if(-f $file && $file =~ /\.csv$/i){ return $self->readConfigFromCsv($file, $datasetName) }
  if(-d $file){ # a directory containing .ini files
    opendir(DH, "$file") or die "Cannot open directory $file:$!\n";
    my @inifiles = map { "$file/$_" } grep { /.+\.ini$/i } readdir(DH);
    foreach my $inifile (@inifiles){
      read_config($inifile, my %cfg);
      next unless(defined($cfg{$datasetName}));
      printf STDERR ("Found %s in %s\n", $datasetName, $inifile);
      # clean it up
      my %data;
      while(my($k,$v) = each %{$cfg{$datasetName}}){
        my $arr = [];
        if(ref($v)){ $arr = $v } # array of values
        else { $arr = [ $v ] } # single value
        foreach my $av (@$arr){ # array value
          $av =~ s/^\s*|\s*$//g; # strip whitespace (probably not necessary, Config::Std should handle it
          if($av =~ /\w+/){
            $data{$k} //= [];
            push(@{$data{$k}}, $av);
          }
        }
      }
      return \%data ;
    }
    return {}; # study not found, fail gracefully
  }
}

sub readConfigFromCsv {
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

# sub undoTables {
#   my ($self) = @_;
# 
#   return (
#     'Study.StudyCharacteristic',
#      );
# }

1;

