package ApiCommonData::Load::ApplicationTableDumper;

use strict;

use lib "$ENV{GUS_HOME}/lib/perl";

use ApiCommonData::Load::Sqlldr;

use Data::Dumper;


my $DEFAULT_TABLE_INFO_QUERY = "select table_schema
    , table_name
    , is_nullable
    , column_name
    , character_maximum_length
    , data_type
    , numeric_precision
  from information_schema.columns
  where table_schema = ?
  and table_name = ?
";

my $DEVAULT_VIEWS_QUERY = "select view_definition
            from information_schema.views
            where table_schema = ?
            and table_name = ?";

my $DEFAULT_INDEXES_QUERY = "SELECT i.relname AS index_name,
       a.attname AS column_name,
       idx.indisunique AS is_unique,
       idx.indisprimary AS is_primary,
       idx.indkey,
       a.attnum
FROM pg_class t
JOIN pg_namespace ns ON ns.oid = t.relnamespace
JOIN pg_index idx ON t.oid = idx.indrelid
JOIN pg_class i ON i.oid = idx.indexrelid
JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = ANY(idx.indkey)
WHERE t.relkind = 'r'
and ns.nspname = ? --table_schema
and t.relname = ? --table_name
";

sub getDbh {$_[0]->{_dbh}}
sub setDbh {$_[0]->{_dbh} = $_[1]}

sub getTablesQuery {$_[0]->{_tables_query}}
sub setTablesQuery {$_[0]->{_tables_query} = $_[1]}

sub getIndexesQuery {$_[0]->{_indexes_query} || $DEFAULT_INDEXES_QUERY}
sub setIndexesQuery {$_[0]->{_indexes_query} = $_[1]}

sub getViewsQuery {$_[0]->{_views_query} || $DEVAULT_VIEWS_QUERY}
sub setViewsQuery {$_[0]->{_views_query} = $_[1]}

sub getTableInfoQuery {$_[0]->{_table_info_query}  || $DEFAULT_TABLE_INFO_QUERY}
sub setTableInfoQuery {$_[0]->{_table_info_query} = $_[1]}

sub getSchemaOutputFh {$_[0]->{_schema_output_fh}}
sub setSchemaOutputFh {$_[0]->{_schema_output_fh} = $_[1]}

# maybe the tables already exist?
sub skipCreateTableSql {$_[0]->{_skip_create_table_sql}}
sub skipSqlldrFiles {$_[0]->{_skip_sqlldr_files}}

sub new {
  my ($class, $args) = @_;

  my @required = ('_dbh'
                  , '_tables_query'
                  , '_schema_output_fh'
      );

  foreach(@required) {
    die "missing required value for param $_" unless(defined($args->{$_}));
  }

  return bless $args, $class;
}


sub dumpFiles {
    my ($self) = @_;

    my $tables = $self->queryForTables();

    foreach my $inputSchema(keys %$tables) {
        foreach my $table (@{$tables->{$inputSchema}}) {
            my $tableInfo = $self->makeTableInfo($inputSchema, $table);

            my $tableName = $tableInfo->getTableName();

            my $datFileName = "${tableName}.dat";
            my $ctlFileName = "${tableName}.ctl";

            $self->writeCreateTable($tableInfo) unless($self->skipCreateTableSql());

            unless($self->skipSqlldrFiles()) {
                $self->writeSqlloaderCtl($tableInfo, $ctlFileName, $datFileName);
                $self->writeSqlloaderDat($inputSchema, $tableInfo, $datFileName);
            }
            $self->writeIndexes($tableInfo, $inputSchema);
            $self->writeViews($tableInfo, $inputSchema);
        }
    }
}

