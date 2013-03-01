package ApiCommonData::Load::Plugin::InsertSpliceSiteFeatures;

@ISA = qw(GUS::PluginMgr::Plugin);

# ----------------------------------------------------------
# Plugin to load date in apidb.SpliceSiteFeature table
# ----------------------------------------------------------

use strict;
use warnings;

use GUS::PluginMgr::Plugin;
use GUS::Model::DoTS::NASequence;
use GUS::Model::ApiDB::SpliceSiteFeature;


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
     stringArg({ name => 'fileNames',
		 descr => 'comma-separated bowtie result files that the plugin has to be run on',
		 constraintFunc=> undef,
		 reqd  => 0,
		 isList => 1,
		 mustExist => 0,
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

  my $configuration = { requiredDbVersion => 3.6,
                        cvsRevision => '$Revision: 53770 $',
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

  my @fileArray;
  #IF no files specified in input, THEN make file list from specified directory
  if ($self->getArg('fileNames')){
    @fileArray = @{$self->getArg('fileNames')};
  } else {
    while ( defined (my $file = readdir DIR) ) {
      if ($file =~ /^(.*)\.bt$/) {  # bowtie output files
	push(@fileArray,$file);
      }
    }
  }

  foreach my $file (@fileArray){
    $fileCount++;
    $self->processFile($file, $extDbReleaseId);

    $self->{alignCount}={};
    $self->{mismatches} ={};

  }
  return "Processed $fileCount files.";
}



sub processFile {
  my ($self, $file, $extDbReleaseId) = @_;
  my $key;

  my $filePath = $self->getArg('dirPath') ."/" . $file;
  open (FILE, $filePath);

  my $all_uniq_counts = 0; # to keep count of ALL unique alignments; needed for normalizing counts later

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

    # bowtie results have zero-based offset
    $location = $location + 1;
    # for reverse strand, location = location in bowtie result + length of match - 1
    $location = $location + $seqLen - 1 if ($temp[1] eq "-");

    my $isUniq = 0;
    $isUniq = 1 if ($temp[6] == 0);
    $all_uniq_counts++ if ($isUniq);

    # set hash key as the unique combination of seq_id, location, strand and isUniq
    $key = "$naSeqId\t$location\t$temp[1]\t$isUniq";

    $self->{alignCount}->{$key}++;  # increment alignment count for each occurrence of a particular hash key


    if ($temp[7]){
      my @misCount = split("\,",$temp[7]); # last field of bowtie output gives comma-separated mis-matches
      $self->{mismatches}->{$key} += $#misCount + 1;  # increment number of total mis-matches for the same alignment
    }
    $self->undefPointerCache();
  }
  close (FILE);

  $self->insertSpliceSiteFeatures($file, $extDbReleaseId, $all_uniq_counts);
}


sub insertSpliceSiteFeatures {
  my ($self, $file, $extDbReleaseId, $all_uniq_counts) = @_;
  my $count;

  # get sample name corresponding to data file
  my $sampleName = $self->getSampleNameForFile($file);

  my $type = $self->getArg('type');
  my $sample_name = $self->{$file};

  my %alignments = %{$self->{alignCount}};
  my @matches = sort (keys(%alignments));
  foreach my $hit (@matches) {

    # NOTE format for $hit IS: "$naSeqId\t$location\t$strand\t$isUniq"
    my @m = split("\t",$hit);
    my $alignCount = $self->{alignCount}->{$hit};

    my $mismatch = $self->{mismatches}->{$hit} || 0;
    my $avg_mismatch = sprintf "%.2f", ($mismatch / $alignCount);

    my $countPerMill = sprintf "%.2f", ($alignCount * 1000000) / ($all_uniq_counts);

    my $ssfeature = GUS::Model::ApiDB::SpliceSiteFeature->new({external_database_release_id => $extDbReleaseId,
							       type => $self->getArg('type'),
							       na_sequence_id => $m[0],
							       location => $m[1],
							       strand => $m[2],
							       sample_name => $sample_name,
							       count => $alignCount,
							       is_unique => $m[3],
							       avg_mismatches => $avg_mismatch,
							       count_per_million => $countPerMill,
							      });
    $ssfeature->submit();
    $count++;
    $self->undefPointerCache() if $count % 1000 == 0;
  }
  $self->log("Inserted $count features from $file");
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

  my $naSeq = GUS::Model::DoTS::NASequence->new({source_id => $srcId});
  unless ($naSeq->retrieveFromDB) {
    $self->error("Can't find na_sequence_id for sequence $srcId");
  }
  my $naSeqId = $naSeq->getNaSequenceId();
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
