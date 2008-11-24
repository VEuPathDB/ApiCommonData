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

  push(@{$self->{_maps}}, @_);
}

sub isValid {
  my ($self, $isRoot) = @_;

  my @validTables = ('IsolateFeature', 'IsolateSource', 'ExternalNaSequence');
  my @validFields = ('product', 'geographic_location', 'specific_host', 'isolation_source', 'source_id');

  my $value = $self->getValue();
  my $field = $self->getField();
  my $table = $self->getTable();

  my $errors;

  unless($value) {
    print STDERR "Error.  No Value Provided for Node:  ";
    print STDERR $self->toString();
    $errors = 1;
  }
  
  unless($self->included(\@validTables, $table)) {
    print STDERR "Error.  Table $table is not valid for Node:  ";
    print STDERR $self->toString();
    $errors = 1;
  }
  
  unless($self->included(\@validFields, $field)) {
    print STDERR "Error.  Field $field is not valid for Node:  ";
    print STDERR $self->toString();
    $errors = 1;
  }

  my $maps = $self->getMaps();
  if($isRoot && ref($maps) ne 'ARRAY') {
    print STDERR "Error.  No Map found for Root Node: ";
    print STDERR $self->toString();
    $errors = 1;
  }
  elsif($isRoot) {
    foreach(@$maps) {
      unless($_->isValid()) {
        $errors = 1;
      }
    }
  }
  elsif(!$isRoot && $maps) {
    print STDERR "Error.  Maps specified for non root node:  ";
    print STDERR $self->toString();
    $errors = 1;
  }
  else {}

  if($errors) {
    return 0;
  }

  return 1;
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
