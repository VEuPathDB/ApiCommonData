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

];


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
  my $extDbRlsSpec = $self->getArg('extDbRlsSpec');
  my $extDbRlsId = $self->getExtDbRlsId($extDbRlsSpec);
  my ($datasetName,$ver) = split(/\|/, $extDbRlsSpec);
  $datasetName =~ s/\|.*//;
  my $outputDir = $self->getArg('outputDir');

  my $ontologySpec = $self->getArg('ontologyExtDbRlsSpec'); # for entity labels
  my $ontologyId = $self->getExtDbRlsId($ontologySpec);

  my $studies = $self->sqlAsDictionary( Sql  => "select study_id, internal_abbrev from apidb.study where external_database_release_id = $extDbRlsId");

  $self->error("Expected one study row.  Found ". scalar keys %$studies) unless(scalar keys %$studies == 1);

  $self->getDbHandle()->do("alter session set nls_date_format = 'yyyy-mm-dd hh24:mi:ss'") or die $self->getDbHandle()->errstr;

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
      my $entityNameForFile = $meta->{PLURAL};
      my $entityName = map { ucfirst($_) } split(/\s/, $meta->{LABEL});
      $entityNameForFile =~ tr/ /_/;
      $entityName =~ tr/ /_/;
      my $outputFile;
      if($outputDir){ 
         unless(-d $outputDir){
           mkdir($outputDir) or die "Cannot create output directory $outputDir: $!\n";
         }
         $outputFile = sprintf("%s/%s_%s.txt", $outputDir, $datasetName, $entityNameForFile);
      }
      else{
        $outputFile = sprintf("%s_%s.txt", $datasetName, $entityNameForFile);
      }
      $self->log("Making download file $outputFile for Entity Type $entityTypeAbbrev (ID $entityTypeId)");
      $mergeInfo{$outputFile} =  $self->createDownloadFile($entityTypeId, $entityTypeAbbrev, \%entityNames, $studyAbbrev,$outputFile);
    }
    #
    my $allMergedFile = sprintf("%s%s.txt", $outputDir ? "$outputDir/" : "", $datasetName);
    $self->log("Making all data merged file $allMergedFile ");
    my $tempScript = "merge_script.R";
    if($outputDir){$tempScript = join("/", $outputDir,$tempScript)}
    printf STDERR "Writing script $tempScript\n";
    open(FH, ">",$tempScript) or die "Cannot write $tempScript: $!\n"; 
    my $code = $self->mergeScript($allMergedFile, \%mergeInfo);
    print FH ($code);
    close(FH);
    if(system("nice -n40 Rscript $tempScript")){
      $self->error("$tempScript failed");
    }
    next;
    ## ontology file

    my $outputFile = "ontologyMetadata.txt"; 
    if($outputDir){ 
       unless(-d $outputDir){
         mkdir($outputDir) or die "Cannot create output directory $outputDir: $!\n";
       }
       $outputFile = sprintf("%s/%s_ontologyMetadata.txt", $outputDir, $datasetName);
    }
    else{
      $outputFile = sprintf("%s_ontologyMetadata.txt", $datasetName);
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
  my $dataTableName = "ApiDB.Attributes_${studyAbbrev}_${entityTypeAbbrev}";
  # [TYPE]_STABLE_ID, [PARENT_TYPE]_STABLE_ID, ...

  my $ancestorTableName = "ApiDB.Ancestors_${studyAbbrev}_${entityTypeAbbrev}";
  # ontology info
  # (iri) STABLE_ID, DISPLAY_NAME
 
  my $attrTableName = "ApiDB.AttributeGraph_${studyAbbrev}_${entityTypeAbbrev}";

  # get an iri dictionary, the column header in the format "display_name [SOURCE_ID]"
  my $sql = "SELECT STABLE_ID, DISPLAY_NAME || ' [' || STABLE_ID || ']' FROM $attrTableName WHERE DATA_TYPE IS NOT NULL";
  # we could format
  my $attrNames = $self->sqlAsDictionary( Sql => $sql );
  my @orderedIRIs = sort { $attrNames->{$a} <=> $attrNames->{$b} } keys %$attrNames;
 #while(my ($k,$v) = each %$attrNames){
 #  $v = $v . " [$k]";
 #  $attrNames->{$k} = $v;
 #}

  # get everything
  $sql = "SELECT a.*, e.* FROM $dataTableName e LEFT JOIN $ancestorTableName a ON e.STABLE_ID = a.${entityTypeAbbrev}_STABLE_ID" ;
  
  my $dbh = $self->getQueryHandle();
  my $sh = $dbh->prepare($sql);
  $sh->execute();
  # set up column headers for ancestor IDs
  my @cols = @{$sh->{NAME}}; 
  my @entityIdCols; # for creating this file (raw ID from SQL)
  my @mergeIdCols; # for merging with this file (pretty ID from file)
  foreach my $col (@cols){
    # the first columns must be *_STABLE_ID
    last if($col eq 'STABLE_ID'); # omitted
    my ($type) = ($col =~ m/^(.*)_STABLE_ID/i);
    my $name = $entityNames->{uc($type)};
    printf STDERR ("TYPE=$type ... $name\n");
    $name =~ tr/ /_/;
    $attrNames->{$col} = "${name}_Id";
    push(@entityIdCols, $col);
    push(@mergeIdCols, $attrNames->{$col});
  }
  open(FH, ">$outputFile") or die "Cannot write $outputFile: $!\n";
  # print header row
  printf FH ("%s\n", join("\t", map { $attrNames->{$_} } @entityIdCols, @orderedIRIs));
  
  while(my $row = $sh->fetchrow_hashref()) {
    printf FH ("%s\n", join("\t", map { $row->{$_} } @entityIdCols, @orderedIRIs));
  }
  close(FH);
  # get Merge Key, if any
  $sql = sprintf("SELECT t1.display_name || ' [' || t1.stable_id || ']' MERGE_KEY,1 value FROM %s t1 WHERE t1.IS_MERGE_KEY = 1", $attrTableName);
  my ($mergeKey) = keys %{ $self->sqlAsDictionary( Sql => $sql ) };
  return { id_cols => \@mergeIdCols, merge_key => $mergeKey };
  # return info for merging
}

