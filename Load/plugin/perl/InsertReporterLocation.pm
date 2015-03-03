package ApiCommonData::Load::Plugin::InsertReporterLocation;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use lib "$ENV{GUS_HOME}/lib/perl";

use GUS::PluginMgr::Plugin;
use GUS::Supported::Util;

use Bio::DB::Sam;

use GUS::Model::Platform::Reporter;
use GUS::Model::Platform::ReporterLocation;

my $argsDeclaration = 
[
    fileArg ( { name => 'inputFile',
                descr => 'BAM file of probe mappings',
                reqd => 1,
                mustExist => 1,
                format => 'bam',
	  constraintFunc => undef,
                isList => 0, }),
        
    stringArg ( { name => 'platformExtDbSpec',
                  descr => 'External database for probeset',
	  constraintFunc => undef,
                  reqd => 1,
                  isList => 0 })
];

my $purpose = <<PURPOSE;
Insert reporter locations from bam file into platform schema
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
Insert reporter locations from bam file into platform schema
PURPOSE_BRIEF

my $notes = <<NOTES;
NOTES

my $tablesAffected = <<TABLES_AFFECTED;
Platform.ReporterLocation
TABLES_AFFECTED


my $tablesDependedOn = <<TABLES_DEPENDED_ON;
Platform.Reporter
Dots.NaSequence
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

  $self->initialize({ requiredDbVersion => 4.0,
              cvsRevision       => '$Revision$', #TODO: change this
              name              => ref($self),
              argsDeclaration   => $argsDeclaration,
              documentation     => $documentation});

  return $self;
}

sub run {
    my ($self) = @_;
    
    my $bamFile = $self->getArg('inputFile');
    
    my $platformDbSpec = $self->getArg('platformExtDbSpec');
    my $platformDbRlsId = $self->getExtDbRlsId($platformDbSpec);

    my $dbh = $self->getQueryHandle();

    my $sql =  "select R.SOURCE_ID, R.REPORTER_ID
                          from PLATFORM.REPORTER R
                          where R.EXTERNAL_DATABASE_RELEASE_ID = ?";

    my $sh = $dbh->prepare($sql);
    $sh->execute($platformDbRlsId);

    my %reporterHash;

    while(my ($sourceId, $reporterId) = $sh->fetchrow_array()) {
       $reporterHash{$sourceId} = $reporterId;
    }
    $sh->finish();

    my $bam = Bio::DB::Sam->new(-bam => $bamFile);
    my @alignments = $bam->features();


    my $count;
    foreach my $alignment (@alignments) {
        my $probeSourceId = $alignment->query->name;
        my $naSequenceSourceId = $alignment->seq_id;
        unless (defined $naSequenceSourceId) {
            next;
        }
        my $naSequenceId = GUS::Supported::Util::getNASequenceId ($self, $naSequenceSourceId);
        my $start = $alignment->start;
        my $end = $alignment->end;
        
        my $parent;

        if (exists $reporterHash{$probeSourceId}) {
            $parent = $reporterHash{$probeSourceId};
        }
        else {
            $self->error("Probe $probeSourceId not found in ReporterTable");
        }

        my $reporterLocation = GUS::Model::Platform::ReporterLocation->new({ reporter_id => $parent,
                                                                             na_sequence_id => $naSequenceId,
                                                                             reporter_start => $start,
                                                                             reporter_end => $end,
        });
        $reporterLocation->submit();                 
        $count++;

        $self->undefPointerCache();
    }

    return("Inserted $count Rows into Platform::ReporterLocation");
}

sub undoTables {
  my ($self) = @_;

    return ( 
      'Platform.ReporterLocation',
        );
}

1;
