package ApiCommonData::Load::Plugin::InsertIsolateVocabularyMapping;

@ISA = qw(GUS::PluginMgr::Plugin);

# ----------------------------------------------------------------------

use strict;
use GUS::PluginMgr::Plugin;

use GUS::Model::ApiDB::IsolateMapping;



my $argsDeclaration =
  [

   fileArg({name           => 'isolateVocabularyMappingFile',
            descr          => 'file with na_sequence_id and isolate_vocabulary_id',
            reqd           => 1,
            mustExist      => 1,
	    format         => '',
            constraintFunc => undef,
            isList         => 0, }),

  ];

my $purpose = <<PURPOSE;

PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;

PURPOSE_BRIEF

my $notes = <<NOTES;

NOTES

my $tablesAffected = <<TABLES_AFFECTED;
ApiDB::IsolateMapping
TABLES_AFFECTED

my $tablesDependedOn = <<TABLES_DEPENDED_ON;
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

# ----------------------------------------------------------------------

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  $self->initialize({ requiredDbVersion => 3.5,
                      cvsRevision       => '$Revision: $',
                      name              => ref($self),
                      argsDeclaration   => $argsDeclaration,
                      documentation     => $documentation});

  return $self;
}

# ======================================================================

sub run {
  my ($self) = @_;

  open(FILE, $self->getArg('isolateVocabularyMappingFile')) || die "Could Not open isolate vocabulary mapping file for reading: $!\n";

  my $count;

  while(<FILE>) {
      chomp;
      next unless $_;

      my ($na_sequence_id, $isolate_vocabulary_id) = split(/\t/, $_);

      my $vocabulary= GUS::Model::ApiDB::IsolateMapping->
	       new({na_sequence_id => $na_sequence_id,
		    isolate_vocabulary_id => $isolate_vocabulary_id
		   });
      $vocabulary->submit();

	  $count++;
	  if ($count % 1000 == 0) {
	      $self->log("Inserted $count Entries into ApiDB.IsolateMapping");
	      $self->undefPointerCache();

	  }
  }
  return("Loaded $count ApiDB::IsolateMapping");
}

sub undoTables {
  my ($self) = @_;

  return ('ApiDB.IsolateMapping',
	 );
}

1;
