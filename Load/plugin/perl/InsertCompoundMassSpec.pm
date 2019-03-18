package ApiCommonData::Load::Plugin::InsertCompoundMassSpec;
@ISA = qw(ApiCommonData::Load::Plugin::InsertStudyResults);

#use lib "$ENV{GUS_HOME}/lib/perl";
use ApiCommonData::Load::Plugin::InsertStudyResults;
use ApiCommonData::Load::MetaboliteProfiles;
use GUS::Model::ApiDB::CompoundPeaksChebi;
use GUS::Model::ApiDB::CompoundPeaks;
use GUS::PluginMgr::Plugin;
use Data::Dumper;


use strict;

my $argsDeclaration =
[
    fileArg({name           => 'mainDirectory',
        descr          => 'Directory in which to find input files',
        reqd           => 1,
        mustExist      => 1,
        format         => '',
        constraintFunc => undef,
        isList         => 0, }),

    stringArg({name => 'extDbSpec',
          descr => 'External database from whence this data came|version',
          constraintFunc=> undef,
          reqd  => 1,
          isList => 0
         }),

    stringArg({name => 'studyName',
          descr => 'Name of the Study;  Will be added if it does not already exist',
          constraintFunc=> undef,
          reqd  => 1,
          isList => 0
         }),   # Need this?

    fileArg({name           => 'peaksFile',
        descr          => 'Name of file containing the compound peaks.',
        reqd           => 1,
        mustExist      => 1,
        format         => '',
        constraintFunc => undef,
        isList         => 0, }),

    fileArg({name           => 'resultsFile',
        descr          => 'Name of file containing the resuls values.',
        reqd           => 1,
        mustExist      => 1,
        format         => '',
        constraintFunc => undef,
        isList         => 0, }),

    fileArg({name           => 'configFile',
        descr          => 'Name of config File, describes the profiles being loaded',
        reqd           => 1,
        mustExist      => 1,
        format         => 'Tab file with header',
        constraintFunc => undef,
        isList         => 0, }),
];

my $purpose = <<PURPOSE;
To load metabolomics datasets -  compounds mapping to mass spec data.
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
To load metabolomics datasets -  compounds mapping to mass spec data.
PURPOSE_BRIEF

my $notes = <<NOTES;
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

my $documentation = {purpose   => $purpose,
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

  $self->initialize({ requiredDbVersion => 4.0,
              cvsRevision       => '$Revision$',
              name              => ref($self),
              argsDeclaration   => $argsDeclaration,
              documentation     => $documentation});

  return $self;
}

sub run {
  my ($self) = @_;

  my $peakFile = $self->getArg('peaksFile');
  #print STDERR "$peakFile :Ross \n";

  open(PEAKS, $peakFile) or $self->("Could not open $peakFile for reading: $!");
  my $header = <PEAKS>;
  chomp $header;

  my @header = split(/\t/, $header);
  my ($external_database_release_id, $peak_id, $mass, $retention_time, $ms_polarity, $compound_id, $compound_peaks_id, $isotopomer);

  while(<PEAKS>){
    my @peaksArray = split(/\t/, $_);
	$peak_id = $peaksArray[0];
	$mass = $peaksArray[1];
	$retention_time = $peaksArray[2];
	$compound_id = $peaksArray[3];
#	$ms_polarity = $peaksArray[4];
#	$isotopomer = $peaksArray[5];

  print STDERR $peak_id, " ",  $mass, " ", $retention_time, " ", $compound_id, " ", $ms_polarity; # - looks fine.

  my $extDbSpec = $self->getArg('extDbSpec');
  $external_database_release_id = $self->getExtDbRlsId($extDbSpec);

  #print STDERR "Ross :$external_database_release_id";

  $ms_polarity = "";
  $isotopomer = ""; # leaving null for now.

# Load into CompoudPeaks #NOTE - may want to take out peak_id #### NOTE ###
# NOTE : Check that changing the format (csv->tab) does not chnage the Mass / RT float values.
  my $compoundPeaksRow = GUS::Model::ApiDB::CompoundPeaks->new({external_database_release_id=>$external_database_release_id, peak_number=>$peak_id, mass=>$mass, retention_time=>$retention_time, ms_polarity=>$ms_polarity});
  $self->undefPointerCache();
  $compoundPeaksRow->submit(); #NOTE, ok to here.

# Load into CompoundPeaksChebi

#  @compoundSQL = $self->sqlAsArray(Sql=>
#		  "SELECT cmp.id
#		  FROM CHEBI.Compounds cmp WHERE cmp.id = '$compound_id'"); #This may need to change depending on if we used CheBi or not.... add option for running plugin with different compound DBs.

#  my @compoundSQL = $self->sqlAsArray(Sql=>
#		  "SELECT cmp.id
#		   FROM APIDB.pubchemcompound cmp WHERE cmp.pubchem_compund_id = '$compound_id'");

  # This look up takes time.
  my @compoundSQL = $self->sqlAsArray(Sql=>
    "select s.structure
		  --, c.chebi_accession
		  --, c.id
		  from chebi.structures s
		  , CHEBI.compounds c
		  where s.type = 'InChIKey'
          and c.id = s.compound_id
		  and to_char(s.structure) = 'InChIKey=$compound_id'"
  );

  print STDERR "Ross";
  #print STDERR Dumper @compoundSQL;

  my $compoundIDLoad = @compoundSQL[0];

  my @compoundPeaksSQL = $self->sqlAsArray(Sql=>
		  "SELECT cp.compound_peaks_id
		   FROM APIDB.CompoundPeaks cp
		   WHERE cp.mass = $mass
			 and cp.retention_time=$retention_time");

  $compound_peaks_id = @compoundPeaksSQL[0];

  print STDERR $compoundIDLoad, " ", $compound_peaks_id, " ", $isotopomer,  "\n";

  my $compoundPeaksChebiRow = GUS::Model::ApiDB::CompoundPeaksChebi->new({compound_id=>$compoundIDLoad, compound_peaks_id=>$compound_peaks_id, isotopomer=>$isotopomer});

  $compoundPeaksChebiRow->submit();
  } #End of while(<PEAKS>)

# munge the results file. Map using the peak ID for now.

#   my $dir = $self->getArg->{mainDirectory} ;
#   my $resultsFile = $self->getArg->{'resultsFile'};
#   my $args = {mainDirectory=>$dir, makePercentiles=>0, inputFile=>$resultsFile, profileSetName=> };
#
#   my $resultsData = ApiCommonData::Load::MetaboliteProfiles->new($args);
#
# # run SUPER class run().
#   $resultsData->run();

  print STDERR "Running";

}

1;
