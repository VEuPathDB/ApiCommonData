package ApiCommonData::Load::IsolateVocabulary::Reader::VocabSqlReader;
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | absent
  # GUS4_STATUS | RAD.Analysis                   | auto   | absent
  # GUS4_STATUS | ApiDB.Profile                  | auto   | absent
  # GUS4_STATUS | Study.Study                    | auto   | absent
  # GUS4_STATUS | Dots.Isolate                   | auto   | broken
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
use base qw(ApiCommonData::Load::IsolateVocabulary::Reader);

use strict;

use Carp;

sub new {
  my ($class, $dbh) = @_;

  my $args = {};

  my $self = bless $args, $class; 

  $self->setDbh($dbh);

  return $self;
}

sub extract {
  my ($self) = @_;

  my $dbh = $self->getDbh();

  my $sql = "select isolate_vocabulary_id, term, parent, type from apidb.isolatevocabulary";
  my $sh = $dbh->prepare($sql);
  $sh->execute();

  my $vocab;

  while(my ($id, $term, $parent, $type) = $sh->fetchrow_array()) {
    die "duplicate ($type, $term) in vocab file line $.\n" if $vocab->{$type}->{$term};
    $vocab->{$type}->{$term} = $id;
  }

  $sh->finish();

  return $vocab;
}


1;
