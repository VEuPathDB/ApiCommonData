package ApiCommonData::Load::Plugin::InsertUniDBPostgres;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use DBI;
use Data::Dumper;
use Fcntl;
use POSIX qw(strftime);

use GUS::PluginMgr::Plugin;
use ApiCommonData::Load::Fifo;
use ApiCommonData::Load::Psql;

use GUS::Model::ApiDB::DATABASETABLEMAPPING;



my $END_OF_COLUMN_DELIMITER = "\t";
my $END_OF_RECORD_DELIMITER = "\n";

my $MAPPING_TABLE_NAME = "ApiDB.DatabaseTableMapping";
my $GLOBAL_NATURAL_KEY_TABLE_NAME = "ApiDB.GlobalNaturalKey";
my $PROJECT_INFO_TABLE = "Core.ProjectInfo";
my $TABLE_INFO_TABLE = "Core.TableInfo";

my $PLACEHOLDER_STRING = "PLACEHOLDER_STRING";
my $OWNER_STRING = "OWNER_STRING";

my %GLOBAL_UNIQUE_FIELDS = (
  "GUS::Model::Core::ProjectInfo" => ["name", "release"],
  "GUS::Model::Core::TableInfo" => ["name", "database_id"],
  "GUS::Model::Core::DatabaseInfo" => ["name"],
  "GUS::Model::Core::DatabaseVersion" => ["version"],
  "GUS::Model::Core::GroupInfo" => ["name"],
  "GUS::Model::Core::UserInfo" => ["login"],
  "GUS::Model::Core::UserProject" => ["user_id", "project_id"],
  "GUS::Model::Core::UserGroup" => ["user_id", "group_id"],
  "GUS::Model::Core::Algorithm" => ["name"],
  "GUS::Model::Core::AlgorithmImplementation" => ["executable", "cvs_revision"],
  "GUS::Model::Core::AlgorithmParamKeyType" => ["type"],
  "GUS::Model::Core::AlgorithmParamKey" => ["algorithm_implementation_id", "algorithm_param_key"],
  "GUS::Model::DoTS::AASequenceImp" => ["source_id", "external_database_release_id"],
  "GUS::Model::DoTS::BLATAlignmentQuality" => ["name"],
  "GUS::Model::DoTS::GOAssociationInstanceLOE" => ["name"],
  "GUS::Model::SRes::ExternalDatabase" => ["name"],
  "GUS::Model::SRes::ExternalDatabaseRelease" => ["external_database_id", "version"],
  "GUS::Model::SRes::OntologyTerm" => ["source_id"],
  "GUS::Model::SRes::OntologySynonym" => ["ontology_term_id", "ontology_synonym"],
  "GUS::Model::SRes::OntologyRelationship" => ["subject_term_id", "object_term_id", "predicate_term_id", "external_database_release_id"],
  "GUS::Model::SRes::OntologyTermType" => ["name"],
  "GUS::Model::SRes::EnzymeClass" => ["ec_number"],
  "GUS::Model::SRes::Taxon" => ["ncbi_tax_id"],
  "GUS::Model::SRes::TaxonName" => ["taxon_id", "name"],
  "GUS::Model::SRes::EnzymeClassAttribute" => ["enzyme_class_id", "attribute_value"],
  "GUS::Model::SRes::GeneticCode" => ["name"],
  "GUS::Model::SRes::DbRef" => ["primary_identifier", "secondary_identifier", "external_database_release_id"],
  "GUS::Model::ApiDB::GoSubset" => ["go_subset_term", "ontology_term_id", "external_database_release_id"],
  "GUS::Model::ApiDB::IsolateGPS" => ["gazetteer_id"],
  "GUS::Model::ApiDB::EcNumberGenus" => ["ec_number", "genus"],
  "GUS::Model::ApiDB::Datasource" => ["name"],
  "GUS::Model::Study::Protocol" => ["name"],
  "GUS::Model::Study::ProtocolParam" => ["protocol_id", "name"],
);

my $HOUSEKEEPING_FIELDS = [
  'modification_date',
  'user_read',
  'user_write',
  'group_read',
  'group_write',
  'other_read',
  'other_write',
  'row_user_id',
  'row_group_id',
  'row_alg_invocation_id',
  'row_project_id',
];

# ----------------------------------------------------------
# Load Arguments
# ----------------------------------------------------------

