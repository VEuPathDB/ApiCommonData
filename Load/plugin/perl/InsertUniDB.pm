package ApiCommonData::Load::Plugin::InsertUniDB;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use GUS::PluginMgr::Plugin;

use DBI;
use DBD::Oracle;

use GUS::Model::ApiDB::DATABASETABLEMAPPING;

use File::Temp qw/ tempfile /;

use Data::Dumper;

my $END_OF_RECORD_DELIMITER = "#EOR#\n";
my $END_OF_COLUMN_DELIMITER = "#EOC#\t";
my $END_OF_LOB_DELIMITER = "<endlob>\n";

my $MAPPING_TABLE_NAME = "ApiDB.DatabaseTableMapping";
my $PROJECT_INFO_TABLE = "Core.ProjectInfo";
my $TABLE_INFO_TABLE = "Core.TableInfo";


my %GLOBAL_UNIQUE_FIELDS = ("GUS::Model::Core::ProjectInfo" => ["name", "release"],
                            "GUS::Model::Core::TableInfo" => ["name", "database_id"],
                            "GUS::Model::Core::DatabaseInfo" => ["name"],
                            "GUS::Model::Core::DatabaseVersion" => ["version"],
                            "GUS::Model::Core::GroupInfo" => ["name"],
                            "GUS::Model::Core::UserInfo" => ["login"],
                            "GUS::Model::Core::UserProject" => ["user_id", "project_id"],
                            "GUS::Model::Core::UserGroup" => ["user_id", "group_id"],
                            "GUS::Model::Core::Algorithm" => ["name"],
                            "GUS::Model::Core::AlgorithmImplementation" => ["executable", "cvs_revision"], 
                            "GUS::Model::DoTS::AASequenceImp" => ["source_id", "external_database_release_id"],
                            "GUS::Model::DoTS::BLATAlignmentQuality" => ["name"],
                            "GUS::Model::SRes::ExternalDatabase" => ["name"],
                            "GUS::Model::SRes::ExternalDatabaseRelease" => ["external_database_id", "version"],
                            "GUS::Model::SRes::OntologyTerm" => ["source_id", "name", "external_database_release_id"],
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


my $HOUSEKEEPING_FIELDS = ['modification_date',
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
     stringArg ({ name => 'database',
                  descr => 'gus oracle instance name (plas-inc), directory or files or possibly mysql database depending on the table_reader below',
                  constraintFunc => undef,
                  reqd => 1,
                  isList => 0 
                }),

     stringArg ({ name => 'table_reader',
                  descr => 'perl class which will serve out rows to this plugin.  Example ApiCommonData::Load::GUSTableReader',
                  constraintFunc => undef,
                  reqd => 1,
                  isList => 0 
                }),


     booleanArg({
       name            =>  'skipUndo', 
       descr           =>  'skip undo method if set',
       reqd            =>  0,
       isList          =>  0
                }),

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



sub new {
  my $class = shift;
  my $self = {};
  bless($self, $class);

  my $documentation = &getDocumentation();

  my $args = &getArgsDeclaration();

  my $configuration = { requiredDbVersion => 4.0,
#                        cvsRevision => '$Revision$',
		      cvsRevision       => '$Revision$',
                        name => ref($self),
                        argsDeclaration => $args,
                        documentation => $documentation
                      };

  $self->initialize($configuration);

  return $self;
}

sub run {
  my $self = shift;

  my $dbh = $self->getDbHandle();
  $dbh->do("alter session set nls_date_format = 'yyyy-mm-dd hh24:mi:ss'") or $self->error($dbh->errstr);

  my $database = $self->getArg('database');
  my $tableReaderClass = $self->getArg('table_reader');

  eval "require $tableReaderClass";
  die $@ if $@;  

  my $tableReader = eval {
    $tableReaderClass->new($database);
  };
  die $@ if $@;

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

  unless($self->getArg('skipUndo')) {
    foreach my $tableName (reverse @$orderedTables) {
      $self->undoTable($database, $tableName, $tableInfo->{$tableName}, $tableReader);
    }
  }

  foreach my $tableName (@$orderedTables) {
    $self->loadTable($database, $tableName, $tableInfo->{$tableName}, $tableReader);
  }

  $tableReader->disconnectDatabase();
}


sub undoTable {
  my ($self, $database, $tableName, $tableInfo, $tableReader) = @_;

  if ($self->{commit} == 1) {
    my $primaryKeyColumn = $tableInfo->{primaryKey};

    my $origPksHash = $tableReader->getDistinctValuesForTableFields($tableName, [$primaryKeyColumn], 0);

    my $sql = &getDatabaseTableMappingSql($database, [$tableName]);
  
    my $dbh = $self->getDbHandle();
    my $sh = $dbh->prepare($sql);
    $sh->execute();

    my $deleteMapSql = "delete from $MAPPING_TABLE_NAME
             where database_orig = '$database'
             and table_name = '$tableName'
             and primary_key_orig = ?";

    my $delMapSh = $dbh->prepare($deleteMapSql) or die $dbh->errstr;;

    my $count;
    while(my ($databaseOrig, $tableName, $pkOrig, $pk) = $sh->fetchrow_array()) {
      next if($origPksHash->{$pkOrig});
      
      $delMapSh->execute($pkOrig);

      if($count++ % 1000 == 0) {
        $self->log("Deleted $count rows from $MAPPING_TABLE_NAME for table $tableName");
        $dbh->commit();
      }
    }
    $dbh->commit();

    # delete rows from primary table where primaryKey not in (select primarykey from mapping table)
    my $tableAbbrev = &getAbbreviatedTableName($tableName, ".");
    my $chunkSize = 100000;

    my $deleteSql = "delete from $tableAbbrev
        where $primaryKeyColumn not in (select primary_key 
                                        from $MAPPING_TABLE_NAME
                                        where database_orig = '$database' 
                                        and table_name = '$tableName')
        and rownum <= $chunkSize";

    my $deleteStmt = $dbh->prepare($deleteSql) or die $dbh->errstr;
    my $rowsDeleted = 0;
    
    while (1) {
      my $rtnVal = $deleteStmt->execute() or die $self->{dbh}->errstr;
      $rowsDeleted += $rtnVal;
      $self->log("Deleted $rowsDeleted rows from $tableName");
      $dbh->commit() || $self->error("Committing deletions from $tableName failed: " . $self->{dbh}->errstr());
      last if $rtnVal < $chunkSize;
    }
  }
}

sub getDatabaseTableMappingSql {
  my ($database, $tableNames) = @_;

  my $tableNamesString = join(",", map { "'" . &getAbbreviatedTableName($_, '::') . "'" } @$tableNames);

  my $sql = "select database_orig
                  , table_name
                  , primary_key_orig
                  , primary_key 
             from $MAPPING_TABLE_NAME
             where database_orig = '$database'
             and table_name in ($tableNamesString)
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

  $self->log("Begin ID Lookup for $tableName from database $database");

  foreach my $pr (@{$tableInfo->{parentRelations}}) {
    my $field = $pr->[1];

    $self->log("Getting Distinct Values for foreign key $field from $database");

    my @tableNames;

    my $keepIds = $tableReader->getDistinctValuesForTableFields($tableName, [$field], 0);

    if(ref($pr->[0]) eq 'ARRAY') {
      push @tableNames, @{$pr->[0]};
    }
    else {
      push @tableNames, $pr->[0];
    }

    $self->addToIdMappings($database, $idMappings, \@tableNames, $keepIds);
  }

  $self->addToIdMappings($database, $idMappings, [$tableName], undef);

  $self->log("Finished ID Lookup for $tableName from database $database");

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

  my $sql = "select max(primary_key_orig) 
             from $MAPPING_TABLE_NAME
             where database_orig = '$database' 
             and table_name = '$tableName'";

  my $dbh = $self->getQueryHandle();  

  my $sh = $dbh->prepare($sql);
  $sh->execute();

  my ($max) = $sh->fetchrow_array();

  unless($max) {
    return 0;
  }

  return $max;
}


sub queryForMaxPK {
  my ($self, $tableName, $primaryKey) = @_;

  my $sql = "select max($primaryKey) from $tableName";

  my $dbh = $self->getQueryHandle();  

  my $sh = $dbh->prepare($sql);
  $sh->execute();

  my ($max) = $sh->fetchrow_array();

  unless($max) {
    return 0;
  }

  return $max;
}


sub writeConfigFile {
  my ($self, $configFh, $tableInfo, $tableName, $datFileName) = @_;

  my $eolLiteral = $END_OF_LOB_DELIMITER;
  $eolLiteral =~ s/\n/\\n/;

  my $eorLiteral = $END_OF_RECORD_DELIMITER;
  $eorLiteral =~ s/\n/\\n/;

  my $eocLiteral = $END_OF_COLUMN_DELIMITER;
  $eocLiteral =~ s/\t/\\t/;


  my $hasRowProjectId = 1;
  if($tableName eq 'ApiDB.Snp' || $tableName eq 'ApiDB.SequenceVariation') {
    $hasRowProjectId = 0;
  }

  my ($sec,$min,$hour,$mday,$mon,$year) = localtime();
  my @abbr = qw(JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC);
  my $modDate = sprintf('%2d-%s-%02d', $mday, $abbr[$mon], ($year+1900) % 100);

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

  my $attributeList = $tableInfo->{attributeList};
  my $attributeInfo = $tableInfo->{attributeInfo};

  
  my $rowProjectId = ($tableName eq $PROJECT_INFO_TABLE || $tableName eq $MAPPING_TABLE_NAME) ? " constant $projectId" : "";

  my $datatypeMap = {'user_read' => " constant $userRead", 
                     'user_write' => " constant $userWrite", 
                     'group_read' => " constant $groupRead", 
                     'group_write' => " constant $groupWrite", 
                     'other_read' => " constant $otherRead", 
                     'other_write' => " constant $otherWrite", 
                     'row_user_id' => " constant $userId", 
                     'row_group_id' => " constant $groupId", 
                     'row_alg_invocation_id' => " constant $algInvocationId",
                     'row_project_id' => $rowProjectId,
  };

  if($tableName eq $MAPPING_TABLE_NAME) {
    $attributeList = ["database_orig",
                      "table_name",
                      "primary_key_orig",
                      "primary_key",
                      "global_natural_key",
                      'modification_date',
        ];

    push @$attributeList, keys %$datatypeMap;

    $datatypeMap->{'database_orig'} = " CHAR(10)";
    $datatypeMap->{'global_natural_key'} = " CHAR(2500)";
    $datatypeMap->{'table_name'} = " CHAR(35)";
    $datatypeMap->{'primary_key_orig'} = " INTEGER EXTERNAL(20)";
    $datatypeMap->{'primary_key'} = " INTEGER EXTERNAL(20)";
  }
  else {
    foreach my $att (@$attributeInfo) {
      my $col = lc($att->{'col'});

      unless($datatypeMap->{$col}) {
        my $prec = $att->{'prec'};
        my $precString = $prec ? "($prec)" : "";
        my $length = $att->{'length'};
        my $type = $att->{'type'};

        if($type eq 'NUMBER') {
          $datatypeMap->{$col} = " CHAR";
        }
        elsif($type eq 'CHAR' || $type eq 'VARCHAR2') {
          $datatypeMap->{$col} = " CHAR($length)";
        }
        elsif($type eq 'DATE') {
          $datatypeMap->{$col} = " DATE 'yyyy-mm-dd hh24:mi:ss'";
        }
        elsif($type eq 'FLOAT') {
          $datatypeMap->{$col} = " CHAR(255)";
        }

        elsif($type eq 'BLOB' || $type eq 'CLOB') {
          $datatypeMap->{$col} = " LOBFILE( CONSTANT '${tableName}.${col}.txt') TERMINATED BY \"$eolLiteral\"";
        }

        else {
          $self->error("$type columns not currently supported by this plugin for loading with sqlloader");
        }
      }
    }
  }

  $datatypeMap->{'modification_date'} = " constant \"$modDate\"";

  my @fields = map { lc($_) . $datatypeMap->{lc($_)}  } grep { $_ ne 'row_project_id'} @$attributeList;

  if($hasRowProjectId) {
    push @fields, "row_project_id " . $datatypeMap->{row_project_id}; #ensure row_project_id is last
  }

  if($tableName eq $MAPPING_TABLE_NAME) {
    # TODO: hoiw to say INTEGER(20) for this pk?
    push @fields, "database_table_mapping_id SEQUENCE(MAX,1)";
  }

  my $fieldsString = join(",\n", @fields);




  print $configFh "LOAD DATA
INFILE '$datFileName' \"str '$eorLiteral'\" 
APPEND
INTO TABLE $tableName
REENABLE DISABLED_CONSTRAINTS
FIELDS TERMINATED BY '$eocLiteral'
TRAILING NULLCOLS
($fieldsString
)
";
}


sub loadTable {
  my ($self, $database, $tableName, $tableInfo, $tableReader) = @_;

  # New GUS Table ApiDB does not use
  next if $tableName =~ /SnpLinkage/;

  # try to reuse all rows from these tables
  # some of these will have rows populated by the installer so globalMapping query is different
  my $isGlobalTable = $tableName =~ /GUS::Model::Core::(\w+)Info/ || 
      $tableName =~ /GUS::Model::Core::Algorithm/ || 
      $tableName eq 'GUS::Model::Study::Protocol' || 
      $tableName eq 'GUS::Model::Study::ProtocolParam';

  $self->log("Begin Loading table $tableName from database $database");

  my $rowCount = 0;
  my $primaryKeyColumn = $tableInfo->{primaryKey};
  my $isSelfReferencing = $tableInfo->{isSelfReferencing};
  my $hasLobColumns = scalar(@{$tableInfo->{lobColumns}}) > 0;

  my ($hasNewRows, $hasNewMapRows);

  my $abbreviatedTableColumn = &getAbbreviatedTableName($tableName, "::");
  my $abbreviatedTablePeriod = &getAbbreviatedTableName($tableName, ".");

  my %lobFiles = map { $_ => 1 } @{$tableInfo->{lobColumns}};
  foreach my $lobCol (@{$tableInfo->{lobColumns}}) {
    open(my $fh, ">${abbreviatedTablePeriod}.$lobCol.txt") or die "Cannot open ${abbreviatedTablePeriod}.$lobCol for writing: $!";
    $lobFiles{$lobCol} = $fh;
  }

  my $alreadyMappedMaxOrigPk = $self->queryForMaxMappedOrigPk($database, $abbreviatedTableColumn);

  my $maxPrimaryKey = $self->queryForMaxPK($abbreviatedTablePeriod, $primaryKeyColumn);

  $tableReader->prepareTable($tableName, $isSelfReferencing, $primaryKeyColumn, $alreadyMappedMaxOrigPk);

  # TODO:  could pass $alredyMappedMaxOrigPk here to cache fewer rows??
  my $idMappings = $self->getIdMappings($database, $tableName, $tableInfo, $tableReader);

  my $globalLookup = $self->globalLookupForTable($primaryKeyColumn, $tableName, $database, $isGlobalTable);

  $self->log("Will skip rows with a $primaryKeyColumn <= $alreadyMappedMaxOrigPk");

  my %housekeepingFieldsHash = map { $_ => 1 } @$HOUSEKEEPING_FIELDS;

  my ($sqlldrDatFh, $sqlldrDatFn) = tempfile("sqlldrDatXXXX", UNLINK => 0, SUFFIX => '.ctl');
  my ($sqlldrMapFh, $sqlldrMapFn) = tempfile("sqlldrMapXXXX", UNLINK => 0, SUFFIX => '.ctl');

  my ($sqlldrDatInfileFh, $sqlldrDatInfileFn) = tempfile("sqlldrDatXXXX", UNLINK => 0, SUFFIX => '.dat');
  my ($sqlldrMapInfileFh, $sqlldrMapInfileFn) = tempfile("sqlldrMapXXXX", UNLINK => 0, SUFFIX => '.dat');

  $self->writeConfigFile($sqlldrDatFh, $tableInfo, $abbreviatedTablePeriod, $sqlldrDatInfileFn);
  $self->writeConfigFile($sqlldrMapFh, $tableInfo, $MAPPING_TABLE_NAME, $sqlldrMapInfileFn);

  my @attributeList = map { lc($_) } @{$tableInfo->{attributeList}};

  while(my $row = $tableReader->nextRowAsHashref($tableInfo)) {
    my $origPrimaryKey = $row->{lc($primaryKeyColumn)};

    next if($origPrimaryKey <= $alreadyMappedMaxOrigPk); # restart OR new data (TODO: won't work for "skipped" datasets)
    next if($tableReader->skipRow($row));

    my ($mappedRow, $fieldsToSetToPk) = $self->mapRow($row, $idMappings, $tableInfo, $origPrimaryKey);

    my $primaryKey;

    my $isGlobal = $tableReader->isRowGlobal($mappedRow) || $isGlobalTable;

    if($isGlobal) {
      $primaryKey = $self->lookupPrimaryKey($tableName, $mappedRow, $globalLookup);

      unless($primaryKey) {
        $self->log("No lookup Found for GLOBAL row $origPrimaryKey in table $tableName...adding row") if($self->getArg("debug"));
      }

      if($primaryKey && !$idMappings->{$tableName}->{$origPrimaryKey}) {
        $hasNewMapRows = 1;
        my @mappingRow = ($database, $abbreviatedTableColumn, $origPrimaryKey, $primaryKey, undef);
        print $sqlldrMapInfileFh join($END_OF_COLUMN_DELIMITER, @mappingRow) . $END_OF_RECORD_DELIMITER ; # note the special line terminator

        $idMappings->{$tableName}->{$origPrimaryKey} = $primaryKey
      }
    }

    if(!$primaryKey && $abbreviatedTablePeriod ne $TABLE_INFO_TABLE) {
      $hasNewRows = 1;
      $rowCount++;

      $primaryKey = ++$maxPrimaryKey;
      $mappedRow->{lc($primaryKeyColumn)} = $primaryKey;

      # If the table is self referencing AND the fk is to the same row
      foreach my $ancestorField (@$fieldsToSetToPk) {
        $mappedRow->{lc($ancestorField)} = $primaryKey;
      }

      # self referencing tables will need mappings for loaded rows
      $idMappings->{$tableName}->{$origPrimaryKey} = $primaryKey if($isSelfReferencing);

      my @nonLobColumns = map { $mappedRow->{$_} } grep { !$lobFiles{$_} && !$housekeepingFieldsHash{$_} } @attributeList;
      push @nonLobColumns, $mappedRow->{row_project_id} if($abbreviatedTablePeriod ne $PROJECT_INFO_TABLE);

      print $sqlldrDatInfileFh join($END_OF_COLUMN_DELIMITER, @nonLobColumns) . $END_OF_RECORD_DELIMITER; # note the special line terminator

      # each lob column is written to a lobfile
      foreach my $lobCol (keys %lobFiles) {
        my $fh = $lobFiles{$lobCol};
        print $fh $mappedRow->{$lobCol} . $END_OF_LOB_DELIMITER;
      }

      # update the globalMapp for newly added rows
      my $globalNaturalKey;
      if($isGlobal) {
        my $globalUniqueFields = $GLOBAL_UNIQUE_FIELDS{$tableName};

        my @globalUniqueValues = map { lc($mappedRow->{lc($_)}) } @$globalUniqueFields;
        $globalNaturalKey = join("_", @globalUniqueValues);
        $globalLookup->{$globalNaturalKey} = $primaryKey;
      }

      my @mappingRow = ($database, $abbreviatedTableColumn, $origPrimaryKey, $primaryKey, $globalNaturalKey);
      print $sqlldrMapInfileFh join($END_OF_COLUMN_DELIMITER, @mappingRow) . $END_OF_RECORD_DELIMITER; # note the special line terminator
    }
  }

  $tableReader->finishTable();

  # Run Loader
  if($hasNewRows || $hasNewMapRows) {
    my $login       = $self->getConfig->getDatabaseLogin();
    my $password    = $self->getConfig->getDatabasePassword();
    my $dbiDsn      = $self->getConfig->getDbiDsn();

    my ($dbi, $type, $db) = split(':', $dbiDsn);

    if($hasNewRows) {
      my $sqlLdrSystemResult = system("sqlldr $login/$password\@$db control=$sqlldrDatFn direct=TRUE log=${sqlldrDatFn}.log discardmax=0 errors=0") if($self->getArg('commit'));
      unless($sqlLdrSystemResult / 256 == 0) {
        $self->error("sqlldr failed:  ${sqlldrDatFn}.log");
      }
    }

    my $sqlLdrMapSystemResult = system("sqlldr $login/$password\@$db control=$sqlldrMapFn rows=1000 log=${sqlldrMapFn}.log discardmax=0 errors=0") if($self->getArg('commit'));
    unless($sqlLdrMapSystemResult / 256 == 0) {
      $self->error("sqlldr failed:  ${sqlldrMapFn}.log");
    }
  }

  # update the sequence 
  my $sequenceName = "${abbreviatedTablePeriod}_sq";
  my $dbh = $self->getQueryHandle();  
  my ($sequenceValue) = $dbh->selectrow_array("select ${sequenceName}.nextval from dual"); 
  my $sequenceDifference = $maxPrimaryKey - $sequenceValue;
  if($sequenceDifference > 0) {
    $dbh->do("alter sequence $sequenceName increment by $sequenceDifference");
    $dbh->do("select ${sequenceName}.nextval from dual");
    $dbh->do("alter sequence $sequenceName increment by 1");
  }

  # clean up the temporary files
  unlink($sqlldrDatFn,$sqlldrMapFn,$sqlldrDatInfileFn,$sqlldrMapInfileFn);

  $rowCount = 0 unless($self->getArg('commit'));
  $self->log("Finished Loading $rowCount Rows into table $tableName from database $database");
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
  my ($self, $primaryKeyColumn, $tableName, $database, $isGlobalTable) = @_;

  my $dbh = $self->getQueryHandle();  

  my $fields = $GLOBAL_UNIQUE_FIELDS{$tableName};

  return unless($fields);

  $self->log("Preparing Global Lookup for table $tableName");

  my $sql;
  if($isGlobalTable) {
    my $fieldsString = join(",", map { $_ } @$fields);
    $tableName = &getAbbreviatedTableName($tableName, ".");

    $sql = "select $primaryKeyColumn, $fieldsString from $tableName";
  }
  else {
    $tableName = &getAbbreviatedTableName($tableName, "::");
    $sql = "select primary_key, global_natural_key from apidb.DatabaseTableMapping where table_name = '$tableName' and global_natural_key is not null";
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

  $self->log("Finished caching Global Lookup for table $tableName");

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
  return "select ti.name as table_name
                  , di.name as database_name
                  , ti. primary_key_column
             from (-- everything but version and userdataset schemas
                   select  t.* 
                   from core.tableinfo t, core.databaseinfo d
                   where lower(t.table_type) != 'version'
                    and t.DATABASE_ID = d.DATABASE_ID
                    and d.name not in ('UserDatasets', 'ApidbUserDatasets', 'chEBI', 'hmdb')
                    and t.name not in ('AlgorithmParam', 'AlgorithmParamKey', 'AlgorithmParamKeyType')
                   minus
                   -- minus Views on tables
                   select * from core.tableinfo where view_on_table_id is not null
                  ) ti, core.databaseinfo di
            where ti.database_id = di.database_id
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

    my @lobColumns;

    my $attributeInfo = $dbiTable->getAttributeInfo();

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

      # NASequenceImp has circular foreign key to sequence piece. we never use
      # TODO:  should fix this in gus schema
      if($fullTableName eq "GUS::Model::DoTS::NASequenceImp" &&
         $parentTable eq "GUS::Model::DoTS::SequencePiece") {
        next;
      }

      if($fullTableName eq "GUS::Model::ApiDB::SequenceVariation" && (lc($field) eq 'location' || lc($parentField) eq 'location')) {
        next;
      }



      # important for us to retain row_project_id
      unless($field eq "row_alg_invocation_id" || $field eq "row_user_id" || $field eq "row_group_id" || (&getAbbreviatedTableName($fullTableName, '.') eq $PROJECT_INFO_TABLE && $field eq "row_project_id")) {
        push @parentRelationsNoHousekeeping, $parentRelation;
      }
    }

    $allTableInfo{$fullTableName}->{attributeInfo} = $attributeInfo;
    $allTableInfo{$fullTableName}->{lobColumns} = \@lobColumns;

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

  my $skips = {'GUS::Model::Core::DatabaseDocumentation' =>  {'table_id' => 1} ,
               'GUS::Model::DoTS::BLATAlignment' => { 'query_table_id' => 1, 'target_table_id' => 1 },
               'GUS::Model::ApiDB::BLATProteinAlignment' => { 'query_table_id' => 1, 'target_table_id' => 1 },
               'GUS::Model::Study::Characteristic' => { 'table_id' => 1 },
               'GUS::Model::Core::TableInfo' => {'superclass_table_id' => 1, 'view_on_table_id' => 1},
               'GUS::Model::Core::TableCategory' => { 'table_id' => 1 },
  };

  my $map = { 'GUS::Model::DoTS::IndexWordSimLink' => {'similarity_table_id' => 'best_similarity_id'},
              'GUS::Model::DoTS::BestSimilarityPair' => {'paired_source_table_id' => 'paired_sequence_id',
                                                         'source_table_id' => 'sequence_id' },
              'GUS::Model::DoTS::Complementation' => { 'table_id' => 'entry_id'},
              'GUS::Model::DoTS::SequenceSequenceGroup' => { 'source_table_id' => 'sequence_id'},
              'GUS::Model::Model::NetworkRelEvidence' => { 'fact_table_id' => 'fact_row_id' },
              'GUS::Model::DoTS::MergeSplit' => { 'table_id' => 'old_id' },
              'GUS::Model::DoTS::ProjectLink' => { 'table_id' => 'id'}

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


sub getConfig {
  my ($self) = @_;

  if (!$self->{config}) {
    my $gusConfigFile = $self->getArg('gusconfigfile');
     $self->{config} = GUS::Supported::GusConfig->new($gusConfigFile);
   }

  $self->{config};
}

1;
