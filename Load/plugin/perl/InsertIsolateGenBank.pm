package ApiCommonData::Load::Plugin::InsertIsolateGenBank;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use lib "$ENV{GUS_HOME}/lib/perl";
use Bio::SeqIO;
use GUS::PluginMgr::Plugin;
use GUS::Model::DoTS::ExternalNASequence;
use GUS::Model::Results::SegmentResult;
use GUS::Model::Study::Study;
use GUS::Model::Study::StudyLink;
use GUS::Model::Study::StudyBibRef;
use GUS::Model::Study::ProtocolAppNode;
use GUS::Model::Study::Characteristic;
use GUS::Model::SRes::OntologyTerm;
use GUS::Model::SRes::BibliographicReference;
use Data::Dumper;

use lib "$ENV{GUS_HOME}/lib/perl/ApiCommonWebsite/Model";
use pcbiPubmed;

my $purposeBrief = <<PURPOSEBRIEF;
Insert GenBank Isolate data from a genbank file (.gbk). 
PURPOSEBRIEF

my $purpose = <<PURPOSE;
Insert GenBank Isolate data from a genbank file (.gbk). 
PURPOSE

my $tablesAffected = [
  ['Results.SegmentResult', 'One row or more per isolate - mRNA, rRNA, gene'],
  ['Study.Study',           'One row per inserted study, one study could have multiple isolates'],
  ['Study.ProtocolAppNode', 'One row per inserted isolate'],
  ['Study.Characteristic',  'One row or more per inserted isolate - metadata, e.g. country, strin, genotype...'],
  ['Study.StudyLink',       'Link Study.Study with Study.ProtocolAppNode - one study could have multiple isolates'],
  ['Study.StudyBibRef',     'Link Study.Study with SRes.BibliographicReference - one study could have multiple references'],
  ['SRes.OntologyTerm',     'Store GenBank source modifiers'],
  ['SRes.BibliographicReference', 'Store GenBank source modifiers'],
  ['DoTS.ExternalNASequence',     'One row inserted per isolate .ProtocolAppNode row'] 
];

my $tablesDependedOn = [
  ['SRes.OntologyTerm', 'Get the ontology_term_id for each metadata']
];

my $howToRestart = "There is currently no restart method.";

my $failureCases = "There are no know failure cases.";

my $notes = <<PLUGIN_NOTES;
Input File is a typical GenBank file, e.g. GenBank accession AF527841
#MetaData  is inside the /source block, e.g. strain, genotype, country, clone, lat-lon...
PLUGIN_NOTES

my $documentation = { purpose          => $purpose,
                      purposeBrief     => $purposeBrief,
                      tablesAffected   => $tablesAffected,
                      tablesDependedOn => $tablesDependedOn,
                      howToRestart     => $howToRestart,
                      failureCases     => $failureCases,
                      notes            => $notes
                    };

my $argsDeclaration = 
  [
    stringArg({name           => 'extDbName',
               descr          => 'the external database name to tag the data with.',
               reqd           => 1,
               constraintFunc => undef,
               isList         => 0,
             }),
    stringArg({name           => 'extDbRlsVer',
               descr          => 'the version of the external database to tag the data with.',
               reqd           => 1,
               constraintFunc => undef,
               isList         => 0,
             }),
    fileArg({  name           => 'inputFile',
               descr          => 'file containing the data',
               constraintFunc => undef,
               reqd           => 1,
               mustExist      => 1,
               isList         => 0,
               format         =>'Tab-delimited.'
             }), 
   ];

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class); 

  $self->initialize({requiredDbVersion => 4.0,
                     cvsRevision => '$Revision$', # cvs fills this in!
                     name => ref($self),
                     argsDeclaration => $argsDeclaration,
                     documentation => $documentation
                   });
  return $self;
}