sub makeTableInfo {
    my ($self, $inputSchema, $table) = @_;

    my $dbh = $self->getDbh();
    my $tableInfoQuery = $self->getTableInfoQuery();
    my $sh = $dbh->prepare($tableInfoQuery);
    $sh->execute($inputSchema, $table);

    my %dateFields;
    my %numberFields;
    my %varcharFields;
    my $inputFullTableName = "${inputSchema}.${table}";

    my %nullFields;

    while(my ($iSchema, $table, $isNull, $col, $charLen, $dataType, $numPrec) = $sh->fetchrow_array()) {
        $nullFields{$col} = uc($isNull) eq "YES" ? "" : "NOT NULL";

        if($dataType eq 'date') {
            $dateFields{$col} = "NA";
        }
        elsif(($dataType eq 'numeric' || $dataType eq 'integer') && defined $numPrec ) {
            $numberFields{$col} = $numPrec;

        }
        # number but unknown precision
        elsif($dataType eq 'numeric' || $dataType eq 'integer') {
            $numberFields{$col} = "NA";

        }
        elsif(defined($charLen)) {
            $varcharFields{$col} = $charLen;
        }
        # not number or date... so let's get the max length of the text
        else {
            # this query is always the same
            my $sh2 = $dbh->prepare("select max(length($col)) from $inputFullTableName");
            $sh2->execute();
            my ($len) = $sh2->fetchrow_array();
            $sh2->finish();
            $varcharFields{$col} = $len;
        }
    }
    $sh->finish();

    return _TableInfoHelper->new({'_table_name' => ${table}
                                      , '_varchar_fields' => \%varcharFields
                                      , '_number_fields' => \%numberFields
                                      , '_date_fields' => \%dateFields,
                                      , '_null_fields' => \%nullFields
                                });
}

sub queryForTables {
    my ($self) = @_;

    my $dbh = $self->getDbh();
    my $tablesQuery = $self->getTablesQuery();

    my $sh = $dbh->prepare($tablesQuery);
    $sh->execute();

    my $tables = {};
    while(my ($schema, $table) = $sh->fetchrow_array()) {
        push @{$tables->{$schema}}, $table;
    }

    return $tables;
}

sub writeSqlloaderDat {
    my ($self, $schema, $tableInfo, $datFileName) = @_;

    open(FILE, ">", $datFileName) or die "Cannot open file $datFileName for writing: $!";

    my $tableName = $tableInfo->getTableName();

    my $dbh = $self->getDbh();

    my $orderedFields = $tableInfo->orderedFieldNames();

    # NOTE: columns here must match order in ctl file
    my $fieldsString = join(',', @$orderedFields);

    my $sql = "select $fieldsString from ${schema}.${tableName}";

    my $sh = $dbh->prepare($sql);
    $sh->execute();

    while(my @a = $sh->fetchrow_array) {
        print FILE join("\t, @a") . "\n";
    }
    $sh->finish();
    close FILE;
}

sub writeSqlloaderCtl {
    my ($self, $tableInfo, $ctlFileName, $datFileName) = @_;

    my $numberFields = $tableInfo->getNumberFields();
    my $varcharFields = $tableInfo->getVarcharFields();
    my $dateFields = $tableInfo->getDateFields();
    my $tableName = $tableInfo->getTableName();


    my %fieldsMap;
    foreach(keys %$varcharFields) {
        $fieldsMap{$_} = "CHAR(" . $varcharFields->{$_} . ")";
    }
    foreach(keys %$dateFields) {
        $fieldsMap{$_} = "DATE 'yyyy-mm-dd hh24:mi:ss'";
    }
    foreach(keys %$numberFields) {
        $fieldsMap{$_} = "CHAR"; #use default here for numbers
    }

    my $orderedFields = $tableInfo->orderedFieldNames();

    # NOTE: columns here must match order in dat file
    my @fields = map { $_ .  " " . $fieldsMap{$_} } @$orderedFields;

    my $sqlldr = ApiCommonData::Load::Sqlldr->new({_direct => 1,
                                                   _controlFilePrefix => $tableName,
                                                   _quiet => 0,
                                                   _append => 0,
                                                   _infile_name => $datFileName,
                                                   _reenable_disabled_constraints => 1,
                                                   _table_name => '@SCHEMA@'.$tableName,
                                                   _fields => \@fields,
                                                   # something downstream will need to replace these macros
                                                   _login => '@USER@',
                                                   _password => '@PASS@',
                                                   _database => '@INSTANCE@',
                                                  });

    my $sqlldrProcessString = $sqlldr->getCommandLine();
    $sqlldr->writeConfigFile();
}

