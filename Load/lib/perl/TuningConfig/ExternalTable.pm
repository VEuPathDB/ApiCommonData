package ApiCommonData::Load::TuningConfig::ExternalTable;


# @ISA = qw( ApiCommonData::Load::TuningConfig::Table );


use strict;
use Data::Dumper;

sub new {
    my ($class,
	$name,  # name of database table
        $dbh)   # database handle
	= @_;

    my $self = {};

    bless($self, $class);
    $self->{name} = $name;
    $self->{dbh} = $dbh;

    my ($schema, $table) = split(/\./, $name);
    $self->{schema} = $schema;
    $self->{table} = $table;

    # check that this table exists in the database
    my $sql = <<SQL;
       select count(*) from
       (select table_name from all_tables
        where owner = upper('$schema') and table_name = upper('$table')
/*     union
        select view_name from all_views
        where owner = upper('$schema') and view_name = upper('$table')
       union
        select synonym_name from all_synonyms
        where owner = upper('$schema') and synonym_name = upper('$table') */)
SQL
    my $stmt = $dbh->prepare($sql);
    $stmt->execute() or die "failed executing SQL statement \"$sql\"\n";
    my ($count) = $stmt->fetchrow_array();
    $stmt->finish();
    $self->{exists} = $count;

    # get the last-modified date for this table
    # check that this table exists in the database
    my $sql = <<SQL;
       select to_char(max(timestamp), 'yyyy-mm-dd hh24:mi:ss')
       from all_tab_modifications
       where table_owner = upper('$schema') and table_name = upper('$table')
SQL
    my $stmt = $dbh->prepare($sql);
    $stmt->execute() or die "failed executing SQL statement \"$sql\"\n";
    my ($timestamp) = $stmt->fetchrow_array();
    $stmt->finish();
    $self->{timestamp} = $timestamp;

    return $self;
}


sub getTimestamp {
    my ($self) = @_;

    return $self->{timestamp};
}

sub exists {
    my ($self) = @_;

    return $self->{exists};
}

1;