sub getArgsDeclaration {
  my $argsDeclaration  =
    [
      fileArg({
        name           => 'logDir',
        descr          => 'directory where to log sqlldr output',
        reqd           => 1,
        mustExist      => 1,
        format         => '',
        constraintFunc => undef,
        isList         => 0,
      }),
      stringArg ({
        name => 'database',
        descr => 'name of the source database, directory, or files or possibly mysql database depending on the table_reader below',
        constraintFunc => undef,
        reqd => 0,
        isList => 0
      }),
      stringArg ({
        name => 'table_reader',
        descr => 'perl class which will serve out full rows to this plugin.  Example ApiCommonData::Load::GUSTableReader',
        constraintFunc => undef,
        reqd => 1,
        isList => 0
      }),
      enumArg({
        name => 'mode',
        descr => 'load,undo',
        constraintFunc => undef,
        reqd => 0,
        isList => 0,
        enum => 'load, undo',
        default => 'early'
      }),
      fileArg({
        name           => 'forceSkipDatasetFile',
        descr          => 'list of datasets to skip',
        reqd           => 0,
        mustExist      => 1,
        format         => '',
        constraintFunc => undef,
        isList         => 0,
      }),
      fileArg({
        name           => 'forceLoadDatasetFile',
        descr          => 'list of datasets to load',
        reqd           => 0,
        mustExist      => 1,
        format         => '',
        constraintFunc => undef,
        isList         => 0,
      }),
      fileArg({
        name           => 'databaseDir',
        descr          => 'directory for input database files',
        reqd           => 0,
        mustExist      => 0,
        format         => '',
        constraintFunc => undef,
        isList         => 0, }),
    ];
  return $argsDeclaration;
}

# ----------------------------------------------------------
# Documentation
# ----------------------------------------------------------

sub getDocumentation {

  my $description = <<DESCR;
Plugin to load UniDB Database
DESCR

  my $purpose = <<PURPOSE;
Plugin to load UniDB Database
PURPOSE

  my $purposeBrief = <<PURPOSEBRIEF;
Plugin to load UniDB Database
PURPOSEBRIEF

  my $notes = <<NOTES;
NOTES

  my $tablesAffected = <<AFFECT;
The whole shebang
AFFECT

  my $tablesDependedOn = <<TABD;
TABD

  my $howToRestart = <<RESTART;
Can be restarted
RESTART

  my $failureCases = <<FAIL;
Run again
FAIL

  my $documentation = { purpose          => $purpose,
    purposeBrief     => $purposeBrief,
    tablesAffected   => $tablesAffected,
    tablesDependedOn => $tablesDependedOn,
    howToRestart     => $howToRestart,
    failureCases     => $failureCases,
    notes            => $notes
  };

  return ($documentation);
}

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
  my $class = shift;
  my $self = {};
  bless($self, $class);

  my $documentation = &getDocumentation();

  my $args = &getArgsDeclaration();

  my $configuration = {
    requiredDbVersion => 4.0,
    cvsRevision       => '$Revision$',
    name              => ref($self),
    argsDeclaration   => $args,
    documentation     => $documentation
  };

  $self->initialize($configuration);

  return $self;
}

sub error {
  my ($self, $msg) = @_;
  print STDERR "\nERROR: $msg\n";

  foreach my $pid (@{$self->getActiveForkedProcesses()}) {
    kill(9, $pid);
  }

  $self->SUPER::error($msg);
}

sub makeReaderObj {
  my ($database, $readerClass, $forceSkipDatasetFile, $forceLoadDatasetFile, $databaseDir) = @_;

  eval "require $readerClass";
  die $@ if $@;

  my $reader = eval {
    $readerClass->new($database, $forceSkipDatasetFile, $forceLoadDatasetFile, $databaseDir);
  };
  die $@ if $@;

  return $reader;
}

sub run {
  my $self = shift;

  chdir $self->getArg('logDir');

  my $database = $self->getArg('database');
  my $tableReaderClass = $self->getArg('table_reader');
  my $forceSkipDatasetFile = $self->getArg('forceSkipDatasetFile');
  my $forceLoadDatasetFile = $self->getArg('forceLoadDatasetFile');
  my $databaseDir = $self->getArg('databaseDir');

  my $tableReader = &makeReaderObj($database, $tableReaderClass, $forceSkipDatasetFile, $forceLoadDatasetFile, $databaseDir);

  $tableReader->connectDatabase();

  $self->log("Getting Table Dependencies and Ordering Tables by Foreign Keys...");

  my $tableInfo = $self->getAllTableInfo($tableReader);

  my $initialTableCount = scalar(keys(%$tableInfo));

  my $orderedTables = [];
  $self->orderTablesByRelations($tableInfo, $orderedTables);

  my $orderedTableCount = scalar @$orderedTables;

  unless($initialTableCount == $orderedTableCount) {
    $self->error("Expected $initialTableCount tables but found $orderedTableCount upon Ordering");
  }

  my $mode = $self->getArg('mode');

  if($mode eq 'undo') {
    foreach my $tableName (reverse @$orderedTables) {
      $self->undoTable($database, $tableName, $tableInfo->{$tableName}, $tableReader);
    }
  }

  if($mode eq 'load') {
    foreach my $tableName (@$orderedTables) {
      $self->loadTable($database, $tableName, $tableInfo->{$tableName}, $tableReader);
    }
  }

  $tableReader->disconnectDatabase();
}

