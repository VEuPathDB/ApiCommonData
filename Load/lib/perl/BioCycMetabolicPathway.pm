package ApiCommonData::Load::BioCycMetabolicPathway;

use base qw(ApiCommonData::Load::MetabolicPathway);

use strict;
use warnings;
use Data::Dumper;

use GUS::Model::SRes::Pathway;
use GUS::Model::SRes::PathwayNode;
use GUS::Model::SRes::PathwayRelationship;

use GUS::Model::ApiDB::PathwayReaction;
use GUS::Model::ApiDB::PathwayReactionRel;

sub getReaderClass {
  return "GUS::Supported::BioCycReader";
}

sub makeGusObjects {
    my ($self) = @_;


    my $reader = $self->getReader();
    my $pathwayHash = $reader->getPathwayHash();

    my $typeToTableMap = {compound => 'chEBI::Compounds', enzyme => 'SRes::EnzymeClass', map => 'SRes::Pathway' };
    my $typeToOntologyTerm = {compound => 'molecular entity', map => 'metabolic process', enzyme => 'enzyme'};

    print STDERR "Making GUS Objects for pathway $pathwayHash->{'Description'} ($pathwayHash->{'SourceId'} )\n";

    my $pathway = GUS::Model::SRes::Pathway->new({name => $pathwayHash->{'Description'}, 
                                               source_id => $pathwayHash->{'SourceId'},
                                               external_database_release_id => $self->getExtDbRlsId()#,
                                              # url => $pathwayHash->{URI} TODO: Make URL in reader and add
                                               });


    $self->setPathway($pathway);
    foreach my $pathwayStep (keys(%{$pathwayHash})) {
        if ($pathwayStep =~ /^BiochemicalPathwayStep/) {
            #Add reaction node
            my $reactionName = (keys(%{$pathwayHash->{$pathwayStep}->{'Reactions'}}))[0];
            my $reaction = $pathwayHash->{$pathwayStep}->{'Reactions'}->{$reactionName};
            my $type = $typeToOntologyTerm->{$reaction->{'NodeType'}};
            my $typeId = $self->mapAndCheck($type, $self->getOntologyTerms());

            my $tableName = $typeToTableMap->{$reaction->{'NodeType'}};
            my $tableId = $self->mapAndCheck($tableName, $self->getTableIds());

            my ($displayLabel, $rowId);
            if (defined ($reaction->{'ecNumber'})) {
                $displayLabel = $reaction->{'ecNumber'};
                $rowId = $self->getRowIds()->{$tableName}->{$reaction->{'ecNumber'}};
            }elsif (defined ($reaction->{'Description'})) {
                $displayLabel = $reaction->{'Description'};
            }else {
                $displayLabel = $reaction->{'SourceId'};
            }
            
            unless (defined ($rowId)) {
                print STDERR "WARN:  No EC number defined for reaction $reactionName with BioCyc source ID $reaction->{'SourceId'}\n";
                $tableId = undef;
            }

            my $gusNode = GUS::Model::SRes::PathwayNode->new(
                                                            {'display_label' => $displayLabel,
                                                             'pathway_node_type_id' => $typeId,
                                                             'table_id' => $tableId,
                                                             'row_id' => $rowId
                                                            });
            $gusNode->setParent($pathway);
            my $uniqueNodeId = $reaction->{'UniqueId'}; 
            $self->addNode($gusNode, $uniqueNodeId); 
    
            #Add reaction
            my $gusReaction = GUS::Model::ApiDB::PathwayReaction->new(
                                                                    {'source_id' => $reaction->{'SourceId'},
                                                                     'description' => $reaction->{'Description'}#,
                                                                   #  'equation' => $reaction->{'Equation'} remove for now because field not big enough
                                                                    });
            $gusReaction->retrieveFromDB();
            $self->addReaction($gusReaction, $reaction->{'UniqueId'});
        

            #Add compound nodes
            my $leftCompounds = [keys(%{$pathwayHash->{$pathwayStep}->{'Compounds'}->{'left'}})];
            foreach my $leftCompound (@{$leftCompounds}) {
                $self->makeGusCompound($leftCompound, 'left', $pathway, $pathwayHash, $pathwayStep, $typeToOntologyTerm, $typeToTableMap);
            }

            my $rightCompounds = [keys(%{$pathwayHash->{$pathwayStep}->{'Compounds'}->{'right'}})];
            foreach my $rightCompound (@{$rightCompounds}) {
                $self->makeGusCompound($rightCompound, 'right', $pathway, $pathwayHash, $pathwayStep, $typeToOntologyTerm, $typeToTableMap);
            }
        }
    }

    #Can't add edges until all nodes loaded, so loop through again
    my $relationshipTypeId = $self->getOntologyTerms()->{'metabolic process'};

    foreach my $pathwayStep (keys(%{$pathwayHash})) {
        if ($pathwayStep =~ /^BiochemicalPathwayStep/) {
            my $edges = [keys(%{$pathwayHash->{$pathwayStep}->{'Edges'}})];
            foreach my $edge (@{$edges}) {
                my $nodeId = $pathwayHash->{$pathwayStep}->{'Edges'}->{$edge}->{'Node'};
                my $associatedNodeId = $pathwayHash->{$pathwayStep}->{'Edges'}->{$edge}->{'AssociatedNode'};

                my $gusNode = $self->getNodeByUniqueId($nodeId);
                my $gusAssociatedNode = $self->getNodeByUniqueId($associatedNodeId);

                # Don't have data on whether reactions are reversible
                my $gusRelationship = GUS::Model::SRes::PathwayRelationship->new({'relationship_type_id' => $relationshipTypeId});
                $gusRelationship->setParent($gusNode, "node_id");
                $gusRelationship->setParent($gusAssociatedNode, "associated_node_id");

                #get gus reaction object for this step
                my $reaction = (keys(%{$pathwayHash->{$pathwayStep}->{'Reactions'}}))[0];
                my $reactionUniqueId = $pathwayHash->{$pathwayStep}->{'Reactions'}->{$reaction}->{'UniqueId'};
                my $gusReaction = $self->getReactionByUniqueId($reactionUniqueId); 

                my $pathwayReactionRel = GUS::Model::ApiDB::PathwayReactionRel->new();
                $pathwayReactionRel->setParent($pathway);
                $pathwayReactionRel->setParent($gusRelationship);
                $pathwayReactionRel->setParent($gusReaction);

                $self->addRelationship($gusRelationship);
            }
        }
    }
}            
    
