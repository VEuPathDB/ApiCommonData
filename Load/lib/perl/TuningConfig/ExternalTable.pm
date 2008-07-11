package ApiCommonData::Load::TuningConfig::ExternalTable;


# @ISA = qw( ApiCommonData::Load::TuningConfig::Table );


use strict;
use Data::Dumper;
use ApiCommonData::Load::TuningConfig::Log;

sub new {
    my ($class,
	$name,  # name of database table
        $dbh)   # database handle
	= @_;

    my $self = {};

    bless($self, $class);
    $self->{name} = $name;

    my ($schema, $table) = split(/\./, $name);
    $self->{schema} = $schema;
    $self->{table} = $table;

    # check that this table exists in the database
    my $sql = <<SQL;
       select count(*) from all_tables
        where owner = upper('$schema') and table_name = upper('$table')
SQL
    my $stmt = $dbh->prepare($sql);
    $stmt->execute()
      or ApiCommonData::Load::TuningConfig::Log::addErrorLog("\n" . $dbh->errstr . "\n");
    my ($count) = $stmt->fetchrow_array();
    $stmt->finish();
    $self->{exists} = $count;

    ApiCommonData::Load::TuningConfig::Log::addErrorLog("$self->{name} does not exist")
	if !$count;

    # get the last-modified date for this table
    $sql = <<SQL;
       select to_char(max(modification_date), 'yyyy-mm-dd hh24:mi:ss'), count(*)
       from $name
SQL
    my $stmt = $dbh->prepare($sql);
    $stmt->execute()
      or ApiCommonData::Load::TuningConfig::Log::addErrorLog("\n" . $dbh->errstr . "\n");
    my ($max_mod_date, $row_count) = $stmt->fetchrow_array();
    $stmt->finish();

    # get stored ExternalDependency info for this table
    $sql = <<SQL;
       select to_char(max_mod_date, 'yyyy-mm-dd hh24:mi:ss'), row_count, timestamp
       from apidb.ExternalDependency
       where name = upper('$name')
SQL
    my $stmt = $dbh->prepare($sql);
    $stmt->execute()
      or ApiCommonData::Load::TuningConfig::Log::addErrorLog("\n" . $dbh->errstr . "\n");
    my ($stored_max_mod_date, $stored_row_count, $timestamp) = $stmt->fetchrow_array();
    $stmt->finish();

    # compare stored and calculated table stats
    if ($max_mod_date eq $stored_max_mod_date && $row_count == $stored_row_count) {
      # stored stats still valid
      $self->{timestamp} = $timestamp;
      ApiCommonData::Load::TuningConfig::Log::addLog("Stored timestamp ($timestamp) still valid for $self->{name}");
    } else {
      # table has changed; set timestamp high and update ExternalDependency
      $self->{timestamp} = '9999-12-12 23:59:59';

      if ($timestamp) {
	# ExternalDependency record exists; update it
	ApiCommonData::Load::TuningConfig::Log::addLog("Stored timestamp ($timestamp) no longer valid for $self->{name}");
	$sql = <<SQL;
        update apidb.ExternalDependency
        set (max_mod_date, timestamp, row_count) =
          (select '$max_mod_date', sysdate, $row_count
	  from dual)
        where name = upper('$name')
SQL
      } else {
	# no ExternalDependency record; insert one
	ApiCommonData::Load::TuningConfig::Log::addLog("No stored timestamp found for $self->{name}");
	$sql = <<SQL;
        insert into apidb.ExternalDependency (name, max_mod_date, timestamp, row_count)
        select upper('$name'), '$max_mod_date', sysdate, $row_count
	from dual
SQL
      }

      my $stmt = $dbh->prepare($sql);
      $stmt->execute()
	or ApiCommonData::Load::TuningConfig::Log::addErrorLog("\n" . $dbh->errstr . "\n");
      $stmt->finish();
    }

    return $self;
}


sub getTimestamp {
    my ($self) = @_;

    return $self->{timestamp};
}

sub getName {
    my ($self) = @_;

    return $self->{name};
}

sub exists {
    my ($self) = @_;

    return $self->{exists};
}

1;