sub run {
  my ($self) = @_;
  my $count = 0;
  my $dbiDb = $self->getDb();
  $dbiDb->setMaximumNumberOfObjects(100000);

  my $extDbRlsId = $self->getExtDbRlsId($self->getArg('extDbName'),
                                        $self->getArg('extDbRlsVer'));

  my $inputFile = $self->getArg('inputFile');

  $self->loadOntologyTerm($inputFile, $extDbRlsId);
  $self->loadProtocolAppNode($inputFile, $extDbRlsId);
  $self->loadStudy($inputFile, $extDbRlsId);

}

# load isolates into Study.Study and Study.StudyLink table
sub loadStudy {
  my ($self, $inputFile, $extDbRlsId) = @_;

  my %studyHash;
  my %publicationHash;

  my $seq_io = Bio::SeqIO->new(-file => $inputFile);

  while(my $seq = $seq_io->next_seq) {
    my $ac = $seq->annotation;

    my $source_id = $seq->accession_number;
    foreach my $key ( $ac->get_all_annotation_keys() ) { 
      next unless $key =~ /reference/i;
      my @values = $ac->get_Annotations($key);
      foreach my $value ( @values ) { 
        # value is an Bio::AnnotationI, and defines a "as_text" method
        # 'location' => 'Mol. Biochem. Parasitol. 61 (2), 159-169 (1993) PUBMED   7903426'

        my $title = $value->title;

        # tile cut to 200 characters - study.study name column
        $title = substr $title, 0, 150;
        my $location = $value->location;

        next if ($title eq "" || $title =~ /Direct Submission/i);
        push @{$studyHash{$title}}, $source_id; # title with a list of isolate source_id 

        my ($pmid) = $location =~ /PUBMED\s+(\d+)/;

        if($pmid) {
          $publicationHash{$title} = $pmid;
        }

        print "## $source_id|$location|$pmid\n";

        last; # load first title only ? should be good enough for isolates
        
      } # end foreach value   
     } # end foreach key
  } # end foreach seq

  print "\n\n";

  while(my ($title, $isolate_id_array_ref) = each %studyHash) {

    next if $title eq "";

    my $study = GUS::Model::Study::Study->new({ name => $title, 
                                                external_database_release_id => $extDbRlsId,
                                              });
    $study->submit;

    foreach my $isolate_id (@$isolate_id_array_ref) {

      my $study_id =  $self->getStudyId($title);
      my $protocol_app_node_id = $self->getProtocolAppNodeId($isolate_id);
      my $link = GUS::Model::Study::StudyLink->new({ study_id => $study_id,
                                                     protocol_app_node_id => $protocol_app_node_id,
                                                    });

      $link->submit;                                              
    }
  }

  while(my ($title, $pmid) = each %publicationHash) {
    $self->loadStudyBibRef($title, $pmid);
  }
}

sub loadStudyBibRef {
  my ($self, $title, $pmid) = @_;

  my $study_id = $self->getStudyId($title) ;

  pcbiPubmed::setPubmedID ($pmid);
  my $publication = pcbiPubmed::fetchPublication(); 
  my $authors = pcbiPubmed::fetchAuthorListLong();

  my $ref = GUS::Model::SRes::BibliographicReference->new({ title       => $title,
                                                            authors     => $authors,
                                                            publication => $publication,
                                                           });
  $ref->submit;

  $ref = GUS::Model::SRes::BibliographicReference->new({ title       => $title,
                                                         authors     => $authors,
                                                         publication => $publication,
                                                       });

  $ref->retrieveFromDB;

  my $ref_id = $ref->getBibliographicReferenceId();

  my $study_ref = GUS::Model::Study::StudyBibRef->new({ study_id                   => $study_id,
                                                        bibliographic_reference_id => $ref_id,
                                                      });
  $study_ref->submit;

}

