package ApiCommonData::Load::Plugin::InsertGFF3;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use GUS::PluginMgr::Plugin;
use Bio::Tools::GFF;

use GUS::Model::DoTS::NASequence;
use GUS::Model::SRes::SequenceOntology;
use GUS::Model::SRes::ExternalDatabase;
use GUS::Model::SRes::ExternalDatabaseRelease;
use GUS::Model::ApiDB::GFF3;
use ApiCommonData::Load::Util;

# ----------------------------------------------------------
# Load Arguments
# ----------------------------------------------------------

sub getArgsDeclaration {
  my $argsDeclaration  =
    [
     fileArg({ name => 'file',
         descr => 'tab delimited file',
         constraintFunc=> undef,
         reqd  => 1,
         isList => 0,
         mustExist => 1,
         format => 'Nine column tab delimited file in the order seqid, source, type, start, end, score, strand, phase, attribute',
       }),
     stringArg({ name => 'gffFormat',
     descr => 'gff format 1, 2, 3',
     constraintFunc=> undef,
     reqd  => 1,
     isList => 0,
		 mustExist => 1,
         }),
     stringArg({ name => 'gff3DbName',
     descr => 'externaldatabase name for gff3 source',
     constraintFunc=> undef,
     reqd  => 1,
     isList => 0
         }),
     stringArg({ name => 'gff3DbVer',
     descr => 'externaldatabaserelease version used for gff3 source',
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
Plugin to load GFF3 file into apidb.gff3 table
DESCR

  my $purpose = <<PURPOSE;
Plugin to load GFF3 file into apidb.gff3 table 
PURPOSE

  my $purposeBrief = <<PURPOSEBRIEF;
Plugin to load GFF3 file into apidb.gff3 table 
PURPOSEBRIEF

  my $notes = <<NOTES;
NOTES

  my $tablesAffected = <<AFFECT;
ApiDB.GFF3
AFFECT

  my $tablesDependedOn = <<TABD;
DoTS.NASequence, SRes.ExternalDatabaseRelease, Sres.SequenceOntology 
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

sub new {
  my $class = shift;
  my $self = {};
  bless($self, $class);

  my $documentation = &getDocumentation();

  my $args = &getArgsDeclaration();

  my $configuration = { requiredDbVersion => 3.5,
                        cvsRevision => '$Revision: 89 $',
                        name => ref($self),
                        argsDeclaration => $args,
                        documentation => $documentation
                      };

  $self->initialize($configuration);

  return $self;
}

sub run {
  my $self = shift;

  my $gff3ExtDbReleaseId = $self->getExtDbRlsId($self->getArg('gff3DbName'),
             $self->getArg('gff3DbVer')) || $self->error("Can't find external_database_release_id for gff3 data source");

  my $processed;

	my $gffIO = Bio::Tools::GFF->new(-file => $self->getArg('file'),
	                                 -gff_format => $self->getArg('gffFormat'),
																	);

  while (my $feature = $gffIO->next_feature()) {
     $self->insertGFF3($feature, $gff3ExtDbReleaseId);
		 $processed++;
     #print "$processed gff3 lines parsed and loaded\n";
	}

  return "$processed gff3 lines parsed and loaded";
}

sub getNaSequencefromSourceId {
   my ($self, $seqid) = @_;
	 if($self->{nasequences}->{$seqid}) {
	   return $_;
	 }
   
   my $naSeq = GUS::Model::DoTS::NASequence->new({source_id => $seqid});
   unless ($naSeq->retrieveFromDB) {
			$self->error("Can't find na_sequence_id for gff3 sequence $seqid");
	 } 
	 $self->{nasequences}->{$seqid} = $naSeq;
   return $naSeq;
}

sub getSoIdfromSoTerm {
   my ($self, $soterm) = @_;
	 if($self->{soids}->{$soterm}) {
	   return $_;
	 }
   
   my $SOTerm = GUS::Model::SRes::SequenceOntology->new({'term_name' => $soterm });
	 unless($SOTerm->retrieveFromDB){
			$self->error("Can't find sequence onotology id for term $soterm");
	 }
	 $self->{soids}->{$soterm} = $SOTerm;
   return $SOTerm;
}

sub insertGFF3 {
  my ($self,$feature, $gff3ExtDbReleaseId) = @_;

	my $seqid = $feature->seq_id;
  my $naSeq = $self->getNaSequencefromSourceId($seqid);

	my $soterm = $feature->primary_tag;
  my $sotermObj = $self->getSoIdfromSoTerm($soterm);

	my $snpStart = $feature->location()->start();
	my $snpEnd = $feature->location()->end();
	my $strand = $feature->location()->strand() == -1 ? 1 : 0;
	my $score = $feature->score;
	
	my $source = $feature->source_tag;
	my $frame = $feature->frame;

	my @tags = $feature->get_all_tags();

  my $gff3 = GUS::Model::ApiDB::GFF3->new({ 
                                'source' => $source,
                                'mapping_start' => $snpStart,
                                'mapping_end' => $snpEnd,
                                'score' => $score,
                                'is_reversed' => $strand,
                                'phase' => $frame,
                                'external_database_release_id' => $gff3ExtDbReleaseId
                                 });

  $gff3->setParent($naSeq);
  $gff3->setParent($sotermObj);
  #$gff3->setAttr($attr);

  #print $gff3->toString();
	#exit;

  $gff3->submit();
}

sub undoTables {
  return ('ApiDB.GFF3');
}