sub writeViews {
    my ($self, $tableInfo, $inputSchema) = @_;

    my $dbh = $self->getDbh();

    my $tableName = $tableInfo->getTableName();
    my $fh = $self->getSchemaOutputFh();

    my $viewsQuery = $self->getViewsQuery();

    my $sh = $dbh->prepare($viewsQuery);
    $sh->execute($inputSchema, $tableName);

    while(my ($viewDef) = $sh->fetchrow_array()) {
        print $fh "CREATE OR REPLACE VIEW \&1.$tableName AS $viewDef;\n";
    }
    $sh->finish();
}
sub writeIndexes {
    my ($self, $tableInfo, $inputSchema) = @_;

    my $dbh = $self->getDbh();

    my $tableName = $tableInfo->getTableName();
    my $fh = $self->getSchemaOutputFh();

    my $indexesQuery = $self->getIndexesQuery();

    my $sh = $dbh->prepare($indexesQuery);
    $sh->execute($inputSchema, $tableName);

    my $indexCols = {};
    my $indexKeys = {};

    while(my ($indexName, $colName, $isUnique, $isPrimary, $indKey, $attNum) = $sh->fetchrow_array()) {
        $indexCols->{$indexName}->{col}->{$attNum} = $colName;
        $indexCols->{$indexName}->{isPrimary} = $isPrimary;
        $indexCols->{$indexName}->{isUnique} = $isUnique;

        $indexKeys->{$indexName} = $indKey; #always the same for an index name so can just always set
    }
    $sh->finish();

    foreach my $indexName (keys %$indexKeys) {

        # the key here is ordered string like "4 2 3 1"
        my $key = $indexKeys->{$indexName};
        my @a = split(' ', $key);

        my $colString = join(",", map { $indexCols->{$indexName}->{col}->{$_} } @a);

        print $fh "CREATE INDEX $indexName ON \&1.$tableName ($colString) TABLESPACE indx\n";
        # TODO: set unique and pk constraints
    }


}

sub writeCreateTable {
    my ($self, $tableInfo) = @_;

    my $numberFields = $tableInfo->getNumberFields();
    my $varcharFields = $tableInfo->getVarcharFields();
    my $dateFields = $tableInfo->getDateFields();
    my $tableName = $tableInfo->getTableName();
    my $nullFields = $tableInfo->getNullFields();

    my $fh = $self->getSchemaOutputFh();

    my $varchars = join(",\n", map { $_ . " VARCHAR(" . $varcharFields->{$_} . ") " . $nullFields->{$_}} keys %$varcharFields);
    my $numbers = join(",\n", map { $_ . " NUMBER"} keys %$numberFields);
    my $dates = join(",\n", map { $_ . " DATE"} keys %$dateFields);


    my $sqlString = "CREATE TABLE  \&1.${tableName} (\n";
    $sqlString .= "$varchars,\n" if $varchars;
    $sqlString .= "$numbers,\n" if $numbers;
    $sqlString .= "$dates,\n" if $dates;

    $sqlString .= ");
GRANT INSERT, SELECT, UPDATE, DELETE ON \&1.${tableName} TO gus_w;
GRANT SELECT ON \&1.${tableName} TO gus_r;
";

    print $fh $sqlString;
}

package _TableInfoHelper;

sub getTableName {$_[0]->{_table_name}}
sub setTableName {$_[0]->{_table_name} = $_[1]}

sub getVarcharFields {$_[0]->{_varchar_fields}}
sub setVarcharFields {$_[0]->{_varchar_fields} = $_[1]}

sub getNumberFields {$_[0]->{_number_fields}}
sub setNumberFields {$_[0]->{_number_fields} = $_[1]}

sub getDateFields {$_[0]->{_date_fields}}
sub setDateFields {$_[0]->{_date_fields} = $_[1]}

sub getNullFields {$_[0]->{_null_fields}}
sub setNullFields {$_[0]->{_null_fields} = $_[1]}

sub new {
  my ($class, $args) = @_;

  my @required = ('_table_name'
                  , '_varchar_fields'
                  , '_number_fields'
                  , '_date_fields'
                  , '_null_fields'
      );

  foreach(@required) {
    die "missing required value for param $_" unless(defined($args->{$_}));
  }

  return bless $args, $class;
}

sub orderedFieldNames {
    my ($self) = @_;

    my $numberFields = $self->getNumberFields();
    my $varcharFields = $self->getVarcharFields();
    my $dateFields = $self->getDateFields();

    my @rv = sort(keys %$numberFields, keys %$varcharFields, keys %$dateFields);
    return \@rv;
}


package ApiCommonData::Load::ApplicationTableDumper;

1;
