package ApiCommonData::Load::Plugin::LoadSignalP;
@ISA = qw(GUS::PluginMgr::Plugin);

#######################################
#       LoadSignalP.pm
#
# Written for Version 3.0 of SignalP
# Ed Robinson, Feb-March, 2005
# Checking and Logging added 5/9/05 - EAR
#######################################

use strict;

use DBI;
use Digest::MD5;
use Data::Dumper;
use CBIL::Util::Disp;
use GUS::PluginMgr::Plugin;
use GUS::Model::Core::Algorithm;
use GUS::Model::DoTS::SignalPeptideFeature;
use GUS::Model::DoTS::TranslatedAASequence;
use GUS::Model::DoTS::AALocation;


# ----------------------------------------------------------
# Load Arguments
# ----------------------------------------------------------

sub getArgsDeclaration {
my $argsDeclaration  =
[

fileArg({name => 'data_file',
         descr => 'text file containing external sequence annotation data',
         constraintFunc=> undef,
         reqd  => 1,
         isList => 0,
         mustExist => 1,
         format=>'Text'
        }),

fileArg({name => 'restart_file',
         descr => 'text file containg prior run data/for printing out cache',
         constraintFunc=> undef,
         reqd  => 0,
         isList => 0,
         mustExist => 0,
         format=>'Text'
        }),

stringArg({name => 'algName',
       descr => 'Name of algorithm used For predictions',
       constraintFunc=> undef,
       reqd  => 1,
       isList => 0
      }),

stringArg({name => 'algVer',
       descr => 'Version of algorithm used For predictions',
       constraintFunc=> undef,
       reqd  => 0,
       isList => 0
      }),

stringArg({name => 'algDesc',
       descr => 'Detailed description of use',
       constraintFunc=> undef,
       reqd  => 1,
       isList => 0
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

stringArg({name => 'project_name',
       descr => 'project this data belongs to - must in entered in GUS',
       constraintFunc=> undef,
       reqd  => 1,
       isList => 0
      }),

booleanArg({name => 'is_update_mode',
       descr => 'whether this is an update mode',
       constraintFunc=> undef,
       reqd  => 0,
       isList => 0,
       default => 0,
      }),

booleanArg({name => 'useSourceId',
       descr => 'Use source_id to link back to AASequence view',
       constraintFunc=> undef,
       reqd  => 0,
       isList => 0,
       default => 0,
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
CBS (Denmark) SignalP version 3.0 feature prediction application.  The 
application uses as input single line formatted output from the 
application run with BOTH the HMM and NN models.  When running signalP, 
begin with a spooled fasta output of AA sequences from GUS with GUSIDs, 
selecting only the first 70 residues of the 5' end of the aa sequence.  
Run Signal PP for BOTH HMM and NN models.  Select ONLY brief output 
with NO GRAPHICS.
example signalp output:
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
You may have to modify the fixed length positions of the features for 
your specific installation of signalP. This application assumes the 
short format output notation (NO GRAPHICS!!) from SignalP.  This output 
formats the data for each record on a single row and each prediction 
parameter is placed in its own fixed location.  Make sure the positions 
assumed in this application are correct for your installation.  Make 
sure you select BOTH HMMr and NN when you run it!.  And don't write a 
pre-formatting script, just modfy the field lengths for your own 
installation!
example: /usr/local/signalp3.0/signalp -t euk /home/input/signalp.fasta
SignalP-NN euk predictions                                                      SignalP-HMM euk predictions
name                Cmax  pos ?  Ymax  pos ?  Smax  pos ?  Smean ?  D     ?     name      !  Cmax  pos ?  Sprob ?
TGME49_112420-1       0.366  20 Y  0.306  20 N  0.664   6 N  0.348 N  0.327 N   TGME49_112420-1  Q  0.057  20 N  0.061 N
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
It shouldn't fail.  My plugins are always perfect.
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

      $self->initialize({requiredDbVersion => 3.5,
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
  $self->logAlgInvocationId;
  $self->logCommit;

  my $dataFile = $self->getArg('data_file') || die ('No Data File');

  my $hmmAlgId =  $self->getSetAlgorithm('HMM');

  my $nnAlgId =  $self->getSetAlgorithm('NN');

  my ($lnsInDb, $lnsInsrtd, $lnsCach, $lnsPrc) = 0;
  open(DATAFILE, "<$dataFile");
  while (my $line_in = <DATAFILE>) {
    next if $line_in =~ m/^#/;
    my $recordHash = $self->parseData($line_in); 
    my $hmmObj =$self-> buildRecord($recordHash,$hmmAlgId);
    my $hmmAaLoc = $self->makeLocation($recordHash,'HMM');
    $hmmObj->addChild($hmmAaLoc);
    if ($hmmObj->retrieveFromDB()) { 
      print 'Record already in GUS. Insert not attempted';
      $lnsInDb++;
    }
    else {
      eval { $hmmObj->submit(); };
      if ($@) {
	$self->handleFailure($hmmObj, $@); 
      }
      $lnsInsrtd++;
    }
    my $nnObj =$self-> buildRecord($recordHash,$nnAlgId);
    my $nnAaLoc = $self->makeLocation($recordHash,'NN');
    $nnObj->addChild($nnAaLoc);
    if ($nnObj->retrieveFromDB()) { 
      print 'Record already in GUS. Insert not attempted';
      $lnsInDb++;
    }
    else {
      eval { $nnObj->submit(); };
      if ($@) {
	$self->handleFailure($nnObj, $@); 
      }
      $lnsInsrtd++;
    }
    $lnsPrc++;
    $self->undefPointerCache();
  }
$self->log("LoadSignalP: Lines Processed; $lnsPrc \t Lines In Db: $lnsInDb \t Lines Inserted: $lnsInsrtd \n");
}

#Sub-routines
sub parseData {
   my ($self, $line_in) = @_;
   my @vals = split(/\s+/,$line_in);

   my $aaFeatId = $vals[0];
   $aaFeatId=~s/^\s+//;
   $aaFeatId=~s/\s+$//;

   my $cMaxScore = $vals[1];

   my $nnCleavageSite = $vals[5];

   my $cMaxConc = &translateC($vals[3]);

   my $yMaxScore = $vals[4];

   my $yMaxConc = &translateC($vals[6]);

   my $sMaxScore = $vals[7];

   my $sMaxConc = &translateC($vals[9]);

   my $meansScore = $vals[10];

   my $meansConc = &translateC($vals[11]);

   my $signProbability = $vals[19];

   my $hmmCleavageSite = $vals[17];
 
        if ($self->getArg('useSourceId')) {
           $aaFeatId = $self->retSeqIdFromSrcId($aaFeatId);
        }
 
         my $recordHash = { featId=>$aaFeatId,
                            cMax=>$cMaxScore,
                            cConc=>$cMaxConc,
                            sMax=>$sMaxScore,
                            sConc=>$sMaxConc,
                            yMax=>$yMaxScore,
                            yConc=>$yMaxConc,
                            means=>$meansScore,
                            meansC=>$meansConc,
                            sProb=>$signProbability,
                            hmmCleav=>$hmmCleavageSite,
                            nnCleav=>$nnCleavageSite
                           };

  return $recordHash;
}


# Build and return a GUS SignalPeptideFeature
sub buildRecord {
  my ($self, $recHash,$algId) = @_;

  my $algName = $self->getArg('algName');

  my $gusObj = GUS::Model::DoTS::SignalPeptideFeature->new({'aa_sequence_id' => $recHash->{'featId'}});

  $gusObj->setMaxyScore($recHash->{'yMax'});
  $gusObj->setMaxyConclusion($recHash->{'yConc'});
  $gusObj->setMaxcScore($recHash->{'cMax'});
  $gusObj->setMaxcConclusion($recHash->{'cConc'});
  $gusObj->setMaxsScore($recHash->{'sMax'});
  $gusObj->setMaxsConclusion($recHash->{'sConc'});
  $gusObj->setMeansScore($recHash->{'means'});
  $gusObj->setMeansConclusion($recHash->{'meansC'});
  $gusObj->setSignalProbability($recHash->{'sProb'});
  $gusObj->setPredictionAlgorithmId($algId);
  $gusObj->setAlgorithmName($algName);

  if (($recHash->{'meansC'}) == 0) {
    $gusObj->setIsPredicted(0); }
  else { $gusObj->setIsPredicted(1); }

  return $gusObj;
}


# Build and return a GUS AALocation object
sub makeLocation {
  my ($self, $recHash,$model) = @_;

  my $gusObj = GUS::Model::DoTS::AALocation->new();
    $gusObj->setStartMax(1);
    $gusObj->setStartMin(1);

  if ($model eq 'HMM') {
    $gusObj->setEndMax($recHash->{'hmmCleav'});
    $gusObj->setEndMin($recHash->{'hmmCleav'});
  }
  else {
    $gusObj->setEndMax($recHash->{'nnCleav'});
    $gusObj->setEndMin($recHash->{'nnCleav'});
  }

  return $gusObj;
}


# Build an algorithm entry for this data set. 
sub getSetAlgorithm {
  my ($self,$model) = @_;

  my $algName = $self->getArg('algName');

  $algName .= $model;

  my $algDesc = $self->getArg('algDesc');

  $algDesc .= "$model based";

  my $algEntry = GUS::Model::Core::Algorithm->new({'name' => $algName, 'description' => $algDesc});

  unless ($algEntry->retrieveFromDB()) {
    $algEntry->submit(); }

  my $algId = $algEntry->getId();

  return $algId;
}


sub translateC {
  my $tVal = shift;

 $tVal=~s/N/0/;
 $tVal=~s/Y/1/;

return $tVal;
}


sub handleFailure {
  my ($self, $err, $obj) = @_;

  $self->log("Failure Processing Entry\n\n");
  $self->log($err); 
  exit;
}


   sub retSeqIdFromSrcId {
      my ($self,$featId) = @_;

    my $dbRlsId = $self->getExtDbRlsId($self->getArg('extDbName'),$self->getArg('extDbRlsVer'));
    my $gusTabl = GUS::Model::DoTS::TranslatedAASequence->new( {  #BIG ASSUMPTION - all seqs from TranslatedAASequence
                     'source_id' => $featId, 
                     'external_database_release_id' => $dbRlsId,
                     } );

     $gusTabl->retrieveFromDB() || die ("Source Id $featId not found in TranslatedAASequence"); 
     my $seqId = $gusTabl->getId();

  return $seqId;
  }







return 1;

