package ApiCommonData::Load::Plugin::AddProtocolAppNodes;

@ISA = qw(GUS::Community::Plugin::AddToStudy);

use strict;
use GUS::Community::Plugin::AddToStudy;

# sub new {
#   my ($class) = @_;
#   my $self = {};
#   bless($self,$class);

#   my $documentation = &getDocumentation();
#   my $argumentDeclaration    = &getArgumentsDeclaration();

#   $self->initialize({requiredDbVersion => 4.0,
# 		     cvsRevision => '$Revision$',
# 		     name => ref($self),
# 		     revisionNotes => '',
# 		     argsDeclaration => $argumentDeclaration,
# 		     documentation => $documentation
# 		    });
#   return $self;
# }

sub handleExistingProtocolAppNode {
  my ($self,$protocolAppNode) = @_;
  my $name = $protocolAppNode->findvalue('./name');
  my $protocolAppNode = GUS::Model::Study::ProtocolAppNode->new({name => $name});
   $self->userError("Input ProtocolAppNode $name is not in the database, please make sure that all input protocoal app nodes have been loaded") unless $protocolAppNode->retrieveFromDB();
  my $id = $protocolAppNode->getId();

  return ($id);

}

sub setExtDbSpec () {
my ($self, $node) = @_;
my $extDbSpec = $node->findvalue('./external_database_release');
$extDbSpec = $node->findvalue('./ext_db_rls') unless $extDbSpec;
$extDbSpec = 'OBI|http://purl.obolibrary.org/obo/obi/2012-07-01/obi.owl' unless $extDbSpec;
 my $extDbRlsId =  $self->getExtDbRlsId($extDbSpec) ;
      if (!$extDbRlsId || !defined($extDbRlsId)) {
	$self->userError("Database is missing an entry for $extDbSpec");
	}
return $extDbRlsId;
}

1;
