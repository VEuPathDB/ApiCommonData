package ApiCommonData::Load::TuningConfig::ExternalTable;


# @ISA = qw( ApiCommonData::Load::TuningConfig::Table );


use strict;
use Data::Dumper;
use ApiCommonData::Load::TuningConfig::Log;
use ApiCommonData::Load::TuningConfig::Utils;

my $currentDate;

sub new {
    my ($class,
	$name,         # name of database table
        $dblink,       # dblink (if any) needed to access table
        $dbh,          # database handle
        $doUpdate,     # are we updating, not just checking, the db?
        $dblinkSuffix) # suffix (such as "build") which must be appended to dblink
	= @_;

    my $self = {};

    bless($self, $class);
    $self->{name} = $name;
    $self->{dbh} = $dbh;

    if ($dblink) {
      $dblink = '@' . $dblink . $dblinkSuffix;
    }
    $self->{dblink} = $dblink;

    my ($schema, $table) = split(/\./, $name);
    $self->{schema} = $schema;
    $self->{table} = $table;

    # check that this table exists in the database
    my $sql = <<SQL;
select count(*) from (
 select owner, table_name from all_tables$dblink
 where owner = upper('$schema') and table_name = upper('$table')
union
 select owner, view_name from all_views$dblink
 where owner = upper('$schema') and view_name = upper('$table')
union
 select owner, table_name from all_synonyms$dblink
 where owner = upper('$schema') and synonym_name = upper('$table'))
SQL
    my $stmt = $dbh->prepare($sql);
    $stmt->execute()
      or ApiCommonData::Load::TuningConfig::Log::addErrorLog("\n" . $dbh->errstr . "\n");
    my ($count) = $stmt->fetchrow_array();
    $stmt->finish();
    $self->{exists} = $count;

    ApiCommonData::Load::TuningConfig::Log::addErrorLog("$self->{name} does not exist")
	if !$count;

    $self->checkTrigger($doUpdate);

    return $self;
}


