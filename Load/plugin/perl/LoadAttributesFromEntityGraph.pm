package ApiCommonData::Load::Plugin::LoadAttributesFromEntityGraph;
# Load attributes into EDA.attribute and EDA.attributevalue
# Warning! Only one instance of this plugin should run at a time
# because values for attribute_value_id are written as SEQUENCE(MAX,1)
#
@ISA = qw(GUS::PluginMgr::Plugin ApiCommonData::Load::Plugin::ParameterizedSchema);
use strict;
use warnings;
use GUS::PluginMgr::Plugin;
use ApiCommonData::Load::Plugin::ParameterizedSchema;

use ApiCommonData::Load::Fifo;
use ApiCommonData::Load::Sqlldr;

use Scalar::Util qw(looks_like_number);

use List::Util qw(min max);
#use Date::Manip qw(ParseDate Date_Cmp);

use File::Temp qw/ tempfile tempdir tmpnam /;

use Time::HiRes qw(gettimeofday);

use ApiCommonData::Load::StudyUtils qw(queryForOntologyTerms getTermsWithDataShapeOrdinal);

use JSON;

use Data::Dumper;

my $SCHEMA = '__SCHEMA__'; # must be replaced with real schema name

my $END_OF_RECORD_DELIMITER = "#EOR#\n";
my $END_OF_COLUMN_DELIMITER = "#EOC#\t";

my $RANGE_FIELD_WIDTH = 16; # truncate numbers to fit Attribute table: Range_min, Range_max, Bin_width (varchar2(16))

my $TERMS_WITH_DATASHAPE_ORDINAL = {};

my $ALLOW_VOCABULARY_COUNT = 10; # if the number of distinct values is less, generate vocabulary/ordered_values/ordinal_values

my $FORCED_PRECISION = {
    ### for studies with lat/long: GEOHASH i => i
    EUPATH_0043203 => 1, 
    EUPATH_0043204 => 2, 
    EUPATH_0043205 => 3, 
    EUPATH_0043206 => 4, 
    EUPATH_0043207 => 5, 
    EUPATH_0043208 => 6,
  };

my $purposeBrief = 'Read Study tables and insert tall table for attribute values and attribute table';
my $purpose = $purposeBrief;

my @UNDO_TABLES = qw(
  Attribute
  AttributeValue
);
my @REQUIRE_TABLES = qw(
  Attribute
);

my $tablesAffected =
    [ ['__SCHEMA__::Attribute', ''],
      ['__SCHEMA__::AttributeValue', '']
    ];

my $tablesDependedOn =
    [['__SCHEMA__::Study',''],
     ['__SCHEMA__::EntityAttributes',  ''],
     ['__SCHEMA__::ProcessAttributes',  ''],
     ['__SCHEMA__::ProcessType',  ''],
     ['__SCHEMA__::EntityType',  ''],
     ['__SCHEMA__::AttributeUnit',  ''],
     ['SRes::OntologyTerm',  ''],
     ['__SCHEMA__::ProcessType',  ''],
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
   stringArg({name           => 'schema',
            descr          => 'GUS::Model schema for entity tables',
            reqd           => 1,
            constraintFunc => undef,
            isList         => 0, }),

   booleanArg({name => 'runRLocally',
          descr => 'if true, will assume Rscript and plot.data are installed locally.  otherwise will call singularity',
          reqd => 1,
          constraintFunc => undef,
          isList => 0,
         }),



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
  $self->{_require_tables} = \@REQUIRE_TABLES;
  $self->{_undo_tables} = \@UNDO_TABLES;
  return $self;
}


$| = 1;

