package ApiCommonData::Load::Plugin::InsertStudy;
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | absent
  # GUS4_STATUS | RAD.Analysis                   | auto   | absent
  # GUS4_STATUS | ApiDB.Profile                  | auto   | absent
  # GUS4_STATUS | Study.Study                    | auto   | broken
  # GUS4_STATUS | Dots.Isolate                   | auto   | absent
  # GUS4_STATUS | DeprecatedTables               | auto   | broken
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

@ISA = qw(GUS::PluginMgr::Plugin);

use GUS::Model::SRes::Contact;
use GUS::Model::Study::Study;

# ----------------------------------------------------------------------

use strict;
use GUS::PluginMgr::Plugin;

my $argsDeclaration =
  [

   stringArg({name           => 'name',
            descr          => 'Study Name',
            reqd           => 1,
            constraintFunc => undef,
            isList         => 0, }),

   stringArg({name           => 'extDbRlsSpec',
            descr          => 'External Database Spec for this study',
            reqd           => 1,
            constraintFunc => undef,
            isList         => 0, }),

   stringArg({name           => 'contactName',
            descr          => 'Contact Name - The plugin will try to retrieve',
            reqd           => 0,
            constraintFunc => undef,
            isList         => 0, }),
            
  ];


my $documentation = { purpose          => "",
                      purposeBrief     => "",
                      notes            => "",
                      tablesAffected   => "",
                      tablesDependedOn => "",
                      howToRestart     => "",
                      failureCases     => "" };

# ----------------------------------------------------------------------

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  $self->initialize({ requiredDbVersion => 3.6,
                      cvsRevision       => '$Revision$',
                      name              => ref($self),
                      argsDeclaration   => $argsDeclaration,
                      documentation     => $documentation});

  return $self;
}

# ======================================================================

sub run {
  my ($self) = @_;

 my $contactName = $self->getArg('contactName');
 $contactName = "Not Assigned" unless($contactName);
 
 my $contact = GUS::Model::SRes::Contact->new({name => $contactName});
 $contact->retrieveFromDB();

 my $extDbRlsSpec = $self->getArg('extDbRlsSpec');
 
 my $extDbRlsId = $self->getExtDbRlsId($extDbRlsSpec);
 
 my $studyName = $self->getArg('name');
 my $study = GUS::Model::Study::Study->new({name => $studyName, 
                                            external_database_release_id => $extDbRlsId,
                                           }); 

 unless($study->retrieveFromDB()){
	$study->setParent($contact);
	$study->submit();
	return("Loaded 1 Study.Study with name $studyName.")
 }
 return("Study.Study with name $studyName and extDbRlsSpec $extDbRlsSpec already exists. Nothing was loaded");
}
	

sub undoTables {
  my ($self) = @_;

  return ('Study.Study'
     );
}

1;
