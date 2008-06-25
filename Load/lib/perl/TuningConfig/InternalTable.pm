package ApiCommonData::Load::TuningConfig::InternalTable;


# @ISA = qw( ApiCommonData::Load::TuningConfig::Table );


use strict;
use Data::Dumper;

sub new {
    my ($class,
	$name,                    # name of tuning table
        $internalDependencyNames,
        $externalDependencyNames,
        $sqls, # reference to array of SQL statements
        $perls,
        $dbh)
	= @_;

    my $self = {};

    bless($self, $class);
    $self->{name} = $name;
    $self->{internalDependencyNames} = $internalDependencyNames;
    $self->{externalDependencyNames} = $externalDependencyNames;
    $self->{sqls} = $sqls;
    $self->{perls} = $perls;
    $self->{internalDependencies} = [];
    $self->{externalDependencies} = [];

    # get timestamp and definition from database
    my $sql = <<SQL;
       select to_char(timestamp, 'yyyy-mm-dd hh24:mi:ss') as timestamp, definition
       from apidb.TuningDefinition
       where name = '$self->{name}'
SQL

    my $stmt = $dbh->prepare($sql);
    $stmt->execute()
      or ApiCommonData::Load::TuningConfig::Log::addLog("failed executing SQL statement \"$sql\"");
    my ($timestamp, $dbDef) = $stmt->fetchrow_array();
    ApiCommonData::Load::TuningConfig::Log::addLog("No TuningDefinition found for $name")
	if !$dbDef;
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

sub getState {
  my ($self, $doUpdate) = @_;

  return $self->{state} if defined $self->{state};

  my $needUpdate;
  my $broken;

  # check if the definition is different (or none is stored)
  if (!$self->{dbDef}) {
    ApiCommonData::Load::TuningConfig::Log::addLog("No TuningDefinition exists for $self->{name}");
    $needUpdate = 1;
  } elsif ($self->{dbDef} != $self->getDefString()) {
    ApiCommonData::Load::TuningConfig::Log::addLog("Stored TuningDefinition differs from current definition for $self->{name}");
    $needUpdate = 1;
  } else {
    # check internal dependencies
    foreach my $dependency (@{$self->getInternalDependencies()}) {
      my $childState = $dependency->getState($doUpdate);
      if ($childState eq "neededUpdate") {
	ApiCommonData::Load::TuningConfig::Log::addLog("$self->{name} must be updated because it depends on $dependency->getName(), which needed update.");
	$needUpdate = 1;
      } elsif ($childState eq "broken") {
	ApiCommonData::Load::TuningConfig::Log::addLog("$self->{name} is broken because it depends on $dependency->getName(), which is broken.");
	$broken = 1;
      }
    }

    # check external dependencies
    foreach my $dependency (@{$self->getExternalDependencies()}) {
      if ($dependency->getTimestamp() > $self->getTimestamp()) {
	ApiCommonData::Load::TuningConfig::Log::addLog("$self->{name} depends on $dependency->getName(), which is newer than $self->{name}.");
	$needUpdate = 1;
      }
    }
  }

  if ($doUpdate and $needUpdate) {
    my $updateResult = $self->update();
    $broken = 1 if $updateResult = "broken";
  }

  if ($broken) {
    $self->{state} = "broken";
  } elsif ($needUpdate) {
    $self->{state} = "neededUpdate";
  } else {
    $self->{state} = "up-to-date";
  }

  return $self->{state};
}

sub update {
  my ($self) = @_;

}

sub storeDefinition {
  my ($self, $dbh) = @_;

  my $sql = <<SQL;
       delete from apidb.TuningDefinition
       where name = '$self->{name}'
SQL

  my $stmt = $dbh->prepare($sql);
  $stmt->execute()
    or ApiCommonData::Load::TuningConfig::Log::addLog("failed executing SQL statement \"$sql\"");
  $stmt->finish();

  my $sql = <<SQL;
       insert into apidb.TuningDefinition
          (name, timestamp, definition) values (?, sysdate, ?)
SQL

  my $stmt = $dbh->prepare($sql);
  $stmt->execute($self->{name}, $self->getDefString())
    or ApiCommonData::Load::TuningConfig::Log::addLog("failed executing SQL statement \"$sql\"");
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

sub addExternalDependency {
    my ($self, $dependency) = @_;

    push(@{$self->{externalDependencies}}, $dependency);
}

sub addInternalDependency {
    my ($self, $dependency) = @_;

    push(@{$self->{internalDependencies}}, $dependency);
}

1;
