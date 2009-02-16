package ApiCommonData::Load::Plugin::InsertLowComplexityFeature;

@ISA = qw(GUS::PluginMgr::Plugin);

# ----------------------------------------------------------------------

use strict;

use GUS::PluginMgr::Plugin;
use GUS::PluginMgr::PluginUtilities;
use GUS::PluginMgr::PluginUtilities::ConstraintFunction;

use FileHandle;

use Bio::SeqIO;
use Bio::Seq;

use GUS::Model::DoTS::LowComplexityNAFeature;
use GUS::Model::DoTS::LowComplexityAAFeature;
use GUS::Model::DoTS::NALocation;
use GUS::Model::DoTS::AALocation;


my $argsDeclaration =
[

 fileArg({name           => 'seqFile',
	  descr          => 'A File of Sequence Data.',
	  reqd           => 1,
	  mustExist      => 1,
	  format         => 'BioPerl SeqIO Compatible (see format)',
	  constraintFunc => undef,
	  isList         => 0, 
	 }),

 stringArg({ name => 'fileFormat',
	     descr => 'BioPerl SeqIO compatible format (ex. fasta)',
	     isList    => 0,
	     reqd  => 1,
	     constraintFunc => undef,
	   }),

 stringArg({ descr => 'Name of the External Database',
	     name  => 'extDbName',
	     isList    => 0,
	     reqd  => 1,
	     constraintFunc => undef,
	   }),

 stringArg({ descr => 'Version of the External Database Release',
	     name  => 'extDbVersion',
	     isList    => 0,
	     reqd  => 1,
	     constraintFunc => undef,
	   }),

 enumArg({ descr => 'Type of Sequence:  dna or protein',
	   name  => 'seqType',
	   isList    => 0,
	   reqd  => 1,
	   constraintFunc => undef,
	   enum => "dna, protein",
	   }),

# enumArg({ descr => 'Table where the DNA sequence is located: DoTS.ExternalNASequence or DoTS.VirtualSequence.  Required if using --seqType dna.',
#           name  => 'dnaSeqTable',
#           isList    => 0,
#           reqd  => 0,
#           constraintFunc => undef,
#           enum => "DoTS.ExternalNASequence, DoTS.VirtualSequence",
#           }),

 stringArg({ descr => 'Character which masks the low complexity region',
	     name  => 'maskChar',
	     isList    => 0,
	     reqd  => 1,
	     constraintFunc =>  sub {
	       my ($self, $m) = @_;
	       return("maskChar must be exaclty one character\n") if length($m) !=  1;
	     }
	   }),

 stringArg({ descr => 'Name Field for the LC Describing the Type of Analysis (Required for NA)',
	     name  => 'LowComplexityName',
	     isList    => 0,
	     reqd  => 0,
	     constraintFunc => undef,
	   }),

];

my $purpose = <<PURPOSE;
The purpose of this plugin is to load LowComplexity data from a file containing
amino acid or nucleic acid sequences.  The input file contains Sequence data in a 
Bio::SeqIO compatible format which has been processed with a low complexity 
algorythm.  These processed files will contain sequence data matching 
Dots.NASequence or Dots.AASequence sequences with the exception that regions of 
low complexity will be marked with a "mask" character.  The plugin will
generate rows corresponding to these Features and Locations of Low Complexity
regions accordingly.
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
The purpose of this plugin is to load LowComplexity data from a file containing
amino acid or nucleic acid sequences.
PURPOSE_BRIEF

my $notes = <<NOTES;
NOTES

my $tablesAffected = <<TABLES_AFFECTED;
DoTS::LowComplexityNAFeature, DoTS::LowComplexityAAFeature, Dots::AALocation, Dots::NALocation
TABLES_AFFECTED

my $tablesDependedOn = <<TABLES_DEPENDED_ON;
SRes::ExternalDatabase, SRes::ExternalDatabaseRelease, DoTS::NASequence, DoTS::AASequence
TABLES_DEPENDED_ON

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

my $featuresLoaded = 0;

# ----------------------------------------------------------------------

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  $self->initialize({ requiredDbVersion => 3.5,
		      cvsRevision       => '$Revision$',
		      name              => ref($self),
		      argsDeclaration   => $argsDeclaration,
		      documentation     => $documentation});

  return $self;
}

# ======================================================================

