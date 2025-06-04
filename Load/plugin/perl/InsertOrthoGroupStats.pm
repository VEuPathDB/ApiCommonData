package ApiCommonData::Load::Plugin::InsertOrthoGroupStats;

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
    while (my $line = <$data>) {
        chomp $line;

        my ($group,$max,$seventyfifth,$median,$twentyfifth,$min,$count) = split(/\t/, $line);
      
        if ($min eq "0") {
            addRow($group,"min",$min,$proteinSubset);
            $rowCount++;
        }
        else  {
            &formatValueAndAddRow($group,$proteinSubset,$min,"min");
            $rowCount++;
        }
        if ($twentyfifth eq "0") {
            addRow($group,"25 PCT",$twentyfifth,$proteinSubset);
            $rowCount++;
        }
        else  {
            &formatValueAndAddRow($group,$proteinSubset,$twentyfifth,"25 PCT");
            $rowCount++;
        }
        if ($median eq "0") {
            addRow($group,"median",$median,$proteinSubset);
            $rowCount++;
        }
        else  {
            &formatValueAndAddRow($group,$proteinSubset,$median,"median");
            $rowCount++;
        }
        if ($seventyfifth eq "0") {
            addRow($group,"75 PCT",$seventyfifth,$proteinSubset);
            $rowCount++;
        }
        else  {
            &formatValueAndAddRow($group,$proteinSubset,$seventyfifth,"75 PCT");
            $rowCount++;
        }
        if ($max eq "0") {
            addRow($group,"max",$max,$proteinSubset);
            $rowCount++;
        }
        else  {
            &formatValueAndAddRow($group,$proteinSubset,$max,"max");
            $rowCount++;
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

sub formatValueAndAddRow {
  my ($group,$proteinSubset,$value,$statType) = @_;
  $value = 1.0e-5 if ($value > 1.0e-5);
  my ($statValue, $statExponent) = split /e-/, $value;
  my $statValueRounded = sprintf("%.2f", $statValue);
  my $valueFormatted = "${statValueRounded}e-$statExponent";
  addRow($group,"${statType}",$valueFormatted,$proteinSubset);
}

sub undoTables {
  my ($self) = @_;

  return ('ApiDB.OrthologGroupStats');
}

1;
