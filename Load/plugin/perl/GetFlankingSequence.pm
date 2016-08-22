package ApiCommonData::Load::Plugin::GetFlankingSequence;
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | broken
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
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^
@ISA = qw(GUS::PluginMgr::Plugin);


use strict;

use GUS::PluginMgr::Plugin;
use GUS::Model::SRes::SequenceOntology;
use GUS::Model::DoTS::NALocation;
use GUS::Model::DoTS::Transcript;
use GUS::Model::DoTS::VirtualSequence;

use Bio::Seq;
use Bio::Tools::GFF;
use CBIL::Bio::SequenceUtils;

# ---------------------------------------------------------------------------
# Load Arguments
# ---------------------------------------------------------------------------

sub getArgumentsDeclaration{
  my $argsDeclaration =
    [
     stringArg({name => 'naExtDbRlsSpec',
		descr => 'sres.externaldatabase.name and sres.externaldatabaserelease.version for the genome sequences',
		constraintFunc => undef,
		reqd => 1,
		isList => 0
	       }),
     stringArg({name => 'seqTable',
		descr => 'where do we find the nucleotide sequences',
		constraintFunc => undef,
		reqd => 1,
		isList => 0
	       }),
     stringArg({name => 'organism',
		descr => 'Genus and species, example T. gondii',
		constraintFunc=> undef,
		reqd  => 1,
		isList => 0
	       }),
     stringArg({name => 'snpFile',
		descr => 'gff file containing the SNP data',
		constraintFunc => undef,
		reqd => 1,
		isList => 0,
		mustExist => 1,
		format => 'GFF, Ex:995313  Stanford        SNP     3093368 3093369 .       .       .       SNP TGG_995313_Contig28_138 ; Allele RH:C ; Allele ME49:- ; Allele VEG:-'
	       }),
     stringArg({name => 'outFile',
		descr => 'gff file the updated SNP data will be printed to',
		constraintFunc => undef,
		reqd => 1,
		isList => 0,
		mustExist => 1,
		format => "GFF, Ex:MAL1	gene	#Snps	Snp-Position	3D7-allele	7G8-allele	DD2-allele	D10-allele	HB3-allele	External ID	5' Flank sequence	Allele in slashed form or IUPAC Code	3' Flank sequence
MAL1	PFA0125c	3	114793	A	A	T	T	A	PFA0125c-1	AAAATGTATGTGTCAATCATATATTGATTTAAAAATCCAATTTAAAAATA	A/T	TGATATTTGTTCATTTAATGCTCAAACAGATACTGTTTCTAGCGATAAAA"
	       }),
     stringArg({name => 'reference',
		descr => 'Strain or individual used as reference for all indels and substitutions',
		constraintFunc=> undef,
		reqd  => 1,
		isList => 0,
	       }),
     integerArg({name => 'restart',
		descr => 'for restarting use number from last processed row number in STDOUT',
	        constraintFunc => undef,
	        reqd => 0,
	        isList => 0
	    }),
     stringArg({name => 'gffFormat',
		descr => 'Which gff format is the gff file in',
		constraintFunc=> undef,
		reqd  => 0,
                default => 'gff2',
		isList => 0,
	       }),
   stringArg({ name           => 'groupTag',
	       descr          => 'For GFF versions < 3, one must specify which of the tags found in the group column is the group tag',
	       reqd           => 1,
	       constraintFunc => undef,
	       isList         => 0,
	     }),
   stringArg({ name           => 'sourceIdTag',
	       descr          => 'The tag that identifies the sourceId in the file, ex: SNP or ID',
	       reqd           => 1,
	       constraintFunc => undef,
	       isList         => 0,
	     }),
    ];
  return $argsDeclaration;
}

# ----------------------------------------------------------------------
# Documentation
# ----------------------------------------------------------------------

sub getDocumentation {
  my $purposeBrief = "Gets creates a new GFF file that includes the flanking sequence.";

  my $purpose = "Gets sequence that flanks the SNPs in the file and creates a new GFF file that includes the flanking sequence.";

  my $tablesAffected = [];

  my $tablesDependedOn = [["DoTS.NASequence","The sequences that contain the SNPs must be in this table"]];

  my $howToRestart = "Use restart option and last processed row number from STDOUT file.";

  my $failureCases = "";

  my $notes = "";

  my $documentation = {purpose=>$purpose,
		       purposeBrief=>$purposeBrief,
		       tablesAffected=>$tablesAffected,
		       tablesDependedOn=>$tablesDependedOn,
		       howToRestart=>$howToRestart,
		       failureCases=>$failureCases,
		       notes=>$notes
		      };

  return $documentation;
}

# ----------------------------------------------------------------------
# create and initalize new plugin instance.
# ----------------------------------------------------------------------

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  my $documentation = &getDocumentation();
  my $argumentDeclaration = &getArgumentsDeclaration();


  $self->initialize({requiredDbVersion => 3.6,
		     cvsRevision => '$Revision$',
                     name => ref($self),
                     revisionNotes => '',
                     argsDeclaration => $argumentDeclaration,
                     documentation => $documentation});

  return $self;
}

