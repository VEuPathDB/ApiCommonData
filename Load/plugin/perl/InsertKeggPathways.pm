package ApiCommonData::Load::Plugin::InsertKeggPathways;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use Data::Dumper;
use GUS::PluginMgr::Plugin;
use GUS::Supported::ParseKeggXml;
use GUS::Supported::MetabolicPathway;
use GUS::Supported::MetabolicPathways;
use GUS::Model::ApiDB::NetworkContext;
use GUS::Model::ApiDB::Network;
use GUS::Model::ApiDB::NetworkNode;
use GUS::Model::ApiDB::NetworkRelationship;
use GUS::Model::ApiDB::NetworkRelationshipType;
use GUS::Model::ApiDB::NetworkRelContext;

# ----------------------------------------------------------
# Load Arguments
# ----------------------------------------------------------

sub getArgsDeclaration {
  my $argsDeclaration  =
    [   
     stringArg({ name => 'fileDir',
                 descr => 'full path to xml files',
                 constraintFunc=> undef,
                 reqd  => 1,
                 isList => 0,
                 mustExist => 1,
	       }),

     enumArg({ name           => 'format',
               descr          => 'The file format for pathways (Kegg, Biopax, Other)',
               constraintFunc => undef,
               reqd           => 1,
               isList         => 0,
               enum           => 'KEGG, Biopax, Other'
	    }),
    ];

  return $argsDeclaration;
}

# ----------------------------------------------------------------------
# Documentation
# ----------------------------------------------------------------------

sub getDocumentation {
  my $purposeBrief = "Inserts KEGG pathways from a set of KGML files into Network schema.";

  my $purpose =  "Inserts KEGG pathways from a set of KGML files into Network schema.";

  my $tablesAffected = [['ApiDB.NetworkContext','One row for each new context. Added if not already existing'],['ApiDB.Network', 'One Row to identify each pathway'],['ApiDB.NetworkNode', 'one row per for each Coumpound or EC Number in the KGML files'],['ApiDB.NetworkRelationship', 'One row per association bewteen nodes (Compounds/EC Numbers)'], ['ApiDB.NetworkRelationshipType','One row per type of association (if not already existing)'], ['ApiDB.NetworkRelContext','One row per association bewteen nodes (Compounds/EC Numbers) indicating direction of relationship']];

  my $tablesDependedOn = [['Core.TableInfo',  'To store a reference to tables that have Node records (ex. EC Numbers, Coumpound IDs']];

  my $howToRestart = "No restart";

  my $failureCases = "";

  my $notes = "";

  my $documentation = {purpose=>$purpose, purposeBrief=>$purposeBrief, tablesAffected=>$tablesAffected, tablesDependedOn=>$tablesDependedOn, howToRestart=>$howToRestart, failureCases=>$failureCases,notes=>$notes};

  return $documentation;
}

#--------------------------------------------------------------------------------

sub new {
  my $class = shift;
  my $self = {};
  bless($self, $class);

  my $documentation = &getDocumentation();

  my $args = &getArgsDeclaration();

  my $configuration = { requiredDbVersion => 3.6,
                        cvsRevision => '$Revision$',
                        name => ref($self),
                        argsDeclaration => $args,
                        documentation => $documentation
                      };

  $self->initialize($configuration);

  return $self;
}


#######################################################################
# Main Routine
#######################################################################

