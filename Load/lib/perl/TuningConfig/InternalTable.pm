package ApiCommonData::Load::TuningConfig::InternalTable;

use ApiCommonData::Load::TuningConfig::TableSuffix;

# @ISA = qw( ApiCommonData::Load::TuningConfig::Table );


use strict;
use Data::Dumper;

sub new {
    my ($class,
	$name,                    # name of tuning table
        $internalDependencyNames,
        $externalDependencyNames,
	$intermediateTables,
        $sqls, # reference to array of SQL statements
        $perls, $dbh, $debug)
	= @_;

    my $self = {};

    bless($self, $class);
    $self->{name} = $name;
    $self->{internalDependencyNames} = $internalDependencyNames;
    $self->{externalDependencyNames} = $externalDependencyNames;
    $self->{intermediateTables} = $intermediateTables;
    $self->{sqls} = $sqls;
    $self->{perls} = $perls;
    $self->{debug} = $debug;
    $self->{internalDependencies} = [];
    $self->{externalDependencies} = [];

    # get timestamp and definition from database
    my $sql = <<SQL;
       select to_char(timestamp, 'yyyy-mm-dd hh24:mi:ss') as timestamp, definition
       from apidb.TuningTable
       where name = '$self->{name}'
SQL

    my $stmt = $dbh->prepare($sql);
    $stmt->execute()
      or ApiCommonData::Load::TuningConfig::Log::addErrorLog("\n" . $dbh->errstr . "\n");
    my ($timestamp, $dbDef) = $stmt->fetchrow_array();
    $stmt->finish();
    $self->{timestamp} = $timestamp;
    $self->{dbDef} = $dbDef;

    return $self;
  }

sub getSqls {
  my ($self) = @_;

  return $self->{sqls};
}

sub getPerls {
  my ($self) = @_;

  return $self->{perls};
}

sub getInternalDependencyNames {
  my ($self) = @_;

  return $self->{internalDependencyNames};
}

sub getExternalDependencyNames {
  my ($self) = @_;

  return $self->{externalDependencyNames};
}

sub getInternalDependencies {
  my ($self) = @_;

  return $self->{internalDependencies};
}

sub getExternalDependencies {
  my ($self) = @_;

  return $self->{externalDependencies};
}

sub getState {
  my ($self, $doUpdate, $dbh, $purgeObsoletes) = @_;

  return $self->{state} if defined $self->{state};

  ApiCommonData::Load::TuningConfig::Log::addLog("checking $self->{name}");

  my $needUpdate;
  my $broken;

  # check if the definition is different (or none is stored)
  if (!$self->{dbDef}) {
    ApiCommonData::Load::TuningConfig::Log::addLog("    no TuningTable record exists in database for $self->{name}");
    $needUpdate = 1;
  } elsif ($self->{dbDef} ne $self->getDefString()) {
    ApiCommonData::Load::TuningConfig::Log::addLog("    stored TuningTable record differs from current definition for $self->{name}");
    $needUpdate = 1;
  }

  # check internal dependencies
  foreach my $dependency (@{$self->getInternalDependencies()}) {
    ApiCommonData::Load::TuningConfig::Log::addLog("    depends on tuning table " . $dependency->getName());

    # increase log-file indentation for recursive call
    ApiCommonData::Load::TuningConfig::Log::increaseIndent();
    my $childState = $dependency->getState($doUpdate, $dbh, $purgeObsoletes);
    ApiCommonData::Load::TuningConfig::Log::decreaseIndent();

    if ($childState eq "neededUpdate") {
      $needUpdate = 1;
    } elsif ($childState eq "broken") {
      ApiCommonData::Load::TuningConfig::Log::addLog("    $self->{name} is broken because it depends on " . $dependency->getName() . ", which is broken.");
      $broken = 1;
    }
  }

  # check external dependencies
  foreach my $dependency (@{$self->getExternalDependencies()}) {
    ApiCommonData::Load::TuningConfig::Log::addLog("    depends on external table " . $dependency->getName());
    if ($dependency->getTimestamp() gt $self->{timestamp}) {
      $needUpdate = 1;
    }
  }

  if ($doUpdate and $needUpdate) {
    my $updateResult = $self->update($dbh, $purgeObsoletes);
    $broken = 1 if $updateResult eq "broken";
  }

  ApiCommonData::Load::TuningConfig::Log::setUpdateNeededFlag()
      if $needUpdate;

  if ($broken) {
    $self->{state} = "broken";
    ApiCommonData::Load::TuningConfig::Log::setErrorsEncounteredFlag();
  } elsif ($needUpdate) {
    $self->{state} = "neededUpdate";
  } else {
    $self->{state} = "up-to-date";
  }

  ApiCommonData::Load::TuningConfig::Log::addLog("    $self->{name} found to be \"$self->{state}\"");

  return $self->{state};
}