sub undoTable {
  $self->error("Undo not implemented for Postgres");
}

sub loadTable {
  my ($self, $database, $tableName, $tableInfo, $tableReader) = @_;

  $self->resetActiveForkedProcesses();

  my $abbreviatedTableColumn = &getAbbreviatedTableName($tableName, "::");
  my $abbreviatedTablePeriod = &getAbbreviatedTableName($tableName, ".");

  # try to reuse all rows from these tables
  # some of these will have rows populated by the installer so globalMapping query is different
  my $isAllGlobalTable = $self->isAllGlobalTable($tableName);

  my $hasHousekeepingFields = ($abbreviatedTablePeriod eq 'ApiDB.Snp' || $abbreviatedTablePeriod eq 'ApiDB.SequenceVariation') ? 0 :1;

  $self->log("Begin Loading table $abbreviatedTableColumn from database $database");

  my $rowCount = 0;
  my $primaryKeyColumn = $tableInfo->{primaryKey};
  my $isSelfReferencing = $tableInfo->{isSelfReferencing};

  my $alreadyMappedMaxOrigPk = $self->queryForMaxMappedOrigPk($database, $abbreviatedTableColumn);

  my $dbh = $self->getQueryHandle();
  my $sequenceName = "${abbreviatedTablePeriod}_sq";
  my $sequenceSql = "select NEXTVAL('${sequenceName}')";
  my $sequenceSh = $dbh->prepare($sequenceSql);

  #############################
  my ($psqlDataInfileFh, $dataFifo, $psqlDataObj) = $self->getFifoFileHandle($tableInfo, $abbreviatedTablePeriod, $hasHousekeepingFields);
  my ($psqlMapInfileFh, $mapFifo) = $self->getFifoFileHandle($tableInfo, $MAPPING_TABLE_NAME, $hasHousekeepingFields);
  my ($psqlGlobInfileFh, $globFifo) = $self->getFifoFileHandle($tableInfo, $GLOBAL_NATURAL_KEY_TABLE_NAME, $hasHousekeepingFields);

  #############################

  # may add this back if using the sequence is too slow for all cases
  #  my $maxPrimaryKey = $self->queryForPKAggFxn($abbreviatedTablePeriod, $primaryKeyColumn, 'max');

  $tableReader->prepareTable($tableName, $isSelfReferencing, $primaryKeyColumn, $alreadyMappedMaxOrigPk);

  my ($idMappings, $globalLookup);

  $self->log("Will skip rows with a $primaryKeyColumn <= $alreadyMappedMaxOrigPk");

  my %housekeepingFieldsHash = map { $_ => 1 } @$HOUSEKEEPING_FIELDS;

  my $databaseTarget = $self->getDb();
  my $defaultProjectId = $databaseTarget->getDefaultProjectId();
  my $userId = $databaseTarget->getDefaultUserId();
  my $groupId = $databaseTarget->getDefaultGroupId();
  my $algInvocationId = $databaseTarget->getDefaultAlgoInvoId();
  my $userRead = $databaseTarget->getDefaultUserRead();
  my $userWrite = $databaseTarget->getDefaultUserWrite();
  my $groupRead = $databaseTarget->getDefaultGroupRead();
  my $groupWrite = $databaseTarget->getDefaultGroupWrite();
  my $otherRead = $databaseTarget->getDefaultOtherRead();
  my $otherWrite = $databaseTarget->getDefaultOtherWrite();

  my $modificationDate = strftime "%m-%d-%Y", localtime();

  my @housekeepingFields = ($hasHousekeepingFields) ? (
    "$modificationDate",
    "$userRead",
    "$userWrite",
    "$groupRead",
    "$groupWrite",
    "$otherRead",
    "$otherWrite",
    "$userId",
    "$groupId",
    "$algInvocationId",
  ) : ("$modificationDate");

  my @attributeList = map { lc($_) } @{$tableInfo->{attributeList}};

  while(my $row = $tableReader->nextRowAsHashref($tableInfo)) {
    my $origPrimaryKey = $row->{lc($primaryKeyColumn)};

    #Always false for EBITableReader
    # next if($tableReader->skipRow($row));

    #loadRow always true for EBITableReader
    # if($origPrimaryKey <= $alreadyMappedMaxOrigPk){
    #   next unless $tableReader->loadRow($row); # restart OR new data (TODO: won't work for "skipped" datasets)
    # }

    # first time we see data

    unless($idMappings) {
      $idMappings = $self->getIdMappings($database, $tableName, $tableInfo, $tableReader);
      $globalLookup = $self->globalLookupForTable($primaryKeyColumn, $tableName, $database, $isAllGlobalTable);
    }

    my ($mappedRow, $fieldsToSetToPk) = $self->mapRow($row, $idMappings, $tableInfo, $origPrimaryKey);

    my $primaryKey;

    my $isGlobal = $isAllGlobalTable || $tableReader->isRowGlobal($mappedRow);

    if($isGlobal) {
      $primaryKey = $self->lookupPrimaryKey($tableName, $mappedRow, $globalLookup);

      unless($primaryKey) {
        $self->log("No lookup Found for GLOBAL row $origPrimaryKey in table $abbreviatedTableColumn...adding row") if($self->getArg("debug"));
      }

      if($primaryKey && !$idMappings->{$tableName}->{$origPrimaryKey}) {
        # my @mappingRow = ($database, $abbreviatedTableColumn, $origPrimaryKey, $primaryKey, undef);
        # removing undef because we'll be passing the modification date here not by sqlldr
        my @mappingRow = ($database, $abbreviatedTableColumn, $origPrimaryKey, $primaryKey);
        push @mappingRow, @housekeepingFields;
        push @mappingRow, $defaultProjectId;

        print $psqlMapInfileFh join($END_OF_COLUMN_DELIMITER, @mappingRow) . $END_OF_RECORD_DELIMITER ; # note the special line terminator

        $idMappings->{$tableName}->{$origPrimaryKey} = $primaryKey
      }
    }

    if(!$primaryKey && $abbreviatedTablePeriod ne $TABLE_INFO_TABLE) {
      $rowCount++;

      #############################
      $sequenceSh->execute();
      $primaryKey = $sequenceSh->fetchrow_array();
      #        $primaryKey = ++$maxPrimaryKey;
      $mappedRow->{lc($primaryKeyColumn)} = $primaryKey;

      # If the table is self referencing AND the fk is to the same row
      foreach my $ancestorField (@$fieldsToSetToPk) {
        $mappedRow->{lc($ancestorField)} = $primaryKey;
      }

      my $quot = $psqlDataObj->getQuoteCharacter();
      my $null = $psqlDataObj->getNullValue();

      # remove housekeeping fields (to be added later) and process the data fields
      # if the field is null, return empty string
      # if the field is not null
      #   and the field is not empty, wrap it in quotes and escape any quotes in the string
      #   and the field is empty, just return unquoted empty string
      my @dataRow = map {
        (defined $mappedRow->{$_} && length($mappedRow->{$_}))
          ? do {
          $mappedRow->{$_} =~ s/$quot/$quot$quot/g;
          "$quot" . $mappedRow->{$_} . "$quot"
        }
          : "$null"
      } grep { !$housekeepingFieldsHash{$_} } @attributeList;

      push @dataRow, @housekeepingFields;

      if($hasHousekeepingFields){
        if ( $abbreviatedTablePeriod ne $PROJECT_INFO_TABLE ){
          $self->error("Could not map row_project_id") unless $mappedRow->{row_project_id};
          push @dataRow, $mappedRow->{row_project_id};
        }
        else {
          push @dataRow, $defaultProjectId;
        }
      }

      print $psqlDataInfileFh join($END_OF_COLUMN_DELIMITER, @dataRow) . $END_OF_RECORD_DELIMITER; # note the special line terminator

      #############################
      # self referencing tables will need mappings for loaded rows
      $idMappings->{$tableName}->{$origPrimaryKey} = $primaryKey if($isSelfReferencing);

      # update the globalMap for newly added rows
      my $globalNaturalKey;
      if($isGlobal) {
        my $globalUniqueFields = $GLOBAL_UNIQUE_FIELDS{$tableName};

        my @globalUniqueValues = map { lc($mappedRow->{lc($_)}) } @$globalUniqueFields;
        $globalNaturalKey = join("_", @globalUniqueValues);
        $globalLookup->{$globalNaturalKey} = $primaryKey;

        my @globalRow = ($abbreviatedTableColumn, $primaryKey, $globalNaturalKey);
        push @globalRow, @housekeepingFields;
        push @globalRow, $defaultProjectId;
        print $psqlGlobInfileFh join($END_OF_COLUMN_DELIMITER, @globalRow) . $END_OF_RECORD_DELIMITER;
      }

      my @mappingRow = ($database, $abbreviatedTableColumn, $origPrimaryKey, $primaryKey);
      push @mappingRow, @housekeepingFields;
      push @mappingRow, $defaultProjectId;
      print $psqlMapInfileFh join($END_OF_COLUMN_DELIMITER, @mappingRow) . $END_OF_RECORD_DELIMITER;

      if($rowCount % 100000 == 0) {
        $self->log("Processed $rowCount from $abbreviatedTableColumn");
      }
    }
  }

  $self->log("Finished Reading data from $abbreviatedTableColumn");

  $tableReader->finishTable();

  $mapFifo->cleanup();
  $globFifo->cleanup();
  $dataFifo->cleanup();

  $sequenceSh->finish();

  # update the sequence;  may add this back if using sequence for pk is too slow
  # my $sequenceName = "${abbreviatedTablePeriod}_sq";
  # my $dbh = $self->getQueryHandle();
  # my ($sequenceValue) = $dbh->selectrow_array("select ${sequenceName}.nextval from dual");
  # my $sequenceDifference = $maxPrimaryKey - $sequenceValue;
  # if($sequenceDifference > 0) {
  #   $dbh->do("alter sequence $sequenceName increment by $sequenceDifference") or die $dbh->errstr;
  #   $dbh->do("select ${sequenceName}.nextval from dual") or die $dbh->errstr;
  #   $dbh->do("alter sequence $sequenceName increment by 1") or die $dbh->errstr;
  # }

  $self->log("Finished Loading $rowCount Rows into table $abbreviatedTableColumn from database $database");
}

