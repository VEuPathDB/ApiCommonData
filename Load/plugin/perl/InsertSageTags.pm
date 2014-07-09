package ApiCommonData::Load::Plugin::InsertSageTags;
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | broken
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

@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use GUS::PluginMgr::Plugin;
use GUS::Model::RAD::ArrayDesign;
use GUS::Model::RAD::SAGETag;
use GUS::Model::SRes::ExternalDatabaseRelease;
sub getArgumentsDeclaration{
	my $argsDeclaration =
	[
         stringArg({name => 'arrayName',
                    descr => 'Name for RAD.arrayDesign',
                    constraintFunc=> undef,
                    reqd  => 1,
                    isList => 0
                   }),

         stringArg({name => 'externalDatabaseSpec',
                    descr => 'External database of the profile sets'.
                    '(name|version format)',
                    constraintFunc=> undef,
                    reqd  => 1,
                    isList => 0
                   }),

         fileArg({name=>'sageTagFile',
                  descr => 'Raw sequence file containing Sage Tags',
                  constraintFunc=> undef,
                  reqd =>1,
                  isList => 0,
                  mustExist => 1,
                  format=>'Text'
                 }),

	];
}
# ----------------------------------------------------------------------
# Documentation
# ----------------------------------------------------------------------

sub getDocumentation {
  my $purpose = <<PURPOSE;
Plugin that inserts SAGETags into RAD.Array Design Table.
PURPOSE

  my $purposeBrief = <<PURPOSE_BRIEF;
Plugin to insert SAGETags
PURPOSE_BRIEF

  my $notes = <<NOTES;

NOTES

  my $tablesAffected = <<TABLES_AFFECTED;
GUS::Model::RAD::ArrayDesign - Inserts one row for the array being 
loaded

GUS::Model::RAD::SAGETag; - Inserts a row for each SAGETag in the file

GUS::Model::SRes::ExternalDatabaseRelease;
TABLES_AFFECTED

  my $tablesDependedOn = <<TABLES_DEPENDED_ON;
GUS::Model::SRes::ExternalDatabaseRelease - Gets an existing external 
database release spec for the RAD.ArrayDesign row insertion
TABLES_DEPENDED_ON

  my $howToRestart = <<RESTART;
There are no restart facilities for this plugin
RESTART

  my $failureCases = <<FAIL_CASES;
FAIL_CASES

  my $documentation = { purpose          => $purpose,
                        purposeBrief     => $purposeBrief,
                        notes            => $notes,
                        tablesAffected   => $tablesAffected,
                        tablesDependedOn => $tablesDependedOn,
                        howToRestart     => $howToRestart,
                        failureCases     => $failureCases };
}

# ----------------------------------------------------------------------
# create and initalize new plugin instance.
# ----------------------------------------------------------------------

sub new {
  my ($class) = @_;
  my $self = { };
  bless($self,$class);

  my $documentation = &getDocumentation();
  my $argumentDeclaration = &getArgumentsDeclaration();


  $self->initialize({requiredDbVersion => 3.6,
                     cvsRevision => '$Revision$',
                     name => ref($self),
                     revisionNotes => '',
                     argsDeclaration => $argumentDeclaration,
                     documentation => $documentation});

  return $self;
}

sub run {
  my ($self) = @_;

  my $extDbSpec = $self->getArg('externalDatabaseSpec');
  my $extDbRlsId = $self->getExtDbRlsId($extDbSpec);

  my $extDbRls = GUS::Model::SRes::ExternalDatabaseRelease->
    new({external_database_release_id => $extDbRlsId});
  unless($extDbRls->retrieveFromDB()) {
    $self->error("Could not retrieve".
                 "SRes.ExternalDatabaseRelease object");
  }


  my $arrayName= $self->getArg('arrayName');
  my $arrayDesign = GUS::Model::RAD::ArrayDesign->
    new({name => $arrayName});
  $arrayDesign->setParent($extDbRls);

  my $sageTagFile = $self->getArg('sageTagFile');
  open(FILE, "< $sageTagFile") or 
    $self->error("Cannot open file $sageTagFile for reading:  $!");
  my $count = 0;
  while(<FILE>) {
    chomp;
    my $sageTag = GUS::Model::RAD::SAGETag->
      new({tag => $_});
    $sageTag->setParent($arrayDesign);
    if(++$count % 100000 == 0) {
      $arrayDesign->submit();
      $self->log('$count RAD.SageTag(s) inserted' );
    }
    $arrayDesign->submit();
    $self->undefPointerCache();
  }
    return("I inserted one RAD.ArrayDesign and $count RAD.SageTag(s)");
  }

sub undoTables {
  my ($self) = @_;

  return ('RAD.SageTag',
	  'RAD.ArrayDesign',
	 );
}


1;

