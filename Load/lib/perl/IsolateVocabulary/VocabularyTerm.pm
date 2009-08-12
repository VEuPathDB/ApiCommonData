package ApiCommonData::Load::IsolateVocabulary::VocabularyTerm;

use strict;
use Carp;
use Data::Dumper;

sub new {
  my ($class, $original, $table, $field, $type, $value) = @_;

  my $self = bless {}, $class; 

  $self->setOriginal($original);
  $self->setType($type);
  $self->setValue($value);
  $self->setTable($table);
  $self->setField($field);

  return $self;
}

sub getTable {$_[0]->{_table}}
sub setTable {$_[0]->{_table} = $_[1]}

sub getOriginal {$_[0]->{_original}}
sub setOriginal {$_[0]->{_original} = $_[1]}

sub getField {$_[0]->{_field}}
sub setField {$_[0]->{_field} = $_[1]}

sub getValue {$_[0]->{_value}}
sub setValue {$_[0]->{_value} = $_[1]}

sub getType {$_[0]->{_type}}
sub setType {$_[0]->{_type} = $_[1]}

sub isValid {
  my ($self) = @_;

  my @validTables = ('IsolateFeature', 'IsolateSource', 'ExternalNaSequence');
  my @validFields = ('product', 'country', 'specific_host', 'isolation_source', 'source_id');
  my @validTypes = ('product', 'geographic_location', 'specific_host', 'isolation_source');

  my $value = $self->getValue();
  my $field = $self->getField();
  my $table = $self->getTable();
  my $type = $self->getType();
  my $original = $self->getOriginal();

  my $errors;

  unless($original) {
    print STDERR "Error.  No Original Provided for Node:  ";
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

  unless($self->included(\@validTypes, $type)) {
    print STDERR "Error.  Type $type is not valid for Node:  ";
    print STDERR $self->toString();
    $errors = 1;
  }

  if($errors) {
    return 0;
  }

  return 1;
}

sub toString { Dumper $_[0]}


# TODO:  Fix for new representation
#sub toXml {
#  my ($self) = @_;

#  my $value = $self->getValue();
#  my $field = $self->getField();
#  my $table = $self->getTable();

#  my $maps = $self->getMaps();

#  my @rows;
#  foreach my $row (@$maps) {
#    my $mapValue = $row->getValue();
#    my $mapTable = $row->getTable();
#    my $mapField = $row->getField();

#    push @rows, "      <row table=\"$table\" field=\"$field\" value=\"$value\" />";
#  }

#  my $rows = join("\n", @rows);

#  my $xml = <<XML;
#  <initial table="$table" field="$field" value="$value">
#    <maps>
#$rows
#    </maps>
#  </initial>
#XML

#}


sub included {
  my ($self, $a, $v) = @_;

  foreach(@$a) {
    return 1 if($_ eq $v);
  }
  return 0;
}

1;
