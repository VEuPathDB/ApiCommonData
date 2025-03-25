package ApiCommonData::Load::Plugin::LoadSignalP;
@ISA = qw(GUS::PluginMgr::Plugin);


use strict;

use GUS::PluginMgr::Plugin;

use GUS::Model::DoTS::SignalPeptideFeature;
use GUS::Model::DoTS::AALocation;

use Bio::Tools::GFF;
use Data::Dumper;
# ----------------------------------------------------------
# Load Arguments
# ----------------------------------------------------------


sub getArgsDeclaration {
my $argsDeclaration  =
[

fileArg({name => 'gff_file',
         descr => 'gff file containing signalp data',
         constraintFunc=> undef,
         reqd  => 1,
         isList => 0,
         mustExist => 1,
         format=>'Text'
        }),


stringArg({name => 'extDbName',
       descr => 'External database from whence the data file you are loading came (original source of data)',
       constraintFunc=> undef,
       reqd  => 0,
       isList => 0
      }),

 stringArg({name => 'extDbRlsVer',
       descr => 'Version of external database from whence the data file you are loading came (original source of data)',
       constraintFunc=> undef,
       reqd  => 0,
       isList => 0
      }),

];

return $argsDeclaration;
}


# ----------------------------------------------------------
# Documentation
# ----------------------------------------------------------

sub getDocumentation {

my $description = <<NOTES;
An application for loading SignalPeptide predictions into GUS from the 
CBS (Denmark) SignalP version 4,5,6 feature prediction application.  
NOTES

my $purpose = <<PURPOSE;
LoadSignalP loads the out put of the CBS (Denmark) SignalP application 
into the GUS view Dots.SignalPeptideFeature.
PURPOSE

my $purposeBrief = <<PURPOSEBRIEF;
Load Signal Peptide Data into GUS.
PURPOSEBRIEF

my $syntax = <<SYNTAX;
Standard Plugin Syntax.
SYNTAX

my $notes = <<NOTES;
will load output from nextflow veupath/signalp workflow
NOTES


my $tablesAffected =   [
   ['DoTS.AAFeatureImp',
    '(SignalPeptideFeature sub_class view)'
   ],
  ];

my $tablesDependedOn = [
   ['DoTS.AASequenceImp',
    'Contains the AASequence used by the SignalP 
predictor'
   ],
  ];

my $howToRestart = <<RESTART;
There are no restart facilities at the present time.
RESTART

my $failureCases = <<FAIL;
It won't fail.  My plugins are always perfect.
FAIL

my $documentation = { purpose=>$purpose, 
                      purposeBrief=>$purposeBrief,
                      tablesAffected=>$tablesAffected,
                      tablesDependedOn=>$tablesDependedOn,
                      howToRestart=>$howToRestart,
                      failureCases=>$failureCases,
                      notes=>$notes
                     };

return ($documentation);

}


##############################################################
#Let there be objects!
##############################################################
sub new {
   my $class = shift;
   my $self = {};
   bless($self, $class);

      my $documentation = &getDocumentation();

      my $args = &getArgsDeclaration();

      $self->initialize({requiredDbVersion => 4.0,
                 cvsRevision => '$Revision$',
                 cvsTag => '$Name:  $',
                 name => ref($self),
                 revisionNotes => '',
                 argsDeclaration => $args,
                 documentation => $documentation
                });

   return $self;
}


#Main Routine
sub run{
  my $self = shift;

  my $lnsPrc;

  my $dbRlsId = $self->getExtDbRlsId($self->getArg('extDbName'), $self->getArg('extDbRlsVer'));

  my $gffFile = $self->getArg('gff_file') || die ('No Data File');

  my $fh;
  if($gffFile =~ /\.gz$/) {
    open($fh, "gzip -dc $gffFile |") or die "Could not open '$gffFile': $!";
  }
  else {
    open($fh, $gffFile) or die "Could not open '$gffFile': $!";
  }

  my $gffIo = Bio::Tools::GFF->new(-fh => $fh, -gff_version => 3);


  # PF3D7_0100600.1-p1	SignalP-4.1	SIGNAL	1	24	0.819	.	.ID=sp4_PF3D7_0100600.1-p1
  # PF3D7_0100600.1-p1	SignalP-5.0	signal_peptide	1	24	0.899926.	.	ID=sp5_PF3D7_0100600.1-p1
  # PF3D7_0100600.1-p1	SignalP-6.0	n-region	1	2	.	..	ID=sp6_PF3D7_0100600.1-p1_1_2;Parent=sp6_PF3D7_0100600.1-p1
  # PF3D7_0100600.1-p1	SignalP-6.0	signal_peptide	1	21	0.84309596	.	.	ID=sp6_PF3D7_0100600.1-p1
  # PF3D7_0100600.1-p1	SignalP-6.0	h-region	3	19	.	..	ID=sp6_PF3D7_0100600.1-p1_3_19;Parent=sp6_PF3D7_0100600.1-p1
  # PF3D7_0100600.1-p1	SignalP-6.0	c-region	20	21	.	..	ID=sp6_PF3D7_0100600.1-p1_20_21;Parent=sp6_PF3D7_0100600.1-p1
  while (my $feature = $gffIo->next_feature()) {

    my $primaryTag = $feature->primary_tag();
    my $sourceTag = $feature->source_tag();

    next unless($sourceTag =~ /^SignalP/ && lc($primaryTag) =~ /signal/);

    my $proteinSourceId = $feature->seq_id();
    my $aaSeqId = $self->retSeqIdFromSrcId($proteinSourceId);
    my $signalProbability = $feature->score();

    my $start = $feature->start();
    my $end = $feature->end();

    my $spFeat = GUS::Model::DoTS::SignalPeptideFeature->new({aa_sequence_id => $aaSeqId,
                                                               algorithm_name => $sourceTag,
                                                               signal_probability => $signalProbability,
                                                             is_predicted => 0});

    my $aaLoc = GUS::Model::DoTS::AALocation->new({start_min => $start,
                                                  start_max => $start,
                                                  end_min => $end,
                                                  end_max => $end});

    $aaLoc->setParent($spFeat);

    $spFeat->submit();

    $lnsPrc++;
    $self->undefPointerCache();
  }

  $self->log("LoadSignalP: Lines Processed; $lnsPrc");
}



sub retSeqIdFromSrcId {
  my ($self,$seqId) = @_;

  if(my $aaSeqId = $self->{_aa_sequence_ids}->{$seqId}) {
    return $aaSeqId;
  }

  my $dbh = $self->getQueryHandle();
  my $dbRlsId = $self->getExtDbRlsId($self->getArg('extDbName'),$self->getArg('extDbRlsVer'));

  my $sql = "select source_id, aa_sequence_id from dots.translatedaasequence where external_database_release_id = ?";

  my $sh = $dbh->prepare($sql);
  $sh->execute($dbRlsId);

  while(my ($sourceId, $aaSeqId) = $sh->fetchrow_array()) {
    $self->{_aa_sequence_ids}->{$sourceId} = $aaSeqId;
  }

  my $aaSeqId = $self->{_aa_sequence_ids}->{$seqId};

  unless($aaSeqId) {
    $self->error("Could not retrieve aa_sequence_id for $seqId");
  }

  return $aaSeqId;
}



sub undoTables {
  my ($self) = @_;

  return ('DoTS.AALocation',
	  'DoTS.AAFeature',
	 );
}


  1;
