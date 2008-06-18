package ApiCommonData::Load::TuningConfig::InternalTable;


# @ISA = qw( ApiCommonData::Load::TuningConfig::Table );


use strict;
use Data::Dumper;

sub new {
    my ($class,
	$name) # name of tuning table
	= @_;

    my $self = {};

    bless($self, $class);
    $self->{name} = $name;

    return $self;
}

sub addDependencyName {
    my ($self, $dependencyName) = @_;
}

sub getDependencyNames {
    my ($self) = @_;
}

sub isOutdated {
    my ($self) = @_;
}

sub definitionHasChanged {
    my ($self) = @_;
}

sub storeDefinition {
    my ($self, $definitionString) = @_;
}

1;
