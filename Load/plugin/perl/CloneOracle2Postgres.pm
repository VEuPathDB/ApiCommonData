package ApiCommonData::Load::Plugin::CloneOracle2Postgres;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use GUS::PluginMgr::Plugin;

use DBI;

use Data::Dumper;

use ApiCommonData::Load::Fifo;
use ApiCommonData::Load::Psql;

use Fcntl;

my $END_OF_COLUMN_DELIMITER = "\t";
my $END_OF_RECORD_DELIMITER = "\n";

my $PROJECT_INFO_TABLE = "Core.ProjectInfo";

# ----------------------------------------------------------
# Load Arguments
# ----------------------------------------------------------
sub getArgsDeclaration {
  my $argsDeclaration  = [
    fileArg({
      name           => 'logDir',
      descr          => 'directory where to log psql output',
      reqd           => 1,
      mustExist      => 1,
      format         => '',
      constraintFunc => undef,
      isList         => 0, }),

    stringArg ({
      name => 'database',
      descr => 'gus oracle instance name (plas-inc), directory or files or possibly mysql database depending on the table_reader below',
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
      descr => 'load,undo, rebuildIndexesAndEnableConstraints',
      constraintFunc => undef,
      reqd => 0,
      isList => 0,
      enum => 'load, undo, rebuildIndexesAndEnableConstraints',
      default => 'early'
    }),

    fileArg({
      name           => 'forceSkipDatasetFile',
      descr          => 'list of datasets to skip',
      reqd           => 0,
      mustExist      => 1,
      format         => '',
      constraintFunc => undef,
      isList         => 0, }),

    fileArg({
      name           => 'forceLoadDatasetFile',
      descr          => 'list of datasets to load',
      reqd           => 0,
      mustExist      => 1,
      format         => '',
      constraintFunc => undef,
      isList         => 0, }),

    fileArg({
      name           => 'databaseDir',
      descr          => 'directory for input database files',
      reqd           => 0,
      mustExist      => 0,
      format         => '',
      constraintFunc => undef,
      isList         => 0, }),

    fileArg({
      name           => 'gusConfigSourceFile',
      descr          => 'gus.config file location for source database',
      reqd           => 0,
      mustExist      => 0,
      format         => '',
      constraintFunc => undef,
      isList         => 0
    })
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

  my $configuration = { requiredDbVersion => 4.0,
		                    cvsRevision => '$Revision$',
                        name => ref($self),
                        argsDeclaration => $args,
                        documentation => $documentation
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
  my ($database, $readerClass, $forceSkipDatasetFile, $forceLoadDatasetFile, $databaseDir, $gusConfigFile) = @_;

  eval "require $readerClass";
  die $@ if $@;  

  my $reader = eval {
    $readerClass->new($database, $forceSkipDatasetFile, $forceLoadDatasetFile, $databaseDir, $gusConfigFile);
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
  my $gusConfigFile = $self->getArg('gusConfigSourceFile');

  my $tableReader = &makeReaderObj($database, $tableReaderClass, $forceSkipDatasetFile, $forceLoadDatasetFile, $databaseDir, $gusConfigFile);

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

  if($mode eq 'load') {
    foreach my $tableName (@$orderedTables) {
      $self->loadTable($database, $tableName, $tableInfo->{$tableName}, $tableReader);
    }
  }

  $tableReader->disconnectDatabase();
}

sub getMaxPk {
  my ($self, $tableName, $primaryKeyColumn) = @_;

  my $sql = "select max($primaryKeyColumn) from $tableName";

  my $dbh = $self->getQueryHandle();

  my $sh = $dbh->prepare($sql);
  $sh->execute();

  my ($val) = $sh->fetchrow_array();

  unless($val) {
    return 0;
  }

  return $val;
}

sub updatePsqlConfig {
  my ($self, $psqlObj, $tableInfo, $tableName) = @_;

  my $eocLiteral = $END_OF_COLUMN_DELIMITER;

  $psqlObj->setFieldDelimiter($eocLiteral);

  my $attributeList = $tableInfo->{attributeList};

  my @fields = map { lc($_) } @$attributeList;

  $psqlObj->setFields(\@fields);
  $psqlObj->setTableName($tableName);

}

sub loadTable {
  my ($self, $database, $tableName, $tableInfo, $tableReader) = @_;

  $self->resetActiveForkedProcesses();

  my $abbreviatedTableColumn = &getAbbreviatedTableName($tableName, "::");
  my $abbreviatedTablePeriod = &getAbbreviatedTableName($tableName, ".");

  my $login       = $self->getDb->getLogin();
  my $password    = $self->getDb->getPassword();
  my $dbiDsn      = $self->getDb->getDSN();

  $dbiDsn =~ /(:|;)dbname=((\w|\.)+);?/ ;
  my $db = $2;

  $self->log("Begin Loading table $abbreviatedTableColumn from database $database");

  my $rowCount = 0;
  my $primaryKeyColumn = $tableInfo->{primaryKey};
  my $isSelfReferencing = $tableInfo->{isSelfReferencing};

  my $maxAlreadyLodadedPk = $self->getMaxPk($abbreviatedTablePeriod, $primaryKeyColumn);

  my ($datFifo, $psqlObj, $psqlDataInfileFh, $psqlDataInfileFn, $psqlDataProcessString, $sequenceSh);

  #############################
  $psqlDataInfileFn = "${abbreviatedTablePeriod}.dat";
  $psqlObj = ApiCommonData::Load::Psql->new({_login => $login,
                                             _password => $password,
                                             _database => $db,
                                             _dbiDsn => $dbiDsn,
                                             _quiet => 0,
                                             _infile_name => $psqlDataInfileFn,
                                            });
  $self->updatePsqlConfig($psqlObj, $tableInfo, $abbreviatedTablePeriod);
  $datFifo = ApiCommonData::Load::Fifo->new($psqlDataInfileFn, undef, undef, "LOG:  ". $self->getArg('logDir') . "/" . $psqlObj->getLogFileName());
  $psqlDataProcessString = $psqlObj->getCommandLine();
  #############################

  my $pid = $datFifo->attachReader($psqlDataProcessString);
  $self->addActiveForkedProcess($pid);
  $psqlDataInfileFh = $datFifo->attachWriter();

  $tableReader->prepareTable($tableName, $isSelfReferencing, $primaryKeyColumn, $maxAlreadyLodadedPk);

  my $quoteCharacter = $psqlObj->getQuoteCharacter();

  $self->log("Will skip rows with a $primaryKeyColumn <= $maxAlreadyLodadedPk");

  my @attributeList = map { lc($_) } @{$tableInfo->{attributeList}};

  while(my $row = $tableReader->nextRowAsHashref($tableInfo)) {

    my $primaryKey;

    $rowCount++;

    my @columns = map {
      (defined $row->{$_})
        ? do { $row->{$_} =~ s/$quoteCharacter/$quoteCharacter$quoteCharacter/g ; "$quoteCharacter" . $row->{$_} . "$quoteCharacter" }
        : "null"
    } @attributeList;

    print $psqlDataInfileFh join($END_OF_COLUMN_DELIMITER, @columns) . $END_OF_RECORD_DELIMITER; # note the special line terminator

    if($rowCount % 1000000 == 0) {
      $self->log("Processed $rowCount from $abbreviatedTableColumn");
    }
  }

  $self->log("Finished Reading data from $abbreviatedTableColumn");

  $tableReader->finishTable();

  $datFifo->cleanup();

  # $sequenceSh->finish();

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

sub getAbbreviatedTableName {
  my ($fullTableName, $del) = @_;

  $fullTableName =~ /GUS::Model::(.+)::(.+)/i;
  return $1 . $del . $2;
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
      AND d.name NOT IN ('UserDatasets', 'ApidbUserDatasets')
      AND t.name NOT IN ('DatabaseInfo', 'TableInfo')
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
    my $fullTableName = "GUS::Model::${schema}::${table}";
    my $packageName = "${fullTableName}_Table";
    eval "require $packageName";
    die $@ if $@;  

    my $dbiTable = eval {
      $packageName->new();
    };
    die $@ if $@;

    my $parentRelations = $dbiTable->getParentRelations();

    my @lobColumns;

    my $attributeInfo = $dbiTable->getAttributeInfo();

    # TODO REMOVE LOB PROCESSING IF ONLY NEEDED FOR THE TARGET
    foreach my $att (@{$dbiTable->getAttributeInfo()}) {
      if(uc($att->{type}) eq "CLOB" || uc($att->{type}) eq "BLOB") {
        push @lobColumns, $att->{col};
      }
    }

    my @parentRelationsNoHousekeeping;

    my $isSelfReferencing;

    foreach my $parentRelation (@$parentRelations) {
      my $parentTable = $parentRelation->[0];
      my $field = $parentRelation->[1];
      my $parentField = $parentRelation->[2];

      if($parentTable eq $fullTableName) {
        $isSelfReferencing = 1;
      }
      # if(&getAbbreviatedTableName($parentTable, ".") eq $TABLE_INFO_TABLE) {
      #   my $softKeyTablesHash = $tableReader->getDistinctTablesForTableIdField($field, "${schema}.${table}");
      #   my @softKeyTables = values %$softKeyTablesHash;
      #
      #   if(scalar @softKeyTables > 0) {
      #     my $rowIdField = $self->getRowIdFieldForTableIdField($fullTableName, $field, $dbiTable);
      #     if($rowIdField) {
      #       push @parentRelationsNoHousekeeping, [\@softKeyTables, $rowIdField, undef, $field, $softKeyTablesHash];
      #     }
      #   }
      # }

      # NASequenceImp has circular foreign key to sequence piece. we never use
      # should work now. has been fixed in gus schema
      #if($fullTableName eq "GUS::Model::DoTS::NASequenceImp" &&
      #   $parentTable eq "GUS::Model::DoTS::SequencePiece") {
      #  next;
      #}

      # if($fullTableName eq "GUS::Model::ApiDB::SequenceVariation" && (lc($field) eq 'location' || lc($parentField) eq 'location')) {
      #   next;
      # }

      # if($fullTableName eq "GUS::Model::ApiDB::SequenceVariation" && lc($field) eq 'ref_na_sequence_id') {
      #   $parentRelation->[0] = 'GUS::Model::DoTS::NASequenceImp';
      # }

      ## TODO I'm not sure about this
      # important for us to retain row_project_id
      unless($field eq "row_alg_invocation_id" || $field eq "row_user_id" || $field eq "row_group_id" || (&getAbbreviatedTableName($fullTableName, '.') eq $PROJECT_INFO_TABLE && $field eq "row_project_id")) {
        push @parentRelationsNoHousekeeping, $parentRelation;
      }
    }

    $allTableInfo{$fullTableName}->{attributeInfo} = $attributeInfo;
    $allTableInfo{$fullTableName}->{lobColumns} = \@lobColumns;

    $allTableInfo{$fullTableName}->{isSelfReferencing} = $isSelfReferencing;
    $allTableInfo{$fullTableName}->{parentRelations} = \@parentRelationsNoHousekeeping;
    # $allTableInfo{$fullTableName}->{parentRelations} = $parentRelations;

    $allTableInfo{$fullTableName}->{fullTableName} = $fullTableName;

    $allTableInfo{$fullTableName}->{primaryKey} = $dbiTable->getPrimaryKey();

    $allTableInfo{$fullTableName}->{attributeList} = $dbiTable->getAttributeList();
  }

  return \%allTableInfo;
}

1;
