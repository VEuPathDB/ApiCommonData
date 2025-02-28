package ApiCommonData::Load::Plugin::InsertGFF3;
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | fixed
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
  # GUS4_STATUS | dots.gene                      | manual | absent
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use GUS::PluginMgr::Plugin;
use Bio::Tools::GFF;
use IO::Uncompress::Gunzip qw(gunzip);

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
       descr => 'Version of the seq ext db (deprecated)',
       constraintFunc=> undef,
       reqd  => 0,
       isList => 0
      }),

     stringArg({name => 'soExtDbSpec',
       descr => 'sequence ontology external database spec',
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
DoTS.NASequence, SRes.ExternalDatabaseRelease, Sres.OntologyTerm
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

  my $configuration = { requiredDbVersion => 4.0,
                        cvsRevision => '$Revision: 86267 $',
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

  # getting na_sequence_ids and so_term_ids as hashrefs of name:id rather than making and storing GUS objects saves time

  my $seqextDbName = $self->getArg('seqExtDbName');
  my $seqHash = $self->sqlAsDictionary(Sql => "SELECT ns.source_id, ns.na_sequence_id
  from dots.nasequence ns
     , sres.ontologyterm oterm 
     , apidb.datasource ds
  where ns.sequence_ontology_id = oterm.ontology_term_id
    and ds.name = '$seqextDbName'     
    and ds.taxon_id = ns.taxon_id
    and oterm.name in ('random_sequence', 'contig', 'supercontig', 'chromosome','mitochondrial_chromosome','plastid_sequence','cloned_genomic','apicoplast_chromosome')");

  my $soExtDbRlsId = $self->getExtDbRlsId($self->getArg('soExtDbSpec')) || $self->error("Can't find external_database_release_id for sequence ontology");
  my $soHash = $self->sqlAsDictionary(Sql => "select name, ontology_term_id
                                              from sres.ontologyterm
                                              where external_database_release_id = $soExtDbRlsId");
 
  my $processed;
  my $file = $self->getArg('file');
#  my $fh;
#  if ($file =~ /\.gz$/) {
#    open($fh, "gzip -dc $file |") or die "Could not open '$file': $!";
#  } else {
#    open($fh, "<", $file) or die "Could not open '$file': $!";
#  }
  my $was_gzipped = 0;
  if ($file =~ /\.gz$/) {
    $was_gzipped = 1;
    my $unzipped_file = $file;
    $unzipped_file =~ s/\.gz$//;
    system("gzip -d -f $file") == 0 or die "Failed to unzip '$file': $!\n";
    $file = $unzipped_file;
  } 
  my $gffIO = Bio::Tools::GFF->new(-file => $file,
                                   -gff_version => $self->getArg('gffFormat'),
                                  );
  if ($was_gzipped) {
    system("gzip -f $file") == 0 or die "Failed to gzip '$file': $!\n";
  }

  $self->getDb()->manageTransaction(0,'begin');

  while (my $feature = $gffIO->next_feature()) {
     $self->insertGFF3($feature, $gff3ExtDbReleaseId, $seqHash, $soHash);
     $processed++;

     if ($processed % 1000 == 0) {
        $self->getDb()->manageTransaction(0,'commit');
        $self->getDb()->manageTransaction(0,'begin');
    }
     $self->undefPointerCache();
  }
  $self->getDb()->manageTransaction(0,'commit');
  return "$processed gff3 lines parsed and loaded";
}


sub getNaSequencefromSourceId {
    my ($self, $seqid, $seqHash) = @_;
    my $naSeqId = $seqHash->{$seqid};
    unless (defined $naSeqId) {
        $self->error("Can't find na_sequence_id for gff3 sequence $seqid");
    }
    return $naSeqId;
}


sub getSOfromSoTerm {
    my ($self, $soterm, $soHash) = @_;
    my $soTermId = $soHash->{$soterm};
    unless (defined $soTermId) {
        $self->error("Can't find so_term_id for $soterm");
    }
    return $soTermId;
}


sub getGFF3AttributeKey{
 my ($self, $key) = @_;
 if(my $found = $self->{attr_keys}->{$key}) {
     return $found;
   }
   
   my $attrKey = GUS::Model::ApiDB::GFF3AttributeKey->new({'name' => $key });
   unless($attrKey->retrieveFromDB){
     $attrKey->submit();

   }
   $self->{attr_keys}->{$key} = $attrKey;
   return $attrKey;
}

sub createGff3AttrObj{
  my ($self,$key,$value) = @_;
  my $attrKey = $self->getGFF3AttributeKey($key);

  my $attr = GUS::Model::ApiDB::GFF3Attributes->new({'value' => $value ,
                                                    gff3_attribute_key_id => $attrKey->getId() });
#  $attr->setParent($attrKey);

  return $attr
}

sub insertGFF3{
  my ($self,$feature, $gff3ExtDbReleaseId, $seqHash, $soHash) = @_;

  my $seqid = $feature->seq_id;
  my $naSeqId = $self->getNaSequencefromSourceId($seqid, $seqHash);
  die "Can't find na_sequence_id for $seqid\n" unless defined $naSeqId;

  my $soterm = $feature->primary_tag;
  my $soId = $self->getSOfromSoTerm($soterm, $soHash);
  die "Can't find ontology_term_id for $soterm\n" unless defined $soId;

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

  $gff3->submit(0,1);
}


sub undoTables {
  qw(
    ApiDB.GFF3Attributes
    ApiDB.GFF3AttributeKey
    ApiDB.GFF3

    );
}

1;
