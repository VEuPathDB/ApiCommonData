package ApiCommonData::Load::ApplicationTableDumper;

use strict;

use lib "$ENV{GUS_HOME}/lib/perl";

use ApiCommonData::Load::Sqlldr;

use JSON;

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

my $DEFAULT_VIEW_INFO_QUERY = "select view_definition
            from information_schema.views
            where table_schema = ?
            and table_name = ?";

my $DEFAULT_INDEX_INFO_QUERY = "SELECT i.relname AS index_name,
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

#NOTE: this hash is the result of the tables query
sub getTablesHash {$_[0]->{_tables_hash}}
sub setTablesHash {$_[0]->{_tables_hash} = $_[1]}

sub getIndexInfoQuery {$_[0]->{_index_info_query} || $DEFAULT_INDEX_INFO_QUERY}
sub setIndexInfoQuery {$_[0]->{_index_info_query} = $_[1]}

sub getViewsQuery {$_[0]->{_views_query}}
sub setViewsQuery {$_[0]->{_views_query} = $_[1]}

sub getViewsHash {$_[0]->{_views_hash}}
sub setViewsHash {$_[0]->{_views_hash} = $_[1]}

sub getTableInfoQuery {$_[0]->{_table_info_query}  || $DEFAULT_TABLE_INFO_QUERY}
sub setTableInfoQuery {$_[0]->{_table_info_query} = $_[1]}

sub getTableAndViewSpecs {$_[0]->{_table_and_view_specs} || []}
sub addTableAndViewSpecs {push @{$_[0]->{_table_and_view_specs}}, $_[1]}

sub getViewInfoQuery {$_[0]->{_view_info_query}  || $DEFAULT_VIEW_INFO_QUERY}
sub setViewInfoQuery {$_[0]->{_view_info_query} = $_[1]}

sub getDbiConfigOutputFh {$_[0]->{_dbi_config_output_fh}}
sub setDbiConfigOutputFh {$_[0]->{_dbi_config_output_fh} = $_[1]}

sub getSkipSqlldrTables {$_[0]->{_skip_sqlldr_tables} || []}
sub setSkipSqlldrTables {$_[0]->{_skip_sqlldr_tables} = $_[1]}

sub skipSqlldrFiles {
    my ($self, $table) = @_;

    my @skips = keys %{$self->getSkipSqlldrTables()};

    foreach my $skip (@skips) {
        if($table =~ /^${skip}/i) {
            return 1;
        }
    }
    return 0;
}

sub new {
  my ($class, $args) = @_;

  my @required = ('_dbh'
                  , '_tables_query'
      );

  foreach(@required) {
    die "missing required value for param $_" unless(defined($args->{$_}));
  }

  return bless $args, $class;
}


sub dumpFiles {
    my ($self) = @_;


    my $tables = $self->queryForTablesOrViews($self->getTablesQuery());
    $self->setTablesHash($tables);

    foreach my $inputSchema(keys %$tables) {
        foreach my $table (@{$tables->{$inputSchema}}) {
            my $tableInfo = $self->makeTableInfo($inputSchema, $table);

            my $tableName = $tableInfo->getTableName();

            my $datFileName = "${tableName}.cache";
            my $ctlFileName = "${tableName}.ctl";

            #$self->writeCreateTable($tableInfo);

            unless($self->skipSqlldrFiles($table)) {
                $self->writeSqlloaderCtl($tableInfo, $ctlFileName, $datFileName);
                $self->writeSqlloaderDat($inputSchema, $tableInfo, $datFileName);
            }

            $self->writeIndexes($tableInfo, $inputSchema);

            $self->addTableAndViewSpecs($tableInfo->transformToConfigObject());
        }
    }

    my $views = $self->queryForTablesOrViews($self->getViewsQuery());
    $self->setViewsHash($views);

    foreach my $inputSchema(keys %$views) {
        foreach my $view (@{$views->{$inputSchema}}) {
            my $definition = $self->writeViewDefinition($view, $inputSchema);
            $definition =~ s/\n/ /g;
            $definition =~ s/;//g;
            $self->addTableAndViewSpecs({name => $view, type => 'view', definition => $definition, macro => 'SCHEMA'});
        }
    }

    $self->writeDbiConfig();
}

sub writeDbiConfig {
    my ($self) = @_;

    my $fh = $self->getDbiConfigOutputFh();
    my $tableAndViewSpecs = $self->getTableAndViewSpecs();

    print $fh encode_json($tableAndViewSpecs);
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

            if($len) {
                $varcharFields{$col} = $len;
            }
            else {
                # NOTE:  the values here must be null but we need to assign something
                $varcharFields{$col} = 1;
            }
        }
    }
    $sh->finish();

    return _TableInfoHelper->new({'_table_name' => ${table}
                                  , '_varchar_fields' => \%varcharFields
                                      , '_number_fields' => \%numberFields
                                      , '_date_fields' => \%dateFields
                                      , '_null_fields' => \%nullFields
                                      , '_skip_table_column_regexes' => $self->getSkipSqlldrTables()
                                });
}

