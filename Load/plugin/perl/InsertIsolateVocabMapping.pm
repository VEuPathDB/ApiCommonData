package ApiCommonData::Load::Plugin::InsertIsolateVocabMapping;
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
@ISA = qw(GUS::PluginMgr::Plugin);
 
use strict;

use FileHandle;
use GUS::PluginMgr::Plugin;

use ApiCommonData::Load::IsolateVocabulary::Reader::VocabSqlReader;

use ApiCommonData::Load::IsolateVocabulary::Reader::SqlTermReader;
use ApiCommonData::Load::IsolateVocabulary::Reader::XmlTermReader;

use ApiCommonData::Load::IsolateVocabulary::InsertMappedValues;

$| = 1;


my $argsDeclaration =
[

   fileArg({name => 'geographicXmlFile',
	    descr => 'xml file with corrections to geographic location mappings',
	    reqd => 0,
	    mustExist => 1,
	    format => '',
	    constraintFunc => undef,
	    isList => 0,
	   }),

   fileArg({name => 'sourceXmlFile',
	    descr => 'xml file with corrections to isolation source mappings',
	    reqd => 0,
	    mustExist => 1,
	    format => '',
	    constraintFunc => undef,
	    isList => 0,
	   }),

   fileArg({name => 'hostXmlFile',
	    descr => 'xml file with corrections to specific host mappings',
	    reqd => 0,
	    mustExist => 1,
	    format => '',
	    constraintFunc => undef,
	    isList => 0,
	   }),

 ];


my $purposeBrief = <<PURPOSEBRIEF;
Insert mappings between isolates and controlled vocabularies.
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
Insert mappings between isolates and controlled vocabularies for three fields: host, geographic loc, and isolation source.  They are mapped by finding matches between those fields in the isolate sequence (provided with the isolates from the original provider) and values in the vocabularly already loaded into the database.  the xml files provide mappings for the case in which the isolate feature fields do not map into the vocabulary, ie, corrected mappings. 
PLUGIN_PURPOSE

my $tablesAffected = [
['ApiDB.IsolateMapping', 'One row is added to this table for each vocab term mapped to an isolate']
];

my $tablesDependedOn = ['ApiDB.IsolateFeature', 'ApiDB.IsolateSource', 'ApiDB.ExternalNaSequence'];

my $howToRestart = <<PLUGIN_RESTART;
This plugin cannot be restarted.
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
unknown
PLUGIN_FAILURE_CASES

my $notes = <<PLUGIN_NOTES;

PLUGIN_NOTES

my $documentation = {purposeBrief => $purposeBrief,
		     purpose => $purpose,
		     tablesAffected => $tablesAffected,
		     tablesDependedOn => $tablesDependedOn,
		     howToRestart => $howToRestart,
		     failureCases => $failureCases,
		     notes => $notes
		    };


sub new {
    my ($class) = @_;
    my $self = {};
    bless($self, $class);

    $self->initialize({requiredDbVersion => 3.6,
		       cvsRevision =>  '$Revision$',
		       name => ref($self),
		       argsDeclaration   => $argsDeclaration,
		       documentation     => $documentation
		      });

    return $self;
}

sub run {
    my ($self) = @_;

    my $sourceXmlFile = $self->getArg('sourceXmlFile');
    my $locationXmlFile = $self->getArg('geographicXmlFile');
    my $hostXmlFile = $self->getArg('hostXmlFile');

    my $vocabularyReader = ApiCommonData::Load::IsolateVocabulary::Reader::VocabSqlReader->new($self->getDbHandle());
    my $vocabulary = $vocabularyReader->extract();

    my $count;
    $count += $self->insert($sourceXmlFile, 'isolation_source', $vocabulary) if $sourceXmlFile;
    $count += $self->insert($locationXmlFile, 'geographic_location', $vocabulary) if $locationXmlFile;
    $count += $self->insert($hostXmlFile, 'specific_host', $vocabulary) if $hostXmlFile;

    # insert mapping for null/unknown terms
    $count += $self->insertNullMappings($vocabulary,'isolation_source','geographic_location','specific_host');
    return "Inserted $count rows into IsolateMapping";
}

sub insert {
    my ($self, $xmlFile, $type, $vocabulary) = @_;

    my $xmlReader = ApiCommonData::Load::IsolateVocabulary::Reader::XmlTermReader->new($xmlFile);
    my $xmlTerms = $xmlReader->extract();

    my $sqlReader = ApiCommonData::Load::IsolateVocabulary::Reader::SqlTermReader->new($self->getDbHandle(), $type, $vocabulary);
    my $sqlTerms = $sqlReader->extract();

    my $inserter = ApiCommonData::Load::IsolateVocabulary::InsertMappedValues->new($self, $type, $xmlTerms, $sqlTerms, $vocabulary);
    my ($count, $msg) = $inserter->insert();
    $self->log("$type: $msg");
    return $count;
}

sub insertNullMappings {
    my ($self, $vocabulary, @types) = @_;
    my $ct;

    foreach my $type  (@types) {
      my $sqlReader = ApiCommonData::Load::IsolateVocabulary::Reader::SqlTermReader->new($self->getDbHandle(), $type, $vocabulary);
      my $sqlTerms = $sqlReader->extract();

      my $inserter = ApiCommonData::Load::IsolateVocabulary::InsertMappedValues->new($self, $type, '', $sqlTerms, $vocabulary);
      my ($count, $msg) = $inserter->insertNullMappedTerms();
      $ct += $count;
      $self->log("$type: $msg");
    }
    return $ct;
}

sub undoTables {
  my ($self) = @_;

  return ('ApiDB.IsolateMapping',
          'ApiDB.VocabularyBiomaterial',
         );
}


1;
