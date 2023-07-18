package ApiCommonData::Load::Plugin::MakeEntityDownloadFiles;

@ISA = qw(GUS::PluginMgr::Plugin);
use strict;
use GUS::PluginMgr::Plugin;

use File::Basename;
use Data::Dumper;

my $purposeBrief = 'Dump dataset-specific ANCESTORS+ATTRIBUTES to a tabular file with headers as display_name [IRI] from ATTRIBUTEGRAPH';
my $purpose = $purposeBrief;

my $tablesAffected =
    [     ];

my $tablesDependedOn =
    [    ];

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
 stringArg({ name            => 'outputDir',
	     descr           => 'directory for output files',
	     reqd            => 0,
	     constraintFunc  => undef,
	     isList          => 0 }),
 stringArg({ name            => 'fileBasename',
	     descr           => 'basename for output files',
	     reqd            => 0,
	     constraintFunc  => undef,
	     isList          => 0 }),
 stringArg({name           => 'schema',
       descr          => 'GUS::Model schema for entity tables',
       reqd           => 1,
       constraintFunc => undef,
       isList         => 0, }),

];

my ${SCHEMA} = '__SCHEMA__'; # must be replaced with real schema name

# temporary, just in case
my $HARDCODE_FORCED_HIDDEN = {
  EUPATH_0043203 => 1,
  EUPATH_0043204 => 1,
  EUPATH_0043205 => 1,
  EUPATH_0043206 => 1,
  EUPATH_0043207 => 1,
  EUPATH_0043208 => 1,
  EUPATH_0043209 => 1,
};

# ----------------------------------------------------------------------

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  $self->initialize({ requiredDbVersion => 4.0,
                      cvsRevision       => '$Revision$',
                      name              => ref($self),
                      argsDeclaration   => $argsDeclaration,
                      documentation     => $documentation});

  return $self;
}

# ======================================================================

sub run {
  my ($self) = @_;
  ${SCHEMA} = $self->getArg('schema');
  my $extDbRlsSpec = $self->getArg('extDbRlsSpec');
  my $extDbRlsId = $self->getExtDbRlsId($extDbRlsSpec);
  my ($datasetName,$ver) = split(/\|/, $extDbRlsSpec);
  $datasetName =~ s/\|.*//;
  my $outputDir = $self->getArg('outputDir');
  my $fileBasename = sprintf("%s_PREFIX_%s", $datasetName, $self->getArg('fileBasename') || $datasetName);

  my $ontologySpec = $self->getArg('ontologyExtDbRlsSpec'); # for entity labels
  my $ontologyId = $self->getExtDbRlsId($ontologySpec);

  my $studies = $self->sqlAsDictionary( Sql  => "select study_id, internal_abbrev from ${SCHEMA}.study where external_database_release_id = $extDbRlsId");

  $self->error("Expected one study row.  Found ". scalar keys %$studies) unless(scalar keys %$studies == 1);

  $self->getDbHandle()->do("alter session set nls_date_format = 'yyyy-mm-dd'") or die $self->getDbHandle()->errstr;

  foreach my $studyId (keys %$studies) {
    my $studyAbbrev = $studies->{$studyId};
    $self->log("Loading Study: $studyAbbrev");
    my $entityTypeIds = $self->entityTypeIdsFromStudyId($studyId,$ontologyId);
    my %entityNames = map { uc($_->{ABBREV}) => $_->{LABEL} } values %$entityTypeIds;
  
    #  When generating R script these must be copied to a new column in each table: mergeKey
    #  Observation date [EUPATH_0004991]
    #  Collection date [EUPATH_0020003]
    #  Don't forget to delete the new column before writing output

    my %mergeInfo; # populate with id_cols, merge_key for each file
    while( my ($entityTypeId, $meta) = each %$entityTypeIds) {
      my $entityTypeAbbrev = $meta->{ABBREV};
      my $entityNameForFile = $meta->{PLURAL} || $meta->{LABEL} || $entityTypeAbbrev;
      my $entityName = map { ucfirst($_) } split(/\s/, $meta->{LABEL});
      $entityNameForFile =~ tr/ /_/;
      $entityName =~ tr/ /_/;
      my $outputFile;
      if($outputDir){ 
         unless(-d $outputDir){
           mkdir($outputDir) or die "Cannot create output directory $outputDir: $!\n";
         }
         $outputFile = sprintf("%s/%s_%s.txt", $outputDir, $fileBasename, $entityNameForFile);
      }
      else{
        $outputFile = sprintf("%s_%s.txt", $fileBasename, $entityNameForFile);
      }
      $self->log("Making download file $outputFile for Entity Type $entityTypeAbbrev (ID $entityTypeId)");
      $mergeInfo{$outputFile} =  $self->createDownloadFile($entityTypeId, $entityTypeAbbrev, \%entityNames, $studyAbbrev,$outputFile);
    }
    #
    my $allMergedFile = sprintf("%s%s.txt", $outputDir ? "$outputDir/" : "", $fileBasename);
    $self->log("Making all data merged file $allMergedFile ");
    my $tempScript = "merge_script.R";
    if($outputDir){$tempScript = join("/", $outputDir,$tempScript)}
    printf STDERR "Writing script $tempScript\n";
    open(FH, ">",$tempScript) or die "Cannot write $tempScript: $!\n"; 
    my $code = $self->mergeScript($allMergedFile, \%mergeInfo);
    print FH ($code);
    close(FH);
    printf STDERR "Running $tempScript\n";
  # if(system("nice -n40 Rscript $tempScript")){
  #   $self->error("$tempScript failed");
  # }

    ## ontology file

    my $outputFile = "OntologyMetadata.txt"; 
    if($outputDir){ 
       unless(-d $outputDir){
         mkdir($outputDir) or die "Cannot create output directory $outputDir: $!\n";
       }
       $outputFile = sprintf("%s/%s_OntologyMetadata.txt", $outputDir, $fileBasename);
    }
    else{
      $outputFile = sprintf("%s_OntologyMetadata.txt", $fileBasename);
    }
    $self->log("Making ontology file $outputFile");
    $self->makeOntologyFile($outputFile, $studyAbbrev, $ontologyId);
  }
  return("Created download files");
}

