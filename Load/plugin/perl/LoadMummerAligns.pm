package ApiCommonData::Load::Plugin::LoadMummerAligns;
@ISA = qw(GUS::PluginMgr::Plugin);

#######################################
#       LoadMummerAligns.pm
#            Beta 1.0
#
# Written for Version 3.0 of MUMer
# basic alignment out put of draft sequence
# comparissons created by NUCmer
#
# Ed Robinson, April, 2005
#######################################

use strict;

use DBI;
use Tie::RefHash;
use CBIL::Util::Disp;
use GUS::PluginMgr::Plugin;
use GUS::Model::Core::Algorithm;
use GUS::Model::DoTS::ExternalNASequence;
use GUS::Model::DoTS::Similarity;
use GUS::Model::DoTS::SimilaritySpan;

sub getArgsDeclaration {
my $argsDeclaration  =
[

fileArg({name => 'data_file',
         descr => 'text file containing external sequence annotation data. Must be a ref_qry.cluster file.',
         constraintFunc=> undef,
         reqd  => 1,
         isList => 0,
         mustExist => 1,
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
       reqd  => 1,
       isList => 0
      }),

stringArg({name => 'algDesc',
       descr => 'Detailed description of use',
       constraintFunc=> undef,
       reqd  => 1,
       isList => 0
      }),

stringArg({name => 'refDbName',
       descr => 'External database from whence the reference data came (original source of data)',
       constraintFunc=> undef,
       reqd  => 1,
       isList => 0
      }),
                                                                                                                             
stringArg({name => 'refDbRlsVer',
       descr => 'Version of external database from whence the reference came (original source of data)',
       constraintFunc=> undef,
       reqd  => 1,
       isList => 0
      }),
stringArg({name => 'queryDbName',
       descr => 'External database from whence the reference data came (original source of data)',
       constraintFunc=> undef,
       reqd  => 1,
       isList => 0
      }),
                                                                                                                             
stringArg({name => 'queryDbRlsVer',
       descr => 'Version of external database from whence the reference came (original source of data)',
       constraintFunc=> undef,
       reqd  => 1,
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
];

return $argsDeclaration;
}


sub getDocumentation {

my $description = <<NOTES;
Loads Nucmer output for Nuc to Nuc comparissons only.  Cannot handle shifting frames.  Loads ref_qry.cluster output.
NOTES

my $purpose = <<PURPOSE;
Loading output from Nucmer for nucleotide based comparisson of similar genomes.
PURPOSE

my $purposeBrief = <<PURPOSEBRIEF;
Loading mummer comparissons.
PURPOSEBRIEF

my $syntax = <<SYNTAX;
SYNTAX

my $notes = <<NOTES;
Cannot handle shifting farms, only 1/-1 complementation of query string in a direct nucleotide to nucleotide comparisson.  Future versions should handle frame shifting of translating applications.
NOTES

my $tablesAffected = <<AFFECT;
Core.algorithm
Dots.Similarity
Dots.SimilaritySpan
AFFECT

my $tablesDependedOn = <<TABD;
sres.externaldatabase
sres.externaldatabaserelease
TABD

my $howToRestart = <<RESTART;
RESTART

my $failureCases = <<FAIL;
FAIL

my $documentation = {purpose=>$purpose, purposeBrief=>$purposeBrief,tablesAffected=>$tablesAffected,tablesDependedOn=>$tablesDependedOn,howToRestart=>$howToRestart,failureCases=>$failureCases,notes=>$notes};

return ($documentation);

}

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


sub setContext{
   my $self = shift;

   my $algId = getSetAlgorithm($self->getArg('algName'), $self->getArg('algVer'), $self->getArg('algDesc'));
   my $sourceTableId = $self->getSourceTable;

   $self->{'SourceTable'} = $sourceTableId;
   $self->{'AlgId'} = $algId;
   $self->{'MatchNum'} = 0;
   $self->{'MinSubjectStart'} = 999999999;
   $self->{'MaxSubjectEnd'} = 0;
   $self->{'MinQueryStart'} = 999999999;
   $self->{'MaxQueryEnd'} = 0;

return;
}


#Main Routine
sub run{
  my $self = shift;

  $self->logAlgInvocationId;
  $self->logCommit;
  $self->setContext;

   my $args = $self->getArgs();
   my $dataFile = $self->getArg('data_file'); 

   my $lineCnt = 0;
   my $simNum = 0;
   my (@simSpans, $refStr, $queryStr, $refEnd, $queryEnd, $spanNum, $rev);

   open(DATAFILE, "<$dataFile");
     while (<DATAFILE>) {
          if (/^\>/) {
               $self->buildAndSubmit($refStr, $queryStr, $refEnd, $queryEnd, $spanNum, $rev, @simSpans);
               undef @simSpans;
               $rev = 0; 
               ($refStr, $queryStr, $refEnd, $queryEnd) = split(/\s/,substr($_,1));
               $simNum++;
           } 
          elsif (/^\s1\s\-1/) { #Only handles Nucmer values
              $rev = 1;
          }
          else {
              tr/-/0/;
              my @simSpan = split(/(?<=\d)\s+/,$_);
              unless (scalar(@simSpan) != 5) {
                 push @simSpans, \@simSpan;
              }
          }
      $lineCnt++;
    }
    my $matchNum = $self->{'MatchNum'};
$self->log("LoadMummerAligns: Lines Processed; $lineCnt \t Similarities; $simNum \t Spans; $matchNum\t \n");
}



sub buildAndSubmit {
     my ($self, $refStr, $queryStr, $refEnd, $queryEnd, $spanNum, $rev, @simSpans) = @_;

   my $sourceTableId = $self->{'SourceTable'};
   my $algId = $self->{'AlgId'};
   my $matchNum = 0;

          if ($refStr) {
                 my $sim = $self->createSim(
                      $sourceTableId, $algId, $refStr, $queryStr, $refEnd, $queryEnd, $spanNum, $rev);
                 foreach my $span (@simSpans) {
                      my $simSpan=$self->createSimSpan($span);
                      $sim->addChild($simSpan);
                      $matchNum++;
                 }
                 $sim = $self->finishSim($sim,$matchNum);
                 unless ( $sim->retrieveFromDB() ) {
                           $sim->submit();
                           $self->undefPointerCache();
                 }
          }
   my $globalMatch = $self->{'MatchNum'};
   $self->{'MatchNum'} = $matchNum + $globalMatch;
return 1;
}



sub finishSim {
   my ($self, $sim, $matchNum) = @_;

   $sim->setMinSubjectStart($self->{'MinSubjectStart'});
   $sim->setMaxSubjectEnd($self->{'MaxSubjectEnd'});
   $sim->setMinQueryStart($self->{'MinQueryStart'});
   $sim->setMaxQueryEnd($self->{'MaxQueryEnd'});
   $sim->setNumberOfMatches($matchNum);

   $self->setContext();

return $sim;
}



sub getSourceTable{
my $tableObj = GUS::Model::Core::TableInfo->new(); 
   $tableObj->setName('NASequenceImp');
   $tableObj->retrieveFromDB();

   my $tableId = $tableObj->getId();

return $tableId;
}


sub createSim{
  my ($self, $sourceTableId, $algId, $refStr, $queryStr, $refEnd, $queryEnd, $matchNum, $rev) = @_;

  my $gusSim = GUS::Model::DoTS::Similarity->new(); 
   #$gusSim->setAlgorithmId($algId);
   $gusSim->setSubjectTableId($sourceTableId);
   $gusSim->setQueryTableId($sourceTableId);
   $gusSim->setSubjectId($refStr);
   $gusSim->setQueryId($queryStr);
   $gusSim->setIsReversed($rev);
   $gusSim->setMinSubjectStart(1); #here down meaningless, table requires 
   $gusSim->setMaxSubjectEnd($refEnd);
   $gusSim->setMinQueryStart(1); 
   $gusSim->setMaxQueryEnd($queryEnd);
   $gusSim->setNumberOfMatches($matchNum);
   $gusSim->setScore(0);
   $gusSim->setPvalueMant(0);
   $gusSim->setPvalueExp(0);
   $gusSim->setTotalMatchLength(0);
   $gusSim->setNumberIdentical(0);
   $gusSim->setNumberPositive(0);

return $gusSim;
}


sub createSimSpan{
  my ($self, $span) = @_;
  my $gusSim = GUS::Model::DoTS::SimilaritySpan->new(); 
   $gusSim->setMatchLength($span->[2]);
   $gusSim->setSubjectStart($span->[0]);
   $gusSim->setSubjectEnd($span->[0] + $span->[2]); 
   $gusSim->setQueryStart($span->[1]);
   $gusSim->setQueryEnd($span->[1] + $span->[2]);
   $gusSim->setIsReversed(0); #here down meaningless, but table requires
   $gusSim->setMatchLength(0);
   $gusSim->setNumberIdentical(0);
   $gusSim->setNumberPositive(0);
   $gusSim->setScore(0);
   $gusSim->setBitScore(0);
   $gusSim->setPvalueMant(0);
   $gusSim->setPvalueExp(0);

   $self->setSimMinMax($span);

return $gusSim;
}


sub setSimMinMax {
   my ($self, $span) = @_;
   
   my $sStrt = $span->[0];
   my $sEnd = ($span->[0] + $span->[2]); 
   my $qStrt = $span->[1];
   my $qEnd = ($span->[1] + $span->[2]);

    if ($sStrt < ($self->{'MinSubjectStart'})) {
        $self->{'MinSubjectStart'} = $sStrt;
    }
   
    if ($sEnd > ($self->{'MaxSubjectEnd'})) {
       $self->{'MaxSubjectEnd'} = $sEnd;
    }

    if ($qStrt < ($self->{'MinQueryStart'})) {
       $self->{'MinQueryStart'} = $qStrt;
    }

    if ($qEnd > ($self->{'MaxQueryEnd'})) {
       $self->{'MaxQueryEnd'} = $qEnd;
    }

return 1;
}




sub getSetAlgorithm {
  my ($self, $algName, $algVer, $algDesc) = @_;
  
  my $gusAlg = GUS::Model::Core::Algorithm->new(); 
    $gusAlg->setName("$algName $algVer");
    $gusAlg->setDescription($algDesc);

  #unless ($gusAlg->retrieveFromDB()) { 
  #Only way is to get this back via invocationID, 
  #so submit info with EACH invocation so it is available
    $gusAlg->submit();
  #}

  my $algId = $gusAlg->getId();

return $algId;
}

1;

=cut
/scratch/erobinso/MUMMer/C_parvum.out /scratch/erobinso/MUMMer/C_hominis.out
NUCMER
>8139 6171 446 58905
 1  1
       1    41055     84     -      -
      86    41140     80     1      1
     167    41221    131     1      1
     314    41368    115    16     16
>6148 6171 1278458 58905
 1 -1
  457600    58905    180     -      -
  457781    58724    138     1      1
  457926    58579     23     7      7
  457950    58555     25     1      1
  457976    58529    132     1      1
  458118    58387    215    10     10
  458334    58171     50     1      1
  458385    58120     29     1      1
  458433    58072     44    19     19
  458478    58027     30     1      1
  458519    57986     34    11     11
  458554    57951     49     1      1
  458604    57901     46     1      1
  458651    57854     96     1      1
  458748    57757     20     1      1
  458769    57736     26     1      1
  458796    57709     32     1      1
  458829    57676     22     1      1
...... etc.



