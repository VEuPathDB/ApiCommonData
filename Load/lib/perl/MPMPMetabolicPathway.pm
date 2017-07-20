package ApiCommonData::Load::MPMPMetabolicPathway;
use lib "$ENV{GUS_HOME}/lib/perl";
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
  return "GUS::Supported::MPMPReader";
}

sub makeGusObjects {
    my ($self) = @_;


    my $reader = $self->getReader();
    my $pathwayHash = $reader->getPathwayHash();

    my $verbose = $self->getVerbose();
    if ($verbose) {
        print Dumper ($pathwayHash);
    }

    my $typeToTableMap = {molecularentity => 'chEBI::Compounds', compound => 'chEBI::Compounds', enzyme => 'SRes::EnzymeClass', pathway => 'SRes::Pathway' };
    my $typeToOntologyTerm = {molecularentity => 'molecular entity', compound => 'molecular entity', pathway => 'metabolic process', enzyme => 'enzyme'};


    my $pathway = $pathwayHash->{'data'};

    my $pathwaySourceId = $pathway->{'source_id'};
    print STDERR "Making GUS Objects for pathway $pathwaySourceId\n";
    my $url = "http://mpmp.huji.ac.il/maps/$pathwaySourceId.html";
    my $extDbRlsId = $self->getExtDbRlsId();

    my $gusPathway = GUS::Model::SRes::Pathway->new({'name' => $pathway->{'name'},
                                                     'source_id' => $pathwaySourceId,
                                                     'external_database_release_id' => $extDbRlsId,
                                                     'url' => $url,
                                                   });
    $self->setPathway($gusPathway);

    foreach my $node (@{$pathwayHash->{'elements'}->{'nodes'}}) {
        my $nodeData = $node->{'data'};
        unless ($nodeData->{'node_type'} eq 'pathway_internal') {
            my $type = $typeToOntologyTerm->{$nodeData->{'node_type'}};
            my $typeId = $self->mapAndCheck($type, $self->getOntologyTerms());
            my $tableName = $typeToTableMap->{$nodeData->{'node_type'}};
            my $tableId = $self->mapAndCheck($tableName, $self->getTableIds());
            my $rowId = $self->getRowIds()->{$tableName}->{$nodeData->{'node_identifier'}};
            unless (defined($rowId)) {
                $tableId = undef;
            }
            my $gusNode = GUS::Model::SRes::PathwayNode->new({'display_label' => $nodeData->{'display_label'},
                                                              'pathway_node_type_id' => $typeId,
                                                              'table_id' => $tableId,
                                                              'row_id' => $rowId,
                                                              'x' => $nodeData->{'x'},
                                                              'y' => $nodeData->{'y'},
                                                            });
            if (defined($nodeData->{'cellular_location'})) {
                $gusNode->{'cellular_location'} = $nodeData->{'cellular_location'};
            }
            $gusNode->setParent($gusPathway);
            my $uniqueId = $nodeData->{'id'};
            $self->addNode($gusNode, $uniqueId); 

            if ($nodeData->{'node_type'} eq 'enzyme') {
                my $gusReaction = GUS::Model::ApiDB::PathwayReaction->new({
                                                                            'source_id' => $nodeData->{'reaction_source_id'}
                                                                         });                
                $self->addReaction($gusReaction, $uniqueId);
            }
        }
    }        
    
    foreach my $edge (@{$pathwayHash->{'elements'}->{'edges'}}) {
        my $edgeData = $edge->{'data'};
        my $nodeUniqueId = $edgeData->{'source'};
        my $associatedNodeUniqueId = $edgeData->{'target'};
        my $gusNode = $self->getNodeByUniqueId($nodeUniqueId);
        my $gusAssociatedNode = $self->getNodeByUniqueId($associatedNodeUniqueId); 
        my $gusRelationship = GUS::Model::SRes::PathwayRelationship->new({'relationship_type_id' => $self->getOntologyTerms()->{'metabolic process'},
                                                                          'is_reversible' => $edgeData->{'is_reversible'},
                                                                        });
        $gusRelationship->setParent($gusNode, "node_id");                                                                                                                                           
        $gusRelationship->setParent($gusAssociatedNode, "associated_node_id");

        my $gusReaction = defined($self->getReactionByUniqueId($nodeUniqueId)) ? $self->getReactionByUniqueId($nodeUniqueId) : $self->getReactionByUniqueId($associatedNodeUniqueId);

        my $pathwayReactionRel = GUS::Model::ApiDB::PathwayReactionRel->new();

        $pathwayReactionRel->setParent($gusPathway);                                                                                                                                                   
        $pathwayReactionRel->setParent($gusRelationship);
        $pathwayReactionRel->setParent($gusReaction);

        $self->addRelationship($gusRelationship);

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


1;

