
package ApiCommonData::Load::Plugin::InsertSequenceFeatures;

@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use Bio::SeqIO;
use Bio::Tools::SeqStats;
use Bio::Tools::GFF;
use Bio::SeqFeature::Tools::Unflattener;

use GUS::PluginMgr::Plugin;
use ApiCommonData::Load::BioperlFeatMapperSet;
use ApiCommonData::Load::SequenceIterator;

#GENERAL USAGE TABLES
use GUS::Model::SRes::ExternalDatabase;
use GUS::Model::SRes::ExternalDatabaseRelease;
use GUS::Model::SRes::Reference;

#USED IN LOADING NASEQUENCE
use GUS::Model::SRes::TaxonName;
use GUS::Model::SRes::SequenceOntology;
use GUS::Model::DoTS::SequenceType;
use GUS::Model::DoTS::NASequence;
use GUS::Model::DoTS::ExternalNASequence;
use GUS::Model::DoTS::VirtualSequence;
use GUS::Model::DoTS::Assembly;
use GUS::Model::DoTS::SplicedNASequence;
use GUS::Model::DoTS::NAEntry;
use GUS::Model::DoTS::SecondaryAccs;
use GUS::Model::DoTS::NALocation;
use GUS::Model::DoTS::NASequenceRef;
use GUS::Model::DoTS::Keyword;
use GUS::Model::DoTS::NAComment;

#USED BY TRANSCRIPT FEATURES TO LOAD THE TRANSLATED PROTEIN SEQ
use GUS::Model::DoTS::TranslatedAAFeature;
use GUS::Model::DoTS::TranslatedAASequence;

#TABLES AND VIEWS USED IN SPECIAL CASES
use GUS::Model::DoTS::NAGene;
use GUS::Model::DoTS::NAProtein;
use GUS::Model::DoTS::NAPrimaryTranscript;
use GUS::Model::SRes::DbRef;
use GUS::Model::DoTS::NAFeatureComment;
use GUS::Model::DoTS::NASequenceOrganelle;
use GUS::Model::DoTS::NASequenceKeyword;
use GUS::Model::DoTS::NAFeatureNAGene;
use GUS::Model::DoTS::NAFeatureNAPT;
use GUS::Model::DoTS::NAFeatureNAProtein;
use GUS::Model::DoTS::DbRefNAFeature;



#FROM MY NOTES
# need chromosome in na sequence, not just source.

#steve's requests
#- improved error msg if bioperl parser fails (inlude the affected vars)
#- handle failures from making Feature (eg, db xref not found)

# future considerations....
#
# - handling dbxrefs (if we ever need this):
#    - by default, use name from input as db name
#    - by default, use "unknown" as version
#    - take optional --defaultDbxrefVersion on command line
#    - take optional --dbxrefMapFile on command line
#    - the map file maps from input name to GUS name and (optionally) version
#    - when a name is first encountered in input, read all its ids into memory
#    - if a name is not found in GUS or mapping filem, error
#
# - do we need to fill in info in TranslatedAASeq and TranslatedAAFeat such as:
#    - so term
#    - source id
#    - is simple 
#
# - take a cmd line arg for a mapping file for SeqType CV
#
# - handle the case of multiple tag values better... should be controlled by xml file

  my $description = <<NOTES;
This is the first version of this application, and it does not handle updates at this time.

Also note that we need to move a couple more arguments to the command line!!

Finally, it only handles four special cases that we encounter in the C.parvum and C.hominis GenBank Files.
NOTES

  my $purpose = <<PURPOSE;
This application will load any annotated sequence file into GUS via BioPerl's Bio::Seq interface so long as there is a valid Bioperl format module.
PURPOSE

  my $purposeBrief = <<PURPOSEBRIEF;
Load any and all annotated sequence data formats into GUS.
PURPOSEBRIEF

  my $syntax = <<SYNTAX;