sub getDatabaseTableMappingSql {
  my ($database, $tableNames) = @_;

  my $tableNamesString = join(",", map { "'" . &getAbbreviatedTableName($_, '::') . "'" } @$tableNames);

  my $sql = "
    SELECT database_orig
           , table_name
           , primary_key_orig
           , primary_key
    FROM $MAPPING_TABLE_NAME
    WHERE database_orig = '$database'
      AND table_name in ($tableNamesString)
  ";

  return $sql;
}

sub addToIdMappings {
  my ($self, $database, $idMappings, $tableNames, $keepIds) = @_;

  my $sql = &getDatabaseTableMappingSql($database, $tableNames);

  my $dbh = $self->getDbHandle(); # this is the one which is inserting rows
  my $sh = $dbh->prepare($sql);
  $sh->execute();

  while(my ($databaseOrig, $tableName, $pkOrig, $pk) = $sh->fetchrow_array()) {
    if(!defined($keepIds) || $keepIds->{$pkOrig}) {
      $tableName = "GUS::Model::$tableName";
      $idMappings->{$tableName}->{$pkOrig} = $pk;
    }
  }
  $sh->finish();

  return $idMappings;
}

sub getIdMappings {
  my ($self, $database, $tableName, $tableInfo, $tableReader) = @_;

  my $idMappings = {};

  my $abbreviatedTableColumn = &getAbbreviatedTableName($tableName, "::");
  $self->log("Begin ID Lookup for $abbreviatedTableColumn from database $database");

  foreach my $pr (@{$tableInfo->{parentRelations}}) {
    my $field = $pr->[1];

    $self->log("Getting Distinct Values for foreign key $field from $database");

    my @tableNames;

    my $keepIds = $tableReader->getDistinctValuesForField($tableName, $field);

    if(ref($pr->[0]) eq 'ARRAY') {
      push @tableNames, @{$pr->[0]};
    }
    else {
      push @tableNames, $pr->[0];
    }

    $self->addToIdMappings($database, $idMappings, \@tableNames, $keepIds);
  }

  $self->addToIdMappings($database, $idMappings, [$tableName], undef);

  $self->log("Finished ID Lookup for $abbreviatedTableColumn from database $database");

  return $idMappings;
}

