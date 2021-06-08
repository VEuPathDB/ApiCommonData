package ApiCommonData::Load::Plugin::LoadAttributesFromEntityGraph;

@ISA = qw(GUS::PluginMgr::Plugin);
use strict;
use warnings;
use GUS::PluginMgr::Plugin;

use GUS::Model::ApiDB::Attribute;

use ApiCommonData::Load::Fifo;
use ApiCommonData::Load::Sqlldr;

use Scalar::Util qw(looks_like_number);

#use List::Util qw(min max);
#use Date::Manip qw(ParseDate Date_Cmp);

use File::Temp qw/ tempfile tempdir tmpnam /;

use Time::HiRes qw(gettimeofday);

use ApiCommonData::Load::StudyUtils qw(queryForOntologyTerms);

use JSON;

use Data::Dumper;


my $VALUE_COUNT_CUTOFF = 10;

my $END_OF_RECORD_DELIMITER = "#EOR#\n";
my $END_OF_COLUMN_DELIMITER = "#EOC#\t";

my $purposeBrief = 'Read Study tables and insert tall table for attribute values and attribute table';
my $purpose = $purposeBrief;

my $tablesAffected =
    [ ['ApiDB::Attribute', ''],
      ['ApiDB::AttributeValue', '']
    ];

my $tablesDependedOn =
    [['ApiDB::Study',''],
     ['ApiDB::EntityAttributes',  ''],
     ['ApiDB::ProcessAttributes',  ''],
     ['ApiDB::ProcessType',  ''],
     ['ApiDB::EntityType',  ''],
     ['ApiDB::AttributeUnit',  ''],
     ['SRes::OntologyTerm',  ''],
     ['ApiDB::ProcessType',  ''],
    ];

my $howToRestart = ""; 
my $failureCases = "";
my $notes = "";

my $documentation = { purpose => $purpose,
                      purposeBrief => $purposeBrief,
                      tablesAffected => $tablesAffected,
                      tablesDependedOn => $tablesDependedOn,
                      howToRestart => $howToRestart,
                      failureCases => $failureCases,
                      notes => $notes
};

my $argsDeclaration =
[
   fileArg({name           => 'logDir',
            descr          => 'directory where to log sqlldr output',
            reqd           => 1,
            mustExist      => 1,
            format         => '',
            constraintFunc => undef,
            isList         => 0, }),

 stringArg({ name            => 'extDbRlsSpec',
	     descr           => 'ExternalDatabaseSpec for the Entity Graph',
	     reqd            => 1,
	     constraintFunc  => undef,
	     isList          => 0 }),

 stringArg({ name            => 'ontologyExtDbRlsSpec',
	     descr           => 'ExternalDatabaseSpec for the Associated Ontology',
	     reqd            => 1,
	     constraintFunc  => undef,
	     isList          => 0 }),

];

sub getActiveForkedProcesses {
  my ($self) = @_;

  return $self->{_active_forked_processes} || [];
}

sub addActiveForkedProcess {
  my ($self, $pid) = @_;

  push @{$self->{_active_forked_processes}}, $pid;
}

sub resetActiveForkedProcesses {
  my ($self) = @_;

  $self->{_active_forked_processes} = [];
}

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  $self->initialize({requiredDbVersion => 4.0,
		     cvsRevision => '$Revision$', # cvs fills this in!
		     name => ref($self),
		     argsDeclaration   => $argsDeclaration,
		     documentation     => $documentation
		    });
  return $self;
}


$| = 1;