sub getTimestamp {
    my ($self) = @_;

    return $self->{timestamp} if defined $self->{timestamp};

    my $dbh = $self->{dbh};
    my $dblink = $self->{dblink};

    # get the last-modified date for this table
    my $sql = <<SQL;
       select to_char(max(modification_date), 'yyyy-mm-dd hh24:mi:ss'), count(*)
       from $self->{name}$dblink
SQL
    my $stmt = $dbh->prepare($sql)
      or ApiCommonData::Load::TuningConfig::Log::addErrorLog("\n" . $dbh->errstr . "\n");

    ApiCommonData::Load::TuningConfig::Utils::sqlBugWorkaroundExecute($dbh, $stmt)
      or ApiCommonData::Load::TuningConfig::Log::addErrorLog("\n" . $dbh->errstr . "\n");
    my ($max_mod_date, $row_count) = $stmt->fetchrow_array();
    $stmt->finish();

    # get stored ExternalDependency info for this table
    $sql = <<SQL;
       select to_char(max_mod_date, 'yyyy-mm-dd hh24:mi:ss'), row_count,
              to_char(timestamp, 'yyyy-mm-dd hh24:mi:ss')
       from apidb.TuningMgrExternalDependency$dblink
       where name = upper('$self->{name}')
SQL
    my $stmt = $dbh->prepare($sql)
      or ApiCommonData::Load::TuningConfig::Log::addErrorLog("\n" . $dbh->errstr . "\n");

    $stmt->execute()
      or ApiCommonData::Load::TuningConfig::Log::addErrorLog("\n" . $dbh->errstr . "\n");
    my ($stored_max_mod_date, $stored_row_count, $timestamp) = $stmt->fetchrow_array();
    $stmt->finish();

    my $debug = ApiCommonData::Load::TuningConfig::Log::getDebugFlag();

    # compare stored and calculated table stats
    if ($max_mod_date eq $stored_max_mod_date && $row_count == $stored_row_count) {
      # stored stats still valid
      $self->{timestamp} = $timestamp;
      ApiCommonData::Load::TuningConfig::Log::addLog("    Stored timestamp ($timestamp) still valid for $self->{name}")
	  if $debug;
    } else {
      # table has changed; tell the world, set timestamp high, and update TuningMgrExternalDependency
      if (!defined $stored_row_count) {
	ApiCommonData::Load::TuningConfig::Log::addLog("    No TuningMgrExternalDependency record for $self->{name}");
      } elsif ($row_count != $stored_row_count) {
	ApiCommonData::Load::TuningConfig::Log::addLog("    Number of rows has changed for $self->{name}");
      } elsif ($max_mod_date ne $stored_max_mod_date) {
	ApiCommonData::Load::TuningConfig::Log::addLog("    max(modification_date) has changed for $self->{name}");
      } else {
	ApiCommonData::Load::TuningConfig::Log::addErrorLog("checking state of external dependency $self->{name}");
      }
      $self->{timestamp} = $self->getCurrentDate();

      if ($timestamp) {
	# ExternalDependency record exists; update it
	ApiCommonData::Load::TuningConfig::Log::addLog("    Stored timestamp ($timestamp) no longer valid for $self->{name}");
	$sql = <<SQL;
        update apidb.TuningMgrExternalDependency$dblink
        set (max_mod_date, timestamp, row_count) =
          (select to_date('$max_mod_date', 'yyyy-mm-dd hh24:mi:ss'), sysdate, $row_count
	  from dual)
        where name = upper('$self->{name}')
SQL
      } else {
	# no ExternalDependency record; insert one
	ApiCommonData::Load::TuningConfig::Log::addLog("    No stored timestamp found for $self->{name}");
	$sql = <<SQL;
        insert into apidb.TuningMgrExternalDependency$dblink
                    (name, max_mod_date, timestamp, row_count)
        select upper('$self->{name}'), to_date('$max_mod_date', 'yyyy-mm-dd hh24:mi:ss'), sysdate, $row_count
	from dual
SQL
      }

      my $stmt = $dbh->prepare($sql)
	or ApiCommonData::Load::TuningConfig::Log::addErrorLog("\n" . $dbh->errstr . "\n");
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

sub checkTrigger {
    my ($self, $doUpdate) = @_;

    my $dbh = $self->{dbh};

    # don't mess with triggers if we're looking at a remote table
    return if $self->{dblink};

    # is this a table, a view, a materialized view, a synonym, or what?
    my $schema = $self->{schema};
    my $table = $self->{table};

    my $stmt = $dbh->prepare(<<SQL);
 select 'table' from all_tables
 where owner = upper('$schema') and table_name = upper('$table')
union
 select 'view' from all_views
 where owner = upper('$schema') and view_name = upper('$table')
union
 select 'mview' from all_mviews
 where owner = upper('$schema') and mview_name = upper('$table')
union
 select 'synonym' from all_synonyms
 where owner = upper('$schema') and synonym_name = upper('$table')
SQL
    $stmt->execute()
      or ApiCommonData::Load::TuningConfig::Log::addErrorLog("\n" . $dbh->errstr . "\n");
    my ($objectType) = $stmt->fetchrow_array();
    $stmt->finish();

    if ($objectType eq "mview" || $objectType eq "synonym") {
      ApiCommonData::Load::TuningConfig::Log::addErrorLog("unsupported object type $objectType for " . $self->{name});
      return;
    }

    # if this is a view, find the underlying table
    if ($objectType eq "view") {
      my $stmt = $dbh->prepare(<<SQL);
 select text from all_views
 where owner = upper('$schema') and view_name = upper('$table')
SQL
      $stmt->execute()
	or ApiCommonData::Load::TuningConfig::Log::addErrorLog("\n" . $dbh->errstr . "\n");
      my ($viewText) = $stmt->fetchrow_array();
      $stmt->finish();

      $viewText =~ m/[.\r\n]*\bfrom\b\s*(\S*)\.(\S*)[.\r\n]*/i;
      $schema = $1; $table = $2;
    }

    # check for a trigger
    my $stmt = $dbh->prepare(<<SQL);
 select trigger_name, trigger_body from all_triggers
 where table_owner = upper('$schema') and table_name = upper('$table')
SQL
    $stmt->execute()
      or ApiCommonData::Load::TuningConfig::Log::addErrorLog("\n" . $dbh->errstr . "\n");

    my $gotModDateTrigger;
    while (my ($triggerName, $triggerText) = $stmt->fetchrow_array()) {

      if ($triggerText =~ m/modification_date/i) {
	$gotModDateTrigger = 1;
      } else {
	ApiCommonData::Load::TuningConfig::Log::addLog("Trigger $triggerName, on $schema.$table doesn't update modification_date");
      }
    }
    $stmt->finish();

    # if it doesn't exist and -doUpdate is not set, complain
    ApiCommonData::Load::TuningConfig::Log::addLog("$table.$schema has no trigger to keep modification_date up to date.")
	if (!$gotModDateTrigger && !$doUpdate);

    # if it doesn't exist and -doUpdate is set, create it
    if (!$gotModDateTrigger && $doUpdate) {
      my $triggerName = $table . "_md_tg";
      $triggerName =~ s/[aeiou]//gi;
      ApiCommonData::Load::TuningConfig::Log::addLog("Creating trigger $triggerName to maintain modification_date column of " . $self->{name});
      my $sqlReturn = $dbh->do(<<SQL);
create or replace trigger $schema.$triggerName
before update or insert on $schema.$table
for each row
begin
  :new.modification_date := sysdate;
end;
SQL

    if (!defined $sqlReturn) {
      ApiCommonData::Load::TuningConfig::Log::addErrorLog("\n" . $dbh->errstr . "\n");
    }
    }

}

sub getCurrentDate {
    my ($self) = @_;

    return $self->{currentDate}
      if $self->{currentDate};

    my $dbh = $self->{dbh};


    my $stmt = $dbh->prepare(<<SQL);
 select to_char(sysdate, 'yyyy-mm-dd hh24:mi:ss') from dual
SQL

    $stmt->execute()
      or ApiCommonData::Load::TuningConfig::Log::addErrorLog("\n" . $dbh->errstr . "\n");
    ($self->{currentDate}) = $stmt->fetchrow_array();
    $stmt->finish();

    return $self->{currentDate};
}

1;
