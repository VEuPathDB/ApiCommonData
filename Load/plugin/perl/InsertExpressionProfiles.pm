package ApiCommonData::Load::Plugin::InsertExpressionProfiles;

@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use CBIL::Util::Disp;
use GUS::PluginMgr::Plugin;
use ApiCommonData::Load::ExpressionProfileInsertion;

my $argsDeclaration =
[
   fileArg({name           => 'inputDir',
	    descr          => 'Directory in which to find input files',
	    reqd           => 1,
	    mustExist      => 1,
	    format         => '',
	    constraintFunc => undef,
	    isList         => 0, }),

   fileArg({name           => 'configFile',
	    descr          => 'Describes the profiles being loaded',
	    reqd           => 1,
	    mustExist      => 1,
	    format         => 'Tab file with no header and these columns: file_base_name, profile_name, profile_descrip, source_id_type, skip_second_row, load_profile_element.  The source_id_type must be one of: oligo, gene, none. The skip_second_row is 1 if second row in file is unneeded header, and load_profile_element is 1 if we want to load the expression data into the profileElement table.',
	    constraintFunc => undef,
	    isList         => 0, }),

 	 booleanArg ({name => 'tolerateMissingIds',
	              descr => 'Set this to tolerate (and log) source ids in the input that do not find an oligo or gene in the database.  If not set, will fail on that condition',
	              reqd => 0,
                      default =>0
                     }),
 
   fileArg({name           => 'dudProfilesFile',
	    descr          => 'A single column file containing source ids of profiles that should be tagged with no_evidence_of_expr',
	    reqd           => 0,
	    mustExist      => 1,
	    format         => '',
	    constraintFunc => undef,
	    isList         => 0, }),

   stringArg({name => 'externalDatabase',
	      descr => 'External database from whence this data came',
	      constraintFunc=> undef,
	      reqd  => 1,
	      isList => 0
	     }),

   stringArg({name => 'externalDatabaseRls',
	      descr => 'Version of external database from whence this data came',
	      constraintFunc=> undef,
	      reqd  => 1,
	      isList => 0
	     }),

];

my $purpose = <<PURPOSE;
Insert a group of expression profile sets into the ProfileSet table and its friends.  The members of the group are different proceeing of the same experimental data
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
Insert a set group of expression profile sets from one experiment into the ProfileSet table and its friends.
PURPOSE_BRIEF

my $notes = <<NOTES;
This plugin takes a PlasmoDB shortcut (would be easy to fix).  It assumes that there is only one version of the SequenceOntology in the database, and that the source_id column of ExternalNaSequence is unique for all sequences with SO term 'oligo'.
NOTES

my $tablesAffected = <<TABLES_AFFECTED;
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

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  $self->initialize({ requiredDbVersion => 3.5,
		      cvsRevision       => '$Revision$',
		      name              => ref($self),
		      argsDeclaration   => $argsDeclaration,
		      documentation     => $documentation});

  return $self;
}

sub run {
  my ($self) = @_;

  $self->readConfigFile();

  $self->readDudsFile();

  my $inputDir = $self->getArg('inputDir');

  my $extDbRlsId = $self->getExtDbRlsId($self->getArg('externalDatabase'),
				     $self->getArg('externalDatabaseRls'));

  my @inputFiles = @{$self->{inputFiles}};
  for (my $i=0; $i<scalar(@inputFiles); $i++) {
    my ($header, $profileRows) =
      &parseInputFile($self, "$inputDir/$inputFiles[$i]",
		      $self->{profileSetNames}->[$i],
		      $self->{skipSecondRow}->[$i]);

    &processInputProfileSet($self, $extDbRlsId, $header, $profileRows,
			    $self->{profileSetNames}->[$i],
			    $self->{profileSetDescrips}->[$i],
			    $self->{sourceIdTypes}->[$i],
			    $self->{loadProfileElement}->[$i],
			    $self->getArg('tolerateMissingIds'),
			    0);
  }
  return "Inserted profiles: " . join(", ", @{$self->{profileSetNames}});
}

sub readConfigFile {
  my ($self) = @_;

  my $inputDir = $self->getArg('inputDir');
  open(CONFIG_FILE, $self->getArg('configFile'));
  while (<CONFIG_FILE>) {
    chomp;
    my @vals = split(/\t/, $_);
    scalar(@vals) == 6
      || $self->userError("Config file has invalid line: '$_'");

    push(@{$self->{inputFiles}}, $vals[0]);
    -r "$inputDir/$vals[0]" || $self->userError("Can't open file '$inputDir/$vals[0]' for reading");
    push(@{$self->{profileSetNames}}, $vals[1]);
    push(@{$self->{profileSetDescrips}}, $vals[2]);
    push(@{$self->{sourceIdTypes}}, $vals[3]);
    push(@{$self->{skipSecondRow}}, $vals[4]);
    push(@{$self->{loadProfileElement}}, $vals[5]);
  }
}

sub readDudsFile {
  my ($self) = @_;

  if ($self->getArg('dudProfilesFile')) {
    open(DUDS, $self->getArg('dudProfilesFile'));
    while(<DUDS>) {
      chomp;
      $self->userError("Invalid dudProfilesFile.  Must be single column of ids") unless /^\S+$/;
      $self->{duds}->{$_} = 1;
    }
    close(DUDS);
  }
}


sub undoTables {
  my ($self) = @_;

  return ('ApiDB.ProfileElement',
	  'ApiDB.Profile',
	  'ApiDB.ProfileElementName',
	  'ApiDB.ProfileSet',
	 );
}


1;

