package ApiCommonData::Load::Plugin::CreatePlasmoMappFile;
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
  # GUS4_STATUS | Dots.Isolate                   | auto   | absent
  # GUS4_STATUS | DeprecatedTables               | auto   | broken
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

use strict;
use warnings;

use FileHandle;
use GUS::PluginMgr::Plugin;
use GUS::Supported::Util;
use GUS::Model::DoTS::NASequence;

my $argsDeclaration =
  [
   stringArg({name => 'inDir',
	      descr => 'directory path to MAPP data',
	      constraintFunc=> undef,
	      reqd  => 1,
	      isList => 0
	     }),
   stringArg({name => 'table',
	      descr => 'table that will be eventually used to load MAPP data',
	      constraintFunc => undef,
	      reqd => 1,
	      isList => 0
	     }),
   fileArg({name => 'outFile',
	    descr => 'output file, with full path, for loading of MAPP data',
	    reqd => 1,
	    mustExist => 0,
	    format => '0',
	    constraintFunc => undef,
	    isList => 0, }),
  ];

my $purpose = <<PURPOSE;
The purpose of this plugin is to create a file for the Plasmo MAPP (Malaria Promoter Predictor) data provided by Kevin Brick. The file is to be in format for bulk loading via sqlldr.
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
The purpose of this plugin is to create a file for the Plasmo MAPP data.
PURPOSE_BRIEF

my $notes = <<NOTES;
NOTES

my $tablesAffected = <<TABLES_AFFECTED;
TABLES_AFFECTED

my $tablesDependedOn = [["DoTS.NASequence", "The sequence must exist here with the given source_id."]];

my $howToRestart = <<RESTART;
No Restart utilities for this plugin.
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


sub run {
  my ($self) = @_;

  my ($table) = $self->getArg("table");
  eval "require ($table)";

  # gather the list of all input files in a single file
  my $files;
  my $inDir =  $self->getArg('inDir');
  my $cmd="ls $inDir > $files";
  system($cmd);

  my $location = 0;  # var to hold the promoter location
  my $inFile;        # var for each input file entry

  open(FILE,"<". $files) or die "cannot open $files for reading: $!\n";
  my $fileNum = 0;
  while (<FILE>) {
    $inFile = $_;
    chop($inFile);

    # valid data files have .MAPP extension; other files are ignored
    if ($inFile =~/.*MAPP$/) {
      $fileNum++;
      $self->processFile($inFile, $location, $table, $fileNum);
      $self->log("Processing $inFile");
    } else {
      $self->log("NOT an input file: $inFile");
    }
  }
  $self->log("Total number of files processed = $fileNum");
  return 1;
}


sub processFile {
  my ($self, $inFile, $location, $table, $fileNum) = @_;
  my ($na_sequence_id, $source_id, $dir, $val);

  my $inFilePath = $self->getArg('inDir') . "/" .$inFile;
  my $outFile = $self->getArg('outFile');

  open(INFILE,"<". $inFilePath) or die "cannot open $inFile for reading: $!\n";
  open(OUTFILE, ">>" . $outFile) or die "cannot open $outFile for appending: $!\n";

#  if ($inFile =~ /^(.+)\.(.+)\.(.+)\.(.+)\.MAPP$/) {
  if ($inFile =~ /^(.+)\.(.+)\.MAPP$/) {
    ($source_id, $dir) = ($1, $2);   # gather chromosome source_id and strand info from filename
    $dir = ($dir eq "fwd")? 1: -1;

    $na_sequence_id = $self->getNaSeqId($source_id); # find na_sequence_id for chr source_id

    while (<INFILE>) {
      if ($_=~ m/^(.*)$/){
        print OUTFILE "LOAD DATA INFILE * INTO TABLE $table\n" .
          "FIELDS TERMINATED BY '\\t' (na_sequence_id, strand, location, value)\n" .
          "BEGINDATA\n" if ($fileNum == 1 && $location ==0);
        $location++;
	if ($1 > 0) {  # i.e. if there is a promoter (prediction value >0)
          $val = $1;
          chop($val);
          print OUTFILE "$na_sequence_id\t$dir\t$location\t$val\n";
        }
      }
    }
    $self->log("Loaded data from $inFile");
  }
  close(INFILE);
  close(OUTFILE);
}


sub getNaSeqId {
  my ($self, $src_id) = @_;

  my $dbh = $self->getQueryHandle();
  my $stmt = $dbh->prepare("SELECT na_sequence_id FROM dots.NASequence WHERE source_id = ?");
  $stmt->execute($src_id);
  my ($seq_id) = $stmt->fetchrow_array();
  $self->undefPointerCache();
  $self->log("na_sequence_id for $src_id = $seq_id");
  return $seq_id;
}

sub undoTables {
  my ($self) = @_;

  return ('ApiDB.plasmoMapp');
}


1;