sub run {
  my $self  = shift;

  ## ParameterizedSchema
  $self->requireModelObjects();
  $self->resetUndoTables(); # for when logRowsInserted() is called after loading
  $SCHEMA = $self->getArg('schema');
  ## 

  chdir $self->getArg('logDir');


  my $extDbRlsId = $self->getExtDbRlsId($self->getArg('extDbRlsSpec'));
  
  my $studies = $self->sqlAsDictionary( Sql  => "select study_id, max_attr_length from $SCHEMA.study where external_database_release_id = $extDbRlsId");

  $self->error("Expected one study row.  Found ". scalar keys %{$studies}) unless(scalar keys %$studies == 1);

  $self->getQueryHandle()->do("alter session set nls_date_format = 'yyyy-mm-dd hh24:mi:ss'") or die $self->getQueryHandle()->errstr;

  my $dbh = $self->getQueryHandle();
  my $ontologyExtDbRlsSpec = $self->getExtDbRlsId($self->getArg('ontologyExtDbRlsSpec'));

  my $studiesCount;
  while(my ($studyId, $maxAttrLength) = each (%$studies)) {
    $studiesCount++;

    my $entityTypeIds = $self->queryForEntityTypeIds($studyId);

    my $ontologyTerms = &queryForOntologyTerms($dbh, $ontologyExtDbRlsSpec);
    $self->addUnitsToOntologyTerms($studyId, $ontologyTerms, $self->getExtDbRlsId($self->getArg('ontologyExtDbRlsSpec')));
    $TERMS_WITH_DATASHAPE_ORDINAL = &getTermsWithDataShapeOrdinal($dbh, $ontologyExtDbRlsSpec) ;

    my $tempDirectory = tempdir( CLEANUP => 1 );
    my ($dateValsFh, $dateValsFileName) = tempfile( DIR => $tempDirectory);
    my ($numericValsFh, $numericValsFileName) = tempfile( DIR => $tempDirectory);

    my ($annPropsByAttributeStableIdAndEntityTypeId, $typeCountsByAttributeStableIdAndEntityTypeId) = $self->loadAttributeValues($studyId, $ontologyTerms, $maxAttrLength, $dateValsFh, $numericValsFh);

    my $statsForPlotsByAttributeStableIdAndEntityTypeId = $self->statsForPlots($dateValsFileName, $numericValsFileName, $tempDirectory);

    my $attributeCount = $self->loadAttributeTerms($annPropsByAttributeStableIdAndEntityTypeId, $typeCountsByAttributeStableIdAndEntityTypeId, $statsForPlotsByAttributeStableIdAndEntityTypeId, $entityTypeIds);

    $self->log("Loaded $attributeCount attributes for study id $studyId");
  }

  return 0;
}


sub statsForPlots {
  my ($self, $dateValsFileName, $numericValsFileName, $tempDirectory) = @_;

  my $outputStatsFileName = tmpnam();
  while(-e $outputStatsFileName) {
    $outputStatsFileName = tmpnam();
  }

  my ($rCommandsFh, $rCommandsFileName) = tempfile( DIR => $tempDirectory, UNLINK => 0 );

  print $rCommandsFh $self->rCommandsForStats();

  my $singularity =  "singularity exec docker://veupathdb/rserve";
  if($self->getArg("runRLocally")) {
    $singularity = "";
  }

  printf STDERR ("$singularity Rscript $rCommandsFileName $numericValsFileName $outputStatsFileName\n");
  my $numberSysResult = system("$singularity Rscript $rCommandsFileName $numericValsFileName $outputStatsFileName");
  if($numberSysResult) {
    $self->error("Error Running Rscript for numericFile");
  }

  printf STDERR ("$singularity Rscript $rCommandsFileName $dateValsFileName $outputStatsFileName\n");
  my $dateSysResult = system("$singularity Rscript $rCommandsFileName $dateValsFileName $outputStatsFileName");
  if($dateSysResult) {
    $self->error("Error Running Rscript for datesFile");
  }

  my $rv = {};
  open(FILE, "<", $outputStatsFileName) or die "Cannot open $outputStatsFileName for reading: $!";
  
  while(<FILE>) {
    chomp;
    my ($attributeSourceId, $entityTypeId, $min, $max, $binWidth, $mean, $median, $lower_quartile, $upper_quartile) = split(/\t/, $_);

    $rv->{$attributeSourceId}->{$entityTypeId} =  {range_min => $self->truncateSummaryStat($min),
                                                   range_max => $self->truncateSummaryStat($max),
                                                   bin_width => $self->truncateSummaryStat($binWidth),
                                                   mean => $self->truncateSummaryStat($mean),
                                                   median => $self->truncateSummaryStat($median),
                                                   lower_quartile => $self->truncateSummaryStat($lower_quartile),
                                                   upper_quartile => $self->truncateSummaryStat($upper_quartile),
    };
  }
  close FILE;
  unlink $outputStatsFileName;

  return $rv;
}

