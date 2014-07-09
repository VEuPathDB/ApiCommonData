package ApiCommonData::Load::IsolateVocabulary::VocabularyTerm;
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | absent
  # GUS4_STATUS | RAD.Analysis                   | auto   | absent
  # GUS4_STATUS | ApiDB.Profile                  | auto   | absent
  # GUS4_STATUS | Study.Study                    | auto   | absent
  # GUS4_STATUS | Dots.Isolate                   | auto   | absent
  # GUS4_STATUS | DeprecatedTables               | auto   | absent
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

use strict;
use Carp;
use Data::Dumper;

sub new {
  my ($class, $term, $mapTerm, $table, $field, $type, $alreadyMaps) = @_;

  my $self = bless {}, $class; 

  $self->setType($type);
  $self->setTerm($term);
  $self->setMapTerm($mapTerm);
  $self->setTable($table);
  $self->setField($field);
  $self->setAlreadyMaps($alreadyMaps);

  return $self;
}

sub getMapTerm {$_[0]->{_map_term}}
sub setMapTerm {$_[0]->{_map_term} = $_[1]}

sub getTable {$_[0]->{_table}}
sub setTable {$_[0]->{_table} = $_[1]}

sub getField {$_[0]->{_field}}
sub setField {$_[0]->{_field} = $_[1]}

sub getTerm {$_[0]->{_term}}
sub setTerm {$_[0]->{_term} = $_[1]}

sub getType {$_[0]->{_type}}
sub setType {$_[0]->{_type} = $_[1]}

sub getAlreadyMaps {$_[0]->{_already_maps}}
sub setAlreadyMaps {$_[0]->{_already_maps} = $_[1]}

sub isValid {
  my ($self) = @_;

  my @validTables = ('IsolateSource', 'OntologyEntry');
  my @validFields = ('country', 'specific_host', 'isolation_source', 'source_id', 'GeographicLocation', 'Host', 'BioSourceType');
  my @validTypes = ('geographic_location', 'specific_host', 'isolation_source');

  my $term = $self->getTerm();
  my $field = $self->getField();
  my $table = $self->getTable();
  my $type = $self->getType();

  my $errors;

  unless($term) {
    print Error "No.  STDERR Term Provided for Node:  ";
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

#  my $term = $self->getTerm();
#  my $field = $self->getField();
#  my $table = $self->getTable();

#  my $maps = $self->getMaps();

#  my @rows;
#  foreach my $row (@$maps) {
#    my $mapTerm = $row->getTerm();
#    my $mapTable = $row->getTable();
#    my $mapField = $row->getField();

#    push @rows, "      <row table=\"$table\" field=\"$field\" term=\"$term\" />";
#  }

#  my $rows = join("\n", @rows);

#  my $xml = <<XML;
#  <initial table="$table" field="$field" term="$term">
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