sub mapRow {
  my ($self, $row, $idMappings, $tableInfo, $origPrimaryKey) = @_;

  my @setToPk;

  my %mappedRow = %$row;

  foreach my $rel (@{$tableInfo->{parentRelations}}) {
    my $parentTable = $rel->[0];
    my $field = $rel->[1];
    my $parentField = $rel->[2];

    my $softKeyTableField = $rel->[3];
    my $softKeyTableMap = $rel->[4];

    my $origId = $mappedRow{lc($field)};

    next unless($origId); # no mappings for null values

    # Handle "Soft Keys"
    if($softKeyTableField) {
      my $softKeyTableId = $row->{lc($softKeyTableField)};
      $parentTable = $softKeyTableMap->{$softKeyTableId};
      $self->error("Soft key mapping error:  Value $softKeyTableId could not be mapped for field $softKeyTableField") unless($parentTable);
    }

    my $mappedId = $idMappings->{$parentTable}->{$origId};

    unless($mappedId) {
      if($tableInfo->{fullTableName} eq $parentTable && $origId eq $origPrimaryKey) {
        push @setToPk, lc($field);
      }
      else {
        $self->error("Could not map foreign key value $origId from $parentTable");
      }
    }

    $mappedRow{lc($field)} = $mappedId;
  }

  return \%mappedRow, \@setToPk;
}

sub queryForMaxMappedOrigPk {
  my ($self, $database, $tableName) = @_;

  return $self->pkOrigFunctions($database, $tableName, "max");
}