sub update {
  my ($self, $dbh, $purgeObsoletes) = @_;

  my $startTime = time;

  ApiCommonData::Load::TuningConfig::Log::setUpdatePerformedFlag();


  my $suffix = ApiCommonData::Load::TuningConfig::TableSuffix::getSuffix($dbh);

  ApiCommonData::Load::TuningConfig::Log::addLog("    Rebuilding tuning table " . $self->{name});

  $self->dropIntermediateTables($dbh);

  my $updateError;

  foreach my $sql (@{$self->{sqls}}) {

    last if $updateError;

    my $sqlCopy = $sql;
    $sqlCopy =~ s/&1/$suffix/g;  # use suffix to make db object names unique
    ApiCommonData::Load::TuningConfig::Log::addLog("running sql of length "
						   . length($sqlCopy)
						   . " to build $self->{name}:\n$sqlCopy")
	if $self->{debug};

    my $sqlReturn = $dbh->do($sqlCopy);

    ApiCommonData::Load::TuningConfig::Log::addLog("sql returned \"$sqlReturn\"; \$dbh->errstr = \"$dbh->errstr\"")
	if $self->{debug};
    if (!defined $sqlReturn) {
      $updateError = 1;
      ApiCommonData::Load::TuningConfig::Log::addErrorLog("\n" . $dbh->errstr . "\n");
    }
  }

  foreach my $perl (@{$self->{perls}}) {
    last if $updateError;

    my $perlCopy = $perl;
    $perlCopy =~ s/&1/$suffix/g;  # use suffix to make db object names unique

    ApiCommonData::Load::TuningConfig::Log::addLog("running perl of length " . length($perlCopy) . "to build $self->{name}::\n$perlCopy")
	if $self->{debug};
    eval $perlCopy;

    if ($@) {
      $updateError = 1;
      ApiCommonData::Load::TuningConfig::Log::addErrorLog("Error \"$@\" encountered executing Perl statement:\n$perlCopy");
    }
  }

  return "broken" if $updateError;

  $self->dropIntermediateTables($dbh, 'warn on nonexistence');

  $self->publish($suffix, $dbh, $purgeObsoletes) or return "broken";

  ApiCommonData::Load::TuningConfig::Log::addLog("    " . (time - $startTime) .
						 " seconds to rebuild tuningTable " .
						 $self->{name});

  return "neededUpdate"
}

sub storeDefinition {
  my ($self, $dbh) = @_;

  my $sql = <<SQL;
       delete from apidb.TuningTable
       where name = '$self->{name}'
SQL

  my $stmt = $dbh->prepare($sql);
  $stmt->execute()
    or ApiCommonData::Load::TuningConfig::Log::addErrorLog("\n" . $dbh->errstr . "\n");
  $stmt->finish();

  my $sql = <<SQL;
       insert into apidb.TuningTable
          (name, timestamp, definition) values (?, sysdate, ?)
SQL

  my $stmt = $dbh->prepare($sql);
  $stmt->execute($self->{name}, $self->getDefString())
    or ApiCommonData::Load::TuningConfig::Log::addErrorLog("\n" . $dbh->errstr . "\n");
  $stmt->finish();
}

sub getDefString {
  my ($self) = @_;

  my $sqls = $self->getSqls();
  my $defString = join(" ", @{$sqls}) if $sqls;

  my $perls = $self->getPerls();
  $defString .= join(" ", @{$perls}) if $perls;

  return $defString;
}

sub getName {
  my ($self) = @_;

  return $self->{name};
}

sub addExternalDependency {
    my ($self, $dependency) = @_;

    push(@{$self->{externalDependencies}}, $dependency);
}

sub addInternalDependency {
    my ($self, $dependency) = @_;

    push(@{$self->{internalDependencies}}, $dependency);
}