sub createDownloadFile {
 my ($self, $entityTypeId, $entityTypeAbbrev, $entityNames, $studyAbbrev, $outputFile) = @_;

  # entity data with unsorted IRI columns
  # (entity) STABLE_ID, IRIs...
  my $dataTableName = "${SCHEMA}.Attributes_${studyAbbrev}_${entityTypeAbbrev}";
  # [TYPE]_STABLE_ID, [PARENT_TYPE]_STABLE_ID, ...

  my $ancestorTableName = "${SCHEMA}.Ancestors_${studyAbbrev}_${entityTypeAbbrev}";
  # ontology info
  # (iri) STABLE_ID, DISPLAY_NAME
 
  my $attrTableName = "${SCHEMA}.AttributeGraph_${studyAbbrev}_${entityTypeAbbrev}";
  my $multiValueIRIs = $self->sqlAsDictionary( Sql =>
    "select stable_id, is_multi_valued from $attrTableName where is_multi_valued=1");

  # get an iri dictionary, the column header in the format "display_name [SOURCE_ID]"
  my $sql = <<SQL_GETLABELS;
SELECT STABLE_ID, DISPLAY_NAME || ' [' || STABLE_ID || ']' as LABEL FROM $attrTableName WHERE DATA_TYPE IS NOT NULL and UNIT IS NULL
and (HIDDEN is NULL or json_value(HIDDEN,'\$[0]') NOT IN ('everywhere','download'))
UNION
SELECT STABLE_ID, DISPLAY_NAME || ' (' || UNIT || ') [' || STABLE_ID || ']' as LABEL FROM $attrTableName WHERE DATA_TYPE IS NOT NULL and UNIT IS NOT NULL
and (HIDDEN is NULL or json_value(HIDDEN,'\$[0]') NOT IN ('everywhere','download'))
SQL_GETLABELS
  my $attrNames = $self->sqlAsDictionary( Sql => $sql );
  my @orderedIRIs = sort { $attrNames->{$a} cmp $attrNames->{$b} } keys %$attrNames;
  my $totalcols = scalar(@orderedIRIs);
  # get Merge Key, if any
  $sql = sprintf("SELECT t1.display_name || ' [' || t1.stable_id || ']' MERGE_KEY,t1.stable_id value FROM %s t1 WHERE t1.IS_MERGE_KEY = 1", $attrTableName);
  my ($mergeKey, $mergeKeyIRI) = each  %{ $self->sqlAsDictionary( Sql => $sql ) };

  my $valueTableName = "${SCHEMA}.AttributeValue_${studyAbbrev}_${entityTypeAbbrev}";
  my $stableIdCol = uc("${entityTypeAbbrev}_STABLE_ID");

  my $sql = "select DISTINCT at.*, vt.attribute_stable_id, vt.string_value from $ancestorTableName at left join $valueTableName vt on at.$stableIdCol=vt.$stableIdCol where vt.string_value is not NULL order by at.$stableIdCol";
  my $dbh = $self->getQueryHandle();
  my $sh = $dbh->prepare($sql);
  $sh->execute;
  my @cols = @{$sh->{NAME}}; 
  my @entityIdCols; # for creating this file (raw ID from SQL)
  my @mergeIdCols; # for merging with this file (pretty ID from file)
  foreach my $col (@cols){
    # the first columns must be *_STABLE_ID
    last if($col eq 'ATTRIBUTE_STABLE_ID');
    my ($type) = ($col =~ m/^(.*)_STABLE_ID/i);
    my $name = $entityNames->{uc($type)};
    $name =~ tr/ /_/;
    $attrNames->{$col} = "${name}_Id";
    push(@entityIdCols, $col);
    push(@mergeIdCols, $attrNames->{$col});
  }
  if($mergeKey){ # place immediately after IDs
    push(@entityIdCols, $mergeKeyIRI);
    @orderedIRIs = grep { ! /^$mergeKeyIRI$/ } @orderedIRIs;
  }
  open(FH, ">$outputFile") or die "Cannot write $outputFile: $!\n";
  # print header row
  printf FH ("%s\n", join("\t", map { $attrNames->{$_} } @entityIdCols, @orderedIRIs));
  
  my $entityId = "___NOT_SET____";
  my $hash = {};
  my $keycount = 0;
  my $totalEntityIds = 0;
  while(my $row = $sh->fetchrow_hashref()) {
    next if ($HARDCODE_FORCED_HIDDEN->{$row->{ATTRIBUTE_STABLE_ID}});
    # $entityId ||= $row->{ $stableIdCol };
    my ($attrId, $value) = ($row->{ATTRIBUTE_STABLE_ID}, $row->{STRING_VALUE});
    if($entityId ne $row->{ $stableIdCol }) {
      #New row batch (per entityId): print previous and load next entity+ancestor IDs
      $self->formatValues($hash, \@orderedIRIs, $multiValueIRIs);
      if(keys %$hash){
        printf FH ("%s\n", join("\t", map { ref($hash->{$_}) eq 'ARRAY' ? join("|",@{$hash->{$_}}) : $hash->{$_} } @entityIdCols, @orderedIRIs));
      }
      $hash = $row; 
      delete $hash->{ATTRIBUTE_STABLE_ID};
      delete $hash->{STRING_VALUE};
      $keycount = 0;
      $totalEntityIds++;
      $entityId = $row->{ $stableIdCol };
    }
    if( $keycount > $totalcols ){
      # Not necessary to wipe out the entire row; only mapped terms will get printed
      #foreach my $col (@entityIdCols, @orderedIRIs){ delete $hash->{$col} }
      printf STDERR ("WARNING... too many variables found (wanted $totalcols, found $keycount): %s\n", join(",", keys %$hash));
      #die ("ERROR: Entity ID not incremented $entityId. Saw $totalEntityIds entities, last variable count $keycount > $totalcols\n");
    }
    unless(defined $hash->{$attrId} ){
      $hash->{$attrId} = [];
      $keycount++;
    }
    push(@{ $hash->{ $attrId } }, $value);
  }
  $self->formatValues($hash, \@orderedIRIs, $multiValueIRIs);
  printf FH ("%s\n", join("\t", map { ref($hash->{$_}) eq 'ARRAY' ? join("|",@{$hash->{$_}}) : $hash->{$_} } @entityIdCols, @orderedIRIs));
  close(FH);
  return { id_cols => \@mergeIdCols, merge_key => $mergeKey };
}