sub run {
  my $self  = shift;

  chdir $self->getArg('logDir');

  my $extDbRlsId = $self->getExtDbRlsId($self->getArg('extDbRlsSpec'));
  
  my $studies = $self->sqlAsDictionary( Sql  => "select study_id, max_attr_length from apidb.study where external_database_release_id = $extDbRlsId");

  $self->error("Expected one study row.  Found ". scalar keys %{$studies}) unless(scalar keys %$studies == 1);

  $self->getQueryHandle()->do("alter session set nls_date_format = 'yyyy-mm-dd hh24:mi:ss'") or die $self->getQueryHandle()->errstr;


  my $studiesCount;
  while(my ($studyId, $maxAttrLength) = each (%$studies)) {
    $studiesCount++;

    my $entityTypeIds = $self->queryForEntityTypeIds($studyId);

    my $ontologyTerms = &queryForOntologyTerms($self->getQueryHandle(), $self->getExtDbRlsId($self->getArg('ontologyExtDbRlsSpec')));
    $self->addUnitsToOntologyTerms($studyId, $ontologyTerms);

    my $tempDirectory = tempdir( CLEANUP => 1 );
    my ($dateValsFh, $dateValsFileName) = tempfile( DIR => $tempDirectory );
    my ($numericValsFh, $numericValsFileName) = tempfile( DIR => $tempDirectory );

    my ($annPropsByAttributeStableIdAndEntityTypeId, $typeCountsByAttributeStableIdAndEntityTypeId) = $self->loadAttributeValues($studyId, $ontologyTerms, $maxAttrLength, $dateValsFh, $numericValsFh);

    my $statsForPlotsByAttributeStableIdAndEntityTypeId = $self->statsForPlots($dateValsFileName, $numericValsFileName, $tempDirectory);

    my $attributeCount = $self->loadAttributeTerms($annPropsByAttributeStableIdAndEntityTypeId, $typeCountsByAttributeStableIdAndEntityTypeId, $statsForPlotsByAttributeStableIdAndEntityTypeId, $entityTypeIds);

    $self->log("Loaded $attributeCount attributes for study id $studyId");
  }

  return "Loaded attributes for $studiesCount studies"; 
}


sub statsForPlots {
  my ($self, $dateValsFileName, $numericValsFileName, $tempDirectory) = @_;

  my $outputStatsFileName = tmpnam();
  while(-e $outputStatsFileName) {
    $outputStatsFileName = tmpnam();
  }

  my ($rCommandsFh, $rCommandsFileName) = tempfile( DIR => $tempDirectory );

  print $rCommandsFh $self->rCommandsForStats();

  unless(system("singularity exec docker://veupathdb/rserve Rscript $rCommandsFileName $numericValsFileName $outputStatsFileName 2>/dev/null")) {
    $self->error("Error Running singularity for numericFile");
  }
  unless(system("singularity exec docker://veupathdb/rserve Rscript $rCommandsFileName $dateValsFileName $outputStatsFileName 2>/dev/null")) {
    $self->error("Error Running singularity for datesFile");
  }


  my %rv;
  open(FILE, $outputStatsFileName) or die "Cannot open $outputStatsFileName for reading: $!";
  
  while(<FILE>) {
    chomp;
    my ($attributeSourceId, $entityTypeId, $min, $max, $binWidth) = split($_);

    $rv{$attributeSourceId}{$entityTypeId} =  {display_range_min => $min,
                                               display_range_max => $max,
                                               bin_width => $binWidth 
    };
  }
  close FILE;
  unlink $outputStatsFileName;

  return \%rv;
}

sub rCommandsForStats {
  return "args = commandArgs(trailingOnly = TRUE);
fileName = args[1];
outputFileName = args[2];
t = read.table(fileName, header=FALSE);
u = unique(t[,1:2]);
subsetFxn = function(x, output){
   v = subset(t, V1==x[1] & V2==x[2])\$V3
   data.min = min(v);
   data.max = max(v);
   data.binWidth = plot.data::findBinWidth(v);
   data.output = c(x, data.min, data.max, data.binWidth);
   write(data.output, file=outputFileName, append=T, ncolumns=5)
};
apply(u, 1, subsetFxn);
";

}