######################Subroutines#######################

sub mapAndCheck {
  my ($self, $key, $hash) = @_;

  my $rv = $hash->{$key};

  unless($rv) {
    die "Could not determine value for term $key in hash";
  }

  return $rv;
}

sub makeGusCompound {
    my ($self, $compound, $side, $pathway, $pathwayHash, $pathwayStep, $typeToOntologyTerm, $typeToTableMap) = @_;
    my $compoundHash = $pathwayHash->{$pathwayStep}->{'Compounds'}->{$side}->{$compound};
    
    my $type = $typeToOntologyTerm->{$compoundHash->{'NodeType'}};
    my $typeId = $self->mapAndCheck($type, $self->getOntologyTerms());

    my $tableName = $typeToTableMap->{$compoundHash->{'NodeType'}};
    my $tableId = $self->mapAndCheck($tableName, $self->getTableIds());

    my ($displayLabel, $rowId);
    if (defined ($compoundHash->{'chEBI'})) {
        $displayLabel = $compoundHash->{'chEBI'};
        $rowId = $self->getRowIds()->{$tableName}->{$compoundHash->{'chEBI'}};
    }else {
        $displayLabel = $compoundHash->{'standardName'};
    }
    
    
    unless (defined ($rowId)) {
        print STDERR "WARN: No chEBI id defined for compound $compound with standardName $compoundHash->{'standardName'}\n";
        $tableId = undef;
    }

    my $gusNode = GUS::Model::SRes::PathwayNode->new(
                                                    {'display_label' => $displayLabel,
                                                     'pathway_node_type_id' => $typeId,
                                                     'table_id' => $tableId,
                                                     'row_id' => $rowId
                                                    });
    $gusNode->setParent($pathway);
    my $uniqueNodeId = $compoundHash->{'UniqueId'};
    $self->addNode($gusNode, $uniqueNodeId);
}

1;