sub formatValues {
  my ($self, $hash, $orderedIRIs, $multiValueIRIs) = @_;
  foreach my $col ( @$orderedIRIs){
    if(!defined($hash->{$col}) || scalar @{$hash->{$col}} < 1 ){ next }
    if((scalar @{ $hash->{$col} } > 1) || $multiValueIRIs->{$col}){
      $hash->{$col} = sprintf('[%s]', join(",", map { sprintf('"%s"', $_) } @{$hash->{$col}}));
    }
    else {
      $hash->{$col} = $hash->{$col}->[0];
    }
  }
}

sub entityTypeIdsFromStudyId {
  my ($self, $studyId,$ontologyId) = @_;

  my $sql = "select t.entity_type_id TYPE_ID, t.internal_abbrev ABBREV,os.ontology_synonym LABEL, os.plural PLURAL,
regexp_replace(os.ONTOLOGY_SYNONYM ,'\s','_') || '_Id' ID_COLUMN
from ${SCHEMA}.entitytype t
left join SRes.OntologySynonym os on t.type_id=os.ontology_term_id
where t.study_id = $studyId
and os.external_database_release_id = $ontologyId
UNION 
select t.entity_type_id TYPE_ID, t.internal_abbrev ABBREV,t.name LABEL, '' PLURAL,
regexp_replace(t.name ,'\s','_') || '_Id' ID_COLUMN
from EDA.entitytype t
where t.study_id = $studyId
AND t.TYPE_ID NOT IN (SELECT ontology_term_id FROM SRes.OntologySynonym WHERE EXTERNAL_DATABASE_RELEASE_ID = $ontologyId)";

  my $dbh = $self->getQueryHandle();
  $dbh->do("alter session set nls_date_format = 'yyyy-mm-dd'");
  my $sh = $dbh->prepare($sql);
  $sh->execute();
  my %entityTypeIds;
  while(my $row = $sh->fetchrow_hashref()) {
    $entityTypeIds{ $row->{TYPE_ID} } = $row;
  }
  $self->{entityTypeIds} = \%entityTypeIds;
  return \%entityTypeIds;
}