ga GUS::Common::Plugin::LoadAnnotatedSeqs
--mapFile [xml file containg correct feature->gus feature mapping]
--seqFile [your data file]
--fileFormat [valid BioPerl name for the fprmat of your data file (e.g. genbank)
--db_rls_id=[The gus external database release id for this data set
--commit
SYNTAX

  my $notes = <<NOTES;
This is only in insert mode right now, and has only been tested for GenBank.  It is still a new plugin.
NOTES

  my $tablesAffected = <<AFFECT;
All views of NaFeatureImp, DbRefNaSequence, NAProtein, NaProteinNaFeature, NaSequenceImp
AFFECT

  my $tablesDependedOn = <<TABD;
A whole bunch, I will have to go through this list soon.
TABD

  my $howToRestart = <<RESTART;
Kill and re-submit it.
RESTART

  my $failureCases = <<FAIL;
It just craps out and you figure out what you need to add.  Oy vey.
FAIL

my $documentation = { purpose=>$purpose, 
		      purposeBrief=>$purposeBrief,
		      tablesAffected=>$tablesAffected,
		      tablesDependedOn=>$tablesDependedOn,
		      howToRestart=>$howToRestart,
		      failureCases=>$failureCases,notes=>$notes
		    };

my $argsDeclaration  =
  [
   fileArg({name => 'mapFile',
	    descr => 'XML file with mapping of Sequence Features from BioPerl to GUS',
	    constraintFunc=> undef,
	    reqd  => 1,
	    isList => 0,
	    mustExist => 1,
	    format=>'XML'
	   }),

   fileArg({name => 'seqFile',
	    descr => 'Text file containing features and optionally sequence data',
	    constraintFunc=> undef,
	    reqd  => 1,
	    isList => 0,
	    mustExist => 1,
	    format=>'Text'
	   }),

   enumArg({name => 'naSequenceSubclass',
	    descr => 'If the input file does not include the sequence, the subclass of NASequence in which to find the sequence (which must already be in the database)',
	    constraintFunc=> undef,
	    reqd  => 0,
	    isList => 0,
	    enum => "ExternalNASequence, VirtualSequence, Assembly, SplicedNASequence",
	   }),

   enumArg({name => 'seqIdColumn',
	    descr => 'The column to use to identify the sequence in the database (if input does not contain sequence).',
	    constraintFunc=> undef,
	    reqd  => 0,
	    isList => 0,
	    enum => "na_sequence_id, source_id",
	    default => "source_id",
	   }),


   stringArg({name => 'seqType',
	      descr => 'The type of the sequences in the input file (from DoTS.SequenceType.name)',
	      constraintFunc=> undef,
	      reqd  => 0,
	      isList => 0,
	      default => "DNA",
	     }),

   stringArg({name => 'seqSoTerm',
	      descr => 'The SO term describing the sequences in the input file ',
	      constraintFunc=> undef,
	      reqd  => 0,
	      isList => 0,
	     }),

   stringArg({name => 'soCvsVersion',
	      descr => 'The CVS version of the Sequence Ontology to use',
	      constraintFunc=> undef,
	      reqd  => 0,
	      isList => 0,
	     }),

   stringArg({name => 'fileFormat',
	      descr => 'Format of external data being loaded.  See Bio::SeqIO::new() for allowed options.  GFF is an additional options',
	      constraintFunc=> undef,
	      reqd  => 1,
	      isList => 0
	     }),

   enumArg({name => 'gffFormat',
	      descr => 'Format (version) of GFF, if GFF is the input format',
	      constraintFunc=> undef,
	      reqd  => 0,
	      isList => 0,
	      enum=>"2,3",
              default => 2,
	     }),

   stringArg({name => 'gff2GroupTag',
	      descr => 'Name of the tag to be used for GFF2 grouping',
	      constraintFunc=> undef,
	      reqd  => 0,
	      isList => 1,
              default => "GenePrediction,Gene",
	     }),

   stringArg({name => 'extDbName',
	      descr => 'External database from whence this data came',
	      constraintFunc=> undef,
	      reqd  => 1,
	      isList => 0
	     }),

   stringArg({name => 'extDbRlsVer',
	      descr => 'Version of external database from whence this data came',
	      constraintFunc=> undef,
	      reqd  => 1,
	      isList => 0
	     }),

   stringArg({name => 'downloadURL',
	      descr => 'URL from whence this file came should include filename',
	      constraintFunc=> undef,
	      reqd  => 0,
	      isList => 0
	     }),

   stringArg({name => 'extDbRlsDate',
	      descr => 'Release date of external data source',
	      constraintFunc=> undef,
	      reqd  => 0,
	      isList => 0
	     }),

   stringArg({name => 'filename',
	      descr => 'Name of the file in the resource (including path)',
	      constraintFunc=> undef,
	      reqd  => 0,
	      isList => 0
	     }),

   stringArg({name => 'description',
	      descr => 'a quoted description of the resource, should include the download date',
	      constraintFunc=> undef,
	      reqd  => 0,
	      isList => 0
	     }),

   stringArg({name => 'failDir',
	      descr => 'where to place a failure log',
	      constraintFunc=> undef,
	      reqd  => 0,
	      isList => 0
	     }),

   stringArg({name => 'projectName',
	      descr => 'project this data belongs to - must in entered in GUS',
	      constraintFunc=> undef,
	      reqd  => 0,
	      isList => 0
	     }),

   integerArg({name => 'restartPoint',
	       descr => 'Point at which to restart submitting data.  Format = SEQ:[ID] or FEAT:[ID]',
	       constraintFunc=> undef,
	       reqd  => 0,
	       isList => 0
	      }),

   integerArg({name => 'testNumber',
	       descr => 'number of entries to do test on',
	       constraintFunc=> undef,
	       reqd  => 0,
	       isList => 0
	      }),

   booleanArg({name => 'isUpdateMode',
	       descr => 'whether this is an update mode',
	       constraintFunc=> undef,
	       reqd  => 0,
	       isList => 0,
	       default => 0,
	      }),
  ];


sub new {
  my $class = shift;
  my $self = {};
  bless($self, $class);

  $self->initialize({requiredDbVersion => 3.5,
		     cvsRevision => '$Revision$',
		     name => ref($self),
		     argsDeclaration => $argsDeclaration,
		     documentation => $documentation
		    });

  return $self;
}

sub run{
  my ($self) = @_;

  my $dbh = $self->getDbHandle();
  $dbh->{'LongReadLen'} = 10_000_000;

  $dbh = $self->getQueryHandle();
  $dbh->{'LongReadLen'} = 10_000_000;

  $self->{mapperSet} =
    ApiCommonData::Load::BioperlFeatMapperSet->new($self->getArg('mapFile'));

  my $dbRlsId = $self->getExtDbRlsId($self->getArg('extDbName'),
				     $self->getArg('extDbRlsVer'))
    or die "Couldn't retrieve external database!\n";

  $self->getSoPrimaryKeys(); ## pre-load into memory and validate

  $self->{immedFeatureCount} = 0;
  my $featureTreeCount=0;
  my $seqCount=0;
  my $bioperlSeqIO = $self->getSeqIO();

  while (my $bioperlSeq = $bioperlSeqIO->next_seq() ) {

    my $naSequence;
    if ($self->getArg('naSequenceSubclass')) {
      $naSequence = $self->retrieveNASequence($bioperlSeq);
    } else {
      $naSequence = $self->bioperl2NASequence($bioperlSeq);
      $naSequence->submit();
    }

    # use id instead of object because object is zapped by undefPointerCache
    my $naSequenceId = $naSequence->getNaSequenceId();

    $seqCount++;

    $self->unflatten($bioperlSeq)
      unless ($self->getArg("fileFormat") =~ m/^gff$/i);

    foreach my $bioperlFeatureTree ($bioperlSeq->get_SeqFeatures()) {
      my $NAFeature = $self->makeFeature($bioperlFeatureTree, $naSequenceId);
      $NAFeature->submit();
      $featureTreeCount++;
    }
    $self->undefPointerCache();
  }

  my $filename = $self->getArg('seqFile');
  my $format = $self->getArg('fileFormat');
  $self->setResultDescr("Processed: $filename : $format \n\t Seqs Inserted: $seqCount \n\t Features Inserted: $self->{immedFeatureCount} \n\t Feature Trees Inserted: $featureTreeCount");
}

sub unflatten {
  my ($self, $seq) = @_;

  my $unflattener =
    $self->{_unflattener} ||= Bio::SeqFeature::Tools::Unflattener->new();

  $unflattener->unflatten_seq(-seq => $seq,
			      -use_magic => 1);
}

sub getSeqIO {
  my ($self) = @_;

  my $format = $self->getArg('fileFormat');

  my $bioperlSeqIO;

  # SDF: what does bioperl do on a parsing error?   does it die?   if so, 
  # we probably want to catch that error, and add to it the filename we are
  # parsing, if they don't already state that

  # AJM: it throws an error (i.e. dies with context) during next_seq
  # (which is when/where the parsing is happening, not here during IO
  # construction); it also can throw warnings which you might also
  # want to catch via a $SIG{__WARN__} handler

  if ($format =~ m/^gff$/i) {
    # convert a GFF "features-referring-to-sequence" stream into a
    # "sequences-with-features" stream; also aggregate grouped features.
    my $gffIO = Bio::Tools::GFF->new(-file => $self->getArg('seqFile'),
				     -gff_format => $self->getArg('gffFormat')
				    );

    my @aggregators =
      map {
	Feature::Aggregator->new($_, $self->getArg("gff2GroupTag"));
      } qw(Bio::DB::GFF::Aggregator::processed_transcript);
    
    my %seqs; my @seqs;
    while (my $feature = $gffIO->next_feature()) {
      push @{$seqs{$feature->seq_id}}, $feature;
    }

    while (my ($seq_id, $features) = each %seqs) {
      my $seq = Bio::Seq->new( -alphabet => 'dna',
			       -display_id => $seq_id,
			       -accession_number => $seq_id,
			     );

      if ($self->getArg('gffFormat') < 3) {
	# GFF2 - use group aggregators to re-nest subfeatures
	for my $aggregator (@aggregators) {
	  $aggregator->aggregate($features);
	}
      } else {
	# GFF3 - use explicit ID/Parent hierarchy to re-nest
	# subfeatures
	my %top; my %children; my @keep;

	for my $feature (@$features) {
	  my $id = 0;
	  ($id) = $feature->each_tag_value("ID")
	    if $feature->has_tag("ID");
	  if ($feature->has_tag("Parent")) {
	    for my $parent ($feature->each_tag_value("Parent")) {
	      push @{$children{$parent}}, [$id, $feature];
	    }
	  } else {
	    push @keep, $feature;
	    $top{$id} = $feature if $id; # only features with IDs can
                                         # have children
	  }
	}

	# breadth-first tree reconstruction - uses a stack to avoid
	# recursion.
	while (my ($id, $feature) = each %top) {
	  my @children =
	    map {
	      push @$_, $feature;
	    } @{delete($children{$id}) || []};
	  while (my $child = shift @children) {
	    my ($id, $feature, $parent) = @$child;
	    $parent->add_SubFeature($feature);
	    push @children,
	      map {
		push @$_, $feature;
	      } @{delete($children{$id}) || []};
	  }
	}

	# replace original feature list with new nested versions:
	@$features = @keep;
      }

      $seq->add_SeqFeature($_) for @$features;
      push @seqs, $seq;
    }

    $bioperlSeqIO = ApiCommonData::Load::SequenceIterator->new(\@seqs);

  } else {
    $bioperlSeqIO = Bio::SeqIO->new(-format => $format,
				    -file   => $self->getArg('seqFile'));
  }

  return $bioperlSeqIO;
}

###########################################################################
########     sequence processing
###########################################################################

# if the input does not include sequence, get it from the db
sub retrieveNASequence {
  my ($self, $bioperlSeq) = @_;

  my $dbRlsId = $self->getExtDbRlsId($self->getArg('extDbName'),
				     $self->getArg('extDbRlsVer'));

  my $naSequenceSubclass = $self->getArg('naSequenceSubclass');
  my $seqIdColumn = $self->getArg('seqIdColumn');

  $seqIdColumn or die "if you provide --naSequenceSubclass you must also provide --seqIdColumn";

  my $class = "GUS::Model::DoTS::$naSequenceSubclass";
  my $naSequence = $class->
    new({ external_database_release_id => $dbRlsId,
	  $seqIdColumn => $bioperlSeq->accession_number});

  $naSequence->retrieveFromDB() or die "--naSequenceSubclass is set on the command line so input file is not providing the sequence.  Failed attempting to retrieve naSequenceSubclass '$naSequenceSubclass' with seqIdColumn '$seqIdColumn' and extDbRlsId: '$dbRlsId'\n";

  return $naSequence;
}

# if the input does include sequence, make GUS NASequence from bioperlSeq
sub bioperl2NASequence {
  my ($self, $bioperlSeq) = @_;

  my $dbRlsId = $self->getExtDbRlsId($self->getArg('extDbName'),
				     $self->getArg('extDbRlsVer'));

  my $naSequence = $self->constructNASequence($bioperlSeq, $dbRlsId);

  my $naEntry = $self->makeNAEntry($bioperlSeq);

  $naSequence->addChild($naEntry);

  $self->addSecondaryAccs($bioperlSeq, $naEntry, $dbRlsId);

  $self->addReferences($bioperlSeq, $naSequence);

  $self->addComments($bioperlSeq, $naSequence);

  $self->addKeywords($bioperlSeq, $naSequence);

  #Annotations we haven't used yet
  #   SEGMENT      segment             SimpleValue e.g. "1 of 2"
  #   ORIGIN       origin              SimpleValue e.g. "X Chromosome."
  #   INV          date_changed        SimpleValue e.g. "08-JUL-1994"

  return $naSequence;
}

sub constructNASequence {
  my ($self, $bioperlSeq, $dbRlsId) = @_;

  if (!$bioperlSeq->seq()) {
    die "No input sequence found for " . $bioperlSeq->accession_number() . "  If the input intentionally contains no sequence, please use --naSequenceSubclass and --seqIdColumn\n";
  }
  my $naSequence = GUS::Model::DoTS::ExternalNASequence->
    new({ external_database_release_id => $dbRlsId,
	  source_id => $bioperlSeq->accession_number});

  my $seqType = $self->getArg('seqType');
  if ($seqType) { 
    $naSequence->setSequenceTypeId($self->getSeqTypeId($seqType));
  }
  my $soTerm = $self->getArg('seqSoTerm');
  if ($soTerm) {
    $naSequence->setSequenceOntologyId($self->{soPrimaryKeys}->{$soTerm});
  }
  my $taxId = $self->getTaxonId($bioperlSeq);
  $naSequence->setTaxonId($taxId);
  $naSequence->setName($bioperlSeq->primary_id());
  $naSequence->setDescription($bioperlSeq->desc());
  $naSequence->setSequenceVersion($bioperlSeq->seq_version());

  if ($bioperlSeq->seq) {
      my $seqcount = Bio::Tools::SeqStats->count_monomers($bioperlSeq);
      $naSequence->setSequence($bioperlSeq->seq());
      $naSequence->setACount(%$seqcount->{'A'});
      $naSequence->setCCount(%$seqcount->{'C'});
      $naSequence->setGCount(%$seqcount->{'G'});
      $naSequence->setTCount(%$seqcount->{'T'}); #RNA Seqs??
      $naSequence->setLength($bioperlSeq->length());
  }

  return $naSequence;
}

sub addSecondaryAccs{
  my ($self, $bioperlSeq, $naEntry, $dbRlsId) = @_;

  my @bioperlSecondaryAccs = $bioperlSeq->get_secondary_accessions();

  foreach my $bioperlSecondaryAcc (@bioperlSecondaryAccs) {
    my $secondaryAccession = GUS::Model::DoTS::SecondaryAccs->new();
    $secondaryAccession->setSourceId($bioperlSeq->accession_number());
    $secondaryAccession->setSecondaryAccs($bioperlSecondaryAcc);
    $secondaryAccession->setExternalDatabaseReleaseId($dbRlsId);
    $naEntry->addChild($secondaryAccession);
  }
}

sub addReferences {
  my ($self, $bioperlSeq, $naSequence,) = @_;

  my $bioperlAnnotation = $bioperlSeq->annotation();

  my @bioperlReferences = $bioperlAnnotation->get_Annotations('reference');

  foreach my $bioperlReference (@bioperlReferences) {
    my $bpReferenceHash = $bioperlReference->hash_tree();
    my $reference = GUS::Model::SRes::Reference->new() ;
    $reference->setAuthor($bpReferenceHash->{'authors'});
    $reference->setTitle($bpReferenceHash->{'title'});
    $reference->setJournalOrBookName($bpReferenceHash->{'location'});

    unless ($reference->retrieveFromDB())  {
      $reference->submit();
    }

    my $refId = $reference->getId();
    my $naSequenceRef = 
      GUS::Model::DoTS::NASequenceRef->new({'reference_id'=>$refId});

    $naSequence->addChild($naSequenceRef);
  }
}

sub addComments {
  my ($self, $bioperlSeq, $naSequence) = @_;

  my $bioperlAnnotation = $bioperlSeq->annotation();

  my @bioperlComments = $bioperlAnnotation->get_Annotations('comment');
  foreach my $bioperlComment (@bioperlComments) {
    my $naComment = GUS::Model::DoTS::NAComment->
      new({'comment_string'=>$bioperlComment->value()});
    $naSequence->addChild($naComment);
  }
}

sub addKeywords {
  my ($self, $bioperlSeq, $naSequence) = @_;

  my $bioperlAnnotation = $bioperlSeq->annotation();

    my @bioperlKeywords = $bioperlAnnotation->get_Annotations('keyword');
    foreach my $bioperlKeyword (@bioperlKeywords) {

      my $keyword = 
	GUS::Model::DoTS::Keyword->new({'keyword'=>$bioperlKeyword->value()});

      unless ($keyword->retrieveFromDB())  {
	$keyword->submit();
      }

      my $keyId = $keyword->getId();
      my $naSequenceKeyword =
	GUS::Model::DoTS::NASequenceKeyword->new({'keyword_id'=>$keyId});

      $naSequence->addChild($naSequenceKeyword);
    }
}


sub makeNAEntry {
  my ($self, $bioperlSeq) = @_;

  my $NAEntry = GUS::Model::DoTS::NAEntry->new();
  $NAEntry->setSourceId($bioperlSeq->accession_number());
  $NAEntry->setDivision($bioperlSeq->division());
  $NAEntry->setVersion($bioperlSeq->seq_version());
  return $NAEntry;
}



###########################################################################
########     feature processing
###########################################################################

sub makeFeature {
  my ($self, $bioperlFeature, $naSequenceId) = @_; 

  # there is an error in the bioperl unflattener such that there may be
  # exon-less rRNAs (eg, in C.parvum short contigs containing only rRNAs)
  # this method has extra logic to compensate for that problem.

  # map the immediate bioperl feature into a gus feature
  my $feature = $self->makeImmediateFeature($bioperlFeature, $naSequenceId);

  # call method to handle unflattener error of giving rRNAs no exon.
  $self->handleExonlessRRNA($bioperlFeature, $feature, $naSequenceId);

  # recurse through the children
  foreach my $bioperlChildFeature ($bioperlFeature->get_SeqFeatures()) {
    my $childFeature =
      $self->makeFeature($bioperlChildFeature, $naSequenceId);
    $feature->addChild($childFeature);
  }
  return $feature;
}

# make a feature itself without worrying about its children
sub makeImmediateFeature {
  my ($self, $bioperlFeature, $naSequenceId) = @_;


  my $tag = $bioperlFeature->primary_tag();

  my $featureMapper = $self->{mapperSet}->getMapperByFeatureName($tag);

  my $gusObjName = $featureMapper->getGusObjectName();

  my $feature = eval "{require $gusObjName; $gusObjName->new()}";

  $feature->setNaSequenceId($naSequenceId);
  $feature->setName($bioperlFeature->primary_tag());

  my $soTerm = $featureMapper->getSoTerm();
  if ($soTerm) {
    $feature->setSequenceOntologyId($self->{soPrimaryKeys}->{$soTerm});
  }
  $feature->addChild($self->makeLocation($bioperlFeature->location(),
					 $bioperlFeature->strand()));

  foreach my $tag ($bioperlFeature->get_all_tags()) {
    $self->handleFeatureTag($bioperlFeature, $featureMapper, $feature, $tag);
  }

  $self->{immedFeatureCount}++;
  return $feature;
}

sub makeLocation {
  my ($self, $f_location, $strand) = @_;

  if ($strand == 0) {
    $strand = '';
  }
  if ($strand == 1) {
    $strand = 0;
  }
  if ($strand == -1) {
    $strand = 1;
  }
   
  my $min_start = $f_location->min_start();
  my $max_start = $f_location->max_start();
  my $min_end = $f_location->min_end();
  my $max_end = $f_location->max_end();
  my $start_pos_type = $f_location->start_pos_type();
  my $end_pos_type = $f_location->end_pos_type();
  my $location_type = $f_location->location_type();
  my $start = $f_location->start();
  my $end = $f_location->end();

  my $gus_location = GUS::Model::DoTS::NALocation->new();
  $gus_location->setStartMax($max_start);
  $gus_location->setStartMin($min_start);
  $gus_location->setEndMax($max_end);
  $gus_location->setEndMin($min_end);
  $gus_location->setIsReversed($strand);
  $gus_location->setLocationType($location_type);

  return $gus_location;
}

sub getSoGusId {
  my ($self, $SOname) = @_;

  return $self->getIdFromCache('seqOntologyCache',
			       $SOname,
			       'GUS::Model::SRes::SequenceOntology',
			       "so_id",
			      );

}

sub getSeqTypeId {
  my ($self, $seqType) = @_;

  return $self->getIdFromCache('seqTypeCache',
			       $seqType,
			       'GUS::Model::DoTS::SequenceType',
			       "name",
			      );

}

sub getTaxonId {
  my ($self, $bioperlSeq) = @_;

  my $spec = $bioperlSeq->species();
  my $genName = $spec->genus();
  my $spcName = $spec->species();
  my $sciName = "$genName $spcName";

  return $self->getIdFromCache('taxonIdCache',
			       $sciName,
			       'GUS::Model::SRes::TaxonName',
			       "name",
			      );

}

sub handleFeatureTag {
  my ($self, $bioperlFeature, $featureMapper, $feature, $tag) = @_;


  #future suggestion: special not if then, special can also have a column value or be lost

  return if ($featureMapper->isLost($tag));

  if ($featureMapper->isSpecialCase($tag)) {
    my @tagValues = $bioperlFeature->get_tag_values($tag);
    foreach my $tagValue (@tagValues) {
      my $specialCaseChild = $self->makeSpecialCaseChild($tag,
						      $tagValue,
						      $featureMapper,
						      $bioperlFeature,
						      #$featureMap);
						      );
      $feature->addChild($specialCaseChild);
    }

  }

  else {
    #my $gusColumnName = $featureMapper->getGusColumn($featureMap, $tag);
    my $gusColumnName = $featureMapper->getGusColumn($tag);
    if ($tag && !$gusColumnName) { die "invalid tag, No Mapping [$tag]\n"; }

    my @tagValues = $bioperlFeature->get_tag_values($tag);
    if (scalar(@tagValues) == 1) { 
      if (@tagValues[0] ne "_no_value") { 
	$feature->set($gusColumnName, $tagValues[0]);
      }
    }
    else {
      #die "invalid tag: more than one value\n"; }
      #snoRNA creates a bunch of empty values! Ignore and keep going.
    }
  }
}

# compensate from error in unflattener that gives no exon to rRNAs sometimes
sub handleExonlessRRNA {
  my ($self, $bioperlFeature, $feature, $naSequenceId) = @_;

  if ($bioperlFeature->primary_tag() eq 'rRNA'
      && (scalar($bioperlFeature->get_SeqFeatures()) == 0)) {
    my $exonFeature = GUS::Model::DoTS::ExonFeature->new();
    $exonFeature->setNaSequenceId($naSequenceId);
    $exonFeature->setName('Exon');
    $exonFeature->addChild($self->makeLocation($bioperlFeature->location(),
					       $bioperlFeature->strand()));
    #exonFeature->setSequenceOntologyId();
    $feature->addChild($exonFeature);
  }
}


# ----------------------------------------------------------
# Handler for special cases
# ----------------------------------------------------------

sub makeSpecialCaseChild {
  my ($self, $tag, $value, $featureMapper) = @_;

  my $specialcase = $featureMapper->isSpecialCase($tag);

  return $self->buildDbXRef($value) if ($specialcase eq 'dbxref');

  return $self->buildProtein($value) if ($specialcase eq 'product');

  return $self->buildNote($value) if ($specialcase eq 'note');

  return $self->buildGene($value) if ($specialcase eq 'gene');

  return $self->buildTranslatedAAFeature($value) if ($specialcase eq 'aaseq');

  die "Unsupported Special Case: $specialcase";
}


#---------------------------------------
# All special cases
#---------------------------------------
sub buildGene {
  my ($self, $geneName) = @_;
  my $geneID = $self->getNAGeneId($geneName);
  my $gene = GUS::Model::DoTS::NAFeatureNAGene->new();
  $gene->setNaGeneId($geneID);
  return $gene;
}

sub getNAGeneId {   
  my ($self, $geneName) = @_;
  my $truncName = substr($geneName,0,300);
  if (!$self->geneNameIds->{$truncName}) {
    my $gene = GUS::Model::DoTS::NAGene->new({'name' => $truncName});
    unless ($gene->retrieveFromDB()){
      $gene->setIsVerified(0);
      $gene->submit();
    }
    $self->geneNameIds->{$truncName} = $gene->getId();
  }
  return $self->geneNameIds->{$truncName};
}


sub buildDbXRef {
  my ($self, $dbSpecifier) = @_;

  my $dbRefNaFeature = GUS::Model::DoTS::DbRefNAFeature->new();
  my $id = $self->getDbXRefId($dbSpecifier);
  $dbRefNaFeature->setDbRefId($id);

  ## If DbRef is outside of Genbank, then link directly to sequence
  #if (!($value =~ /taxon|GI|pseudo|dbSTS|dbEST/i)) {
  #  my $o2 = GUS::Model::DoTS::DbRefNASequence->new();
  #  $o2->setDbRefId($id);
  #}
  #else {
  # my $id = &getDbXRefId($value);}

  return $dbRefNaFeature;

}

sub getDbXRefId {
  my ($self, $dbSpecifier) = @_;

  if (!$self->{dbXrefIds}->{$dbSpecifier}) {
    my ($dbName, $id, $sid)= split(/\:/, $dbSpecifier);
    my $extDbRlsId = $self->getExtDatabaseRlsId($dbName);
    my $dbref = GUS::Model::SRes::DbRef->new({'external_database_release_id' => $extDbRlsId, 
					      'primary_identifier' => $id});

    if ($sid) {
      $dbref->setSecondaryIdentifier($sid);
    }
    unless ($dbref->retrieveFromDB()) {
      $dbref->submit();
    }

    $self->{dbXrefIds}->{$dbSpecifier} = $dbref->getId();
  }

  return $self->{dbXrefIds}->{$dbSpecifier};
}

sub getExtDatabaseRlsId {
  my ($self, $name) = @_;

  if (!$self->{extDbRlsIds}->{$name}) {
    my $externalDatabase
      = GUS::Model::SRes::ExternalDatabase->new({"name" => $name});

    unless($externalDatabase->retrieveFromDB()) {
      $externalDatabase->submit();
    }

    my $externalDatabaseRls = GUS::Model::SRes::ExternalDatabaseRelease->
      new ({'external_database_id'=>$externalDatabase->getId(),
	    'version'=>'unknown'});

    unless($externalDatabaseRls->retrieveFromDB()) {
      $externalDatabaseRls->submit();
    }

    $self->{extDbRlsIds}->{$name} = $externalDatabaseRls->getId();
  }
    return $self->{extDbRlsIds}->{$name};
}


sub buildNote {
  my ($self, $comment) = @_;
  my %note = ('comment_string' => substr($comment, 0, 4000));
  return GUS::Model::DoTS::NAFeatureComment->new(\%note);
}


sub buildProtein {
  my ($self, $proteinName) = @_;

  my $nameTrunc = substr($proteinName,0,300);

  my $naFeatureNaProtein = GUS::Model::DoTS::NAFeatureNAProtein->new();

  my $protein = GUS::Model::DoTS::NAProtein->new({'name' => $nameTrunc});
  unless ($protein->retrieveFromDB()){
    $protein->setIsVerified(0);
    $protein->submit();
  }

  $naFeatureNaProtein->setNaProteinId($protein->getId());

  return $naFeatureNaProtein;
}

sub buildTranslatedAAFeature {
  my ($self, $aaSequence) = @_;

  my $transAaFeat = GUS::Model::DoTS::TranslatedAAFeature->new();
  $transAaFeat->setIsPredicted(1);

  my $aaSeq = GUS::Model::DoTS::TranslatedAASequence->
    new({'sequence' => $aaSequence});
  $aaSeq->addChild($transAaFeat);
  $aaSeq->submit();

  return $transAaFeat;
}

sub buildTranslatedAASequence {
  my ($self, $sequence) = @_;

  my $aaSeq = GUS::Model::DoTS::TranslatedAASequence->new({'sequence' => $sequence});
  $aaSeq->submit();

  my $aaSeqId = $aaSeq->getId();

  return $aaSeqId;
}

##############################################################################
# Utilities
##############################################################################

sub getIdFromCache {
  my ($self, $cacheName, $name, $type, $field) = @_;

  my $id;

  if ($self->{$cacheName} == undef) {
    $self->{$cacheName}= {};
  }

  $id = $self->{$cacheName}->{$name};

  if (!$id && $name) {
    my $obj = $type->new({$field => $name });
    $obj->retrieveFromDB() 
      || die "Failed to retrieve $type id for $field = '$name'";
    my $id = $obj->getId();
    $self->{cacheName}->{$name} = $id;
  }
  return $id;
}

# for all SO terms used, find the GUS primary key
# include in search all SO terms in the mapping file, and the seq SO term
# from the cmd line
sub getSoPrimaryKeys {
  my ($self) = @_;

  my @soTerms = $self->{mapperSet}->getAllSoTerms();
  my $seqSoTerm = $self->getArg('seqSoTerm');
  if ($seqSoTerm) { push(@soTerms, $seqSoTerm); }

  return if (scalar(@soTerms) == 0);

  my $terms = join("', '", @soTerms);
  $terms = "'$terms'";

  my $soCvsVersion = $self->getArg('soCvsVersion');

  $soCvsVersion or $self->userError("You are using Sequence Ontology terms but have not provided a --soCvsVersion on the command line");

  my $dbh = $self->getQueryHandle();
  my $sql = "
select term_name, sequence_ontology_id
from sres.SequenceOntology
where term_name in ($terms)
and so_cvs_version = '$soCvsVersion'
";
  my $stmt = $dbh->prepareAndExecute($sql);
  while (my ($term, $pk) = $stmt->fetchrow_array()){
    $self->{soPrimaryKeys}->{$term} = $pk;
  }

  my @badSoTerms;
  foreach my $soTerm (@soTerms) {
    push(@badSoTerms, $soTerm) unless $self->{soPrimaryKeys}->{$soTerm};
  }

  my $mappingFile = $self->getArg('mapFile');
  (scalar(@badSoTerms) == 0) or $self->userError("Mapping file '$mappingFile' or cmd line args are using the following SO terms that are not found in the database for SO CVS version '$soCvsVersion': " . join(", ", @badSoTerms));
}

############################################################################
# Aggregator private class
############################################################################

package Feature::Aggregator;

sub new {
  my ($class, $agg, $grouptag) = @_;
  $class = ref $class || $class;

  my $self = { };
  bless $self, $class;

  eval "require $agg"; $agg = $agg->new();
  $self->{_matchsub} = $self->match_sub($agg);
  $self->{_main} = $agg->main_name;
  $self->{_grouptag} = $grouptag;
  
  return $self;
}

sub match_sub {
  my ($self, $agg) = @_;
  my @match = ($agg->main_name, $agg->part_names);
  my $matchre = join("|", map { "\Q$_\E" } @match);
  return sub {
    my $f = shift;
    $f->primary_tag =~ m/$matchre/i;
  }
}

sub aggregate {

  my ($self, $features) = @_;

  my @keep;
  my %groups;
  my @grouptags = @{$self->{_grouptag}};
  for my $feature (@$features) {
    if ($self->{_matchsub}->($feature)) {
      my $group;
      for my $grouptag (@grouptags) {
	($group) = $feature->each_tag_value($grouptag)
	  if ($feature->has_tag($grouptag));
      }
      die "No group tag in @{[join(', ', @grouptags)]}!" unless $group;
      if ($feature->primary_tag =~ m/$self->{_main}/i) {
	$groups{$feature->source_tag}->{$group}{base} = $feature;
	push @keep, $feature;
      } else {
	push @{$groups{$feature->source_tag}->{$group}{subparts}}, $feature;
      }
    } else {
      push @keep, $feature;
    }
  }

  for my $groups (values %groups) {
    while (my ($group, $parts) = each %$groups) {
      my ($base, $subparts) = @{$parts}{qw(base subparts)};
      unless ($base) {
	$base = $subparts->[0]->clone; # auto-vivify top-level feature
	push @keep, $base;
      }
      $base->add_SeqFeature($_) for @$subparts;
    }
  }

  @$features = @keep;
}


return 1;