sub run {
  my ($self) = @_;

  my $type = $self->getArgs()->{seqType};

  if($type eq 'dna' && !$self->getArgs()->{LowComplexityName}) {
    die "LowComplexityName Arg Required If loading NA Features!\n";
  }

  my $dbReleaseId = $self->getExtDbRlsId($self->getArgs()->{extDbName}, 
					 $self->getArgs()->{extDbVersion});

  my $seqFile = $self->getArgs()->{seqFile};
  my $fileFormat = $self->getArgs()->{fileFormat};

  my $inSeq = Bio::SeqIO-> new('-file'   => "< $seqFile",
			       '-format' => $fileFormat,
			      );

  while (my $seq = $inSeq->next_seq) {
    my $accession = $seq->id;
    my $dbSeq = $self->_getMatchingSequence($accession, $dbReleaseId);

    my $startStop = $self->_getStartStop($seq, $dbSeq);

    if($self->getArgs()->{seqType} eq 'dna') {
      $self->_loadNaLcFeature($dbSeq, $startStop, $dbReleaseId);
    }
    else {
      $self->_loadAaLcFeature($dbSeq, $startStop, $dbReleaseId);
    }
  }
  return("Inserted $featuresLoaded LowComplexityXXFeatures and XXLocations\n");

}

# ----------------------------------------------------------------------

=pod

=head2 Subroutines

=over 4

=item C<_getMatchingSequences($accession, $dbReleaseId)>

Query for sequence glob based on dbRelease Id and a source_id (accession).

B<Parameters:>

- accession(string):  Source Id from an externalDB
- dbReleaseId(int):  an external_database_release_id from SRes::ExternalDataBaseRelease

B<Return type:> C<Bio::Seq>

=cut

sub _getMatchingSequence {
  my ($self, $accession, $dbReleaseId) = @_;

  my $type = $self->getArgs()->{seqType};
  #my $table = $self->getArgs()->{dnaSeqTable};
  my $sql;

  if($type eq 'dna') {
     # $sql = "SELECT na_sequence_id, sequence 
#               FROM Dots.NASEQUENCE 
#               WHERE na_sequence_id in
#                 (select na_sequence_id 
#                   from Dots.EXTERNALNASEQUENCE 
#                   where source_id = '$accession'
#                    and external_database_release_id = $dbReleaseId)
#               OR na_sequence_id in
#                 (select na_sequence_id 
#                   from Dots.VIRTUALSEQUENCE 
#                   where source_id = '$accession'
#                    and external_database_release_id = $dbReleaseId)";


     $sql = "SELECT na_sequence_id, sequence 
              FROM Dots.NASEQUENCE 
              WHERE na_sequence_id in
               (
                (select na_sequence_id 
                  from Dots.EXTERNALNASEQUENCE 
                  where source_id = '$accession'
                   and external_database_release_id = $dbReleaseId)
              UNION
                (select na_sequence_id 
                  from Dots.VIRTUALSEQUENCE 
                  where source_id = '$accession'
                   and external_database_release_id = $dbReleaseId) )";
  }
  else {
    $sql = "SELECT aa_sequence_id, sequence
            FROM DOTS.AASequence
            WHERE external_database_release_id = $dbReleaseId
            AND source_id = '$accession'";
  }

  my $sh = $self->getQueryHandle()->prepare($sql);
  $sh->execute();


  my ($id, $sequence) = $sh->fetchrow_array();

  if($sh->fetchrow_array) {
    die "Non Distinct sequence for source_id $accession\n";
  }

  my $seq = Bio::Seq->new(-seq => $sequence,
			  -accession_number => $accession,
			  -display_id => $id,
			 );
  return($seq);
}

# ----------------------------------------------------------------------

=pod

=item C<_getStartStop($bioLcSeq, $bioDbSeq)>

Get the Start and The Stop for Low Complexity Regions from Sequence.  Any
instances of the "mask" character found in the dbSeq are "removed" from the
lcSeq.

B<Parameters:>

- bioLcSeq(Bio::Seq):  Sequence with Low Complexity "mask" chars
- bioDbSeq(Bio::DbSeq):  Sequence from db (may contain mask chars)

B<Return type:> C<arrayRef>

=cut