sub truncateSummaryStat {
  my ($self,$val) = @_;
  return $val unless(looks_like_number($val) && $val !~ /^(inf|nan)$/);
  my $type = "integer";
  if(length($val) > $RANGE_FIELD_WIDTH){
    # trim scientific notation, which should always be in the format
    if($val =~ /^([-+]?\d*)\.\d+(e[-+]?\d+)$/){ 
      $type = "exponent";
      # sprintf will always handle irregular notation e.g. 101.3e-12 => 1.013e-10
      my $width = $RANGE_FIELD_WIDTH - (length($1 . $2) + 1);
      $val = sprintf("%.${width}e", $val);
    }
    elsif($val =~ /^([-+]?\d+)\.\d+$/){  # floating point, no exponent
      $type = "floating point";
      my $width = $RANGE_FIELD_WIDTH - (length($1) + 1);
      $val = sprintf("%.${width}f", $val);
    }
    else { # really big number should be in notation anyway
      $type = "long int";
      my $width = $RANGE_FIELD_WIDTH - 6; # should be short enough allowing for negative, decimal, and exp up to 2 digits
      $val = sprintf("%.$width", $val);
    }
    if(length($val) > $RANGE_FIELD_WIDTH ){
      $self->error("Your math is off! $val is still too long; fix the calculation where \$type=$type");
    }
  }
  return $val;
}

sub rCommandsForStats {
  my $R_script = <<'RSCRIPT';
args = commandArgs(trailingOnly = TRUE);
fileName = args[1];
if( file.info(fileName)$size == 0 ){
  quit('no')
}
outputFileName = args[2];
t = read.table(fileName, header=FALSE, sep="\t");
isDate = 0;
if(!is.character(t$V2)) {
  t$V2 = as.character(t$V2);
}
if(is.character(t$V3)) {
  t$V3 = as.Date(t$V3);
  isDate = 1;
}
u = unique(t[,1:2]);
subsetFxn = function(x, output){
   v = subset(t, V1==x[1] & V2==x[2])$V3
   data.min = min(v);
   data.max = max(v);
   data.mean = mean(v);
   data.median = median(v);
   data.binWidth = plot.data::findBinWidth(v);
  
   if(data.min != data.max) {
     if(isDate) {
       stats = as.Date(stats::fivenum(as.numeric(v)), origin = "1970-01-01");
       data.lower_quartile = stats[2];
       data.upper_quartile = stats[4];
     }
     else {
       stats = stats::fivenum(v); # min, lower hinge, median, upper hinge, max
       data.lower_quartile = stats[2];
       data.upper_quartile = stats[4];
     }
   }
   else {
     data.lower_quartile = "";
     data.upper_quartile = "";
   }
   if(is.null(data.binWidth)) { data.binWidth = "" }
   data.output = c(x, as.character(data.min), as.character(data.max), as.character(data.binWidth), as.character(data.mean), as.character(data.median), as.character(data.lower_quartile), as.character(data.upper_quartile));
   write(data.output, file=outputFileName, append=T, ncolumns=16, sep="\t")
};
apply(u, 1, subsetFxn);
quit('no')
RSCRIPT
return $R_script;
}