sub entityTypeIdsFromStudyId {
  my ($self, $studyId,$ontologyId) = @_;

  my $sql = "select t.entity_type_id TYPE_ID, t.internal_abbrev ABBREV,os.ontology_synonym LABEL, os.plural PLURAL,
regexp_replace(os.ONTOLOGY_SYNONYM ,'\s','_') || '_Id' ID_COLUMN
from apidb.entitytype t
left join SRes.OntologySynonym os on t.type_id=os.ontology_term_id
where t.study_id = $studyId
and os.external_database_release_id = $ontologyId";
  my $dbh = $self->getQueryHandle();
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
    my $tableName = "APIDB.AttributeGraph_${studyAbbrev}_${type}";
    my $sql =  <<ONTOSQL;
WITH synrep AS 
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
ag.distinct_values_count, ag.vocabulary, ag.provider_label, synrep.replaces
FROM $tableName ag
left join synrep ON ag.STABLE_ID = synrep.stable_id
LEFT JOIN parent ON ag.parent_stable_id=parent.stable_id
ONTOSQL
print STDERR "Get ontology metadata:\n$sql\n";
    my $dbh = $self->getQueryHandle();
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
  
  my $firstFile = 1;
  my %allMergedCols; # mergeable columns in all, including mergeKey
  # $fileInfo is set at the end of createDownloadFile
  while(my ($fileName, $fileInfo) = each %$mergeInfo){
      push(@scriptLines, sprintf("\n# Merging %s", basename($fileName)));
    my @mergeCols;
    ###
    if($firstFile){
      $firstFile = 0;
      push(@scriptLines, sprintf('%s <- fread("%s")', $ALLTAB, $fileName));
      if( $fileInfo->{merge_key} ){
        push(@scriptLines, sprintf('%s$%s = %s$"%s"', $ALLTAB, $TMK, $ALLTAB, $fileInfo->{merge_key}));
      }
    }
    else {
      push(@scriptLines, sprintf('%s <- fread("%s")', $ENTITYTAB, $fileName));
      if( $fileInfo->{merge_key} ){
        push(@scriptLines, sprintf('%s$%s = %s$"%s"', $ENTITYTAB, $TMK, $ENTITYTAB, $fileInfo->{merge_key}));
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
  
my $moveIdCols = <<MOVEIDCOLS;
orderedIdCols = c()
for( idcol in c("Community_Id", "Community_repeated_measure_Id", "Household_Id", "Household_repeated_measure_Id", "Entomology_collection_Id", "Participant_Id", "Repeated_measure_Id", "Sample_Id") ){
  if( idcol %in% names($ALLTAB) ){
    orderedIdCols <- append( orderedIdCols, grep( idcol, names($ALLTAB) ) )
  }
}
setcolorder( $ALLTAB, orderedIdCols )
MOVEIDCOLS
  push(@scriptLines, $moveIdCols);

  push(@scriptLines, sprintf('fwrite(%s,"%s", sep="\t", na="NA")', $ALLTAB, $outputFile));
  push(@scriptLines, '', 'quit("no")', '');
  return join("\n", @scriptLines);
}





sub undoTables {}


1;
