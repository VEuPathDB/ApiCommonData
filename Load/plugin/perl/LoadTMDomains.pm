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

$| = 1;

# Load Arguments
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
         descr => 'text file containing external sequence annotation data',
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

stringArg({name => 'algDesc',
       descr => 'Detailed description of use',
       constraintFunc=> undef,
       reqd  => 1,
       isList => 0
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

booleanArg({name => 'useSourceId',
       descr => 'Use source_id to link back to AASequence view',
       constraintFunc=> undef,
       reqd  => 0,
       isList => 0,
       default => 0,
      })
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
  my ($self) = shift;

  $self->logAlgInvocationId;
  $self->logCommit;

  my ($lnsPrc, $lnsInsrt);

  my $dataFile = $self->getArg('data_file');

  my $algId = $self->getSetAlgorithm();

  open (DATAFILE, "$dataFile");

  while (<DATAFILE>) {
    my $line_in = $_;

    $lnsPrc++;

    my ($attVals,$locs) =  $self->parseAttVals($line_in,$algId);

    next if (!$attVals);

    $self->error("AA locations missing for aa_sequence_id = $attVals->{'aa_sequence_id'}\n") if (!$locs);

    my $tmFeat = $self->buildTmFeat($attVals);

    if ($tmFeat->retrieveFromDB()) { 
      print 'Record already in GUS. Insert not attempted';
    }
    else {
      $self->makeAALocations($tmFeat,$locs);
      eval { $tmFeat->submit(); };
      if ($@) { 
	$self->handleFailure($@,$tmFeat);
      }
      $lnsInsrt++;
    }
    $self->undefPointerCache();
  }

  my $resultDescrip = "LoadTMHmm: Lines Processed: $lnsPrc, Lines Inserted $lnsInsrt";

  $self->setResultDescr($resultDescrip);
  $self->logData($resultDescrip);
}

sub parseAttVals{
  my ($self,$line_in,$algId) = @_;

  $line_in =~ s/\w+\=//g;

  my %attVals;

  my @Record = split(/\t/,$line_in);

  return if ($Record[4] == 0);

  if ($self->getArg('useSourceId')) {
    my $aaSeqId = $self->retSeqIdFromSrcId($Record[0]);
    $Record[0] = $aaSeqId;
  }

  $attVals{'aa_sequence_id'} = $Record[0];

  $attVals{'length'} = $Record[1];

  $attVals{'expected_aa'} = $Record[2];

  $attVals{'first_60'} = $Record[3];

  $attVals{'predicted_helices'} = $Record[4];

  $attVals{'is_predicted'} = 1;

  $attVals{'prediction_algorithm_id'} = $algId;

  my $topology = $Record[5];

  my ($tmType,$locs) = $self->parseTopology($topology);

  $self->error("Can't get the TM protein type or locations for $attVals{'aa_sequence_id'}\n") if (!$tmType || !$locs);

  $attVals{'topology'} = $tmType;

  return (\%attVals,$locs);
}

sub parseTopology {
  my ($self,$topology) = @_;

  $topology =~ s/\s//g;

  my ($tmType,$tmStart);

  if ($topology =~ /^(i|o)/) {
    $tmStart = $1;

    $topology =~ s/^\w//;

    $tmType = $tmStart eq 'o' ? 1 : 2;

  }
  else {
    return;
  }

  my @locs = split(/i|o/,$topology);

  return ($tmType,\@locs);
}

sub buildTmFeat {
  my ($self,$attVals) = @_;

  my $tmFeat = GUS::Model::DoTS::TransMembraneAAFeature->new($attVals);

  return $tmFeat;
}

sub makeAALocations {
  my ($self,$tmFeat,$aaLocs) = @_;

  foreach my $loc (@$aaLocs) {

    if ($loc =~ /(\d+)-(\d+)/) {
      my $aaLoc = GUS::Model::DoTS::AALocation->new({'start_max'=>$1,'start_min'=>$1,'end_max'=>$2,'end_min'=>$2});

      $aaLoc->setParent($tmFeat);
    }
    else {
      $self->error("Can't parse location\n");
    }
  }
}

sub getSetAlgorithm {
  my ($self) = @_;

  my $algName = $self->getArg('algName');

  my $algDesc = $self->getArg('algDesc');

  my $algEntry = GUS::Model::Core::Algorithm->new({'name' => $algName, 'description' => $algDesc});

  unless ($algEntry->retrieveFromDB()) {
    $algEntry->submit(); }

  my $algId = $algEntry->getId();

  return $algId;
}


sub retSeqIdFromSrcId {
  my ($self,$seqId) = @_;

  my $dbRlsId = $self->getExtDbRlsId($self->getArg('extDbName'),$self->getArg('extDbRlsVer'));
  my $gusTabl = GUS::Model::DoTS::TranslatedAASequence->new( {  #BIG ASSUMPTION - all seqs from TranslatedAASequence
							      'source_id' => $seqId, 
							      'external_database_release_id' => $dbRlsId,
							     } );

  $gusTabl->retrieveFromDB() || die ("Source Id $seqId not found in TranslatedAASequence with external database release id of $dbRlsId"); 
  my $aaSeqId = $gusTabl->getId();

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
	  'DoTS.AAFeature','Core.Algorithm'
	 );
}


1;

=cut
	#Single line, tab delimited, output
        #5H2A_CRIGR	len=471	ExpAA=159.47	First60=0.02	PredHel=7	Topology=o77-99i112-134o149-171i192-214o234-256i325-347o357-379i
