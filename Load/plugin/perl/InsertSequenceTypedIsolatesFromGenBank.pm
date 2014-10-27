package ApiCommonData::Load::Plugin::InsertSequenceTypedIsolatesFromGenBank;
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

  my $extDbRlsId = $self->getExtDbRlsId($self->getArg('extDbName'), $self->getArg('extDbRlsVer'));

  my $inputFile = $self->getArg('inputFile');

  my ($studyHash, $termHash, $nodeHash) = $self->readGenBankFile($inputFile, $extDbRlsId);

  $self->loadOntologyTerm($termHash, $extDbRlsId);

  my $nodes = $self->createProtocolAppNodeObject($studyHash, $nodeHash, $extDbRlsId);

  $self->loadStudy($studyHash, $nodes, $extDbRlsId);

  return $count; ### return count #### need update 
}

sub readGenBankFile {

  my ($self, $inputFile, $extDbRlsId) = @_;

  my %studyHash; # study name => { ids => @ids; pmid => pmid }
  my %termHash;  # list of distinct source modifiers
  my %nodeHash;  # isolate => { desc => desc; seq => seq; terms => { key => value } }

  my $seq_io = Bio::SeqIO->new(-file => $inputFile);

  while(my $seq = $seq_io->next_seq) {

    my $source_id = $seq->accession_number;
    my $desc = $seq->desc;

    $nodeHash{$source_id}{desc} = $desc;
    $nodeHash{$source_id}{seq}  = $seq->seq;

    # process source modifiers, store distince terms as a list
    for my $feat ($seq->get_SeqFeatures) {    
      my $primary_tag = $feat->primary_tag;
      if($primary_tag =~ /source/i) {   
        for my $tag ($feat->get_all_tags) {    
          $termHash{$tag} = 1;
          for my $value ($feat->get_tag_values($tag)) {
             $nodeHash{$source_id}{terms}{$tag} = $value;
          }
        }   
      }
    }

    # process references
    my $ac = $seq->annotation;

    foreach my $key ( $ac->get_all_annotation_keys ) { 
      next unless $key =~ /reference/i;
      my @values = $ac->get_Annotations($key);
      foreach my $value ( @values ) { 
        # value is an Bio::AnnotationI, and defines a "as_text" method
        # 'location' => 'Mol. Bi chem. Parasitol. 61 (2), 159-169 (1993) PUBMED   7903426'

        my $title = $value->title;

        # tile cut to 200 characters - study.study name column
        #$title = substr $title, 0, 150;
        my $location = $value->location;

        next if ($title eq "" || $title =~ /Direct Submission/i);

        push @{$studyHash{$title}{ids}}, $source_id; # title with a list of isolate source_id 

        my ($pmid) = $location =~ /PUBMED\s+(\d+)/;

        if($pmid) {
          $studyHash{$title}{pmid} = $pmid; 
        }

        last; # load first title only ? should be good enough for isolates
        
      } # end foreach value   
     } # end foreach key
  } # end foreach seq

  #print Dumper(%nodeHash);
  #print Dumper(%studyHash);

  $seq_io->close;

  $termHash{taxon} = 1; # add taxon as a term

  return (\%studyHash, \%termHash, \%nodeHash);
}

sub createProtocolAppNodeObject {
  my ($self, $studyHash, $nodeHash, $extDbRlsId) = @_;

  my %tmpHash;

  my $ontologyObj = GUS::Model::SRes::OntologyTerm->new({ name => 'sample from organism' });
  $ontologyObj->retrieveFromDB;
  my $type_id = $ontologyObj->getOntologyTermTypeId;

  # type_id in sres.ontologyterm to use # "sample from organism" or "DNA extract"
  while(my ($source_id, $v) = each %$nodeHash) {
    my $node = GUS::Model::Study::ProtocolAppNode->new({ type_id     => $type_id, 
                                                         description => $v->{desc},
                                                         name        => $source_id,  
                                                         source_id   => $source_id,
                                                         external_database_release_id => $extDbRlsId,
                                                         ### taxon

                                                       });

    while(my ($term, $value) = each %{$v->{terms}}) {

      if($term eq 'db_xref' && $value =~ /taxon/i) {
        $term = 'taxon';
        $value =~ s/taxon://;
        $node->setTaxonId($value);
      }

      $ontologyObj = GUS::Model::SRes::OntologyTerm->new({ name => $term,
                                                          external_database_release_id => $extDbRlsId,
                                                       });

      my $characteristic = GUS::Model::Study::Characteristic->new({ value => $value,
                                                                 });

      $characteristic->setParent($ontologyObj);
      $characteristic->setParent($node);
    }

    #my $extNASeq = GUS::Model::DoTS::ExternalNASequence->new();
    #$extNASeq->setExternalDatabaseReleaseId($extDbRlsId);
    #$extNASeq->setSequence($v->{seq});
    #$extNASeq->setSequenceVersion(1);
    #$extNASeq->addChild($node); 

    $tmpHash{$source_id} = $node;
  }

  return \%tmpHash;
}

sub loadStudy {

  my($self, $studyHash, $nodeObject, $extDbRlsId) = @_;

  while(my ($title, $sv) = each %$studyHash) {

    my $study = GUS::Model::Study::Study->new({ name => $title, 
                                                external_database_release_id => $extDbRlsId,
                                              });

    foreach my $id ( @{$sv->{ids}} ) {
      my $node = $nodeObject->{$id};
      my $link = GUS::Model::Study::StudyLink->new();
      $link->setParent($study);
      $link->setParent($node);
    } 

    my $pmid = $sv->{pmid}; 

    pcbiPubmed::setPubmedID ($pmid);
    my $publication = pcbiPubmed::fetchPublication(); 
    my $authors = pcbiPubmed::fetchAuthorListLong();

    my $ref = GUS::Model::SRes::BibliographicReference->new({ title       => $title,
                                                              authors     => $authors,
                                                              publication => $publication,
                                                             });

    my $study_ref = GUS::Model::Study::StudyBibRef->new();

    $study_ref->setParent($study);
    $study_ref->setParent($ref);

    $study->submit;
  }
}

sub loadOntologyTerm {
  my ($self, $termHash, $extDbRlsId) = @_;

  my $count = 0;

  # insert all distinct qualifier into SRes.OntologyTerm table 
  foreach my $term( keys %$termHash) {
    my $termObj = GUS::Model::SRes::OntologyTerm->new({ name                         => $term,
                                                        external_database_release_id => $extDbRlsId,
                                                      });

    if (!$termObj->retrieveFromDB ) {
      $termObj->submit; 
    } else {
      die "term $term has already exists in SRes.OntologyTerm table\n";
    }

    $count++;
    $self->log("processed $count terms") if ($count % 1000) == 0;
  }
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