# ----------------------------------------------------------------------
# run method to do the work
# ----------------------------------------------------------------------

sub run {
  my ($self) = @_;
  my $count = 0;
  $self->{'naExtDbRlsId'} = $self->getExtDbRlsId($self->getArg('naExtDbRlsSpec'));

  my $inFile = $self->getArg('snpFile');
  my $outFile = $self->getArg('outFile');
  my $groupTag = $self->getArg('groupTag');
  my $seqTable = $self->getArg('seqTable');
  my $ref = $self->getArg('reference');
  my $gffFormat = $self->getArg('gffFormat');
  my $tag = $self->getArg('sourceIdTag');

  my $gffIn  = Bio::Tools::GFF->new(-file => "<$inFile",
				    -gff_version => $gffFormat,
				    -preferred_groups => [$groupTag]
				   );

  my $gffOut = Bio::Tools::GFF->new(-file => ">$outFile",
				    -gff_version => $gffFormat,
				    -preferred_groups => [$groupTag]
				   );

  while (my $feature = $gffIn->next_feature()){
    $self->processFeature($feature, $seqTable, $ref, $tag);
    $gffOut->write_feature($feature);
    $count++;
    $self->log("retrieved sequences for $count SNPs") if ($count%100 == 0);
    $self->undefPointerCache();
  }

  return "File update complete. Flanking sequences for $count SNPs were found."
}


sub processFeature{
  my ($self, $feature, $seqTable, $ref, $tag) = @_;

  my $naSeq = $self->getNaSeq($feature->seq_id(), $seqTable);
  my @values = $feature->get_tag_values($tag);
  my $sourceId = $values[0];

  my $start = $feature->location()->start();
  my $end = $feature->location()->end();
  $self->userError("Snp end is less than snp start in file: $!") if($end < $start);

  my $strand = $feature->location()->strand();

  my $isReversed = $strand eq '-1' ? 1 : 0;
  $isReversed = "NA" if($strand eq '.');

  foreach ($feature->get_tag_values('Allele')) {
    my ($strain, $base) = split(':', $_);

    if(lc($ref) eq lc($strain)) {
      unless($self->_isSnpPositionOk($naSeq, $base, $start, $end, $isReversed)) {

        $self->userError("The snp base: $base for the Reference Strain: $ref doesn't match expected for sourceId $sourceId");

      }
    }
  }

  my ($fivePrimeSeq, $threePrimeSeq) = $self->_getFlankingSequence($naSeq, $start, $isReversed);

  $feature->add_tag_value('FivePrimeFlank',$fivePrimeSeq);
  $feature->add_tag_value('ThreePrimeFlank',$threePrimeSeq);

}

sub _isSnpPositionOk {
  my ($self, $naSeq, $base, $snpStart, $snpEnd, $isReverse) = @_;

  return(1) if($isReverse eq "NA");

  my $lengthOfSnp = $snpEnd - $snpStart + 1;

  my $referenceBase = $naSeq->getSubstrFromClob('sequence', $snpStart, $lengthOfSnp);

  if($isReverse) {
    $referenceBase = CBIL::Bio::SequenceUtils::reverseComplementSequence($referenceBase);
  }

  return($referenceBase eq $base);
}

sub _getFlankingSequence{
  my ($self, $naSeq, $snpStart, $isReversed) = @_;
  my $lengthOfFlankingSeq = 50;

  my $fivePrimeStart = $snpStart - $lengthOfFlankingSeq;
  my $threePrimeStart = $snpStart + 1;

  my $fivePrimeSeq = $naSeq->getSubstrFromClob('sequence', $fivePrimeStart, $lengthOfFlankingSeq);

  my $threePrimeSeq = $naSeq->getSubstrFromClob('sequence', $threePrimeStart, $lengthOfFlankingSeq);

  if($isReversed) {
    my $tempSeq = $fivePrimeSeq;

    $fivePrimeSeq = CBIL::Bio::SequenceUtils::reverseComplementSequence($threePrimeSeq);

    $threePrimeSeq = CBIL::Bio::SequenceUtils::reverseComplementSequence($tempSeq);
  }

  return ($fivePrimeSeq, $threePrimeSeq);
}

sub getNaSeq {
  my ($self, $sourceId, $seqTable) = @_;

  my $extDbRlsId = $self->{'naExtDbRlsId'};

  $seqTable = "GUS::Model::$seqTable";
  eval "require $seqTable";

  my $naSeq = $seqTable->new({'source_id'=>$sourceId,'external_database_release_id'=>$extDbRlsId});

  $naSeq->retrieveFromDB() || $self->error(" $sourceId does not exist in the database with database release = $extDbRlsId\n");

  return $naSeq;
}


1;
