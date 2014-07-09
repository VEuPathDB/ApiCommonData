package ApiCommonData::Load::IsolateVocabulary::Reader::SqlTermReader;
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
  # GUS4_STATUS | Study.OntologyEntry            | auto   | broken
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | absent
  # GUS4_STATUS | RAD.Analysis                   | auto   | absent
  # GUS4_STATUS | ApiDB.Profile                  | auto   | absent
  # GUS4_STATUS | Study.Study                    | auto   | broken
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
use base qw(ApiCommonData::Load::IsolateVocabulary::Reader);

use strict;

use ApiCommonData::Load::IsolateVocabulary::VocabularyTerm;


sub setVocabulary {$_[0]->{_vocabulary} = $_[1]}
sub getVocabulary {$_[0]->{_vocabulary}}


sub new {
  my ($class, $dbh, $type, $vocabulary) = @_;

  my $args = {};

  my $self = bless $args, $class; 

  $self->setDbh($dbh);
  $self->setType($type);
  $self->setVocabulary($vocabulary);

  return $self;
}

sub extract {
  my ($self) = @_;

  my $dotsIsolateSourceTerms = $self->getDotsIsolateSourceTerms();
  my $studyOntologyEntryTerms = $self->getStudyOntologyEntryTerms();
 
  my @rv = (@$dotsIsolateSourceTerms, @$studyOntologyEntryTerms);

  return \@rv;
}

sub getStudyOntologyEntryTerms {
  my ($self) = @_;

  my $dbh = $self->getDbh();
  my $type = $self->getType();
  my $vocabulary = $self->getVocabulary();

  my $table = 'OntologyEntry';

  my $typeMap = {geographic_location => 'GeographicLocation',
                 isolation_source => 'BioSourceType',
                 specific_host => 'Host',
                };

  my $category = $typeMap->{$type};

  my $sql = <<SQL;
select distinct oe.value as term
from study.ontologyentry oe, STUDY.biomaterialcharacteristic bc
where bc.ontology_entry_id = oe.ontology_entry_id 
and oe.category = '$category'
and oe.value is not null
SQL

  my $sh = $dbh->prepare($sql);
  $sh->execute();

  my @sqlTerms;
  while(my ($term) = $sh->fetchrow_array()) {
    my $preexists = 0;
    if($vocabulary->{$type}->{$term}) {
      $preexists = 1;
    }

    my $term = ApiCommonData::Load::IsolateVocabulary::VocabularyTerm->new($term, '', $table, $category, $type, $preexists);
    push @sqlTerms, $term;
  }
  $sh->finish();

  return \@sqlTerms;
}


sub getDotsIsolateSourceTerms {
  my ($self) = @_;

  my $dbh = $self->getDbh();
  my $queryField = $self->getType() eq 'geographic_location' ? 'country' : $self->getType();
  my $type = $self->getType();
  my $vocabulary = $self->getVocabulary();

  my $table = 'IsolateSource';

  my $sql = <<SQL;

select distinct $queryField as term  from dots.$table
where $queryField is not null 
order by $queryField
SQL

  my $sh = $dbh->prepare($sql);
  $sh->execute();

  my @sqlTerms;
  while(my ($term) = $sh->fetchrow_array()) {

    my $preexists = 0;
    if($vocabulary->{$type}->{$term}) {
      $preexists = 1;
    }

    my $term = ApiCommonData::Load::IsolateVocabulary::VocabularyTerm->new($term, '', $table, $queryField, $type, $preexists);
    push @sqlTerms, $term;
  }
  $sh->finish();

  return \@sqlTerms;
}


1;