sub makeOntologyFile {
  my ($self, $outputFile, $studyAbbrev, $ontologyId) = @_;
  my @cols = (qw/ iri label type parentlabel category definition min max average median upper_quartile lower_quartile number_distinct_values distinct_values variable replaces/);
  #my @cols = (qw/ iri label type parentlabel category definition min max number_distinct_values distinct_values variable replaces/);
  open(FH, ">$outputFile") or die "Cannot write $outputFile:$!\n";
  printf FH ("%s\n", join("\t", @cols));
  my $entityTypeIds = $self->{entityTypeIds};
  foreach my $entityType ( values %{$self->{entityTypeIds}} ){
    my $type = $entityType->{ABBREV};
    my $category = $entityType->{LABEL};
    my $tableName = "${SCHEMA}.AttributeGraph_${studyAbbrev}_${type}";
    my $sql =  <<ONTOSQL;
WITH replacesIRI AS
(SELECT o2.SOURCE_ID STABLE_ID, json_value(o.ANNOTATION_PROPERTIES,'\$.replaces[0]') REPLACES FROM sres.ONTOLOGYSYNONYM o
LEFT JOIN sres.ONTOLOGYTERM o2 ON o.ONTOLOGY_TERM_ID=o2.ONTOLOGY_TERM_ID
WHERE o.EXTERNAL_DATABASE_RELEASE_ID=$ontologyId
),
parent AS 
(SELECT o4.SOURCE_ID STABLE_ID, o3.ONTOLOGY_SYNONYM LABEL FROM sres.ONTOLOGYSYNONYM o3
LEFT JOIN sres.ONTOLOGYTERM o4 ON o3.ONTOLOGY_TERM_ID=o4.ONTOLOGY_TERM_ID
WHERE o3.EXTERNAL_DATABASE_RELEASE_ID=$ontologyId)
SELECT ag.stable_id, ag.display_name, ag.data_type, parent.label,
'$category' category, ag.definition, ag.range_min, ag.range_max,
ag.mean, ag.median, ag.upper_quartile, ag.lower_quartile,
ag.distinct_values_count, ag.vocabulary, ag.provider_label, replacesIRI.replaces
FROM $tableName ag
left join replacesIRI ON ag.STABLE_ID = replacesIRI.stable_id
LEFT JOIN parent ON ag.parent_stable_id=parent.stable_id
WHERE (ag.HIDDEN IS NULL OR json_value(ag.hidden,'\$[0]') NOT IN ('everywhere','download'))
ONTOSQL
## print STDERR "Get ontology metadata:\n$sql\n";
    my $dbh = $self->getQueryHandle();
    $dbh->do("alter session set nls_date_format = 'yyyy-mm-dd'");
    my $sh = $dbh->prepare($sql);
    $sh->execute();
    while(my $row = $sh->fetchrow_arrayref()) {
      printf FH ("%s\n", join("\t", @$row));
    }
  }
  close(FH);
}