sub queryForEntityTypeIds {
  my ($self, $studyId) = @_;

  my %rv;

  my $dbh = $self->getQueryHandle();

  my $sql = "select t.name, t.entity_type_id, ot.source_id
from $SCHEMA.entitytype t, sres.ontologyterm ot
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

      my $statProps = $statsForPlotsByAttributeStableIdAndEntityTypeId->{$attributeStableId}->{$etId};
      $statProps = {} unless($statProps);

      next SOURCE_ID unless $valProps;


      # Danielle: A syntactically valid name
      #   consists of letters, numbers and the dot or underline characters
      #   and starts with a letter or the dot not followed by a number
      $self->error("Bad attribute stable ID: $attributeStableId")
        unless $attributeStableId =~ m{^[.A-Za-z]([.A-Za-z][A-Za-z_.0-9]*)?$};

      my $attribute = $self->getGusModelClass('Attribute')->new({entity_type_id => $etId,
                                                         entity_type_stable_id => $entityTypeIds->{$etId},
                                                         stable_id => $attributeStableId,
                                                         %$annProps,
                                                         %$valProps,
                                                         range_min => $statProps->{range_min},
                                                         range_max => $statProps->{range_max},
                                                         bin_width => $statProps->{bin_width},
                                                         mean      => $statProps->{mean},
                                                         median    => $statProps->{median},
                                                         lower_quartile => $statProps->{lower_quartile},
                                                         upper_quartile => $statProps->{upper_quartile},
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

  my ($dataType, $dataShape);
  my $precision = $cs{_PRECISION};
  my $isNumber = $cs{_IS_NUMBER_COUNT} && $cs{_COUNT} == $cs{_IS_NUMBER_COUNT};
  my $isDate = $cs{_IS_DATE_COUNT} && $cs{_COUNT} == $cs{_IS_DATE_COUNT};
  my $valueCount = scalar(keys(%{$cs{_VALUES}}));
#  my $isBoolean = $cs{_COUNT} == $cs{_IS_BOOLEAN_COUNT};

#  my $isMultiValued = $cs{_IS_MULTI_VALUED};

  if($TERMS_WITH_DATASHAPE_ORDINAL->{$attributeStableId}){
    $dataShape = 'ordinal';
  }
# DEPRECATED - never infer shape = ordinal
# elsif($cs{_IS_ORDINAL_COUNT} && $cs{_COUNT} == $cs{_IS_ORDINAL_COUNT}) {
#   $dataShape = 'ordinal';
# }
  elsif($isDate || $isNumber ){
    $dataShape = 'continuous';
  }
  elsif($valueCount == 2) {
    $dataShape = 'binary';
  }
  else {
    ## TODO do not set if min or max is set
    $dataShape = 'categorical'; 
  }

  my $orderedValues;
  if($dataShape ne 'continuous' || $valueCount <= $ALLOW_VOCABULARY_COUNT) {
    my @values = sort { if(looks_like_number($a) && looks_like_number($b)){ $a <=> $b } else { lc($a) cmp lc($b)} } keys(%{$cs{_VALUES}});
    $orderedValues = encode_json(\@values);
  }

  # OBI term here is for longitude
  if($attributeStableId eq 'OBI_0001621') {
    $dataType = 'longitude'
  }
  elsif($isDate) {
    $dataType = 'date';
  }
  elsif($isNumber && ($precision > 0)) {
    $dataType = 'number';
  }
  elsif($isNumber && ($precision == 0)) {
    $dataType = 'integer';
  }
#  elsif($isBoolean) {
#    $dataType = 'boolean';
#  }
  else {
    $dataType = 'string';
  }
  if(defined ( $FORCED_PRECISION->{$attributeStableId} )){
    $precision = $FORCED_PRECISION->{$attributeStableId};
  }
  return {
    data_type => $dataType,
    distinct_values_count => $valueCount,
#    is_multi_valued => $isMultiValued ? 1 : 0,
    data_shape => $dataShape,
    precision => $precision,
    ordered_values => $orderedValues,
  };
}


sub addUnitsToOntologyTerms {
  my ($self, $studyId, $ontologyTerms, $ontologyExtDbRlsId) = @_;

  my $dbh = $self->getQueryHandle();

  my $sql = "select * from (
select  att.source_id, unit.ontology_term_id, unit.name, 2 as priority
from $SCHEMA.study pg
   , $SCHEMA.entitytype vt
   , $SCHEMA.attributeunit au
   , sres.ontologyterm att
   , sres.ontologyterm unit
where pg.study_id = ?
and pg.study_id = vt.study_id
and vt.entity_type_id = au.entity_type_id
and au.ATTR_ONTOLOGY_TERM_ID = att.ontology_term_id
and au.UNIT_ONTOLOGY_TERM_ID = unit.ontology_term_id
UNION
select ot.source_id
     , uot.ontology_term_id
     , json_value(annotation_properties, '\$.unitLabel[0]') label
     , 1 as priority    
from sres.ontologysynonym os
   , sres.ontologyterm ot
   , sres.ontologyterm uot
where os.ontology_term_id = ot.ontology_term_id
and json_value(annotation_properties, '\$.unitIRI[0]') = uot.uri
and json_value(annotation_properties, '\$.unitLabel[0]') is not null
and os.external_database_release_id = ?
) order by priority
";

  my $sh = $dbh->prepare($sql);
  $sh->execute($studyId, $ontologyExtDbRlsId);

  while(my ($sourceId, $unitOntologyTermId, $unitName) = $sh->fetchrow_array()) {
    if($ontologyTerms->{$sourceId}->{UNIT_ONTOLOGY_TERM_ID}) {
      $self->userError("The Attribute $sourceId can only have one unit specification per study.  Units can be specified either in the ISA files OR in annotation properties");
    }

    $ontologyTerms->{$sourceId}->{UNIT_ONTOLOGY_TERM_ID} = $unitOntologyTermId;
    $ontologyTerms->{$sourceId}->{UNIT_NAME} = $unitName;
  }

  $sh->finish();
}




sub loadAttributeValues {
  my ($self, $studyId, $ontologyTerms, $maxAttrLength, $dateValsFh, $numericValsFh) = @_;

  my $timestamp = int (gettimeofday * 1000);
  my $fifoName = "${SCHEMA}_attributevalue_${timestamp}.dat";

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
#######
        if($annProps->{is_multi_valued} && !($annPropsByAttributeStableIdAndEntityTypeId->{$attributeStableId}{$entityTypeId}{is_multi_valued})){
          $annPropsByAttributeStableIdAndEntityTypeId->{$attributeStableId}{$entityTypeId}{is_multi_valued} = 1;
          printf STDERR ("DEBUG: IS_MULTI_VALUED UPDATED!!! %s\n", $attributeStableId);
        }
######

        my $cs = $typeCountsByAttributeStableIdAndEntityTypeId->{$attributeStableId}{$entityTypeId} // {};
        my ($updatedCs, $stringValue, $numberValue, $dateValue) = $self->typedValueForAttribute($attributeStableId, $cs, $value);
        $typeCountsByAttributeStableIdAndEntityTypeId->{$attributeStableId}{$entityTypeId} = $updatedCs;

        if($dateValue) {
          print $dateValsFh join("\t", $attributeStableId, $entityTypeId, $dateValue) . "\n";
        }
        elsif(defined($numberValue)) { # avoid if( 0 ) evaluating to false
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
      $self->undefPointerCache();
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
  my $isMultiValued = (scalar(@{$valueArray//[]}) > 1);
  my @result;

  VALUE:
  for my $value (@{$valueArray//[]}){
    if (ref $value eq 'HASH'){
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
        push @result, ["${ontologySourceId}_$k", annPropsFromParentOntologyTerm($displayName, $ontologyTerm, $processTypeId, $isMultiValued), $subvalue];
      }
    } else {
      push @result, [$ontologySourceId, annPropsFromOntologyTerm($ontologyTerm, $processTypeId, $isMultiValued), $value];
    }
  }
  return @result;
}

sub typedValueForAttribute {
  my ($self, $attributeStableId, $counts, $value) = @_;

  my ($stringValue, $numberValue, $dateValue); 

  $counts->{_COUNT}++;

  my $valueNoCommas = $value;
  $valueNoCommas =~ tr/,//d;

  $counts->{_VALUES}->{$value}++;

  #####################################################
  ## Abort if annotation property forceStringType = yes
  ## which is loaded into SRes.OntologySynonym.Annotation_Properties
  ## by the step _updateOntologySynonym_owlAttributes
  if($TERMS_WITH_DATASHAPE_ORDINAL->{$attributeStableId}){
    $stringValue = $value; # unless(defined($dateValue) || defined($numberValue));
    return $counts, $stringValue, $numberValue, $dateValue;
  }
  #####################################################

  if(looks_like_number($valueNoCommas) && lc($valueNoCommas) ne "nan" && lc($valueNoCommas) ne "inf") {
    # looks_like_number() considers these numbers: nan=not a number, inf=infinity 
    $numberValue = $valueNoCommas;
    $counts->{_IS_NUMBER_COUNT}++;
    
    my $precision = length(($value =~ /\.(\d+)/)[0]) || 0;
    $counts->{_PRECISION} ||= 0;
    $counts->{_PRECISION} = max($counts->{_PRECISION}, $precision);#if $counts->{_PRECISION};
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
  }
  else {
#    my $lcValue = lc $value;
#    if($lcValue eq 'yes' || $lcValue eq 'no' || $lcValue eq 'true' || $lcValue eq 'false') {
#      $counts->{_IS_BOOLEAN_COUNT}++;
#    }
  }

	# Always load string_value (see https://github.com/VEuPathDB/EdaLoadingIssues/issues/1)
  $stringValue = $value; # unless(defined($dateValue) || defined($numberValue));

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
from $SCHEMA.entityattributes va
   , $SCHEMA.entitytype vt
where va.atts is not null
and vt.entity_type_id = va.entity_type_id
and vt.study_id = ?
");
}


sub loadAttributesFromIncomingProcess {
  loadAttributes(@_, "
select va.entity_attributes_id
     , va.entity_type_id
     , ea.process_type_id
     , ea.atts
from $SCHEMA.processattributes ea
   , $SCHEMA.entityattributes va
   , $SCHEMA.entitytype vt
where ea.atts is not null
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
  my ($dbi, $type, $db) = split(':', $dbiDsn, 3);

  my $sqlldr = ApiCommonData::Load::Sqlldr->new({_login => $login,
                                                 _password => $password,
                                                 _database => $db,
                                                 _direct => 0,
                                                 _controlFilePrefix => 'sqlldr_AttributeValue',
                                                 _quiet => 1,
                                                 _infile_name => $fifoName,
                                                 _reenable_disabled_constraints => 1,
                                                 _table_name => "$SCHEMA.AttributeValue",
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


1;
