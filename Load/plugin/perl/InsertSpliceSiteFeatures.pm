package ApiCommonData::Load::Plugin::InsertSpliceSiteFeatures;

@ISA = qw(GUS::PluginMgr::Plugin);

# ----------------------------------------------------------
# Plugin to load date in apidb.SpliceSiteFeature table
# ----------------------------------------------------------

use strict;
use warnings;

use GUS::PluginMgr::Plugin;

use GUS::Model::DoTS::NASequence;
use GUS::Model::SRes::ExternalDatabase;
use GUS::Model::SRes::ExternalDatabaseRelease;
use ApiCommonData::Load::Util;


# NEEDED PARAMS:
# path (to bowtie results), config file (fileNames -> sampleNames),
# extDbName, extDbVer, type (spliceSite OR polyA)

# ----------------------------------------------------------
# Load Arguments
# ----------------------------------------------------------

sub getArgsDeclaration {
  my $argsDeclaration  =
    [
     stringArg({ name => 'dirPath',
		 descr => 'full path to bowtie result files',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0,
		 mustExist => 1,
	       }),
     fileArg({ name => 'configFile',
	       descr => 'tab delimited file, with file name and corresponding sample name',
	       constraintFunc=> undef,
	       reqd  => 1,
	       isList => 0,
	       mustExist => 1,
	       format => 'Nine column tab delimited file in the order file name, sample name',
	     }),
     stringArg({ name => 'extDbName',
		 descr => 'externaldatabase name',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0
	       }),
     stringArg({ name => 'extDbVer',
		 descr => 'externaldatabaserelease version',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0
	       }),
     stringArg({ name => 'type',
		 descr => 'type of feature (Spice Site OR Poly A)',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0
	       })
    ];

  return $argsDeclaration;
}


# ----------------------------------------------------------
# Documentation
# ----------------------------------------------------------

sub getDocumentation {

  my $description = <<DESCR;
Plugin to load Splice Site Features in apidb.SpliceSiteFeature table
DESCR

  my $purpose = <<PURPOSE;
Plugin to load Splice Site Features in apidb.SpliceSiteFeature table
PURPOSE

  my $purposeBrief = <<PURPOSEBRIEF;
Plugin to load Splice Site Features in apidb.SpliceSiteFeature table
PURPOSEBRIEF

  my $notes = <<NOTES;
NOTES

  my $tablesAffected = <<AFFECT;
ApiDB.SpliceSiteFeature
AFFECT

  my $tablesDependedOn = <<TABD;
DoTS.NASequence, SRes.ExternalDatabaseRelease, SRes.ExternalDatabase
TABD

  my $howToRestart = <<RESTART;
No restart provided. Must undo and reload.
RESTART

  my $failureCases = <<FAIL;
FAIL

  my $documentation = { purpose          => $purpose,
                        purposeBrief     => $purposeBrief,
                        tablesAffected   => $tablesAffected,
                        tablesDependedOn => $tablesDependedOn,
                        howToRestart     => $howToRestart,
                        failureCases     => $failureCases,
                        notes            => $notes
                      };

  return ($documentation);
}

# ----------------------------------------------------------

sub new {
  my $class = shift;
  my $self = {};
  bless($self, $class);

  my $documentation = &getDocumentation();

  my $args = &getArgsDeclaration();

  my $configuration = { requiredDbVersion => 3.5,
                        cvsRevision => '$Revision: $',
                        name => ref($self),
                        argsDeclaration => $args,
                        documentation => $documentation
                      };

  $self->initialize($configuration);

  return $self;
}

# ----------------------------------------------------------

sub run {
  my $self = shift;

  # get External Database Release ID
  my $extDbReleaseId = $self->getExtDbRlsId($self->getArg('extDbName'),$self->getArg('extDbVer'))
    || $self->error("Cannot find external_database_release_id for the data source");

# moving so that cache can be undefed after every file is processed
#  # get sample names corresponding to data file names
#  $self->setSampleNameForFile();

  my $fileCount = 0;
  opendir(DIR, $self->getArg('dirPath')) || $self->error("Cannot open data directory.");
  while ( defined (my $file = readdir DIR) ) {
    if ($file =~ /^(.*)\.bt$/) {  # bowtie output files
      $fileCount++;
      $self->processFile($file, $extDbReleaseId);

      $self->undefPointerCache();
    }
  }
  return "Processed $fileCount files.";
}