sub queryForEntityTypeIds {
  my ($self, $studyId) = @_;

  my %rv;

  my $dbh = $self->getQueryHandle();

  my $sql = "select t.name, t.entity_type_id, ot.source_id
from apidb.entitytype t, sres.ontologyterm ot
where t.type_id = ot.ontology_term_id (+)
and study_id = $studyId";

  my $sh = $dbh->prepare($sql);
  $sh->execute();

  while(my ($etName, $etId, $stableId) = $sh->fetchrow_array()) {
    warn "No ontology term for entity type $etName" unless $stableId;
    $rv{$etId} = $stableId;
  }
  $sh->finish();

  return \%rv;
}
sub annPropsFromParentOntologyTerm {
  my ($displayName, $parentOntologyTerm, $processTypeId, $isMultiValued) = @_;
  return {
    ontology_term_id => undef,
    parent_ontology_term_id => $parentOntologyTerm->{ONTOLOGY_TERM_ID},
    unit => $parentOntologyTerm->{UNIT_NAME},
    unit_ontology_term_id => $parentOntologyTerm->{UNIT_ONTOLOGY_TERM_ID},
    provider_label => undef,
    display_name => $displayName,
    process_type_id => $processTypeId,
    is_multi_valued => $isMultiValued,
  };
}
sub annPropsFromOntologyTerm {
  my ($ontologyTerm, $processTypeId, $isMultiValued) = @_;
  return {
    ontology_term_id => $ontologyTerm->{ONTOLOGY_TERM_ID},
    parent_ontology_term_id => $ontologyTerm->{PARENT_ONTOLOGY_TERM_ID},
    unit => $ontologyTerm->{UNIT_NAME},
    unit_ontology_term_id => $ontologyTerm->{UNIT_ONTOLOGY_TERM_ID},
    provider_label => $ontologyTerm->{PROVIDER_LABEL},
    display_name => $ontologyTerm->{DISPLAY_NAME},
    process_type_id => $processTypeId,
    is_multi_valued => $isMultiValued,
  };
}

sub loadAttributeTerms {
  my ($self, $annPropsByAttributeStableIdAndEntityTypeId, $typeCountsByAttributeStableIdAndEntityTypeId, $statsForPlotsByAttributeStableIdAndEntityTypeId, $entityTypeIds) = @_;

  my $attributeCount;
  $self->getDb->setMaximumNumberOfObjects((scalar keys %$annPropsByAttributeStableIdAndEntityTypeId ) * (scalar keys %$entityTypeIds));
  SOURCE_ID:
  foreach my $attributeStableId (keys %$annPropsByAttributeStableIdAndEntityTypeId) {

    foreach my $etId (keys %{$annPropsByAttributeStableIdAndEntityTypeId->{$attributeStableId}}) {
      my $annProps = $annPropsByAttributeStableIdAndEntityTypeId->{$attributeStableId}{$etId};

      my $valProps = valProps($typeCountsByAttributeStableIdAndEntityTypeId->{$attributeStableId}{$etId}, $attributeStableId);

      my $statProps = $statsForPlotsByAttributeStableIdAndEntityTypeId->{$attributeStableId}{$etId};
      $statProps = {} unless($statProps);


      next SOURCE_ID unless $valProps;


      # Danielle: A syntactically valid name
      #   consists of letters, numbers and the dot or underline characters
      #   and starts with a letter or the dot not followed by a number
      $self->error("Bad attribute stable ID: $attributeStableId")
        unless $attributeStableId =~ m{^[.A-Za-z]([.A-Za-z][A-Za-z_.0-9]*)?$};

      my $attribute = GUS::Model::ApiDB::Attribute->new({entity_type_id => $etId,
                                                         entity_type_stable_id => $entityTypeIds->{$etId},
                                                         stable_id => $attributeStableId,
                                                         %$annProps,
                                                         %$valProps,
                                                         %$statProps,
                                                       });

      $attribute->submit();
      $attributeCount++;
    }
  }
  $self->undefPointerCache;

  return $attributeCount;
}

