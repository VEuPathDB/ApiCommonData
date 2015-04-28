package ApiCommonData::Load::KEGGMetabolicPathway;
use base qw(ApiCommonData::Load::MetabolicPathway);

use strict;
use Data::Dumper;

use GUS::Model::SRes::Pathway;
use GUS::Model::SRes::PathwayNode;
use GUS::Model::SRes::PathwayRelationship;

use GUS::Model::ApiDB::PathwayReaction;
use GUS::Model::ApiDB::PathwayReactionRel;

sub getReaderClass {
  return "GUS::Supported::KEGGReader";
}

sub makeGusObjects {
  my ($self) = @_;

  print "ENTER makeGusObjects\n";

  my $reader = $self->getReader();
  my $pathwayHash = $reader->getPathwayHash();

  my $typeToTableMap = {compound => 'ApiDB::PubChemCompound', enzyme => 'SRes::EnzymeClass', map => 'SRes::Pathway' };
  my $typeToOntologyTerm = {compound => 'molecular entity', map => 'metabolic process', enzyme => 'enzyme'};

  my $pathway = GUS::Model::SRes::Pathway->new({name => $pathwayHash->{NAME}, 
                                               source_id => $pathwayHash->{SOURCE_ID},
                                                external_database_release_id => $self->getExtDbRlsId(),
                                               url => $pathwayHash->{URI}
                                               });


  $self->setPathway($pathway);

  # MAKE NODES
  foreach my $node (values %{$pathwayHash->{NODES}}) {
    my $keggType = $node->{TYPE};
    my $keggSourceId = $node->{SOURCE_ID};

    my $type = $typeToOntologyTerm->{$keggType};
    my $tableName = $typeToTableMap->{$keggType};

    next unless($type); 

    my $typeId = $self->mapAndCheck($type, $self->getOntologyTerms());
    my $tableId = $self->mapAndCheck($tableName, $self->getTableIds());
    my $rowId = $self->getRowIds()->{$tableName}->{$keggSourceId};

    unless($rowId) {
      print STDERR "WARN:  Could not find Identifier for $keggSourceId\n";
      $tableId = undef;
    }

    my $gusNode = GUS::Model::SRes::PathwayNode->new({'display_label' => $keggSourceId,
                                                   'pathway_node_type_id' => $typeId,
                                                   'x' => $node->{GRAPHICS}->{X},
                                                   'y' => $node->{GRAPHICS}->{Y},
                                                   'height' => $node->{GRAPHICS}->{HEIGHT},
                                                   'width' => $node->{GRAPHICS}->{WIDTH},
                                                   'table_id' => $tableId,
                                                   'row_id' => $rowId,
                                                  });

    $gusNode->setParent($pathway);

    my $uniqueNodeId = $node->{ENTRY_ID};
    $self->addNode($gusNode, $uniqueNodeId);
  }

  # MAKE REACTIONS AND RELATIONS
  my $relationshipTypeId = $self->getOntologyTerms()->{'metabolic process'};

  foreach my $reaction (values %{$pathwayHash->{REACTIONS}}) {
    my $reactionSourceId = $reaction->{SOURCE_ID};
    my $isReversible = lc($reaction->{TYPE}) eq 'reversible' ? 1 : 0;

    my $gusReaction = GUS::Model::ApiDB::PathwayReaction->new({source_id => $reactionSourceId});
    $self->addReaction($gusReaction, $reactionSourceId);

    foreach my $enzymeId (@{$reaction->{ENZYMES}}) {
      my $enzymeNode = $self->getNodeByUniqueId($enzymeId);

      foreach my $substrateHash(@{$reaction->{SUBSTRATES}}) {
        my $substrateId = $substrateHash->{ENTRY};
        my $substrateEnzymeRelation = GUS::Model::SRes::PathwayRelationship->new({relationship_type_id => $relationshipTypeId,
                                                              is_reversible => $isReversible});

        my $substrateNode = $self->getNodeByUniqueId($substrateId);

        $substrateEnzymeRelation->setParent($substrateNode, "node_id");
        $substrateEnzymeRelation->setParent($enzymeNode, "associated_node_id");

        my $pathwayReactionRel = GUS::Model::ApiDB::PathwayReactionRel->new();
        $pathwayReactionRel->setParent($gusReaction);
        $pathwayReactionRel->setParent($substrateEnzymeRelation);

        $self->addRelationship($substrateEnzymeRelation);
      }

      foreach my $productHash (@{$reaction->{PRODUCTS}}) {
        my $productId = $productHash->{ENTRY};
        my $enzymeProductRelation = GUS::Model::SRes::PathwayRelationship->new({relationship_type_id => $relationshipTypeId,
                                                                                    is_reversible => $isReversible});

        my $productNode = $self->getNodeByUniqueId($productId);

        $enzymeProductRelation->setParent($enzymeNode, "node_id");
        $enzymeProductRelation->setParent($productNode, "associated_node_id");

        my $pathwayReactionRel = GUS::Model::ApiDB::PathwayReactionRel->new();
        $pathwayReactionRel->setParent($gusReaction);
        $pathwayReactionRel->setParent($enzymeProductRelation);

        $self->addRelationship($enzymeProductRelation);
      }
    }
  }


  # MAKE MAP RELATIONS
  foreach my $relation (values %{$pathwayHash->{RELATIONS}->{Maplink}}) {

    my $ae = $relation->{ASSOCIATED_ENTRY};
    my $aeType = $pathwayHash->{NODES}->{$ae}->{TYPE};

    my $e = $relation->{ENTRY};
    my $eType = $pathwayHash->{NODES}->{$e}->{TYPE};

    my $ie = $relation->{INTERACTION_ENTITY_ENTRY};
    my $ieType = $pathwayHash->{NODES}->{$ie}->{TYPE};


    my $simpleRelation = {$ieType => $ie,
    $eType => $e,
    $aeType => $ae
    };

    my $enzymeId = $simpleRelation->{enzyme};
    my $reaction = $pathwayHash->{REACTIONS}->{$enzymeId};
    my $reactionType = $reaction->{TYPE};
    my $isReversible = $reactionType eq 'reversible' ? 1 : 0;    

    my @foundList;
    foreach my $found (("SUBSTRATES", "PRODUCTS")) {
      foreach my $hash (@{$reaction->{$found}}) {
        push @foundList, $found if($hash->{ENTRY} eq $simpleRelation->{compound});
      }
    }
    unless(scalar @foundList == 1) {
      die "Found Compound $simpleRelation->{compound} more than once for reaction $reaction->{SOURCE_ID}";
    }

    my $compoundNode = $self->getNodeByUniqueId($simpleRelation->{compound});
    my $mapNode = $self->getNodeByUniqueId($simpleRelation->{map});

    my $mapRelation = GUS::Model::SRes::PathwayRelationship->new({relationship_type_id => $relationshipTypeId,
                                                                                    is_reversible => $isReversible});

    # compound is a substrate. map is input
    if($foundList[0] eq "SUBSTRATES") {
        $mapRelation->setParent($mapNode, "node_id");
        $mapRelation->setParent($compoundNode, "associated_node_id");
    }

    # compound is a product. map is output
    if($foundList[0] eq "PRODUCTS") {
        $mapRelation->setParent($compoundNode, "node_id");
        $mapRelation->setParent($mapNode, "associated_node_id");
    }
  }
}

sub mapAndCheck {
  my ($self, $key, $hash) = @_;

  my $rv = $hash->{$key};

  unless($rv) {
    die "Could not determine value for term $key in hash";
  }

  return $rv;
}

1;