sub run {
  my ($self) = shift;

  my $inputFileDir = $self->getArg('fileDir');
  die "$inputFileDir directory does not exist" if !(-d $inputFileDir); 

  my @pathwayFiles = <$inputFileDir/*.xml>;
  die "No files found in the directory $inputFileDir" if not @pathwayFiles;

  my $pathwaysObj = new GUS::Supported::MetabolicPathways;
  $self->{"pathwaysCollection"} = $pathwaysObj;

  $self->readKeggFiles(\@pathwayFiles);
  $self->loadPathway();
}



sub readKeggFiles {
  my ($self, $kgmlFiles) = @_;

  my $kgmlParser = new GUS::Supported::ParseKeggXml;

  my $pathwaysObj = $self->{pathwaysCollection};

  foreach my $kgml (@{$kgmlFiles}) {

    my $pathwayElements = $kgmlParser->parseKGML($kgml);
    my $pathwayObj = $pathwaysObj->getNewPathwayObj($pathwayElements->{NAME});
  
    foreach my $node  (keys %{$pathwayElements->{NODES}}) {
      $pathwayObj->setPathwayNode($node, { NODE_NAME => $node,
                                           NODE_TYPE => $pathwayElements->{NODES}->{$node}->{TYPE}
                                         });

      $pathwayObj->setNodeGraphics($node, { X => $pathwayElements->{NODES}->{$node}->{GRAPHICS}->{X},
                                            Y => $pathwayElements->{NODES}->{$node}->{GRAPHICS}->{Y},
                                            SHAPE => $pathwayElements->{NODES}->{$node}->{GRAPHICS}->{TYPE},
                                            HEIGHT => $pathwayElements->{NODES}->{$node}->{GRAPHICS}->{HEIGHT},
                                            WIDTH => $pathwayElements->{NODES}->{$node}->{GRAPHICS}->{WIDTH}
                                           }); 
    }

    foreach my $reaction (keys %{$pathwayElements->{REACTIONS}}) {
    my $reactType = $pathwayElements->{REACTIONS}->{$reaction}->{TYPE};
    my $direction = 1;
    $direction = 0 unless ($reactType eq 'irreversible');
 
    $pathwayObj->setPathwayNodeAssociation($reaction, { SOURCE_NODE => $pathwayElements->{REACTIONS}->{$reaction}->{SUBSTRATE}->{NAME}, 
                                                        ASSOCIATED_NODE => $pathwayElements->{REACTIONS}->{$reaction}->{PRODUCT}->{NAME},
                                                        ASSOC_TYPE => "Reaction ".$reactType,
                                                        DIRECTION => $direction
                                                       });
 

    }

    $pathwaysObj->setPathwayObj($pathwayObj);
  }
  $self->{"pathwaysCollection"} = $pathwaysObj;
}



sub loadPathway {
  my ($self) = @_;

  my $format = $self->getArg('format');
  my $networkContext = GUS::Model::ApiDB::NetworkContext->new({ name => 'Metabolic Pathways - $format',
                                                                description => 'Metabolic Pathways and Associations - $format'
                                                                });
  $networkContext->submit();
  my $networkContextId = $networkContext->getNetworkContextId();
  print "loaded Context\n";

  my $pathwaysObj = $self->{"pathwaysCollection"};

    foreach my $pathwayName (keys %{$pathwaysObj}) {
      my $pathwayObj = $pathwaysObj->{$pathwayName};

      my $network = GUS::Model::ApiDB::Network->new({ name => $pathwayName,
                                                      description => $pathwayObj->{DESCRIPTION} });
      $network->submit();
      my $networkId = $network->getNetworkId();
      print "loaded Network\n";

      foreach my $reactionName (keys %{$pathwayObj->{ASSOCIATIONS}}) {
        my $reaction = $pathwayObj->{ASSOCIATIONS}->{$reactionName};
        my $rel_type = ($reaction->{ASSOC_TYPE} =~ /Reaction/) ? 1 : 2;


        my $srcNode = $pathwayObj->{NODES}->{($reaction->{SOURCE_NODE})};
        my $node_type = ($srcNode->{NODE_TYPE} eq 'enzyme') ? 1 : ($srcNode->{NODE_TYPE} eq 'compound') ? 2 : 3; 
        my $networkNode = GUS::Model::ApiDB::NetworkNode->new({ display_label => $srcNode->{NODE_NAME},
                                                                node_type_id => $node_type });
        $networkNode->submit();
        my $srcNodeId = $networkNode->getNetworkNodeId();
        print "loaded Network Node \n";



        my $asscNode = $pathwayObj->{NODES}->{($reaction->{ASSOCIATED_NODE})}; 
        $node_type = ($asscNode->{NODE_TYPE} eq 'enzyme') ? 1 : ($asscNode->{NODE_TYPE} eq 'compound') ? 2 : 3; 
        $networkNode = GUS::Model::ApiDB::NetworkNode->new({ display_label => $asscNode->{NODE_NAME},
                                                             node_type_id => $node_type });
        $networkNode->submit();
        my $asscNodeId = $networkNode->getNetworkNodeId();
        print "loaded Network Node \n";

  
  
        my $relationship = GUS::Model::ApiDB::NetworkRelationship->new({ node_id => $srcNodeId,
                                                                         associated_node_id => $asscNodeId });
        $relationship->submit();
        my $relId = $relationship->getNetworkRelationshipId();
        print "loaded Network Relationship \n";


       my $relType = GUS::Model::ApiDB::NetworkRelationshipType->new({ relationship_type_id => $rel_type,
                                                                       display_name => $reactionName });
       $relType->submit();
       my $relTypeId = $relType->getNetworkRelationshipTypeId();
        print "loaded Network Relationship Type\n";


       my $direction = ($reaction->{ASSOC_TYPE} =~ /irreversible/) ? 1 : 0; 
       my $relContext = GUS::Model::ApiDB::NetworkRelContext->new({ network_relationship_id => $relId, 
                                                                    network_relationship_type_id => $relTypeId,
                                                                    network_context_id => $networkContextId,
                                                                    source_node => $direction }); 
       $relContext->submit();
       print "loaded Network Relationship Context\n";
      }

        #---------------
        #For Future TO DO
        #Cross Ref Enzymes and compounds. A new DBXref for pathway Enzymes and Compounds weill have to be created.
        #the foriegn key constraint in the schema will the be enforced for table_id and row_id
        #my ($table_id, $row_id);
        #if ($node->{NODE_TYPE} eq 'enzyme') {
          #my ($tableId) = $self->sqlAsArray( Sql => "select table_id from core.tableinfo where name = 'EnzymeClass'" );
         # my ($row_id)  = $self->sqlAsArray( Sql => "select row_id from sres.enzymeclass where ec_number = $node->{NODE_NAME}" );
        #} elsif ($node->{NODE_TYPE} eq 'compound') {
         # my ($tableId) = $self->sqlAsArray( Sql => "select table_id from core.tableinfo where name = ''" );
         # my ($row_id)  = $self->sqlAsArray( Sql => "select row_id from sres.enzymeclass where ec_number = $node->{NODE_NAME}" );
       # }
        #---------------
print "loaded all relationships\n";     

  }
print "loaded pathway\n";
}

sub undoTables {
  my ($self) = @_;

  return ('ApiDB.NetworkContext',
	  'ApiDB.Network',
	  'ApiDB.NetworkNode',
	  'ApiDB.NetworkRelationship',
	  'ApiDB.NetworkRelationshipType',
	  'ApiDB.NetworkRelContext',
	 );
}


1;
