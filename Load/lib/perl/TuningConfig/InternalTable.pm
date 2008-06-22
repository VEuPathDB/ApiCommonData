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
        $perls)
	= @_;

    my $self = {};

    bless($self, $class);
    $self->{name} = $name;
    $self->{internalDependencyNames} = $internalDependencyNames;
    $self->{externalDependencyNames} = $externalDependencyNames;
    $self->{sqls} = $sqls;
    $self->{perls} = $perls;

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

sub isOutdated {
    my ($self) = @_;

    my $outdated;

    # check if the definition is different (or none is stored)
    $outdated = 1 if $self->definitionHasChanged();

    # check internal dependencies

    # check external dependencies

    return $outdated;
}

sub update {
  my ($self) = @_;
}

sub definitionHasChanged {
  my ($self, $dbh) = @_;

  # return true if definition in apidb.TuningDefinition has changed,
  # or this table has no record in apidb.TuningDefinition

  ensureDefTableExists($dbh);

  my $sql = <<SQL;
       select definition from apidb.TuningDefinition
       where name = '$self->{name}'
SQL

  my $stmt = $dbh->prepare($sql);
  $stmt->execute() or die "failed executing SQL statement \"$sql\"\n";
  my ($dbDef) = $stmt->fetchrow_array();
  $stmt->finish();

  return {$dbDef eq $self->getDefString()};

}

sub storeDefinition {
  my ($self, $dbh) = @_;

  my $sql = <<SQL;
       delete from apidb.TuningDefinition
       where name = '$self->{name}'
SQL

  my $stmt = $dbh->prepare($sql);
  $stmt->execute() or die "failed executing SQL statement \"$sql\"\n";
  $stmt->finish();

  my $sql = <<SQL;
       insert into apidb.TuningDefinition
          (name, definition) values (?, ?)
SQL

  my $stmt = $dbh->prepare($sql);
  $stmt->execute($self->{name}, $self->getDefString()) or die "failed executing SQL statement \"$sql\"\n";
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

sub ensureDefTableExists {
  my ($dbh) = @_;

  # does it exist?
  my $sql = <<SQL;
       select count(*) from all_tables
       where owner = 'APIDB' and table_name = 'TUNINGDEFINITION'
SQL
  my $stmt = $dbh->prepare($sql);
  $stmt->execute() or die "failed executing SQL statement \"$sql\"\n";
  my ($count) = $stmt->fetchrow_array();
  $stmt->finish();

  if (!$count) {
    # then create it!
    my $sql = <<SQL;
       create table apidb.TuningDefinition(
          name  varchar2(65) not null,
          definition clob not null)
SQL
    my $stmt = $dbh->prepare($sql);
    $stmt->execute() or die "failed executing SQL statement \"$sql\"\n";
    $stmt->finish();
  }
}

1;