sub valProps {
  my ($typeCounts, $attributeStableId) = @_;
  return unless $typeCounts;
  my %cs = %{$typeCounts};
  return unless $cs{_COUNT};

  my ($dataType, $dataShape, $precision);
  $precision = 1; # THis is the default; probably never changed
  my $isNumber = $cs{_IS_NUMBER_COUNT} && $cs{_COUNT} == $cs{_IS_NUMBER_COUNT};
  my $isDate = $cs{_IS_DATE_COUNT} && $cs{_COUNT} == $cs{_IS_DATE_COUNT};
  my $valueCount = scalar(keys(%{$cs{_VALUES}}));
#  my $isBoolean = $cs{_COUNT} == $cs{_IS_BOOLEAN_COUNT};

  my $isMultiValued = $cs{_IS_MULTI_VALUED};

  if($cs{_IS_ORDINAL_COUNT} && $cs{_COUNT} == $cs{_IS_ORDINAL_COUNT}) {
    $dataShape = 'ordinal';
  }
  elsif($isDate || ($isNumber && $valueCount > $VALUE_COUNT_CUTOFF)) {
    $dataShape = 'continuous';
  }
  elsif($valueCount == 2) {
    $dataShape = 'binary';
  }
  else {
    $dataShape = 'categorical'; 
  }

  # OBI term here is for longitude
  if($attributeStableId eq 'OBI_0001621') {
    $dataType = 'longitude'
  }
  elsif($isDate) {
    $dataType = 'date';
  }
  elsif($isNumber) {
    $dataType = 'number';
  }
#  elsif($isBoolean) {
#    $dataType = 'boolean';
#  }
  else {
    $dataType = 'string';
  }
  return {
    data_type => $dataType,
    distinct_values_count => $valueCount,
    is_multi_valued => $isMultiValued ? 1 : 0,
    data_shape => $dataShape,
    precision => $precision,
  };
}


sub addUnitsToOntologyTerms {
  my ($self, $studyId, $ontologyTerms) = @_;

  my $dbh = $self->getQueryHandle();

  my $sql = "select  att.source_id, unit.ontology_term_id, unit.name
from apidb.study pg
   , apidb.entitytype vt
   , apidb.attributeunit au
   , sres.ontologyterm att
   , sres.ontologyterm unit
where pg.study_id = ?
and pg.study_id = vt.study_id
and vt.entity_type_id = au.entity_type_id
and au.ATTR_ONTOLOGY_TERM_ID = att.ontology_term_id
and au.UNIT_ONTOLOGY_TERM_ID = unit.ontology_term_id";

  my $sh = $dbh->prepare($sql);
  $sh->execute($studyId);

  while(my ($sourceId, $unitOntologyTermId, $unitName) = $sh->fetchrow_array()) {
    $ontologyTerms->{$sourceId}->{UNIT_ONTOLOGY_TERM_ID} = $unitOntologyTermId;
    $ontologyTerms->{$sourceId}->{UNIT_NAME} = $unitName;
  }

  $sh->finish();
}




sub loadAttributeValues {
  my ($self, $studyId, $ontologyTerms, $maxAttrLength, $dateValsFh, $numericValsFh) = @_;

  my $timestamp = int (gettimeofday * 1000);
  my $fifoName = "apidb_attributevalue_${timestamp}.dat";

  my $fields = $self->fields($maxAttrLength);

  my $fifo = $self->makeFifo($fields, $fifoName, $maxAttrLength);
  my $annPropsByAttributeStableIdAndEntityTypeId = {};
  my $typeCountsByAttributeStableIdAndEntityTypeId = {};
  $self->loadAttributesFromEntity($studyId, $fifo, $ontologyTerms, $annPropsByAttributeStableIdAndEntityTypeId, $typeCountsByAttributeStableIdAndEntityTypeId, $dateValsFh, $numericValsFh);
  $self->loadAttributesFromIncomingProcess($studyId, $fifo, $ontologyTerms, $annPropsByAttributeStableIdAndEntityTypeId, $typeCountsByAttributeStableIdAndEntityTypeId, $dateValsFh, $numericValsFh);

  $fifo->cleanup();
  unlink $fifoName;
  return $annPropsByAttributeStableIdAndEntityTypeId, $typeCountsByAttributeStableIdAndEntityTypeId;
}

