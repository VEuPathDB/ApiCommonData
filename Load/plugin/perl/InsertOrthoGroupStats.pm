package OrthoMCLData::Load::Plugin::InsertOrthoGroupStats;

@ISA = qw(GUS::PluginMgr::Plugin);

# ----------------------------------------------------------------------

use strict;
use GUS::PluginMgr::Plugin;
use FileHandle;

use GUS::Model::ApiDB::OrthologGroupStats;

my $argsDeclaration =
[
    fileArg({name           => 'groupStatsFile',
            descr          => 'Ortholog Groups Statistics. OrthologGroupName followed by Stats of the group.',
            reqd           => 1,
            mustExist      => 1,
	    format         => 'OG0000000 3 22.25 30.2666666666667 6 6 1 1.18233333333333e-05',
            constraintFunc => undef,
            isList         => 0, }),

    stringArg({name           => 'proteinSubset',
            descr          => 'Ortholog Groups Statistics Type. Either C, C+P, or R.',
            reqd           => 1,
            mustExist      => 1,
	    format         => 'C or C+P or R',
            constraintFunc => undef,
            isList         => 0, }),

];

my $purpose = <<PURPOSE;
Insert core + peripheral group statistics into ApiDB::OrthologGroupStats
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
Insert core + peripheral group statistics into ApiDB::OrthologGroupStats
PURPOSE_BRIEF

my $notes = <<NOTES;
NOTES

my $tablesAffected = <<TABLES_AFFECTED;
ApiDB.OrthologGroupStats
TABLES_AFFECTED

my $tablesDependedOn = <<TABLES_DEPENDED_ON;
ApiDB.OrthologGroup
TABLES_DEPENDED_ON

my $howToRestart = <<RESTART;
The plugin can been restarted, since the same ortholog group from the same OrthoMCL analysis version will only be loaded once.
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

  $self->initialize({ requiredDbVersion => 4,
                      cvsRevision       => '$Revision: 68598 $',
                      name              => ref($self),
                      argsDeclaration   => $argsDeclaration,
                      documentation     => $documentation});

  return $self;
}

# ======================================================================

sub run {
    my ($self) = @_;

    my $statsFile = $self->getArg('groupStatsFile');
    my $proteinSubset = $self->getArg('proteinSubset');
    open(my $data, '<', $statsFile) || die "Could not open file $statsFile: $!";
    my $rowCount = 0;
    my @statTypes = ("min","25 PCT","median","75 PCT", "max");
    while (my $line = <$data>) {
        chomp $line;
        $rowCount++;
        my ($group,$max,$seventyfifth,$median,$twentyfifth,$min) = split(/\t/, $line);
      
        foreach my $statType (@statTypes) {
            if ($statType eq "min") {
                if ($min == 0) {
                    addRow($group,$statType,$min,$proteinSubset);
                }
                else  {
                    my ($minValue, $minExponent) = split /e-/, $min;
                    my $minValueRounded = sprintf("%.2f", $minValue);
                    my $minFormatted = "${minValueRounded}e-$minExponent";
                    addRow($group,$statType,$minFormatted,$proteinSubset);
                }
            }
            elsif ($statType eq "25 PCT") {
                if ($twentyfifth == 0) {
                    addRow($group,$statType,$twentyfifth,$proteinSubset);
                }
                else  {
                    my ($twentyfifthValue, $twentyfifthExponent) = split /e-/, $twentyfifth;
                    my $twentyfifthValueRounded = sprintf("%.2f", $twentyfifthValue);
                    my $twentyfifthFormatted = "${twentyfifthValueRounded}e-$twentyfifthExponent";
                    addRow($group,$statType,$twentyfifthFormatted,$proteinSubset);
                }
            }
            elsif ($statType eq "median") {
                if ($median == 0) {
                    addRow($group,$statType,$median,$proteinSubset);
                }
                else  {
                    my ($medValue, $medExponent) = split /e-/, $median;
                    my $medValueRounded = sprintf("%.2f", $medValue);
                    my $medFormatted = "${medValueRounded}e-$medExponent";
                    addRow($group,$statType,$medFormatted,$proteinSubset);
                }
            }
            elsif ($statType eq "75 PCT") {
                if ($seventyfifth == 0) {
                    addRow($group,$statType,$seventyfifth,$proteinSubset);
                }
                else  {
                    my ($seventyfifthValue, $seventyfifthExponent) = split /e-/, $seventyfifth;
                    my $seventyfifthValueRounded = sprintf("%.2f", $seventyfifthValue);
                    my $seventyfifthFormatted = "${seventyfifthValueRounded}e-$seventyfifthExponent";
                    addRow($group,$statType,$seventyfifthFormatted,$proteinSubset);
                }
            }
            elsif ($statType eq "max") {
                if ($max == 0) {
                    addRow($group,$statType,$max,$proteinSubset);
                }
                else  {
                    my ($maxValue, $maxExponent) = split /e-/, $max;
                    my $maxValueRounded = sprintf("%.2f", $maxValue);
                    my $maxFormatted = "${maxValueRounded}e-$maxExponent";
                    addRow($group,$statType,$maxFormatted,$proteinSubset);
                }
            }
        }

    }
    print "$rowCount rows added.\n"
}

# ----------------------------------------------------------------------

sub addRow {
  my ($group,$statType,$evalue,$proteinSubset) = @_;
  my $row = GUS::Model::ApiDB::OrthologGroupStats->new({GROUP_ID => $group,
                                                         STAT_TYPE => $statType,
                                                         EVALUE => $evalue,
                                                         PROTEIN_SUBSET => $proteinSubset
                                                     });
  $row->submit();
  $row->undefPointerCache();
}

sub undoTables {
  my ($self) = @_;

  return ('ApiDB.OrthologGroupStats');
}

1;
