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
use GUS::Model::SRes::Taxon;
use GUS::Model::SRes::OntologyTerm;
use GUS::Model::SRes::BibliographicReference;
use GUS::Supported::Util; 
use Data::Dumper;

#use lib "$ENV{GUS_HOME}/lib/perl/ApiCommonWebsite/Model";
use EbrcModelCommon::Model::pcbiPubmed;

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

  $self->initialize({ requiredDbVersion => 4.0,
                      cvsRevision => '$Revision$', # cvs fills this in!
                      name => ref($self),
                      argsDeclaration => $argsDeclaration,
                      documentation => $documentation
                   });
  return $self;
}

sub run {

  my ($self) = @_;
  my $dbiDb = $self->getDb();
  $dbiDb->setMaximumNumberOfObjects(1000000);

  my $extDbRlsId = $self->getExtDbRlsId($self->getArg('extDbName'), $self->getArg('extDbRlsVer'));
  my $inputFile = $self->getArg('inputFile');

  my ($studyHash, $nodeHash, $termHash) = $self->readGenBankFile($inputFile, $extDbRlsId);

  $self->makeOntologyTerm($termHash, $extDbRlsId);

  my $count = $self->loadIsolates($studyHash, $nodeHash, $extDbRlsId);

  my $msg = "$count isolate records have been loaded.";
  $self->log("$msg \n");
  return $msg;
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
    foreach my $feat ($seq->get_SeqFeatures) {    
      
      my $primary_tag = $feat->primary_tag;
      foreach my $tag ($feat->get_all_tags) {    
        next if ($primary_tag =~ /cds/i && $tag ne "product"); # if tag is CDS/rna, only store product
        next if ($primary_tag =~ /rna/i && $tag ne "product"); 
        next if ($primary_tag =~ /variation/i && $tag eq "replace"); 
        next if ($primary_tag =~ /conflict/i); 

        $termHash{$tag} = 1;

        foreach my $value ($feat->get_tag_values($tag)) {
          #print "$source_id: $primary_tag: $tag => $value\n";

          if($tag eq "note" && $value =~ /:(.*)?;+/ ) { # handle EuPathDB notes - key:value ; key:value
            my @pairs = split /;/, $value;
            foreach my $p (@pairs) {
              my ($k, $v) = split /:/, $p;
              $k =~ s/^\s+|\s+$//g; # trim off leading and trailing white spaces
              $v =~ s/^\s+|\s+$//g; # trim off leading and trailing white spaces
              next if $k =~ /PCR_primers/i;

              if($v ne "") {
                $nodeHash{$source_id}{terms}{$k} = defined $nodeHash{$source_id}{terms}{$k} ? "$nodeHash{$source_id}{terms}{$k}; $v" : $v;
                $termHash{$k} = 1;
              } else { # in some cases, the text is not well formatted
                $nodeHash{$source_id}{terms}{note} = defined $nodeHash{$source_id}{terms}{note} ? "$nodeHash{$source_id}{terms}{note}; $k" : $k;
                $termHash{note} = 1;
              }
            }
          } else {
            $nodeHash{$source_id}{terms}{$tag} = defined $nodeHash{$source_id}{terms}{$tag} ? "$nodeHash{$source_id}{terms}{$tag}; $value" : $value;
          }
        }
      }   
    }

    # process references
    my $ac = $seq->annotation;

    foreach my $key ( $ac->get_all_annotation_keys ) { 
      next unless $key =~ /reference/i;
      my @values = $ac->get_Annotations($key);

      # one isolate record could have multiple references
      my $title_count = 0;

      foreach my $value ( @values ) { 
        # value is an Bio::AnnotationI
        # location => 'Mol. Bi chem. Parasitol. 61 (2), 159-169 (1993) PUBMED   7903426'

        my $title = $value->title;
        next if ($title eq "" || $title =~ /Direct Submission/i);

        my $location = $value->location;
        #my ($pmid) = $location =~ /PUBMED\s+(\d+)/;
        my ($pmid) = $value->pubmed;
        if($pmid) {
          push @{$studyHash{$title}{pmid}}, $pmid; 
        }

        # only associlate id with first title
        push @{$studyHash{$title}{ids}}, $source_id unless $title_count > 0; 
        $title_count++;

      } # end foreach value   

     } # end foreach key 
  } # end foreach seq

  $seq_io->close;

  $termHash{ncbi_taxon} = 1; # add hardcoded term "ncbi_taxon" as a term

  return (\%studyHash, \%nodeHash, \%termHash);
}