sub mergeScript {
  my ($self, $outputFile, $mergeInfo) = @_;


  my $TMK = "TemporaryMergeKey";
  my $ALLTAB = "MasterDataTable";
  my $ENTITYTAB = "entityTable";

  my @scriptLines = (
  "#!/usr/bin/env Rscript",
  "library(data.table)",
  "library(plyr)",
  "$ALLTAB = c()", # merged data
  "",""
  );

  my @orderedFiles = sort { scalar(@{$mergeInfo->{$a}->{id_cols}}) <=> scalar(@{$mergeInfo->{$b}->{id_cols}}) } keys %$mergeInfo;
  # process files in order of least number of ID cols (equivalent to number of ancestors + self)
  
  my $firstFile = 1;
  my %allMergedCols; # mergeable columns in all, including mergeKey
  my @mergeKeyCols;
  # $fileInfo is set at the end of createDownloadFile
  foreach my $fileName(@orderedFiles){
      my $fileInfo = $mergeInfo->{$fileName};
      push(@mergeKeyCols, $fileInfo->{merge_key}) if ($fileInfo->{merge_key});
      push(@scriptLines, sprintf("\n# Merging %s", basename($fileName)));
    my @mergeCols;
    ###
    if($firstFile){
      $firstFile = 0;
      push(@scriptLines, sprintf('%s <- fread("%s", header=T, sep="\t")', $ALLTAB, $fileName));
      if( $fileInfo->{merge_key} ){
        push(@scriptLines, sprintf('%s$%s = as.character(%s$"%s")', $ALLTAB, $TMK, $ALLTAB, $fileInfo->{merge_key}));
      }
    }
    else {
      push(@scriptLines, sprintf('%s <- fread("%s", header=T, sep="\t")', $ENTITYTAB, $fileName));
      if( $fileInfo->{merge_key} ){
        push(@scriptLines, sprintf('%s$%s = as.character(%s$"%s")', $ENTITYTAB, $TMK, $ENTITYTAB, $fileInfo->{merge_key}));
        if($allMergedCols{$TMK}) { push(@mergeCols, $TMK) }
      }
      foreach my $idCol ( @{ $fileInfo->{id_cols} } ){
        if( $allMergedCols{$idCol} ) { push(@mergeCols, $idCol) }
      }
      my $mergeBy = join(",", map { "\"$_\"" } @mergeCols);
      push(@scriptLines, sprintf("%s <- merge(%s, %s, by = c(%s), allow.cartesian=T, all=T)", $ALLTAB, $ALLTAB, $ENTITYTAB, $mergeBy));
    }
    ###
    $allMergedCols{$_} = 1 for @{ $fileInfo->{id_cols} };
    $allMergedCols{$TMK} = 1 if($fileInfo->{merge_key});
    push(@scriptLines, 'cat(sprintf("%d rows\n", nrow(' . $ALLTAB .')))');
  }
  if($allMergedCols{$TMK}) { push(@scriptLines, sprintf('%s$%s <- NULL', $ALLTAB, $TMK)) }
  ## reorder all
  push(@scriptLines, sprintf("setcolorder(%s, order(names(%s)))", $ALLTAB, $ALLTAB));

  my $mergeKeys = "";
  if(@mergeKeyCols){  
    $mergeKeys = ', ' . join(",", map { sprintf('"%s"', $_) } @mergeKeyCols);
  }
my $moveIdCols = <<MOVEIDCOLS;
orderedIdCols = c()
for( idcol in c("Community_Id", "Community_repeated_measure_Id", "Household_Id", "Household_repeated_measure_Id",
 "Entomology_collection_Id", "Participant_Id", "Repeated_measure_Id", "Participant_repeated_measure_Id",  "Sample_Id" 
  $mergeKeys ) ){
  if( idcol %in% names($ALLTAB) ){
    orderedIdCols <- append( orderedIdCols, grep( idcol, names($ALLTAB), fixed=T ) )
  }
}
setcolorder( $ALLTAB, orderedIdCols )
MOVEIDCOLS
  push(@scriptLines, $moveIdCols);
  # force all data to be character (for dates, numerical IDs, etc.)
  push(@scriptLines, sprintf('fwrite(%s,"%s", sep="\t", na="NA")', $ALLTAB, $outputFile));
  push(@scriptLines, '', 'quit("no")', '');
  return join("\n", @scriptLines);
}





sub undoTables {}


1;
