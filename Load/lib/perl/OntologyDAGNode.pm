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


1;
