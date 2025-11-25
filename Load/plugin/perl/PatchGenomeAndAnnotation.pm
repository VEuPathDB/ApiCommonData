package ApiCommonData::Load::Plugin::PatchGenomeAndAnnotation;
@ISA = qw(GUS::PluginMgr::Plugin ApiCommonData::Load::Plugin::ParameterizedSchema);

use strict;
use File::Basename;
use GUS::PluginMgr::Plugin;
use ApiCommonData::Load::InstantiatePsql;
use ApiCommonData::Load::Plugin::ParameterizedSchema;

use GUS::Model::DoTS::DbRefNAFeature;
use GUS::Model::DoTS::NALocation;
use GUS::Model::DoTS::Miscellaneous;

my $purposeBrief = <<PURPOSEBRIEF;
patch genome and annotation
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
patch genome and annotation
PLUGIN_PURPOSE

my $tablesAffected = [];

my $tablesDependedOn = [];

my $howToRestart = <<PLUGIN_RESTART;
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
None.
PLUGIN_FAILURE_CASES

my $notes = <<PLUGIN_NOTES;
Input is a .psql file. The .psql file contain all psql commnad that want to run for the patch
The sqls are delimited by a semi-colon followed by newline.  The files use .psql style macro variables.

A typical MY_DENORM_TABLE.psql file might look like this:
update dots.nalocation set start_min = 458021, start_max = 458021, end_min = 462661, end_max = 462661 where na_feature_id in (select na_feature_id from dots.miscellaneous where source_id like 'PF3D7_CEN01');

For undo,it's doing nothing for now.
PLUGIN_NOTES

my $documentation = { purpose=>$purpose,
		      purposeBrief=>$purposeBrief,
		      tablesAffected=>$tablesAffected,
		      tablesDependedOn=>$tablesDependedOn,
		      howToRestart=>$howToRestart,
		      failureCases=>$failureCases,
		      notes=>$notes
		    };

my $TABLE_NAME_ARG = 'tableName';
my $SCHEMA_ARG = 'schema';
my $ORG_ARG = 'organismAbbrev';

my $argsDeclaration =
  [

   fileArg({name           => 'psqlFile',
            descr          => '',
            reqd           => 1,
            mustExist      => 1,
            format         => '',
            constraintFunc => undef,
            isList         => 0, }),
   stringArg({name => 'organismAbbrev',
	      descr => 'internal organism abbrev',
	      constraintFunc => undef,
	      reqd => 0,
	      isList => 0
	     }),
  ];

sub new {
  my ($class) = @_;
  $class = ref $class || $class;

  my $self = bless({}, $class);

  $self->initialize({ requiredDbVersion => 4.0,
                      cvsRevision       => '$Revision$',
                      name              => ref($self),
                      argsDeclaration   => $argsDeclaration,
                      documentation     => $documentation
                   });

  $self->{_undo_tables} = [];
  return $self;
}

sub run {
  my ($self) = @_;

  my $psqlFile = $self->getArg('psqlFile');
  my $organismAbbrev = $self->getArg('organismAbbrev');

  my $dbh = $self->getQueryHandle();
  $dbh->{RaiseError} = 1;
  $dbh->{AutoCommit} = 1;
  my $commitMode = $self->getArg('commit');

  $dbh->do("set role gus_w");

  -e $psqlFile or $self->error("psqlFile $psqlFile does not exist");

  my $startTimeAll = time;

  $self->processPsqlFile($psqlFile, $organismAbbrev, $commitMode, $dbh);

  my $t = time - $startTimeAll;
  $self->log("TOTAL SQL TIME (sec) for psqlFile: $t");
}

sub processPsqlFile {
  my ($self, $psqlFile, $organismAbbrev, $commitMode, $dbh) = @_;

  $self->log("Processing file $psqlFile");
  open my $fh, '<', $psqlFile or $self->error("error opening $psqlFile: $!");
  my $sqls = do { local $/; <$fh> };

  my $newSqls = ApiCommonData::Load::InstantiatePsql::instantiateSql($sqls, $organismAbbrev);

  my @sqlList = split(/;\n\s*/, $newSqls);
  foreach my $sql (@sqlList) {
    my $startTime = time;
    my $sql = ApiCommonData::Load::InstantiatePsql::substituteDelims($sql);
    $self->log(( $commitMode? "FOR REAL" : "TEST ONLY" ). " - SQL: \n$sql\n\n");
    if ($commitMode) {
      $dbh->do($sql);
    }
    my $t = time - $startTime;
    $self->log("INDVIDUAL SQL TIME (sec): $t");
  }
}

sub undoPreprocess {
  my($self, $dbh, $rowAlgInvocationList) = @_;

  $self->error("Expected a single rowAlgInvocationId") if scalar(@$rowAlgInvocationList) != 1;

  $self->log("UNDOing alg invocation id: $rowAlgInvocationList->[0]");

}

sub undoTables {
  my ($self) = @_;

  return ( );
}
1;
