package ApiCommonData::Load::OntologyDAGNode;
use parent 'Tree::DAG_Node';


sub format_node {
  my ($self, $options, $node) = @_;

  my $name = $node->{name};
  my $displayName = $node->{attributes}->{displayName};
  my $isLeaf = $node->{attributes}->{isLeaf};



  if($isLeaf) {
    return $displayName;
  }
  
  if($displayName) {
    return "$displayName ($name)";
  }

  return $name;
}


sub node2string {
  my ($self, $options, $node, $vert_dashes) = @_;

  my $keep = $node->{attributes}->{keep};
  unless($keep) {
    return undef;
  }

  return $self->SUPER::node2string($options, $node, $vert_dashes);
}

1;
