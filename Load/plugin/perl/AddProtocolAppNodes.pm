package ApiCommonData::Load::Plugin::AddProtocolAppNodes;
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | absent
  # GUS4_STATUS | RAD.Analysis                   | auto   | absent
  # GUS4_STATUS | ApiDB.Profile                  | auto   | absent
  # GUS4_STATUS | Study.Study                    | auto   | absent
  # GUS4_STATUS | Dots.Isolate                   | auto   | absent
  # GUS4_STATUS | DeprecatedTables               | auto   | absent
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

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

1;