sub processFile {
  my ($self, $file, $extDbReleaseId) = @_;
  my $key;

  my $filePath = $self->getArg('dirPath') . $file;
  open (FILE, $filePath);

  while (<FILE>){
    chomp;

    # -----------------------------------------------------------------------------------------------------------------------
    # BOWTIE OUTPUT:
    # 0          1       2               3                            4           5              6              7
    # Query_ID   Strand  Target_ID       Target_start(0_offset)  QuerySeq         Qualities	   -M_ceiling	  mismatches
    # 1272       -       Tb927_11_01_v4  2099739                 TCAGGTTGCCC..    IIIIIII...     0              71:T>G,72:C>G
    #
    # -----------------------------------------------------------------------------------------------------------------------

    my @temp = split("\t", $_);
    my $naSeqId = $self->getNaSequenceFromSourceId($temp[2]);

    my $location = $temp[3];
    my $seqLen = length($temp[4]);
    # for reverse strand, location = location in bowtie result + length of match - 1
    $location = $location + $seqLen - 1 if ($temp[1] eq "-");

    my $isUniq = 0;
    $isUniq = 1 if ($temp[6] == 0);

    # set hash key as the unique combination of seq_id, location, strand and isUniq
    $key = "$naSeqId\t$location\t$temp[1]\t$isUniq";

    $self->{alignCount}->{$key}++;  # increment alignment count for each occurrence of a particular hash key

    my @misCount = split("\,",$temp[7]); # last field of bowtie output gives comma-separated mis-matches
    $self->{mismatches}->{$key} += $#misCount + 1;  # increment number of total mis-matches for the same alignment
  }
  close (FILE);

  my $ct = $self->insertSpliceSiteFeatures($file, $extDbReleaseId);

}


sub insertSpliceSiteFeatures {
  my ($self, $file, $extDbReleaseId) = @_;
  my $count;

  # get sample name corresponding to data file
  my $sampleName = $self->getSampleNameForFile($file);

  my $type = $self->getArg('type');
  my $sample_name = $self->{$file};

  my %alignments = $self->{alignCount};
  my @matches = sort (keys(%alignments));
  foreach my $hit (@matches) {
    # NOTE format for $hit IS: "$naSeqId\t$location\t$strand\t$isUniq"

    my @m = split("\t",$hit);
    my $alignCount = $self->{alignCount}->{$hit};
    my $avg_mismatch = ($self->{mismatches}->{$hit}) / $alignCount;

    my $ssfeature = GUS::Model::ApiDB::SpliceSiteFeature->new({external_database_release_id => $extDbReleaseId,
							       type => $self->getArg('type'),
							       na_sequence_id => $m[0],
							       location => $m[1],
							       strand => $m[2],
							       sample_name => $sample_name,
							       count => $alignCount,
							       is_uniq => $m[3],
							       avg_mismatches => $avg_mismatch,
							      });
    $ssfeature->submit();
    $count++;
  }
  return "added $count featurs from $file";
}


sub getSampleNameForFile {
  my ($self, $file) = @_;

  open (CFG, $self->getArg('configFile'));
  while (<CFG>){
    chomp;
    my @temp = split("\t",$_);
    $self->{$temp[0]} = $temp[1];
  }
  close (CFG);
  return $self->{$file};
}

sub getNaSequenceFromSourceId {
  my ($self, $srcId) = @_;
  if (my $id = $self->{naSequence}->{$srcId}) {
    return $id;
  }

  my $naSeqId = GUS::Model::DoTS::NASequence->new({source_id => $srcId});
  unless ($naSeqId->retrieveFromDB) {
    $self->error("Can't find na_sequence_id for sequence $srcId");
  }
  $self->{naSequence}->{$srcId} = $naSeqId;
  return $naSeqId;
}


sub undoTables {
  my ($self) = @_;

  return ('ApiDB.SpliceSiteFeature');
}


# -----------------------------------------------------------------
# $self->{naSequence} :  hash of source_id to na_sequence_id
# $self->{alignCount} :  hash to keep track of alignment counts
# $self->{mismatches} :  hash for calculation of average mis-matches


return 1;