sub loadOntologyTerm {
  my ($self, $inputFile, $extDbRlsId) = @_;

  my $seq_io = Bio::SeqIO->new(-file => $inputFile);

  my %termHash;
  my $count = 0;

  while(my $seq = $seq_io->next_seq) {

    my $source_id = $seq->accession_number;
    my $desc = $seq->desc;

    for my $feat ($seq->get_SeqFeatures) {    
      my $primary_tag = $feat->primary_tag;
      if($primary_tag =~ /source/i) {   # metadata will be loaded into study.characteristic table
        for my $tag ($feat->get_all_tags) {    
          $termHash{$tag} = 1;
        }   
      }
    }
  }

  # insert all distinct qualifier into SRes.OntologyTerm table 
  while(my ($term, $v) = each %termHash) {
    my $term = GUS::Model::SRes::OntologyTerm->new({ name                         => $term,
                                                     external_database_release_id => $extDbRlsId,
                                                   });
    $term->submit;
    $count++;
    $self->log("processed $count terms") if ($count % 1000) == 0;
  }
}

sub loadProtocolAppNode {
  my ($self, $inputFile, $extDbRlsId) = @_;

  my $count = 0;
  my $seq_io = Bio::SeqIO->new(-file => $inputFile);

  while(my $seq = $seq_io->next_seq) {

    my $source_id = $seq->accession_number;

    # insert an isolate into Study.ProtocolAppNode
    my $node = GUS::Model::Study::ProtocolAppNode->new({ type_id     => 1,  # not sure which type_id in sres.ontologyterm to use
                                                         description => $seq->desc,
                                                         name        => $source_id,  
                                                         source_id   => $source_id,
                                                         external_database_release_id => $extDbRlsId,
                                                       });
    $node->submit;

    # load source qualifier into Study.Characteristic table
    $self->loadCharacteristic($seq, $extDbRlsId);

    my $extNASeq = $self->buildSequence($seq->seq, $extDbRlsId);
    $extNASeq->setSourceId($source_id);

    $extNASeq->submit;
    $self->undefPointerCache();
    $count++;
    $self->log("processed $count") if ($count % 1000) == 0;
  }
  return "Inserted $count rows.";
}

sub loadCharacteristic {
  my($self, $seq, $extDbRlsId) = @_;

  for my $feat ($seq->get_SeqFeatures) {    
    my $primary_tag = $feat->primary_tag;
    if($primary_tag =~ /source/i) {   # metadata; study.characteristic table

      for my $tag ($feat->get_all_tags) {    
        print " tag: $tag =>";
        for my $value ($feat->get_tag_values($tag)) {
          print "  $value\n";
          my $characteristic = GUS::Model::Study::Characteristic->new( { 
                                      protocol_app_node_id => $self->getProtocolAppNodeId($seq->accession_number), 
                                      ontology_term_id     => $self->getOntologyTermId($tag, $extDbRlsId),
                                      value => $value,
                                      });
          $characteristic->submit(); 
        }
      }   
    }
  }
}

sub getProtocolAppNodeId {
  my ($self, $source_id) = @_;

  my $node = GUS::Model::Study::ProtocolAppNode->new({ source_id => $source_id });
  $node->retrieveFromDB;
  return $node->getProtocolAppNodeId();
}

sub getStudyId {
  my ($self, $name) = @_;

  my $study = GUS::Model::Study::Study->new({ name => $name });
  $study->retrieveFromDB;
  return $study->getStudyId();
}

sub getOntologyTermId {
  my ($self, $tag, $extDbRlsId) = @_;

  my $term = GUS::Model::SRes::OntologyTerm->new({ name => $tag,
                                                   external_database_release_id => $extDbRlsId,
                                                  });
  $term->retrieveFromDB;
  return $term->getOntologyTermId();
}

sub buildSequence {
  my ($self, $seq, $extDbRlsId) = @_;

  my $extNASeq = GUS::Model::DoTS::ExternalNASequence->new();

  $extNASeq->setExternalDatabaseReleaseId($extDbRlsId);
  $extNASeq->setSequence($seq);
  $extNASeq->setSequenceVersion(1);

  return $extNASeq;
}

sub undoTables {
  my ($self) = @_;
  return ( 'DoTS.ExternalNASequence',
           'Study.Study',
           'Study.StudyLink',
           'Study.StudyBibRef',
           'Study.ProtocolAppNode',
           'Study.Characteristic',
           'SRes.OntologyTerm',
           'SRes.BibliographicReference', 
         );
}

1;

