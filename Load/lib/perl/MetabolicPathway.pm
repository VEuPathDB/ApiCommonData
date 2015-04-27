package ApiCommonData::Load::MetabolicPathway;
use base qw(GUS::Supported::MetabolicPathway);

use strict;


sub new {
  my ($class, $file, $ontologyTerms, $tableIds, $rowIds) = @_;

  my $self = $class->SUPER::new($file);

  $self->setOntologyTerms($ontologyTerms);
  $self->setTableIds($tableIds);
  $self->setRowIds($rowIds);

  return $self;
}

sub setOntologyTerms {
  my ($self, $ontologyTerms) = @_;

  $self->{_ontology_terms} = $ontologyTerms;
}

sub getOntologyTerms {
  my ($self) = @_;
  return $self->{_ontology_terms};
}


sub setTableIds {
  my ($self, $tableIds) = @_;

  $self->{_table_ids} = $tableIds;
}

sub getTableIds {
  my ($self) = @_;
  return $self->{_table_ids};
}


sub setRowIds {
  my ($self, $rowIds) = @_;

  $self->{_row_ids} = $rowIds;
}

sub getRowIds {
  my ($self) = @_;
  return $self->{_row_ids};
}



sub addReaction {
  my ($self, $gusReaction, $uniqueReactionId) = @_;

  my $expected = 'GUS::Model::ApiDB::PathwayReaction';
  my $className = ref($gusReaction);
  &checkClass($className, $expected);

  $self->{_gus_reactions}->{$uniqueReactionId} = $gusReaction;
}

sub getReactionByUniqueId {
  my ($self, $uniqueId) = @_;
  return $self->{_gus_reactions}->{$uniqueId};
}

sub getReactions {
  my ($self) = @_;
  my @rv = values %{$self->{_gus_reactions}};
  return \@rv;
}



1;