sub queryForCountMappedOrigPk {
  my ($self, $database, $tableName) = @_;

  return $self->pkOrigFunctions($database, $tableName, "count");
}

sub pkOrigFunctions {
  my ($self, $database, $tableName, $function) = @_;

  my $sql = "select ${function}(primary_key_orig)
             from $MAPPING_TABLE_NAME
             where database_orig = '$database'
             and table_name = '$tableName'";

  my $dbh = $self->getQueryHandle();

  my $sh = $dbh->prepare($sql);
  $sh->execute();

  my ($val) = $sh->fetchrow_array();

  unless($val) {
    return 0;
  }

  return $val;
}

sub queryForPKAggFxn {
  my ($self, $tableName, $primaryKey, $function) = @_;

  my $sql = "select ${function}($primaryKey) from $tableName";

  my $dbh = $self->getQueryHandle();

  my $sh = $dbh->prepare($sql);
  $sh->execute();

  my ($value) = $sh->fetchrow_array();

  unless($value) {
    return 0;
  }

  return $value;
}

sub isAllGlobalTable {
  my ($self, $tableName) = @_;

  return 0 if( $tableName eq "GUS::Model::DoTS::AASequenceImp" || $tableName eq "GUS::Model::SRes::DbRef" );

  if( $GLOBAL_UNIQUE_FIELDS{$tableName} ){
    return 1;
  }
  return 0;
}

sub getFifoFileHandle(){
  my($self, $tableInfo, $outputTableName, $hasRowProjectId) = @_;

  # my @housekeepingFields = grep { $_ ne 'row_project_id'} @$HOUSEKEEPING_FIELDS;
  my @housekeepingFields = $hasRowProjectId ? @$HOUSEKEEPING_FIELDS : ("modification_date");

  my $login       = $self->getDb->getLogin();
  my $password    = $self->getDb->getPassword();
  my $dbiDsn      = $self->getDb->getDSN();
  $dbiDsn =~ /(:|;)dbname=((\w|\.)+);?/ ;
  my $db = $2;

  my $psqlObj = ApiCommonData::Load::Psql->new({
    _login => $login,
    _password => $password,
    _database => $db,
    _dbiDsn => $dbiDsn,
    _quiet => 0,
  });

  my ($filename, $fileHandle, @fields);

  my $inputTableName = &getAbbreviatedTableName($tableInfo->{fullTableName}, ".");

  if($outputTableName eq $MAPPING_TABLE_NAME) {
    @fields = (
      "database_orig",
      "table_name",
      "primary_key_orig",
      "primary_key",
    );
    push @fields, @housekeepingFields;

    $filename = "$inputTableName.map.dat";
  }
  elsif($outputTableName eq $GLOBAL_NATURAL_KEY_TABLE_NAME) {
    @fields = (
      "table_name",
      "primary_key",
      "global_natural_key",
    );
    push @fields, @housekeepingFields;

    $filename = "$inputTableName.glob.dat";
  }
  else {
    my %housekeepingFieldsHash = map { $_ => 1 }  @$HOUSEKEEPING_FIELDS;

    # Remove existing housekeepingFields which may or may not exist depending on the source. We'll re add them in the next step.
    @fields = map { lc($_) } grep { !$housekeepingFieldsHash{$_} } @{$tableInfo->{attributeList}}; ## minus housekeeping rows
    push @fields, @housekeepingFields;

    $filename = "$inputTableName.dat";
  }

  $psqlObj->setFields(\@fields);
  $psqlObj->setFieldDelimiter($END_OF_COLUMN_DELIMITER);
  $psqlObj->setInfileName($filename);
  $psqlObj->setTableName($outputTableName);

  my $fifo = ApiCommonData::Load::Fifo->new($filename, undef, undef, "LOG:  ". $self->getArg('logDir') . "/" . $psqlObj->getLogFileName());
  my $psqlProcessString = $psqlObj->getCommandLine();
  my $pidData = $fifo->attachReader($psqlProcessString);
  $self->addActiveForkedProcess($pidData);
  $fileHandle = $fifo->attachWriter();

  return $fileHandle, $fifo, $psqlObj;
}

sub getAbbreviatedTableName {
  my ($fullTableName, $del) = @_;

  $fullTableName =~ /GUS::Model::(.+)::(.+)/i;
  return $1 . $del . $2;
}

sub lookupPrimaryKey {
  my ($self, $tableName, $row, $globalLookup) = @_;

  # Load all alg invocations
  if($tableName eq "GUS::Model::Core::AlgorithmInvocation") {
    return undef;
  }

  unless($GLOBAL_UNIQUE_FIELDS{$tableName}) {
    $self->error("Table $tableName requires fields for Global Lookup");
  }

  my $fields = $GLOBAL_UNIQUE_FIELDS{$tableName};

  my @values = map { lc($row->{lc($_)}) } @$fields;
  my $key = join("_", @values);

  return $globalLookup->{$key};
}

