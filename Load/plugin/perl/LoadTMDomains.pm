package ApiCommonData::Load::Plugin::LoadTMDomains;
@ISA = qw(GUS::PluginMgr::Plugin);

#######################################
#       LoadTMDomains.pm
#
# Written for TMHMM ver. 2.0 (CBS, Denmark) 
# Ed Robinson, Feb-March, 2005 
# updated for GUS 3.5, Sept. 2005
#modified D. Pinney Nov. 2005
#######################################


use strict;

use DBI;
use Digest::MD5;
use Data::Dumper;
use Tie::RefHash;
use CBIL::Util::Disp;
use GUS::PluginMgr::Plugin;
use GUS::Model::Core::Algorithm;
use GUS::Model::DoTS::TransMembraneAAFeature;
use GUS::Model::DoTS::AALocation;
use GUS::Model::DoTS::TranslatedAASequence;

use Bio::Tools::GFF;

$| = 1;

# Load Arguments
sub getArgsDeclaration {
my $argsDeclaration  =
[

fileArg({name => 'data_file',
         descr => 'gff file containing external sequence annotation data',
         constraintFunc=> undef,
         reqd  => 1,
         isList => 0,
         mustExist => 1,
         format=>'Text'
        }),


stringArg({name => 'extDbName',
       descr => 'External database from whence the data file you are loading came (original source of data)',
       constraintFunc=> undef,
       reqd  => 1,
       isList => 0
      }),

stringArg({name => 'extDbRlsVer',
       descr => 'Version of external database from whence the data file you are loading came (original source of data)',
       constraintFunc=> undef,
       reqd  => 1,
       isList => 0
      }),

];

return $argsDeclaration;
}



sub getDocumentation {

my $description = <<NOTES;
Written for version 2.0 of CBS (Denmark) TMHMM server software.  The plugin takes as input the tab delimited output of the brief output format from this software.  Make sure to choose the one line per protein output option. 

 Example: /usr/local/tmhmm -short -workdir=scratch/analysis  /home/TmmIn.fasta >/home/output/tmhmm.out

NOTES

my $purpose = <<PURPOSE;
Loads TM predictions from TMHMM Software output into GUS.
PURPOSE

my $purposeBrief = <<PURPOSEBRIEF;
Load TM Domain predictions including locations of tm domains into GUS.
PURPOSEBRIEF

my $syntax = <<SYNTAX;
Standard plugin syntax.
SYNTAX

my $notes = <<NOTES;
Make sure to clean up the top and bottom of the file.
An example of file format of input is at end of plugin.
Dots.transmembraneaafeature.topology has a value of 1 for tm features that start (amino end of protein) from o (ouside) and a value of 2 for i (inside).
Topology values are based on tm protein type definitions.
Each tm feature may contain 1 or more transmembrane helices.
Each helix has a corresponding row in dots.aalocation.
NOTES

my $tablesAffected = <<AFFECT;
Dots.TransMembraneAAFeature and Dots.AALocation.
AFFECT

my $tablesDependedOn = <<TABD;
dots.translatedaasequence or another view of dots.aasequenceimp.  TMHMM server takes AA sequences in fasta format with GUS Ids as input.
TABD

my $howToRestart = <<RESTART;
None.
RESTART

my $failureCases = <<FAIL;
None anticipated.
FAIL

my $documentation = {purpose=>$purpose, purposeBrief=>$purposeBrief,tablesAffected=>$tablesAffected,tablesDependedOn=>$tablesDependedOn,howToRestart=>$howToRestart,failureCases=>$failureCases,notes=>$notes};

return ($documentation);
}


######
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
  my ($self) = shift;

  $self->logAlgInvocationId;
  $self->logCommit;

  my ($lnsPrc, $lnsInsrt);

  my $dataFile = $self->getArg('data_file');

  my $fh;
  if($dataFile =~ /\.gz$/) {
    open($fh, "gzip -dc $dataFile |") or die "Could not open '$dataFile': $!";
  }
  else {
    open($fh, $dataFile) or die "Could not open '$dataFile': $!";
  }

  my $gffIo = Bio::Tools::GFF->new(-fh => $fh, -gff_version => 3);

  my %aaFeatureIds;

  #PF3D7_MIT02300.1-p1	veupathdb	tmhmm2.0	1	376	.	.	.	ID=PF3D7_MIT02300.1-p1_tmhmm;expectedAA=204.69;first60=22.86;predictedHelices=8
  #PF3D7_MIT02300.1-p1	veupathdb	TMhelix	24	46	.	.	.	ID=PF3D7_MIT02300.1-p1_tmhmm_2;Parent=PF3D7_MIT02300.1-p1_tmhmm
  while (my $feature = $gffIo->next_feature()) {

    my $primaryTag = $feature->primary_tag();

    # only load tmhmm results and locations of the helix(s)
    next unless($primaryTag eq 'tmhmm2.0' || $primaryTag eq 'TMhelix');

    my $proteinSourceId = $feature->seq_id();
    my $aaSeqId = $self->retSeqIdFromSrcId($proteinSourceId);

    $lnsPrc++;

    # tmhmm2.0 is the top level feature
    if($primaryTag eq 'tmhmm2.0') {
      my $tmFeat = $self->buildTmFeat($feature, $aaSeqId);

      $tmFeat->submit();
      my $tmFeatId = $tmFeat->getId();
      $aaFeatureIds{$proteinSourceId} = $tmFeatId;
      $lnsInsrt++;
    }
    # TMHelix (load the location associated with the tmfeature)
    else {
      my $parentFeatId = $aaFeatureIds{$proteinSourceId};

      my $aaLoc = $self->makeAALocation($parentFeatId, $feature);
      $aaLoc->submit();
    }

    $self->undefPointerCache();
  }

  my $resultDescrip = "LoadTMHmm: Lines Processed: $lnsPrc, Lines Inserted $lnsInsrt";

  $self->setResultDescr($resultDescrip);
  $self->logData($resultDescrip);
}

sub buildTmFeat {
  my ($self,$feature, $aaSeqId) = @_;

  my ($expectedAA) = $feature->get_tag_values('expectedAA');
  my ($first60) = $feature->get_tag_values('first60');
  my ($predictedHelices) = $feature->get_tag_values('predictedHelices');


  my $tmFeat = GUS::Model::DoTS::TransMembraneAAFeature->new({aa_sequence_id => $aaSeqId,
                                                              is_predicted => 1,
                                                              expected_aa => $expectedAA,
                                                              first_60 => $first60,
                                                              predicted_helices => $predictedHelices
                                                             });
  return $tmFeat;
}

sub makeAALocation {
  my ($self,$tmFeatId,$feature) = @_;

  my $start = $feature->start();
  my $end = $feature->end();

  my $aaLoc = GUS::Model::DoTS::AALocation->new({start_max => $start,
                                                 start_min => $start,
                                                 end_max => $end,
                                                 end_min => $end,
                                                 aa_feature_id => $tmFeatId
                                                });

  return $aaLoc;

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


sub handleFailure {
  my ($self, $err, $obj) = @_;

  print "Failure Processing Entry\n\n";
  print $err; 
  exit;
}

sub undoTables {
  my ($self) = @_;

  return ('DoTS.AALocation',
	  'DoTS.AAFeature'
	 );
}


1;