sub queryForTablesOrViews {
    my ($self, $query) = @_;

    my $dbh = $self->getDbh();

    my $sh = $dbh->prepare($query);
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
        print FILE join("\t", @a) . "\n";
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

sub writeViewDefinition {
    my ($self, $viewName, $inputSchema) = @_;

    my $dbh = $self->getDbh();

    my $viewsQuery = $self->getViewInfoQuery();

    my $sh = $dbh->prepare($viewsQuery);
    $sh->execute($inputSchema, $viewName);

    #there will only be one row here but whatevs
    my ($viewDef) = $sh->fetchrow_array();
    $sh->finish();
    #NOTE: the input schema must be swapped out in the table definition
    $viewDef = lc($viewDef);
    $viewDef =~ s/${inputSchema}/\@SCHEMA\@/g;

    return $viewDef;

}
sub writeIndexes {
    my ($self, $tableInfo, $inputSchema) = @_;

    my $dbh = $self->getDbh();

    my $tableName = $tableInfo->getTableName();


    my $indexesQuery = $self->getIndexInfoQuery();

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


        my @orderedColumns = map { $indexCols->{$indexName}->{col}->{$_} } @a;
        my $colString = join(",", @orderedColumns);


        $self->addTableAndViewSpecs({name => $indexName, tableName => $tableName, type => 'index', orderedColumns => \@orderedColumns});
    }


}


package _TableInfoHelper;

use JSON;

sub getTableName {$_[0]->{_table_name}}
sub setTableName {$_[0]->{_table_name} = $_[1]}

sub getVarcharFields {$_[0]->{_varchar_fields} || {}}
sub setVarcharFields {$_[0]->{_varchar_fields} = $_[1]}

sub getNumberFields {$_[0]->{_number_fields} || {}}
sub setNumberFields {$_[0]->{_number_fields} = $_[1]}

sub getDateFields {$_[0]->{_date_fields} || {}}
sub setDateFields {$_[0]->{_date_fields} = $_[1]}

sub getNullFields {$_[0]->{_null_fields} || {}}
sub setNullFields {$_[0]->{_null_fields} = $_[1]}

sub getSkipTableColumnRegexes {$_[0]->{_skip_table_column_regexes} || {}}
sub setSkipTableColumnRegexes {$_[0]->{_skip_table_column_regexes} = $_[1]}



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

    my @sorted = sort(keys %$numberFields, keys %$varcharFields, keys %$dateFields);

    my @predefinedOrder;

    my $tableName = $self->getTableName();
    my $colRegexes = $self->getSkipTableColumnRegexes();
    if($colRegexes) {


        foreach my $skippedTable (keys %$colRegexes) {
            if($tableName =~ /^${skippedTable}/i) {

                # use order from hash
                my $colOrderRegexes = $colRegexes->{$skippedTable};
                foreach my $regex (@$colOrderRegexes) {
                    my ($found, $foundCount);
                    foreach my $s (@sorted) {
                        if($s =~ /$regex/) {
                            $found = $s;
                            $foundCount++;
                        }
                    }
                    die "Could not determine order of columns for $tableName" if($foundCount != 1);
                    push @predefinedOrder, $found;
                }
                return \@predefinedOrder;
            }
        }
    }

    return \@sorted;
}

sub transformToConfigObject {
    my ($self) = @_;

    my $rv = {};
    my $nullFields = $self->getNullFields();

    my $orderedFieldNames = $self->orderedFieldNames();

    my %fieldIndex;
    my $i = 0;
    foreach(@$orderedFieldNames) {
        $fieldIndex{$_} = $i;
        $i++;
    }

    my $numberFields = $self->getNumberFields();
    my $varcharFields = $self->getVarcharFields();
    my $dateFields = $self->getDateFields();

    $rv->{name} = $self->getTableName();
    $rv->{type} = 'table';
    $rv->{is_preexisting_table} => JSON::false;

    my @unorderedFields;
#@{$rv->{fields}}
    foreach my $field (keys %{$varcharFields}) {
        my $spec = $varcharFields->{$field};
        my $isNullable = $nullFields->{$field} eq 'NOT NULL' ? 'NO' : 'YES';

        push @unorderedFields, {name => $field, cacheFileIndex =>$fieldIndex{$field},  maxLength => $spec, type => 'SQL_VARCHAR', isNullable => $isNullable};
    }

    foreach my $field (keys %{$numberFields}) {
        my $isNullable = $nullFields->{$field} eq 'NOT NULL' ? 'NO' : 'YES';
        my $spec = $numberFields->{$field};
        push @unorderedFields, {name => $field, cacheFileIndex =>$fieldIndex{$field},  prec => $spec, type => 'SQL_NUMBER', isNullable => $isNullable};
    }

    foreach my $field (keys %{$dateFields}) {
        my $isNullable = $nullFields->{$field} eq 'NOT NULL' ? 'NO' : 'YES';
        my $spec = $dateFields->{$field};
        push @unorderedFields, {name => $field, cacheFileIndex =>$fieldIndex{$field},  type => 'SQL_DATE', isNullable => $isNullable};
    }

    my @orderedFields = sort { $a->{cacheFileIndex} <=> $b->{cacheFileIndex} } @unorderedFields;
    $rv->{fields} = \@orderedFields;

    return $rv;
}


package ApiCommonData::Load::ApplicationTableDumper;

1;