sub loadAttributes {
  my ($self, $studyId, $fifo, $ontologyTerms, $annPropsByAttributeStableIdAndEntityTypeId, $typeCountsByAttributeStableIdAndEntityTypeId, $dateValsFh, $numericValsFh, $sql) = @_;

  my $dbh = $self->getQueryHandle();

  my $fh = $fifo->getFileHandle();

  $self->log("Loading attribute values for study $studyId from sql:".$sql);
  my $sh = $dbh->prepare($sql, { ora_auto_lob => 0 } );
  $sh->execute($studyId);

  my $clobCount = 0;

  while(my ($entityAttributesId, $entityTypeId, $processTypeId, $lobLocator) = $sh->fetchrow_array()) {

    my $json = $self->readClob($lobLocator);

    my $attsHash = decode_json($json);

    while(my ($ontologySourceId, $valueArray) = each (%$attsHash)) {

      for my $p ($self->annPropsAndValues($ontologyTerms, $ontologySourceId, $processTypeId, $valueArray)){
        $processTypeId //= "";
        my ($attributeStableId, $annProps, $value) = @{$p};
        $annPropsByAttributeStableIdAndEntityTypeId->{$attributeStableId}{$entityTypeId} //= $annProps;


        my $cs = $typeCountsByAttributeStableIdAndEntityTypeId->{$attributeStableId}{$entityTypeId} // {};
        my ($updatedCs, $stringValue, $numberValue, $dateValue) = $self->typedValueForAttribute($cs, $value);
        $typeCountsByAttributeStableIdAndEntityTypeId->{$attributeStableId}{$entityTypeId} = $updatedCs;

        if($dateValue) {
          print $dateValsFh join("\t", $attributeStableId, $entityTypeId, $dateValue) . "\n";
        }
        elsif($numberValue) {
          print $numericValsFh join("\t", $attributeStableId, $entityTypeId, $numberValue) . "\n";
        }
        else {}

        my @a = ($entityAttributesId,
                 $entityTypeId,
                 $processTypeId,
                 $attributeStableId,
                 $stringValue,
                 $numberValue,
                 $dateValue,
              );
      
        print $fh join($END_OF_COLUMN_DELIMITER, map {$_ // ""} @a) . $END_OF_RECORD_DELIMITER;
        
      }
    }
    if(++$clobCount % 500 == 0){
      $self->log("Loading attribute values for study $studyId: processed $clobCount clobs");
    }
  }
  $self->log("Loaded attribute values for study $studyId: processed $clobCount clobs");
}
sub annPropsAndValues {
  my ($self, $ontologyTerms, $ontologySourceId, $processTypeId, $valueArray) = @_;
  my $ontologyTerm = $ontologyTerms->{$ontologySourceId};
  unless($ontologyTerm) {
    $self->error("No ontology term found for:  $ontologySourceId");
  }
  my $isMultiValued = scalar(@$valueArray) > 1;
  my @result;

  VALUE:
  for my $value (@{$valueArray}){
    # temporary, and assumes all of these are ontology terms
    # better - one parent geohash term?
    if($ontologySourceId eq 'GEOHASH_TEMP_32') {
      push @result, [$ontologySourceId, annPropsFromOntologyTerm($ontologyTerm, $processTypeId), $value];
      for my $n (1 .. 7) {
        my $subvalue = substr($value, 0, $n);
        my $displayName = $ontologyTerm->{DISPLAY_NAME} . ($n == 1 ? ", to 1 digit" : ", to $n digits");
        push @result, ["GEOHASH_TEMP_${n}", annPropsFromParentOntologyTerm($displayName, $ontologyTerm, $processTypeId, $isMultiValued), $subvalue];
      }
    } elsif (ref $value eq 'HASH'){
      # MBio results
      for my $k (keys %{$value}){
        my ($displayName, $subvalue);
        my $o = $value->{$k};
        if (ref $o eq 'ARRAY'){
          $displayName = $o->[0];
          $subvalue = $o->[1];
        } else {
           $displayName = $ontologyTerm->{DISPLAY_NAME}. ": $k";
           $subvalue = $o;
        }
        push @result, ["$ontologySourceId.$k", annPropsFromParentOntologyTerm($displayName, $ontologyTerm, $processTypeId, $isMultiValued), $subvalue];
      }
    } else {
      push @result, [$ontologySourceId, annPropsFromOntologyTerm($ontologyTerm, $processTypeId, $isMultiValued), $value];
    }
  }
  return @result;
}

sub typedValueForAttribute {
  my ($self, $counts, $value, $dateValsFh, $numericValsFh) = @_;

  my ($stringValue, $numberValue, $dateValue); 


  $counts->{_COUNT}++;

  my $valueNoCommas = $value;
  $valueNoCommas =~ tr/,//d;

  if(looks_like_number($valueNoCommas)) {
    $numberValue = $valueNoCommas;
    $counts->{_IS_NUMBER_COUNT}++;
    
    # $counts->{_MIN_NUMBER} = min($counts->{_MIN_NUMBER} || $numberValue, $numberValue);
    # $counts->{_MAX_NUMBER} = max($counts->{_MAX_NUMBER} || $numberValue, $numberValue);

    $counts->{_VALUES}->{$value} //= 0;
    if($counts->{_VALUES}->{$value} <= $VALUE_COUNT_CUTOFF) {
      $counts->{_VALUES}->{$value}++;
    }
  }
  elsif($value =~ /^\d\d\d\d-\d\d-\d\d$/) {
    $dateValue = $value;
    $counts->{_IS_DATE_COUNT}++;

    # my $parsedDate = ParseDate($dateValue);
    # $counts->{_MIN_DATE} = (sort { Date_Cmp($b, $a) } ($counts->{_MIN_DATE} || $parsedDate, $parsedDate))[-1];
    # $counts->{_MAX_DATE} = (sort { Date_Cmp($a, $b) } ($counts->{_MAX_DATE} || $parsedDate, $parsedDate))[-1];
  }
  elsif($value =~ /^\d/) {
    $counts->{_IS_ORDINAL_COUNT}++;
    $counts->{_VALUES}->{$value}++;
  }
  else {
      $counts->{_VALUES}->{$value}++;
#    my $lcValue = lc $value;
#    if($lcValue eq 'yes' || $lcValue eq 'no' || $lcValue eq 'true' || $lcValue eq 'false') {
#      $counts->{_IS_BOOLEAN_COUNT}++;
#    }
  }

  $stringValue = $value unless(defined($dateValue) || defined($numberValue));

  return $counts, $stringValue, $numberValue, $dateValue;
}


sub readClob {
  my ($self, $lobLocator) = @_;

  my $dbh = $self->getQueryHandle();

  my $chunkSize = $self->{_lob_locator_size};

  unless($chunkSize) {
    $self->{_lob_locator_size} = $dbh->ora_lob_chunk_size($lobLocator);
    $chunkSize = $self->{_lob_locator_size};
  }

  my $offset = 1;   # Offsets start at 1, not 0

  my $output;

  while(1) {
    my $data = $dbh->ora_lob_read($lobLocator, $offset, $chunkSize );
    last unless length $data;
    $output .= $data;
    $offset += $chunkSize;
  }

  return $output;
}


sub loadAttributesFromEntity {
  loadAttributes(@_, "
select va.entity_attributes_id
     , va.entity_type_id
     , null as process_type_id
     , va.atts
from apidb.entityattributes va
   , apidb.entitytype vt
where to_char(substr(va.atts, 1, 2)) != '{}'
and vt.entity_type_id = va.entity_type_id
and vt.study_id = ?");
}


sub loadAttributesFromIncomingProcess {
  loadAttributes(@_, "
select va.entity_attributes_id
     , va.entity_type_id
     , ea.process_type_id
     , ea.atts
from apidb.processattributes ea
   , apidb.entityattributes va
   , apidb.entitytype vt
where to_char(substr(ea.atts, 1, 2)) != '{}'
and vt.entity_type_id = va.entity_type_id
and va.entity_attributes_id = ea.out_entity_id
and vt.study_id = ?
");
}

sub fields {
  my ($self, $maxAttrLength) = @_;
  my $database = $self->getDb();
  my $projectId = $database->getDefaultProjectId();
  my $userId = $database->getDefaultUserId();
  my $groupId = $database->getDefaultGroupId();
  my $algInvocationId = $database->getDefaultAlgoInvoId();
  my $userRead = $database->getDefaultUserRead();
  my $userWrite = $database->getDefaultUserWrite();
  my $groupRead = $database->getDefaultGroupRead();
  my $groupWrite = $database->getDefaultGroupWrite();
  my $otherRead = $database->getDefaultOtherRead();
  my $otherWrite = $database->getDefaultOtherWrite();

  my ($sec,$min,$hour,$mday,$mon,$year) = localtime();
  my @abbr = qw(JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC);
  my $modDate = sprintf('%2d-%s-%02d', $mday, $abbr[$mon], ($year+1900) % 100);

  my $datatypeMap = {'user_read' => " constant $userRead", 
                     'user_write' => " constant $userWrite", 
                     'group_read' => " constant $groupRead", 
                     'group_write' => " constant $groupWrite", 
                     'other_read' => " constant $otherRead", 
                     'other_write' => " constant $otherWrite", 
                     'row_user_id' => " constant $userId", 
                     'row_group_id' => " constant $groupId", 
                     'row_alg_invocation_id' => " constant $algInvocationId",
                     'row_project_id' => " constant $projectId",
                     'modification_date' => " constant \"$modDate\"",
  };


  my $attributeList = ["entity_attributes_id",
                       "entity_type_id",
                       "incoming_process_type_id",
                       "attribute_stable_id",
                       "string_value",
                       "number_value",
                       "date_value",
                       "attribute_value_id",
      ];

  push @$attributeList, keys %$datatypeMap;

  $datatypeMap->{'entity_attributes_id'} = " CHAR(12)";
  $datatypeMap->{'entity_type_id'} = "  CHAR(12)";
  $datatypeMap->{'incoming_process_type_id'} = "  CHAR(12)";
  $datatypeMap->{'attribute_stable_id'} = "  CHAR(255)";
  $datatypeMap->{'string_value'} = "  CHAR($maxAttrLength)";
  $datatypeMap->{'number_value'} = "  CHAR($maxAttrLength)";
  $datatypeMap->{'date_value'} = " DATE 'yyyy-mm-dd hh24:mi:ss'";
  $datatypeMap->{'attribute_value_id'} = " SEQUENCE(MAX,1)";
  
  my @fields = map { lc($_) . $datatypeMap->{lc($_)}  } @$attributeList;

  return \@fields;
}


sub makeFifo {
  my ($self, $fields, $fifoName) = @_;

  my $eorLiteral = $END_OF_RECORD_DELIMITER;
  $eorLiteral =~ s/\n/\\n/;

  my $eocLiteral = $END_OF_COLUMN_DELIMITER;
  $eocLiteral =~ s/\t/\\t/;

  my $database = $self->getDb();
  my $login       = $database->getLogin();
  my $password    = $database->getPassword();
  my $dbiDsn      = $database->getDSN();
  my ($dbi, $type, $db) = split(':', $dbiDsn);

  my $sqlldr = ApiCommonData::Load::Sqlldr->new({_login => $login,
                                                 _password => $password,
                                                 _database => $db,
                                                 _direct => 0,
                                                 _controlFilePrefix => 'sqlldr_AttributeValue',
                                                 _quiet => 1,
                                                 _infile_name => $fifoName,
                                                 _reenable_disabled_constraints => 1,
                                                 _table_name => "ApiDB.AttributeValue",
                                                 _fields => $fields,
                                                 _rows => 100000
                                                });

  $sqlldr->setLineDelimiter($eorLiteral);
  $sqlldr->setFieldDelimiter($eocLiteral);

  $sqlldr->writeConfigFile();

  my $fifo = ApiCommonData::Load::Fifo->new($fifoName);

  my $sqlldrProcessString = $sqlldr->getCommandLine();

  my $pid = $fifo->attachReader($sqlldrProcessString);
  $self->addActiveForkedProcess($pid);

  my $sqlldrInfileFh = $fifo->attachWriter();

  return $fifo;
}

sub error {
  my ($self, $msg) = @_;
  print STDERR "\nERROR: $msg\n";

  foreach my $pid (@{$self->getActiveForkedProcesses()}) {
    kill(9, $pid); 
  }

  $self->SUPER::error($msg);
}


sub undoTables {
  my ($self) = @_;
  return (
    'ApiDB.Attribute',
    'ApiDB.AttributeValue',
      );
}

1;
