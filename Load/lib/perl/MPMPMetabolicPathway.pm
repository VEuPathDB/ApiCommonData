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

    my $typeToTableMap = {molecularentity => 'chEBI::Compounds', compound => 'chEBI::Compounds', enzyme => 'SRes::EnzymeClass',  transporter => 'SRes::EnzymeClass', gene => 'DoTS::GeneFeature',
                          translocator => 'SRes::EnzymeClass', protein => 'SRes::EnzymeClass', compartment => 'SRes::Pathway', location => 'SRes::Pathway', pathway => 'SRes::Pathway' };
    my $typeToOntologyTerm = {molecularentity => 'molecular entity', compound => 'molecular entity', pathway => 'metabolic process', compartment => 'metabolic process', 
                              location => 'metabolic process', enzyme => 'enzyme', protein => 'enzyme', transporter => 'enzyme', translocator => 'enzyme', gene => 'gene'};


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
            my $type = $typeToOntologyTerm->{lc($nodeData->{'node_type'})};
            my $typeId = $self->mapAndCheck($type, $self->getOntologyTerms());
            my $tableName = $typeToTableMap->{lc($nodeData->{'node_type'})};
            my $tableId = $self->mapAndCheck($tableName, $self->getTableIds());
            my $rowId = $self->getRowIds()->{$tableName}->{$nodeData->{'node_identifier'}};
            
            # handle entities acting as small molecules that have gene ids (e.g, tRNAs)
            unless (defined($rowId)) {
                if ($type eq 'molecular entity') {
                    $tableName = $typeToTableMap->{'gene'};
                    $tableId = $self->mapAndCheck($tableName, $self->getTableIds());
                    $rowId = $self->getRowIds()->{$tableName}->{$nodeData->{'node_identifier'}};
                }
            }

            unless (defined($rowId)) {
                $tableId = undef;
            }

            my $x = defined ($nodeData->{'x'}) ? $nodeData->{'x'} : $node->{'position'}->{'x'};
            my $y = defined ($nodeData->{'y'}) ? $nodeData->{'y'} : $node->{'position'}->{'y'};
            my $gusNode = GUS::Model::SRes::PathwayNode->new({'display_label' => $nodeData->{'display_label'},
                                                              'pathway_node_type_id' => $typeId,
                                                              'table_id' => $tableId,
                                                              'row_id' => $rowId,
                                                              'x' => $x,
                                                              'y' => $y,
                                                            });
            if (defined($nodeData->{'cellular_location'})) {
                $gusNode->setCellularLocation($nodeData->{'cellular_location'});
            }
            $gusNode->setParent($gusPathway);
            my $uniqueId = $nodeData->{'id'};
            $self->addNode($gusNode, $uniqueId); 

            if ($type eq 'enzyme' || $type eq 'metabolic process' || $type eq 'gene') {
                my $gusReaction = GUS::Model::ApiDB::PathwayReaction->new();
                if ($nodeData->{'reaction_source_id'} ne 'null') {
                    $gusReaction->setSourceId($nodeData->{'reaction_source_id'});
                    $gusReaction->retrieveFromDB();
                    $self->addReaction($gusReaction, $uniqueId);
                }else {
                    $gusReaction->setSourceId('MPMP_'.$pathwaySourceId.'_'.$uniqueId);
                    $gusReaction->retrieveFromDB();
                    $self->addReaction($gusReaction, $uniqueId);
                    
                }
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

        ###handle spontaneous compound-compound conversions (edges with no enzyme)
        unless (defined($gusReaction)) {
            my $node = $self->getNodeByUniqueId($nodeUniqueId);
            my $associatedNode = $self->getNodeByUniqueId($associatedNodeUniqueId);
            $gusReaction = GUS::Model::ApiDB::PathwayReaction->new();
            $gusReaction->setSourceId('MPMP_'.$pathwaySourceId.'_'.$nodeUniqueId.'_'.$associatedNodeUniqueId);
            $gusReaction->retrieveFromDB();
        }

        die("Could not find GUS reaction\n") unless defined($gusReaction);

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

