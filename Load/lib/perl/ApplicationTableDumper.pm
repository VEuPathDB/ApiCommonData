package ApiCommonData::Load::ApplicationTableDumper;

use strict;

use lib "$ENV{GUS_HOME}/lib/perl";

use ApiCommonData::Load::Sqlldr;

use Data::Dumper;

sub getDbh {$_[0]->{_dbh}}
sub setDbh {$_[0]->{_dbh} = $_[1]}

sub getTablesQuery {$_[0]->{_tables_query}}
sub setTablesQuery {$_[0]->{_tables_query} = $_[1]}

# this query must contain 2 bind variable (schema and table)
sub getTableInfoQuery {$_[0]->{_table_info_query}}
sub setTableInfoQuery {$_[0]->{_table_info_query} = $_[1]}

sub getSchemaOutputFh {$_[0]->{_schema_output_fh}}
sub setSchemaOutputFh {$_[0]->{_schema_output_fh} = $_[1]}

# maybe the tables already exist?
 sub skipCreateTableSql {$_[0]->{_skip_create_table_sql}}

sub new {
  my ($class, $args) = @_;

  my @required = ('_dbh'
                  , '_tables_query'
                  , '_table_info_query'
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

    foreach my $schema(keys %$tables) {
        foreach my $table (@{$tables->{$schema}}) {
            my $tableInfo = $self->makeTableInfo($schema, $table);

            my $tableName = $tableInfo->getTableName();

            my $datFileName = "${tableName}.dat";
            my $ctlFileName = "${tableName}.ctl";

            $self->writeCreateTable($tableInfo);
            $self->writeSqlloaderCtl($tableInfo, $ctlFileName, $datFileName);
            $self->writeSqlloaderDat($tableInfo, $datFileName);
            #TODO$self->writeIndexes();
        }
    }
}

sub makeTableInfo {
    my ($self, $schema, $table) = @_;

    my $dbh = $self->getDbh();
    my $tableInfoQuery = $self->getTableInfoQuery();
    my $sh = $dbh->prepare($tableInfoQuery);
    $sh->execute($schema, $table);

    my %dateFields;
    my %numberFields;
    my %varcharFields;
    my $fullTableName = "${schema}.${table}";

    my %nullFields;

    while(my ($schema, $table, $isNull, $col, $charLen, $dataType, $numPrec) = $sh->fetchrow_array()) {
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
            my $sh2 = $dbh->prepare("select max(length($col)) from $fullTableName");
            $sh2->execute();
            my ($len) = $sh2->fetchrow_array();
            $sh2->finish();
            $varcharFields{$col} = $len;
        }
    }
    $sh->finish();

    return _TableInfoHelper->new({'_table_name' => "${schema}.${table}"
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
    my ($self, $tableInfo, $datFileName) = @_;

    open(FILE, ">", $datFileName) or die "Cannot open file $datFileName for writing: $!";

    my $tableName = $tableInfo->getTableName();

    my $dbh = $self->getDbh();

    my $orderedFields = $tableInfo->orderedFieldNames();

    # NOTE: columns here must match order in ctl file
    my $fieldsString = join(',', @$orderedFields);

    my $sql = "select $fieldsString from ${tableName}";

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
                                                   _table_name => $tableName,
                                                   _fields => \@fields,
                                                   # something downstream will need to replace these macros
                                                   _login => '@USER@',
                                                   _password => '@PASS@',
                                                   _database => '@INSTANCE@',
                                                  });

    my $sqlldrProcessString = $sqlldr->getCommandLine();
    $sqlldr->writeConfigFile();
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


    my $sqlString = "CREATE TABLE ${tableName} (\n";
    $sqlString .= "$varchars,\n" if $varchars;
    $sqlString .= "$numbers,\n" if $numbers;
    $sqlString .= "$dates,\n" if $dates;

    $sqlString .= ");
GRANT INSERT, SELECT, UPDATE, DELETE ON ${tableName} TO gus_w;
GRANT SELECT ON ${tableName} TO gus_r;
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
