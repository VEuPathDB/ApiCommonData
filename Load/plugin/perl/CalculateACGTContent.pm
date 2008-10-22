package ApiCommonData::Load::Plugin::CalculateACGTContent;

use strict;
use warnings;

use GUS::PluginMgr::Plugin;
use base qw(GUS::PluginMgr::Plugin);

use GUS::Model::DoTS::NASequence;
use Bio::Tools::SeqStats;

my $argsDeclaration =[


 booleanArg({
               name            =>  'nullsOnly', 
               descr           =>  'if true only calculate for the ones when all residue counts are null',
               reqd            =>  0,
               isList          =>  0
              }),




];

my $purposeBrief = <<PURPOSEBRIEF;
Calculates the A,C,G,T, other counts for NA sequences.
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
Calculates the counts for the different nucleic acids for all of the NA sequences for a given external database release.
PLUGIN_PURPOSE

my $tablesAffected =
  [
   ['DoTS.NASequence' =>
    'the A/C/G/T_count fields are updated if the entry exists'
   ],
  ];

my $tablesDependedOn = [];

my $howToRestart = <<PLUGIN_RESTART;
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
PLUGIN_FAILURE_CASES

my $notes = <<PLUGIN_NOTES;
PLUGIN_NOTES

my $documentation = { purposeBrief => $purposeBrief,
		      purpose => $purpose,
		      tablesAffected => $tablesAffected,
		      tablesDependedOn => $tablesDependedOn,
		      howToRestart => $howToRestart,
		      failureCases => $failureCases,
		      notes => $notes,
		    };

sub new {

  my $class = shift;
  $class = ref $class || $class;
  my $self = {};

  bless $self, $class;

  $self->initialize({ requiredDbVersion => 3.5,
		      cvsRevision =>  '$Revision$',
		      name => ref($self),
		      argsDeclaration   => $argsDeclaration,
		      documentation     => $documentation
		    });
  return $self;
}

sub run {
  my ($self) = @_;
  my @seqArray;
  my $count=0;

  $self->getSeqId(\@seqArray);

  foreach my $seqId (@seqArray){
    $self->getMonomerCount($seqId);

    $count++;
    if($count % 1000 == 0) {
      $self->log("Updated $count sequences.");
      $self->undefPointerCache();
    }

  }

  return $self->log("Successfully updated $count sequences.");
}

sub getSeqId{
  my ($self, $seqArray) = @_;

 my $sql = <<EOSQL;
SELECT distinct na_sequence_id
      FROM DoTS.NASequence
EOSQL

if ($self->getArg('nullsOnly')){

 $sql = <<EOSQL;
SELECT distinct na_sequence_id
      FROM DoTS.NASequence
WHERE a_count is null and t_count is null and c_count is null and g_count is null

EOSQL
}
  my $queryHandle = $self->getQueryHandle();
  my $sth = $queryHandle->prepareAndExecute($sql);

  while(my $seqId = $sth->fetchrow_array()){
    push(@$seqArray, $seqId);
  }
}

sub getMonomerCount{
  my ($self, $seqId)=@_;
  my $monomersHash;
  my $countA = 0;
  my $countT = 0;
  my $countC = 0;
  my $countG = 0;
  my $countOther = 0;

  my $naSeqObj = GUS::Model::DoTS::NASequence->new({na_sequence_id => $seqId});
  $naSeqObj->retrieveFromDB();
  my $naSeq = $naSeqObj->getSequence();

  $naSeq =~ s/-//g;

  my $seqobj = Bio::PrimarySeq->new(-seq=>$naSeq,
				    -alphabet=>'dna');

  my $seqStats  =  Bio::Tools::SeqStats->new(-seq=>$seqobj);

  $monomersHash = $seqStats->count_monomers();
  foreach my $base (keys %$monomersHash) {
    if ($base eq 'A'){
      $countA = $$monomersHash{$base};
    }
    elsif ($base eq 'T'){
      $countT = $$monomersHash{$base};
    }
    elsif ($base eq 'C'){
      $countC = $$monomersHash{$base};
    }
    elsif ($base eq 'G'){
      $countG = $$monomersHash{$base};
    }
    else{
      $countOther = $$monomersHash{$base};
    }
  }

  $naSeqObj->setACount($countA);
  $naSeqObj->setTCount($countT);
  $naSeqObj->setCCount($countC);
  $naSeqObj->setGCount($countG);
  $naSeqObj->setOtherCount($countOther);

  $naSeqObj->submit();
  $self->undefPointerCache();
}

1;
