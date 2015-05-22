package ApiCommonData::Load::Plugin::InsertIsolateGPS;
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
  # GUS4_STATUS | Dots.Isolate                   | auto   | broken
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

# ----------------------------------------------------------------------

use strict;
use GUS::PluginMgr::Plugin;
use GUS::Model::ApiDB::IsolateGPS;

my $argsDeclaration =
  [
   fileArg({name           => 'isolateGPSFile',
            descr          => 'file with isolate country gps info',
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
ApiDB::IsolateGPS
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

  open(FILE, $self->getArg('isolateGPSFile')) || die "Could Not open isolate gps file for reading: $!\n";

  my $count;

  while(<FILE>) {
      chomp;
      next unless $_;
      next if /^##/;

      my ($alpha2, $alpha3, $numeric, $fips, $country, $capital, $area, $population, $continent, $lat, $lng, $toponym_name) = split(/\|/, $_);
      next unless $country;
      $area =~ s/,//g;
      $population =~ s/,//g;
      my $gps = GUS::Model::ApiDB::IsolateGPS->
         new({country              => $country,
              lat                  => $lat,
              lng                  => $lng,
              country_code_alpha2  => $alpha2,
              country_code_alpha3  => $alpha3,
              country_code_numeric => $numeric,
              fips                 => $fips,
              capital              => $capital,
              area_in_km2          => $area,
              population           => $population,
              continent            => $continent,
              toponym_name         => $toponym_name 
           });
      $gps->submit();

    $count++;
    if ($count % 1000 == 0) {
        $self->log("Inserted $count Entries into IsolateGPS");
        $self->undefPointerCache();

    }
  }
  return("Loaded $count ApiDB::IsolateGPS");
}

sub undoTables {
  my ($self) = @_;

  return ('ApiDB.IsolateGPS');
}

1;
