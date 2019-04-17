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
#		return "GUS::Supported::KEGGReader";
	 return "GUS::Supported::KEGGReaderv2";
}

sub makeGusObjects {
  my ($self) = @_;


  my $reader = $self->getReader();
  my $pathwayHash = $reader->getPathwayHash();
  print STDERR Dumper $pathwayHash;

  my $typeToTableMap = {compound => 'chEBI::Compounds', enzyme => 'SRes::EnzymeClass', reaction => 'SRes::EnzymeClass', map => 'SRes::Pathway' };
  my $typeToOntologyTerm = {compound => 'molecular entity', map => 'metabolic process', enzyme => 'enzyme', reaction => 'enzyme'};

  print STDERR "Making GUS Objects for pathway $pathwayHash->{NAME} ($pathwayHash->{SOURCE_ID} )\n";

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
    my $gusReaction = GUS::Model::ApiDB::PathwayReaction->new({source_id => $reactionSourceId});
    $gusReaction->retrieveFromDB();
    $self->addReaction($gusReaction, $reactionSourceId);
  }

  foreach my $compoundId (keys %{$pathwayHash->{EDGES}}) {
		  #print STDERR "cpd id $compoundId \n";
	my $compoundNode = $pathwayHash->{NODES}->{$compoundId};
	#print STDERR  "cpd node \n";
	#print STDERR Dumper $compoundNode; 
	my $compoundSourceId = $compoundNode->{SOURCE_ID};
	#print STDERR "cpdsrcID $compoundSourceId \n";
	my $gusCompoundNode = $self->getNodeByUniqueId($compoundId);
    foreach my $otherId (@{$pathwayHash->{EDGES}->{$compoundId}}) {
      my $otherNode = $pathwayHash->{NODES}->{$otherId};
      my $gusOtherNode = $self->getNodeByUniqueId($otherId);
      my $gusRelationship;
	  #    	print STDERR "node \n";
	  #		print STDERR Dumper $gusCompoundNode->{'display_name'};
	  # 	print STDERR "other node \n";
	  #		print STDERR Dumper $gusOtherNode->{'display_name'};
      if($otherNode->{TYPE} eq 'enzyme') {
        my $reactionId = $otherNode->{REACTION};
        $reactionId =~ s/rn\://g;
		#print STDERR "rxn id: $reactionId\n"; 
		my $reactionHash = $self->findReactionById($reactionId);


        if($reactionHash) {
          my $gusReaction = $self->getReactionByUniqueId($reactionId);

          my $isReversible;
          if($reactionHash->{TYPE} eq 'irreversible') {
            $isReversible = 0;
          }
          if($reactionHash->{TYPE} eq 'reversible') {
            $isReversible = 1;
          }

          my $compoundIsSubstrate = &existsInArrayOfHashes($compoundId, $reactionHash->{SUBSTRATES});
          my $compoundIsProduct = &existsInArrayOfHashes($compoundId, $reactionHash->{PRODUCTS});

          if($compoundIsSubstrate && $compoundIsProduct) {
				  #die "Compound $compoundSourceId cannot be a substrate and a product for reaction $reactionId";
            print STDERR "Compound $compoundSourceId cannot be a substrate and a product for reaction $reactionId";
			# ROSS : this was taken out as there is one legitimate instance in the 2019.02 data. No others were found.
			}

          unless($compoundIsSubstrate || $compoundIsProduct) {
            print STDERR "WARN:  Could not find compound $compoundId in either substrates or products for Reaction $reactionId\n";
            next;
          }
          $gusRelationship = GUS::Model::SRes::PathwayRelationship->new({relationship_type_id => $relationshipTypeId});

          if($compoundIsSubstrate) {
            $gusRelationship->setParent($gusCompoundNode, "node_id");
            print STDERR "gus cpd node:";
			$gusRelationship->setParent($gusOtherNode, "associated_node_id");
            print STDERR "gus other node:";
            $gusRelationship->setIsReversible($isReversible);
		}

          else {
            $gusRelationship->setParent($gusOtherNode, "node_id");
            $gusRelationship->setParent($gusCompoundNode, "associated_node_id");
            $gusRelationship->setIsReversible($isReversible);
          }


          my $pathwayReactionRel = GUS::Model::ApiDB::PathwayReactionRel->new();
          $pathwayReactionRel->setParent($gusReaction);
          $pathwayReactionRel->setParent($gusRelationship);
          $pathwayReactionRel->setParent($pathway);
        }
        else {
          print STDERR "WARN:  Reaction $reactionId not found in this map xml file... cannot set is_reversible for this relation\n";
          $gusRelationship = GUS::Model::SRes::PathwayRelationship->new({relationship_type_id => $relationshipTypeId});
          $gusRelationship->setParent($gusCompoundNode, "node_id");
          $gusRelationship->setParent($gusOtherNode, "associated_node_id");
        }
      }
      elsif($otherNode->{TYPE} eq 'map') {
          $gusRelationship = GUS::Model::SRes::PathwayRelationship->new({relationship_type_id => $relationshipTypeId});
          $gusRelationship->setParent($gusCompoundNode, "node_id");
          $gusRelationship->setParent($gusOtherNode, "associated_node_id");

          #TODO:  How would I ever know if this is reversible??
      }
      else {
        print  "WARN:  Edge should only be compound to X where X is either an enzyme or a map.  Found $otherNode->{TYPE}... skipping\n";
        next;
      }

      $self->addRelationship($gusRelationship);
    }
  }

}

sub existsInArrayOfHashes {
  my ($e, $ar) = @_;

  foreach(@$ar) {
    return 1 if($e == $_->{ENTRY});
  }

  return 0;
}



sub findReactionById {
  my ($self, $reactionId) = @_;

  my $reader = $self->getReader();
  my $pathwayHash = $reader->getPathwayHash();

  foreach my $reaction (values %{$pathwayHash->{REACTIONS}}) {
    return $reaction if($reaction->{SOURCE_ID} eq $reactionId);
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