sub globalLookupForTable  {
  my ($self, $primaryKeyColumn, $tableName, $database, $isAllGlobalTable) = @_;

  my $dbh = $self->getQueryHandle();

  my $fields = $GLOBAL_UNIQUE_FIELDS{$tableName};

  return unless($fields);

  my $abbreviatedTableColumn = &getAbbreviatedTableName($tableName, "::");
  $self->log("Preparing Global Lookup for table $abbreviatedTableColumn from database $database");

  my $sql;
  if($isAllGlobalTable) {
    my $fieldsString = join(",", map { $_ } @$fields);
    $tableName = &getAbbreviatedTableName($tableName, ".");

    $sql = "select $primaryKeyColumn, $fieldsString from $tableName";
  }
  else {
    $tableName = &getAbbreviatedTableName($tableName, "::");
    $sql = "select primary_key, global_natural_key from $GLOBAL_NATURAL_KEY_TABLE_NAME where table_name = '$tableName' and global_natural_key is not null";
  }

  my $sh = $dbh->prepare($sql);
  $sh->execute();
  my %lookup;

  my $rowCount = 0;
  while(my ($pk, @a) = $sh->fetchrow_array()) {

    my @values = map { lc($_) } @a;
    my $key = join("_", @values);

    $lookup{$key} = $pk;
    $rowCount++
  }
  $sh->finish();

  unless($rowCount == scalar(keys(%lookup))) {
    $self->log("The GLOBAL UNIQUE FIELDS for table $tableName resulted in nonunique key when concatenated... choosing one");
  }

  $self->log("Finished caching Global Lookup for table $abbreviatedTableColumn from database $database");

  return \%lookup;
}

sub orderTablesByRelations {
  my ($self, $tableInfo, $orderedTables) = @_;

  my $seenTables = {};

  foreach my $tableName (keys %$tableInfo) {
    $self->orderTable($tableName, $tableInfo, $seenTables, $orderedTables);
  }
}

sub orderTable {
  my ($self, $tableName, $tableInfo, $seenTables, $orderedTables) = @_;

  return if($seenTables->{$tableName});

  next unless($tableInfo->{$tableName});

  my @parentsList;
  foreach my $pr (@{$tableInfo->{$tableName}->{parentRelations}}) {
    if(ref($pr->[0]) eq 'ARRAY') {
      push @parentsList, @{$pr->[0]};
    }
    else {
      push @parentsList, $pr->[0];
    }
  }

  # sequencevariation has a foreign key (nasequence_id,location) to apidb.snp but parentRelations only has the fk to NASequenceImp
  if($tableName eq "GUS::Model::ApiDB::SequenceVariation") {
    push @parentsList, "GUS::Model::ApiDB::Snp";
  }

  foreach my $parentTableName (@parentsList) {
    # foreignKey to own table
    unless($parentTableName eq $tableName) {
      $self->orderTable($parentTableName, $tableInfo, $seenTables, $orderedTables);
    }
  }

  push @$orderedTables, $tableName;
  $seenTables->{$tableName} = 1;
}

sub getTableRelationsSql {
  return "
SELECT ti.name as table_name
       , di.name as database_name
       , ti.primary_key_column
FROM
  (-- everything but version and userdataset schemas
     SELECT  t.*
     FROM core.tableinfo t, core.databaseinfo d
     WHERE lower(t.table_type) != 'version'
      AND t.DATABASE_ID = d.DATABASE_ID
      AND d.name not in ('UserDatasets', 'ApidbUserDatasets', 'chEBI', 'hmdb')
      AND t.name not in ('AlgorithmParam','GlobalNaturalKey','DatabaseTableMapping','SnpLinkage', 'CompoundPeaksChebi')
     EXCEPT
     -- minus Views on tables
     SELECT * FROM core.tableinfo WHERE view_on_table_id is not null
  ) ti, core.databaseinfo di
WHERE ti.database_id = di.database_id
";
}

