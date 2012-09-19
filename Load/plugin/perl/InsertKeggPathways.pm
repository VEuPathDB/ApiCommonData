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
use GUS::Model::ApiDB::Pathway;
use GUS::Model::ApiDB::PathwayNode;
use GUS::Model::ApiDB::PathwayImage;
use DBD::Oracle qw(:ora_types);


# ----------------------------------------------------------
# Load Arguments
# ----------------------------------------------------------

sub getArgsDeclaration {
  my $argsDeclaration  =
    [   
     stringArg({ name => 'pathwaysFileDir',
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

     stringArg({ name => 'imageFileDir',
                 descr => 'full path to image files',
                 constraintFunc=> undef,
                 reqd  => 0,
                 isList => 0,
                 mustExist => 0,
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

  my $inputFileDir = $self->getArg('pathwaysFileDir');
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
    $pathwayObj->{source_id} = $pathwayElements->{SOURCE_ID};
    $pathwayObj->{url} = $pathwayElements->{URI};    
    $pathwayObj->{image_file} = $pathwayElements->{IMAGE_FILE};    

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

  my $pathwaysObj = $self->{"pathwaysCollection"};

    foreach my $pathwayName (keys %{$pathwaysObj}) {
      my $pathwayObj = $pathwaysObj->{$pathwayName};


 
      my $network = GUS::Model::ApiDB::Network->new({ name => $pathwayObj->{source_id},
                                                      description => $pathwayName });
      $network->submit();
      my $networkId = $network->getNetworkId();

      my $pathway = GUS::Model::ApiDB::Pathway->new({ name => $pathwayName,
                                                      external_database_release_id => 0000,
                                                      source_id => $pathwayObj->{source_id},
                                                      url => $pathwayObj->{url} });
      $pathway->submit();
      print "loaded Network\n";
      # REVISIT EXT DB NAME - IS IT NEEDED ? NETWORK SCHEMA HAS NO EXT DB REFS;
      if ($pathwayObj->{image_file}) {
        my $imageFileDir = $self->getArg('imageFileDir');
        die "$imageFileDir directory does not exist" if !(-d $imageFileDir);
        my $imgFile = "$imageFileDir/".$pathwayObj->{image_file};
        $self->loadPathwayImage($networkId, \$imgFile);
      } 

      foreach my $reactionName (keys %{$pathwayObj->{ASSOCIATIONS}}) {
        my $reaction = $pathwayObj->{ASSOCIATIONS}->{$reactionName};
        my $rel_type = ($reaction->{ASSOC_TYPE} =~ /Reaction/) ? 1 : 2;


        my $srcNode = $pathwayObj->{NODES}->{($reaction->{SOURCE_NODE})};
        my $node_type = ($srcNode->{NODE_TYPE} eq 'enzyme') ? 1 : ($srcNode->{NODE_TYPE} eq 'compound') ? 2 : 3; 
        my $networkNode = GUS::Model::ApiDB::NetworkNode->new({ display_label => $srcNode->{NODE_NAME},
                                                                node_type_id => $node_type });
        $networkNode->submit();
        my $srcNodeId = $networkNode->getNetworkNodeId();

        my $nodeGraphics = $pathwayObj->{GRAPHICS}->{($reaction->{SOURCE_NODE})};
        my $nodeShape = ($nodeGraphics->{SHAPE} eq 'round') ? 1 :
                        ($nodeGraphics->{SHAPE} eq 'rectangle') ? 2 : 3;

        my $pathwayNode = GUS::Model::ApiDB::PathwayNode->new({display_label => $srcNode->{NODE_NAME},
                                                                pathway_node_type_id => $node_type, 
                                                                glyph_type_id => $nodeShape, 
                                                                x => $nodeGraphics->{X},
                                                                y => $nodeGraphics->{Y},
                                                                height => $nodeGraphics->{HEIGHT},
                                                                width  => $nodeGraphics->{WIDTH} });
        $pathwayNode->submit();

        print "loaded Network Node \n";



        my $asscNode = $pathwayObj->{NODES}->{($reaction->{ASSOCIATED_NODE})}; 
        $node_type = ($asscNode->{NODE_TYPE} eq 'enzyme') ? 1 : ($asscNode->{NODE_TYPE} eq 'compound') ? 2 : 3; 
        $networkNode = GUS::Model::ApiDB::NetworkNode->new({ display_label => $asscNode->{NODE_NAME},
                                                             node_type_id => $node_type });
        $networkNode->submit();
        my $asscNodeId = $networkNode->getNetworkNodeId();


        $nodeGraphics = $pathwayObj->{GRAPHICS}->{($reaction->{SOURCE_NODE})};
        $nodeShape = ($nodeGraphics->{SHAPE} eq 'round') ? 1 :
                        ($nodeGraphics->{SHAPE} eq 'rectangle') ? 2 : 3;

        $pathwayNode = GUS::Model::ApiDB::PathwayNode->new({ display_label => $asscNode->{NODE_NAME},
                                                             pathway_node_type_id => $node_type, 
                                                             glyph_type_id => $nodeShape, 
                                                             x => $nodeGraphics->{X},
                                                             y => $nodeGraphics->{Y},
                                                             height => $nodeGraphics->{HEIGHT},
                                                             width  => $nodeGraphics->{WIDTH} });
        $pathwayNode->submit();
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


       my $direction = $reaction->{DIRECTION}; 
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


sub loadPathwayImage{
  my($self,$networkId,$imgFile) = @_;
print "HERE\n$$imgFile";
  open(IMGFILE, $$imgFile)  or die "Cannot open file";
  binmode IMGFILE;

  my ($data, $buffer,$bytes);
  while (($bytes = read IMGFILE, $buffer, 500*1024) != 0) {
          $data .= $buffer;
        }
  close IMGFILE;

   my $dbh = $self->getQueryHandle();
#   my $nextvalVar = $self->getDb()->getDbPlatform()->nextVal("ApiDB.PathwayImage");
   my $userId     = $self->getDb()->getDefaultUserId();
   my $groupId    = $self->getDb()->getDefaultGroupId(); 
   my $projectId  = $self->getDb()->getDefaultProjectId();
   my $algInvId   = $self->getAlgInvocation()->getId();
   #my $pathwayImage =  GUS::Model::ApiDB::PathwayImage->new({ #pathway_id => $networkId,
   #                                                            image => $data });
   #$pathwayImage->submit(); 
   my $sql = "Insert into ApiDB.PathwayImage  (pathway_id, image) values (?,?)";
 
   my $sth = $dbh->prepare($sql);
   $sth->bind_param(2,$data,{ora_type=>SQLT_BIN});
   $sth->execute($networkId, $data);
   $dbh->commit;
   $sth->finish;
   return 1;
}

sub undoTables {
  my ($self) = @_;

  return ('ApiDB.NetworkContext',
	  'ApiDB.Network',
	  'ApiDB.NetworkNode',
	  'ApiDB.NetworkRelationship',
	  'ApiDB.NetworkRelationshipType',
	  'ApiDB.NetworkRelContext',
	  'ApiDB.Pathway',
	  'ApiDB.PathwayNode',
	  'ApiDB.PathwayImage',
	 );
}


1;