sub hasDependencyCycle {
    my ($self, $ancestorsRef) = @_;

    my $cycleFound;

    # log error if $self is earliest ancestor
    if ($ancestorsRef->[0] eq $self->{name}) {
      ApiCommonData::Load::TuningConfig::Log::addErrorLog("ERROR: cycle of dependencies: " .
						     join(" -> ", @{$ancestorsRef}) .
						    " -> " . $self->{name});
      return 1;
    }

    # stop recursing if $self is ANY ancestor
    foreach my $ancestor (@{$ancestorsRef}) {
      return 1 if $ancestor eq $self->{name};
    }

    push(@{$ancestorsRef}, $self->{name});
    foreach my $child (@{$self->getInternalDependencies()}) {
      $cycleFound = 1
	if $child->hasDependencyCycle($ancestorsRef);
    }

    pop(@{$ancestorsRef});
    return $cycleFound;
}

sub dropIntermediateTables {
  my ($self, $dbh, $warningFlag) = @_;

  foreach my $intermediate (@{$self->{intermediateTables}}) {
    ApiCommonData::Load::TuningConfig::Log::addLog("    must drop intermediate table $intermediate->{name}");

    my $sql = <<SQL;
       drop table $intermediate->{name}
SQL

    $dbh->{PrintError} = 0;
    my $stmt = $dbh->prepare($sql);
    my $sqlReturn = $stmt->execute();
    $stmt->finish();
    $dbh->{PrintError} = 1;

    ApiCommonData::Load::TuningConfig::Log::addLog("WARNING: intermediateTable"
						   . $intermediate->{name}
						   . " was not created during the update of "
						   . $self->{name})
	if ($warningFlag and !defined $sqlReturn);
  }

}

sub publish {
  my ($self, $suffix, $dbh, $purgeObsoletes) = @_;

  # grant select privilege on new table
    my $sql = <<SQL;
      grant select on $self->{name}$suffix to gus_r
SQL

    my $stmt = $dbh->prepare($sql);
    $stmt->execute()
      or ApiCommonData::Load::TuningConfig::Log::addErrorLog("\n" . $dbh->errstr . "\n");
    $stmt->finish();

  # store definition
  $self->storeDefinition($dbh);

  # get name of old table (for subsequenct purging). . .
  my $oldTable;
  my ($schema, $table) = split(/\./, $self->{name});
  if ($purgeObsoletes) {
    my $sql = <<SQL;
      select table_owner || '.' || table_name
      from all_synonyms
      where owner = upper(?)
        and synonym_name = upper(?)
SQL

    my $stmt = $dbh->prepare($sql);
    $stmt->execute("$schema", "$table")
      or ApiCommonData::Load::TuningConfig::Log::addErrorLog("\n" . $dbh->errstr . "\n");
    ($oldTable) = $stmt->fetchrow_array();
    $stmt->finish();
  } else {
    # . . . or just mark it obsolete
    my $sql = <<SQL;
      insert into apidb.ObsoleteTuningTable (name, timestamp)
      select table_owner || '.' || table_name, sysdate
      from all_synonyms
      where owner = upper(?)
        and synonym_name = upper(?)
SQL

    my $stmt = $dbh->prepare($sql);
    $stmt->execute("$schema", "$table")
      or ApiCommonData::Load::TuningConfig::Log::addErrorLog("\n" . $dbh->errstr . "\n");
    $stmt->finish();
  }

  # update synonym
  my $sql = <<SQL;
    create or replace synonym $self->{name} for $self->{name}$suffix
SQL
  my $synonymRtn = $dbh->do($sql);

  if (!defined $synonymRtn) {
    ApiCommonData::Load::TuningConfig::Log::addErrorLog("\n" . $dbh->errstr . "\n");
  }

  # drop obsolete table, if we're doing that (and it exists)
  if (defined $synonymRtn && $purgeObsoletes && $oldTable) {
    ApiCommonData::Load::TuningConfig::Log::addLog("    purging obsolete table " . $oldTable);    
    $dbh->do("drop table " . $oldTable)
      or ApiCommonData::Load::TuningConfig::Log::addErrorLog("\n" . $dbh->errstr . "\n");
  }

  # Run stored procedure to analye any apidb tables that need it
  $dbh->do("BEGIN apidb.apidb_unanalyzed_stats; END;")
    or ApiCommonData::Load::TuningConfig::Log::addErrorLog("\n" . $dbh->errstr . "\n");

  return $synonymRtn
}

1;
