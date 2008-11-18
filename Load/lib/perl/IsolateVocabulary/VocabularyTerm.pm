package ApiCommonData::Load::IsolateVocabulary::VocabularyTerm;

use strict;
use Carp;
use Data::Dumper;

sub new {
  my ($class, $value, $table, $field) = @_;

  my $self = bless {}, $class; 

  $self->setValue($value);
  $self->setTable($table);
  $self->setField($field);

  return $self;
}

sub getTable {$_[0]->{_table}}
sub setTable {$_[0]->{_table} = $_[1]}

sub getField {$_[0]->{_field}}
sub setField {$_[0]->{_field} = $_[1]}

sub getValue {$_[0]->{_value}}
sub setValue {$_[0]->{_value} = $_[1]}

sub getMaps {$_[0]->{_maps}}

sub addMaps {
  my $self = shift;

  push(@{$self->{maps}}, @_);
}

sub isValid {
  my ($self, $isRoot) = @_;

  my @validTables = ('IsolateFeature', 'IsolateSource');
  my @validFields = ('product', 'country', 'specific_host', 'isolation_source');

  my $value = $self->getValue();
  my $field = $self->getField();
  my $table = $self->getTable();

  unless($value) {
    print STDERR "Error.  No Value Provided for Node:  ";
    print STDERR $self->toString();
  }
  
  unless($self->included(\@validTables, $table)) {
    print STDERR "Error.  Table $table is not valid for Node:  ";
    print STDERR $self->toString();
  }
  
  unless($self->included(\@validFields, $field)) {
    print STDERR "Error.  Field $field is not valid for Node:  ";
    print STDERR $self->toString();
  }

  my $maps = $self->getMaps();
  if($isRoot && ref($maps) ne 'ARRAY') {
    print STDERR "Error.  No Map found for Root Node: ";
    print STDERR $self->toString();
  }
  elsif($isRoot) {
    foreach(@$maps) {
      $self->isValid();
    }
  }
  elsif(!$isRoot && $maps) {
    print STDERR "Error.  Maps specified for non root node:  ";
    print STDERR $self->toString();
  }
  else {}

}

sub toString { Dumper $_[0]}

sub toXml {
  my ($self) = @_;

  my $value = $self->getValue();
  my $field = $self->getField();
  my $table = $self->getTable();

  my $maps = $self->getMaps();

  my @rows;
  foreach my $row (@$maps) {
    my $mapValue = $row->getValue();
    my $mapTable = $row->getTable();
    my $mapField = $row->getField();

    push @rows, "      <row table=\"$table\" field=\"$field\" value=\"$value\" />";
  }

  my $rows = join("\n", @rows);

  my $xml = <<XML;
  <initial table="$table" field="$field" value="$value">
    <maps>
$rows
    </maps>
  </initial>
XML

}


sub included {
  my ($self, $a, $v) = @_;

  foreach(@$a) {
    return 1 if($_ eq $v);
  }
  return 0;
}

1;
