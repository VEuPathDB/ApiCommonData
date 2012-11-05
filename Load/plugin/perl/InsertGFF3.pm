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
use GUS::Model::ApiDB::GFF3AttributeKey;
use GUS::Model::ApiDB::GFF3Attributes;
use GUS::Supported::Util;

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
     descr => '[1,2,3]',
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
         }),
     stringArg({name => 'seqExtDbName',
       descr => 'External database where sequences can be found',
       constraintFunc=> undef,
       reqd  => 1,
       isList => 0
      }),
     stringArg({name => 'seqExtDbRlsVer',
       descr => 'Version of external database where sequences can be found',
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
ApiDB.GFF3, ApiDB.GFF3AttributeKey, ApiDB.Attributes
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

  my $configuration = { requiredDbVersion => 3.6,
                        cvsRevision => '$Revision: 45916 $',
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

  my $genomeDbRlsId = $self->getExtDbRlsId($self->getArg('seqExtDbName'),$self->getArg('seqExtDbRlsVer')) || $self->error("Can't find external_database_release_id for genome sequence");
 
  my $processed;

  my $gffIO = Bio::Tools::GFF->new(-file => $self->getArg('file'),
                                   -gff_version => $self->getArg('gffFormat'),
                                  );

  while (my $feature = $gffIO->next_feature()) {
     $self->insertGFF3($feature, $gff3ExtDbReleaseId, $genomeDbRlsId);
     $processed++;
     $self->undefPointerCache();
  }

  return "$processed gff3 lines parsed and loaded";

}


sub getNaSequencefromSourceId {
   my ($self, $seqid, $genomeDbRlsId) = @_;
   if(my $found = $self->{nasequences}->{$seqid}) {
     return $found;
   }
   
   my $naSeq = GUS::Model::DoTS::NASequence->new({source_id => $seqid,
                                                  external_database_release_id => $genomeDbRlsId});
   unless ($naSeq->retrieveFromDB) {
      $self->error("Can't find na_sequence_id for gff3 sequence $seqid");
   } 
   $self->{nasequences}->{$seqid} = $naSeq;
   return $naSeq;
}



sub getSOfromSoTerm {
   my ($self, $soterm) = @_;
   if(my $found = $self->{soids}->{$soterm}) {
     return $found;
   }
   
   my $SOTerm = GUS::Model::SRes::SequenceOntology->new({'term_name' => $soterm });
   unless($SOTerm->retrieveFromDB){
      $self->error("Can't find sequence onotology id for term $soterm");
   }
   $self->{soids}->{$soterm} = $SOTerm;
   return $SOTerm;
}



sub getGFF3AttributeKeys{
 my ($self, $key) = @_;
   if(my $found = $self->{attr_keys}->{$key}) {
     return $found;
   }
   
   my $attrKey = GUS::Model::ApiDB::GFF3AttributeKeys->new({'name' => $key });
   unless($attrKey->retrieveFromDB){
     print 'key $key added to GFF3AttributeKeys'; 
     $attrKey->submit();
   }
}



sub getGFF3AttributeKey{
 my ($self, $key) = @_;
 if(my $found = $self->{attr_keys}->{$key}) {
     return $found;
   }
   
   my $attrKey = GUS::Model::ApiDB::GFF3AttributeKey->new({'name' => $key });
   unless($attrKey->retrieveFromDB){
     print "key $key added to GFF3AttributeKey"; 
     $attrKey->submit();

   }
   $self->{attr_keys}->{$key} = $attrKey;
   return $attrKey;
}

sub createGff3AttrObj{
  my ($self,$key,$value) = @_;
  my $attrKey = $self->getGFF3AttributeKey($key);
  my $attr = GUS::Model::ApiDB::GFF3Attributes->new({'value' => $value });
  $attr->setParent($attrKey);
  return $attr
}

sub insertGFF3{
  my ($self,$feature, $gff3ExtDbReleaseId, $genomeDbRlsId) = @_;

  my $seqid = $feature->seq_id;
  my $naSeq = $self->getNaSequencefromSourceId($seqid, $genomeDbRlsId);
  die "can't find na_sequence_id for '$seqid'" unless $naSeq;
  my $soterm = $feature->primary_tag;
  my $sotermObj = $self->getSOfromSoTerm($soterm);

  my $naSeqId = $naSeq->getNaSequenceId();
  my $soId = $sotermObj->getSequenceOntologyId();

  my $snpStart = $feature->location()->start();
  my $snpEnd = $feature->location()->end();
  my $strand = $feature->location()->strand() == -1 ? 1 : 0;
  my $score = $feature->score;
  
  my $source = $feature->source_tag;
  my $frame = $feature->frame;

  my $attr = '';
  my $parent = '';
  my $id = '';
  my @tags = $feature->get_all_tags();
  my @attr;

  foreach my $tag(@tags) {
    # change to uc string eq
    if (uc($tag) eq "PARENT"){
      my @parents = $feature->get_tag_values($tag);
      unless (scalar(@parents) == 1){
        $self->userError("Only one parent allowed");
      }
      $parent = $parents[0];
      print $parent
    }
    elsif (uc($tag) eq "ID"){
      my @ids = $feature->get_tag_values($tag);
      unless (scalar(@ids) == 1){
        $self->userError("Only one id allowed")
      }
      $id = $ids[0];
    }
    else {
      my @values = $feature->get_tag_values($tag);
      my $value = $values[0];
      print "SeqID = $seqid : $tag : $value";
      $attr .= $tag. '='. join(',', @values) . ';';
      foreach my $value(@values){
        my $gff3Attr = $self->createGff3AttrObj($tag,$value);
        push(@attr,$gff3Attr);
      }
    }
  }
  $attr =~ s/;$//;


  my $gff3 = GUS::Model::ApiDB::GFF3->new({ 
                                'source' => $source,
                                'mapping_start' => $snpStart,
                                'mapping_end' => $snpEnd,
                                'score' => $score,
                                'is_reversed' => $strand,
                                'phase' => $frame,
                                'external_database_release_id' => $gff3ExtDbReleaseId,
                                'parent_attr' => $parent,
                                'id_attr' => $id
                                 });

  $gff3->setNaSequenceId($naSeqId);
  $gff3->setSequenceOntologyId($soId);
  $gff3->setAttr($attr);

  foreach my $attribute(@attr) {
    $attribute->setParent($gff3);
    }

  $gff3->submit();
}


sub undoTables {
  qw(
    ApiDB.GFF3Attributes
    ApiDB.GFF3AttributeKey
    ApiDB.GFF3

    );
}

1;
