package ApiCommonData::Load::Plugin::FungiMeyerCorrelations;

@ISA = qw(GUS::PluginMgr::Plugin);
use strict;

use GUS::PluginMgr::Plugin;
use File::Temp qw/ tempfile /;

use Data::Dumper;


my $argsDeclaration =
  [
   fileArg({name           => 'dataDir',
            descr          => 'directory where to find tab files to load',
            reqd           => 1,
	    mustExist      => 1,
	    format         => '',
            constraintFunc => undef,
            isList         => 0, }),
  ];

my $documentation = { purpose          => "Inserts into ApiDB.FungiMeyerCoexpression",
                      purposeBrief     => "",
                      notes            => "",
                      tablesAffected   => "ApiDB.FungiMeyerCoexpression",
                      tablesDependedOn => "",
                      howToRestart     => "",
                      failureCases     => "" };

# ----------------------------------------------------------------------

sub getIsReportMode { }

# ----------------------------------------------------------------------

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  $self->initialize({ requiredDbVersion => 4.0,
                      cvsRevision       => '$Revision$',
                      name              => ref($self),
                      argsDeclaration   => $argsDeclaration,
                      documentation     => $documentation});

  return $self;
}

# ======================================================================

sub run {
  my ($self) = @_;
  my $dataDir = $self->getArg('dataDir');

  my $fileCount;
  my ($charFh, $charFile) = tempfile(SUFFIX => '.dat');


  opendir (DIR, $dataDir) or die "Could not open dir '$dataDir'\n";
  my @dataFiles = grep { /\.dat$/ } readdir DIR;
  closedir DIR;

  foreach my $f (@dataFiles) {

    $self->log("Processing file : $f");

    $self->loadData($dataDir, $charFh);
    $fileCount++;
    $self->logRowsInserted() if($self->getArg('commit'));
  }

  return "Processed $fileCount data files";
}


sub loadData {
  my ($self, $charFile) = @_;

  my $configFile = "$charFile" . ".ctrl";
  my $logFile = "$charFile" . ".log";

  $self->writeConfigFile($configFile, $charFile);

  my $login       = $self->getConfig->getDatabaseLogin();

  my $password    = $self->getConfig->getDatabasePassword();

  my $dbiDsn      = $self->getConfig->getDbiDsn();

  my ($dbi, $type, $db) = split(':', $dbiDsn);

  if($self->getArg('commit')) {
    system("sqlldr $login/$password\@$db control=$configFile log=$logFile");

    open(LOG, $logFile) or die "Cannot opoen log file $logFile: $!";

    while(<LOG>) {
      $self->log($_);
    }
    close LOG;

    unlink $logFile;
  }

  unlink $configFile;

  return "Processed lines from data files";
}




sub writeConfigFile {
  my ($self, $configFile, $dataFile) = @_;

  my $database = $self->getDb();

  open(CONFIG, "> $configFile") or die "Cannot open file $configFile For writing:$!";

  print CONFIG "LOAD DATA
INFILE '$dataFile'
APPEND
INTO TABLE ApiDB.FungiMeyerCoexpression
REENABLE DISABLED_CONSTRAINTS
FIELDS TERMINATED BY '\\t'
TRAILING NULLCOLS
(gene_id,
associated_gene_id,
coefficient,
)\n";
  close CONFIG;
}

sub getConfig {
  my ($self) = @_;

  if (!$self->{config}) {
    my $gusConfigFile = $self->getArg('gusconfigfile');
     $self->{config} = GUS::Supported::GusConfig->new($gusConfigFile);
   }

  $self->{config};
}



sub undoTables {
  my ($self) = @_;

  return (
	  'ApiDB.FungiMeyerCoexpression',
	 );
}


1;

