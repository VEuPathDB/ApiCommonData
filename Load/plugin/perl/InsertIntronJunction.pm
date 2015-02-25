package ApiCommonData::Load::Plugin::InsertRUMIntronFeature;
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
  # GUS4_STATUS | DeprecatedTables               | auto   | absent
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | fixed
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

@ISA = qw(GUS::PluginMgr::Plugin);

# ----------------------------------------------------------
# Plugin to load date in apidb.RUMIntronFeature table
# ----------------------------------------------------------

use strict;
use warnings;

use GUS::PluginMgr::Plugin;
use GUS::Model::ApiDB::IntronJunction;

use GUS::Supported::Util;


# ----------------------------------------------------------
# Load Arguments
# ----------------------------------------------------------

sub getArgsDeclaration {
  my $argsDeclaration  =
    [
     stringArg({ name => 'inputFile',
		 descr => 'RUM result file that the plugin has to be run on',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0,
		 mustExist => 1,
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
     stringArg({ name => 'sampleName',
		 descr => 'sample Name',
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
Plugin to load RUM Exon Junction Calls in apidb.IntronJunction table
DESCR

  my $purpose = <<PURPOSE;
Plugin to load RUM Exon Junction Calls in apidb.IntronJunction table
PURPOSE

  my $purposeBrief = <<PURPOSEBRIEF;
Plugin to load RUM Exon Junction Calls in apidb.IntronJunction table
PURPOSEBRIEF

  my $notes = <<NOTES;
NOTES

  my $tablesAffected = <<AFFECT;
ApiDB.IntronJunction
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
                        cvsRevision => '$Revision$',
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

  my $extDbReleaseId = $self->getExtDbRlsId($self->getArg('extDbName'),$self->getArg('extDbVer'))
    || $self->error("Cannot find external_database_release_id for the data source");

  my $file = $self->getArg('inputFile');

  my $sampleName = $self->getArg('sampleName');

  $self->processFileAndInsertIntronJunctions($file, $extDbReleaseId, $sampleName);

  return "Processed $file.";
}



sub processFileAndInsertIntronJunctions {
  my ($self, $file, $extDbReleaseId, $sampleName) = @_;

  open (FILE, $file) or die "Cannot open file $file for reading: $!";

  my $count = 0; 

  while (<FILE>){
    chomp;

    next if (/^Junction/);

    my @temp = split("\t", $_);

    my ($seqSourceId,$location) = split(":", $temp[0]);

    my $naSeqId = GUS::Supported::Util::getNASequenceId($seqSourceId);

    my ($start, $end) = split("\-", $location);

    my $strand = $temp[1];
    my $unique = $temp[2];
    my $nu = $temp[3];

    my $score = $unique + $nu;

    my $isReversed = $strand eq '+' ? 0 : 1;

    my $rifeature = GUS::Model::ApiDB::IntronJunction->new({external_database_release_id => $extDbReleaseId,
                                                            sample_name => $sampleName,
                                                            na_sequence_id => $naSeqId,
                                                            mapping_start => $start,
                                                            mapping_end => $end,
                                                            is_reversed => $isReversed, 
                                                            score => $score,
                                                            unique_reads => $unique,
                                                            nu_reads => $nu,
                                                           });
    $rifeature->submit();
    $count++;
    $self->undefPointerCache() if $count % 1000 == 0;
  }
  close (FILE);

  $self->log("Inserted $count features from $file");

}


sub undoTables {
  my ($self) = @_;

  return ('ApiDB.IntronJunction');
}


return 1;
