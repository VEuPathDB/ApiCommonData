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
    $self->{dbh} = $dbh;

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

    return $self;
}


sub getTimestamp {
    my ($self) = @_;

    return $self->{timestamp} if defined $self->{timestamp};

    my $dbh = $self->{dbh};

    # get the last-modified date for this table
    my $sql = <<SQL;
       select to_char(max(modification_date), 'yyyy-mm-dd hh24:mi:ss'), count(*)
       from $self->{name}
SQL
    my $stmt = $dbh->prepare($sql);
    $stmt->execute()
      or ApiCommonData::Load::TuningConfig::Log::addErrorLog("\n" . $dbh->errstr . "\n");
    my ($max_mod_date, $row_count) = $stmt->fetchrow_array();
    $stmt->finish();

    # get stored ExternalDependency info for this table
    $sql = <<SQL;
       select to_char(max_mod_date, 'yyyy-mm-dd hh24:mi:ss'), row_count,
              to_char(timestamp, 'yyyy-mm-dd hh24:mi:ss')
       from apidb.TuningMgrExternalDependency
       where name = upper('$self->{name}')
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
      ApiCommonData::Load::TuningConfig::Log::addLog("    Stored timestamp ($timestamp) still valid for $self->{name}");
    } else {
      # table has changed; set timestamp high and update TuningMgrExternalDependency
      $self->{timestamp} = '9999-12-12 23:59:59';

      if ($timestamp) {
	# ExternalDependency record exists; update it
	ApiCommonData::Load::TuningConfig::Log::addLog("    Stored timestamp ($timestamp) no longer valid for $self->{name}");
	$sql = <<SQL;
        update apidb.TuningMgrExternalDependency
        set (max_mod_date, timestamp, row_count) =
          (select to_date('$max_mod_date', 'yyyy-mm-dd hh24:mi:ss'), sysdate, $row_count
	  from dual)
        where name = upper('$self->{name}')
SQL
      } else {
	# no ExternalDependency record; insert one
	ApiCommonData::Load::TuningConfig::Log::addLog(    "No stored timestamp found for $self->{name}");
	$sql = <<SQL;
        insert into apidb.TuningMgrExternalDependency (name, max_mod_date, timestamp, row_count)
        select upper('$self->{name}'), to_date('$max_mod_date', 'yyyy-mm-dd hh24:mi:ss'), sysdate, $row_count
	from dual
SQL
      }

      my $stmt = $dbh->prepare($sql);
      $stmt->execute()
	or ApiCommonData::Load::TuningConfig::Log::addErrorLog("\n" . $dbh->errstr . "\n");
      $stmt->finish();
    }

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
