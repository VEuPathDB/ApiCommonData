#!/usr/bin/perl

use strict;

use lib "$ENV{GUS_HOME}/lib/perl";

use DBI;
use DBD::Pg;

use Getopt::Long;

use GUS::Supported::GusConfig;

use ApiCommonData::Load::ApplicationTableDumper;

my ($help, $gusConfigFile, $sqlFile);

&GetOptions('help|h' => \$help,
            'gusConfig|g=s' => \$gusConfigFile,
            'schemaSqlOuptutFile|o=s' => \$sqlFile,
    );


my $sqlFh;
open($sqlFh, ">", $sqlFile) or die "Cannot open file $sqlFile for writing: $@";

my $schema = 'apidbuserdatasets';

my @tablePrefixes = ('attributegraph', 'attributevalue', 'ancestors', 'attributes', 'collection');

my @viewPrefixes = ('attributevalue');

my $gusConfig = GUS::Supported::GusConfig->new($gusConfigFile);

my $login = $gusConfig->getDatabaseLogin();
my $password = $gusConfig->getDatabasePassword();
my $dbiDsn = $gusConfig->getDbiDsn();

my $dbh = DBI->connect($dbiDsn, $login, $password) or die DBI->errstr;
$dbh->{RaiseError} = 1;

my $tablesQuery = join("\nUNION\n", map {
"select table_schema, table_name
        from information_schema.tables
        where lower(table_schema) = '$schema'
        and lower(table_name) like '${_}_%'"
                       } @tablePrefixes);

my $tableInfoQuery = "select table_schema
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

my $applicationTableDumper = ApiCommonData::Load::ApplicationTableDumper->new({'_schema_output_fh' => $sqlFh
                                                                                   , '_dbh' => $dbh
                                                                                   , '_tables_query' => $tablesQuery
                                                                                   , '_table_info_query' => $tableInfoQuery

                                                                              });



$applicationTableDumper->dumpFiles();


# TODO:  InsertInto for entitytypegraph, study, yada yada yada

close $sqlFh;

#my $viewSql = "select table_schema, table_name, view_definition, from information_schema.views where table_name like 'attributevalue%' order by table_schema, table_name"
