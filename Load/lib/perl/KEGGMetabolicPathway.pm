package ApiCommonData::Load::KEGGMetabolicPathway;
use base qw(ApiCommonData::Load::MetabolicPathway);

use strict;
use Data::Dumper;

use GUS::Model::SRes::Pathway;
use GUS::Model::SRes::PathwayNode;
use GUS::Model::SRes::PathwayRelationship;


sub getReaderClass {
  return "GUS::Supported::KEGGReader";
}

sub makeGusObjects {
  my ($self) = @_;

  my $reader = $self->getReader();
  my $pathwayHash = $reader->getPathwayHash();

  my $typeToTableMap = {compound => 'ApiDB::PubChemCompound', enzyme => 'SRes::EnzymeClass', map => 'SRes::Pathway' };
  my $typeToOntologyTerm = {compound => 'molecular entity', map => 'metabolic process', enzyme => 'enzyme'};

  my $pathway = GUS::Model::SRes::Pathway->new({name => $pathwayHash->{NAME}, 
                                               source_id => $pathwayHash->{SOURCE_ID},
                                               url => $pathwayHash->{URI}
                                               });

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
      print STDERR "WARN:  Could not find Identifier for $keggSourceId";
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
    $node->{GUS_NODE} = $gusNode->toString();
  }

#foreach reactions
# make Reaction (or lookup?)
 #lookup ec (compare to reaction id .. I think these should be the same)
 #lookup substrate and product
# direction?
# make Pathway Reactions
# make pathwayreactionrel


#foreach relation
# next unless 'maptype'
 #lookup 3 nodes
 #lookup direction (use compound Reaction)
 #make PathwayRelationship (always compound and Map?)


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