sub _getStartStop {
  my ($self, $bioLcSeq, $bioDbSeq) = @_;

  my @rv;

  my $mask = $self->getArgs()->{maskChar};

  my $seq = $bioDbSeq->seq;
  my $lcSeq = $bioLcSeq->seq;

  my $pos = 0;

  # Replace ALL Occurences of Mask Char from seq in LCSeq with %
  while(index($seq, $mask, $pos) >= 0 ) {
    my $index = index($seq, $mask, $pos);
    substr($lcSeq, $index, 1, '%');
    $pos = $index + 1 ;
  }

  my @answer;
  my $start = 0;
  my $cursor = 0;

  foreach my $bp (split('', $lcSeq)) {
    $cursor++;

    # previously in unmasked region
    if (!$start) { 
      $start = $cursor if ($bp eq $mask);
    }

    # previously in masked region
    else {
      if ($bp ne $mask) {
        my $stop = $cursor - 1;
        push(@answer, {start => $start, stop => $stop});
        $start = 0;
        $self->error("start_min [$start] > end_max [$stop]") if($start > $stop);
      }
    }
  }

  return(\@answer);
}


# ----------------------------------------------------------------------

=pod

=item C<_loadNaLcFeature($bioDbSeq, $startStop, $dbRelease)>

Load a DoTS::LowComplexityNAFeature and DoTS::NALocation

B<Parameters:>

- bioDbSeq(Bio::DbSeq):  Sequence from db (may contain mask chars)
- $startStop(arrayRef):  Each Element contains a hash {start => $start, stop => $stop}

B<Return type:> C<int>

=cut

sub _loadNaLcFeature {
  my ($self, $bioDbSeq, $startStop, $dbReleaseId) = @_;

  my $sequenceId = $bioDbSeq->display_id;

  foreach(@$startStop) {
    my $start = $_->{start};
    my $stop = $_->{stop};

    my $lcFeature = GUS::Model::DoTS::LowComplexityNAFeature->
      new({na_sequence_id => $sequenceId,
	   name => $self->getArgs()->{LowComplexityName},
	   source_id => $bioDbSeq->accession_number,
           is_predicted => 1,
	  });

    if(!defined $start || !defined $stop) {
      die "Missing start or end seq position for (n|a)a_sequence_id:  $sequenceId\n";
    }

    my $location = GUS::Model::DoTS::NALocation->
      new({start_min => $start,
	   start_max => $start,
	   end_min => $stop,
	   end_max => $stop,
	  })->setParent($lcFeature);

    $lcFeature->submit();
    $featuresLoaded++;

    $self->undefPointerCache();

  }

}

# ----------------------------------------------------------------------

=pod

=item C<_loadAaLcFeature($bioDbSeq, $startStop, $dbRelease)>

Load a DoTS::LowComplexityAAFeature and DoTS::AALocation

B<Parameters:>

- bioDbSeq(Bio::DbSeq):  Sequence from db (may contain mask chars)
- $startStop(arrayRef):  Each Element contains a hash {start => $start, stop => $stop}

B<Return type:> C<int>

=cut

sub _loadAaLcFeature {
  my ($self, $bioDbSeq, $startStop, $dbReleaseId) = @_;

  my $sequenceId = $bioDbSeq->display_id;

  my $accession_number = $bioDbSeq->accession_number;

  foreach(@$startStop) {
    my $start = $_->{start};
    my $stop = $_->{stop};

    my $lcFeature = GUS::Model::DoTS::LowComplexityAAFeature->
      new({aa_sequence_id => $sequenceId,
	   source_id => $bioDbSeq->accession_number,
           is_predicted => 1,
	  });

    if(!defined($start) || !defined($stop)) {
      die "Missing start or end seq position for (n|a)a_sequence_id:  $sequenceId\n";
    }

    my $location = GUS::Model::DoTS::AALocation->
      new({start_min => $start,
	   start_max => $start,
	   end_min => $stop,
	   end_max => $stop,
	  })->setParent($lcFeature);

    $lcFeature->submit();
    $featuresLoaded++;

    if ($featuresLoaded % 100 == 0){
      $self->log("Loaded $featuresLoaded features.");
    }
  }
$self->undefPointerCache();

}

sub undoTables {
  my ($self) = @_;

  return ('DoTS.NALocation',
	  'DoTS.AALocation',
	  'DoTS.NAFeatureImp',
	  'DoTS.AAFeatureImp'
	 );
}



1;