sub getAllTableInfo {
  my ($self, $tableReader) = @_;

  my %allTableInfo;

  my $dbh = $self->getQueryHandle();

  my $sql = &getTableRelationsSql();

  my $sh = $dbh->prepare($sql);
  $sh->execute();

  while(my ($table, $schema, $primaryKey) = $sh->fetchrow_array()) {
    next if($table eq 'DATABASETABLEMAPPING'); # Do not sync the mapping table

    my $fullTableName = "GUS::Model::${schema}::${table}";
    my $packageName = "${fullTableName}_Table";
    eval "require $packageName";
    die $@ if $@;

    my $dbiTable = eval {
      $packageName->new();
    };
    die $@ if $@;

    my $parentRelations = $dbiTable->getParentRelations();


    my $attributeInfo = $dbiTable->getAttributeInfo();

    my @parentRelationsNoHousekeeping;
    my $isSelfReferencing;

    foreach my $parentRelation (@$parentRelations) {
      my $parentTable = $parentRelation->[0];
      my $field = $parentRelation->[1];
      my $parentField = $parentRelation->[2];

      if($parentTable eq $fullTableName) {
        $isSelfReferencing = 1;
      }

      if(&getAbbreviatedTableName($parentTable, ".") eq $TABLE_INFO_TABLE) {
        my $softKeyTablesHash = $tableReader->getDistinctTablesForTableIdField($field, "${schema}.${table}");
        my @softKeyTables = values %$softKeyTablesHash;

        if(scalar @softKeyTables > 0) {
          my $rowIdField = $self->getRowIdFieldForTableIdField($fullTableName, $field, $dbiTable);
          if($rowIdField) {
            push @parentRelationsNoHousekeeping, [\@softKeyTables, $rowIdField, undef, $field, $softKeyTablesHash];
          }
        }
      }

      if($fullTableName eq "GUS::Model::ApiDB::SequenceVariation" && (lc($field) eq 'location' || lc($parentField) eq 'location')) {
        next;
      }

      if($fullTableName eq "GUS::Model::ApiDB::SequenceVariation" && lc($field) eq 'ref_na_sequence_id') {
        $parentRelation->[0] = 'GUS::Model::DoTS::NASequenceImp';
      }

      # important for us to retain row_project_id
      unless($field eq "row_alg_invocation_id" || $field eq "row_user_id" || $field eq "row_group_id" || (&getAbbreviatedTableName($fullTableName, '.') eq $PROJECT_INFO_TABLE && $field eq "row_project_id")) {
        push @parentRelationsNoHousekeeping, $parentRelation;
      }
    }

    $allTableInfo{$fullTableName}->{attributeInfo} = $attributeInfo;
    $allTableInfo{$fullTableName}->{isSelfReferencing} = $isSelfReferencing;
    $allTableInfo{$fullTableName}->{parentRelations} = \@parentRelationsNoHousekeeping;

    $allTableInfo{$fullTableName}->{fullTableName} = $fullTableName;

    # TODO:  confirm that this is 1:1 with table
    $allTableInfo{$fullTableName}->{primaryKey} = $dbiTable->getPrimaryKey();

    $allTableInfo{$fullTableName}->{attributeList} = $dbiTable->getAttributeList();
  }

  return \%allTableInfo;
}

sub getRowIdFieldForTableIdField {
  my ($self, $table, $field, $tableObject) = @_;;

  my $skips = {
    'GUS::Model::Core::DatabaseDocumentation' =>  {'table_id' => 1} ,
    'GUS::Model::DoTS::BLATAlignment'         => { 'query_table_id' => 1, 'target_table_id' => 1 },
    'GUS::Model::ApiDB::BLATProteinAlignment' => { 'query_table_id' => 1, 'target_table_id' => 1 },
    'GUS::Model::Study::Characteristic'       => { 'table_id' => 1 },
    'GUS::Model::Core::TableInfo'             => {'superclass_table_id' => 1, 'view_on_table_id' => 1},
    'GUS::Model::Core::TableCategory'         => { 'table_id' => 1 },
  };

  my $map = {
    'GUS::Model::DoTS::IndexWordSimLink'      => {'similarity_table_id' => 'best_similarity_id'},
    'GUS::Model::DoTS::BestSimilarityPair'    => {'paired_source_table_id' => 'paired_sequence_id', 'source_table_id' => 'sequence_id' },
    'GUS::Model::DoTS::Complementation'       => { 'table_id' => 'entry_id'},
    'GUS::Model::DoTS::SequenceSequenceGroup' => { 'source_table_id' => 'sequence_id'},
    'GUS::Model::Model::NetworkRelEvidence'   => { 'fact_table_id' => 'fact_row_id' },
    'GUS::Model::DoTS::MergeSplit'            => { 'table_id' => 'old_id' },
    'GUS::Model::DoTS::ProjectLink'           => { 'table_id' => 'id'}
  };

  return undef if($skips->{$table}->{$field});

  if(my $mappedRowField = $map->{$table}->{$field}) {
    return $mappedRowField;
  }

  my $attributeNames = $tableObject->getAttributeList();

  if($field eq 'table_id' && &foundValueInArray('row_id', $attributeNames)) {
    return 'row_id';
  }

  my $substr = $field;

  $substr =~ s/table_//;

  if(&foundValueInArray($substr, $attributeNames)) {
    return $substr;
  }

  $self->error("Could not map column $field for table $table");
}

sub foundValueInArray {
  my ($value, $array) = @_;

  foreach(@$array) {
    if($_ eq $value) {
      return 1;
    }
  }
  return 0;
}

sub undoTables {
}

1;