sub loadIsolates {

  my($self, $studyHash, $nodeHash, $extDbRlsId) = @_;

  my $count = 0;

  my $ontologyObj = GUS::Model::SRes::OntologyTerm->new({ name => 'sample from organism' });
  $self->error("cannot find ontology term 'sample from organism'") unless $ontologyObj->retrieveFromDB;

  while(my ($title, $v) = each %$studyHash) {

    my $study = GUS::Model::Study::Study->new();
    $study->setName("$title ($extDbRlsId)");
    $study->setExternalDatabaseReleaseId($extDbRlsId);

    foreach my $id ( @{$v->{ids}} ) {  # id is each isolate accession
      my $node = GUS::Model::Study::ProtocolAppNode->new();
      $node->setDescription($nodeHash->{$id}->{desc});
      $node->setName($id);
      $node->setSourceId($id);
      $node->setExternalDatabaseReleaseId($extDbRlsId);
      $node->setParent($ontologyObj);  # type_id 
      
      # skip loading duplicate isolate - https://redmine.apidb.org/issues/28720
      if($node->retrieveFromDB()) {
        print STDERR "\nWarning: found duplicate isolate $id, skip loading this isolate!\n";
        next;
      }

      # skip loading isolate with the same sound_id which is probably loaded under other organims 
      if(GUS::Supported::Util::getNASequenceId ($self, $id)) {
        print STDERR "\nWarning: found douplice isolate $id, probably loaded under different organism, skip loading this isolate!\n";
        next;
      }

      $study->addToSubmitList($node);

      my $extNASeq = $self->buildSequence($nodeHash->{$id}->{seq}, $id, $extDbRlsId);
      $study->addToSubmitList($extNASeq);

      # loop each source modifiers, e.g. isolate => cp2; host => cow
      while(my ($term, $value) = each %{$nodeHash->{$id}->{terms}}) {  
        if($term eq 'db_xref' && $value =~ /taxon\:(\d+)/i) {

          $term = 'ncbi_taxon';
          my $ncbiTax = $1;
          my $taxonObj = GUS::Model::SRes::Taxon->new({ ncbi_tax_id => $ncbiTax });

          if($taxonObj->retrieveFromDB()) {
            $node->setParent($taxonObj);
            $extNASeq->setParent($taxonObj);
          }
          else {
            $self->log("No Row in SRes::Taxon for ncbi tax id $ncbiTax");
          }
        }

        my $categoryOntologyObj = $self->findOntologyTermByCategory($term);
        my $characteristic = GUS::Model::Study::Characteristic->new();
     
        if (length($value)>2000){
           my $subLength = substr($value,0,1999);
           $value=$subLength;
        }
        $characteristic->setValue($value);
        my $qualifierId = $categoryOntologyObj->getId();
        $self->error("Failed to find (or create) an OntologyTerm for term: $term") unless($qualifierId);

        $characteristic->setQualifierId($qualifierId);
        $characteristic->setParent($node);
        #$characteristic->undefPointerCache(); # exceeded the maximum number of allowable objects in memory
      } # end load terms

      my $link = GUS::Model::Study::StudyLink->new();
      if($study->getStudyId()) { 
        $link->setParent($study);
        $link->setParent($node);
      }

      my $segmentResult = GUS::Model::Results::SegmentResult->new();
      ## need to handle feature location
      $segmentResult->setParent($extNASeq);
      $segmentResult->setParent($node);

      $count++;
    }

    my %seen = ();
    my @pmids = grep { ! $seen{$_}++ } @{$v->{pmid}};  # unique pmid

    foreach my $pmid (@pmids) { 

      EbrcModelCommon::Model::pcbiPubmed::setPubmedID ($pmid);
      my $publication = EbrcModelCommon::Model::pcbiPubmed::fetchPublication(); 
      my $authors = EbrcModelCommon::Model::pcbiPubmed::fetchAuthorListLong();

      my $ref = GUS::Model::SRes::BibliographicReference->new();
      $ref->setTitle($title);
      $ref->retrieveFromDB();

      $ref->setAuthors($authors);
      $ref->setPublication($publication);

      my $study_ref = GUS::Model::Study::StudyBibRef->new;
      $study_ref->setParent($study);
      $study_ref->setParent($ref);
    }

    $study->submit;
    $self->undefPointerCache();
    $study->undefPointerCache(); # exceeded the maximum number of allowable objects in memory
  }

  return $count;
}

sub addOntologyCategory {
  my ($self, $ontologyTermObj) = @_;
  push @{$self->{_ontology_category_terms} }, $ontologyTermObj;
}

sub findOntologyTermByCategory {
  my ($self, $name) = @_;
  if (length($name)>247){
     my $subLength = substr($name,0,247);
     $name=$subLength;
  }
  foreach my $term ( @{$self->{_ontology_category_terms}}) {
     return $term if ($term->getName eq $name);
  }

  $self->error("cannot find ontology name $name");
}

sub makeOntologyTerm {
  my ($self, $termHash, $extDbRlsId) = @_;

  foreach my $term( keys %$termHash) {
        if (length($term)>247){
           my $subLength = substr($term,0,247);
           $term=$subLength;
        }
    my $termObj = GUS::Model::SRes::OntologyTerm->new({ source_id => "GENISO $term" });

    unless  ($termObj->retrieveFromDB ){ 
      $termObj->setName($term);
      $termObj->setExternalDatabaseReleaseId($extDbRlsId);
      $termObj->submit();
    }

    $self->addOntologyCategory($termObj);
  }
}

sub buildSequence {
  my ($self, $seq, $source_id, $extDbRlsId) = @_;

  my $extNASeq = GUS::Model::DoTS::ExternalNASequence->new();

  $extNASeq->setExternalDatabaseReleaseId($extDbRlsId);
  $extNASeq->setSequence($seq);
  $extNASeq->setSourceId($source_id);
  $extNASeq->setSequenceVersion(1);

  return $extNASeq;
}

sub undoTables {
  my ($self) = @_;
  return (  'Results.SegmentResult',
            'DoTS.ExternalNASequence',
            'Study.StudyBibRef', 
            'Study.StudyLink',
            'Study.Characteristic',
            'Study.ProtocolAppNode',
            'Study.Study',
            'SRes.OntologyTerm',
         );

}

1;

