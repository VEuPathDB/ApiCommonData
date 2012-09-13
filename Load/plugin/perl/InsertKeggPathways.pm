package ApiCommonData::Load::Plugin::InsertKeggPathways;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use GUS::PluginMgr::Plugin;
use GUS::Supported::ParseKeggXml;
use GUS::Supported::MetabolicPathway;
use GUS::Supported::MetabolicPathways;


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
               descr          => 'The file format fpr pathways (Kegg, Biopax, Other)',
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

  my $tablesAffected = [['ApiDB.NetworkContext','One row for each new context. Added if not already existing']['ApiDB.Network', 'One Row to identify each pathway'],['ApiDB.NetworkNode', 'one row per for each Coumpound or EC Number in the KGML files'],['ApiDB.NetworkRelationship', 'One row per association bewteen nodes (Compounds/EC Numbers)'], ['ApiDB.NetworkRelationshipType','One row per type of association (if not already existing)'], ['ApiDB.NetworkRelContext','One row per association bewteen nodes (Compounds/EC Numbers) indicating direction of relationship']];

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
  die "No Kegg xml files found in the directory $inputFileDir" if not @pathwayFiles;

  &readKeggFiles(@pathwayFiles);
}

sub readKeggFiles {
  my ($self,@kgmlFiles) = @_;

  my $kgmlParser = new GUS::Supported::ParseKeggXml;
  my $pathwaysObj = new GUS::Supported::MetabolicPathways;

  foreach my $kgml (@kgmlFiles) {

    my $pathwayElements = $kgmlParser->parseKGML($kgml);
    my $pathwayObj = $pathwaysObj->getPathwayObj($pathwayElements->{NAME});
  
    foreach my $node  (keys %{$pathwayElements->{NODES}}) {
      $pathwayObj->setPathwayNode($node, { NODE_NAME => $node,
                                           NODE_TYPE => $pathwayElements->{NODES}->{$node}->{TYPE}
                                         })

      $pathwayObj->setNodeGraphics($node, { X => $pathwayElements->{NODES}->{$node}->{GRAPHICS}->{X},
                                            Y => $pathwayElements->{NODES}->{$node}->{GRAPHICS}->{Y},
                                            SHAPE => $pathwayElements->{NODES}->{$node}->{GRAPHICS}->{TYPE},
                                            HEIGHT => $pathwayElements->{NODES}->{$node}->{GRAPHICS}->{HEIGHT},
                                            WIDTH => $pathwayElements->{NODES}->{$node}->{GRAPHICS}->{WIDTH}
                                           })                                          
    }

    foreach my $reaction (keys %{$pathwayElements->{REACTIONS}}) {
    my $reactType = $pathwayElements->{REACTIONS}->$reaction->{TYPE};
    my $direction = 1;
    $direction = 0 unless ($reactType eq 'irreversible');
 
    $pathwayObj->setPathwayNodeAssociation($reaction, { SOURCE_NODE => $pathwayElements->{REACTIONS}->$reaction->{SUBSTRATE}->{NAME}, 
                                                        ASSOCIATED_NODE => $pathwayElements->{REACTIONS}->$reaction->{PRODUCT}->{NAME},
                                                        ASSOC_TYPE => "Reaction ".$reactType,
                                                        DIRECTION => $direction
                                                       })
 
    }

 
  }
}

1;
