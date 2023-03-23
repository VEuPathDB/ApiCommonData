package ApiCommonData::Load::Plugin::InsertAnnotationProperties;

# Example usage
# ga ApiCommonData::Load::Plugin::InsertAnnotationProperties  --extDbRlsSpec 'ISASimple_Gates_LLINE-UP_rct_qa_RSRC|2023-01' --attributesFile owlAttributes.txt --schema EDA --commit 1
# owlAttributes.txt:
# SOURCE_ID props
# CMO_0000026 {"unitLabel":["g/dL"],"displayOrder":["2"],"variable":["hh_member_18m::hemoglobin","hh_member_12m::hemoglobin","household member level data 25m survey_final::hemoglobin","hh_member_00m::hemoglobin","hh_member_06m::hemoglobin"],"unitIRI":["http://purl.obolibrary.org/obo/UO_0000208"],"replaces":["EUPATH_0000047"]}
# ENVO_00000009 {"displayOrder":["1"],"variable":["hh_18m::country","hh_12m::country","hh_06m::country","hh_00m::country"],"replaces":["ENVO_00000004"]}
# ENVO_00000501 {"displayOrder":["2"],"variable":["hh_12m::bed","hh_18m::bed","household level data 25m survey_final::bed","hh_06m::bed","hh_00m::bed"]}
# ENVO_00003064 {"displayOrder":["1"],"variable":["hh_06m::otherscs","hh_12m::swater","hh_12m::otherscs","hh_00m::swater","hh_06m::swater","hh_18m::otherscs","household level data 25m survey_final::swater","hh_18m::swater"]}
#

@ISA = qw(GUS::PluginMgr::Plugin ApiCommonData::Load::Plugin::ParameterizedSchema);
use strict;
use warnings;
use GUS::PluginMgr::Plugin;
use ApiCommonData::Load::Plugin::ParameterizedSchema;
use GUS::Model::SRes::OntologyTerm;
use Text::CSV;

my $SCHEMA = '__SCHEMA__'; # must be replaced with real schema name
my @UNDO_TABLES = qw(
  AnnotationProperties
);
my @REQUIRE_TABLES = qw(
  Study
  AnnotationProperties
);

my $argsDeclaration =
  [

 fileArg({name           => 'attributesFile',
    descr          => 'A tab-delimited file with columns IRI, Props where Props is a JSON hash',
    reqd           => 1,
    mustExist      => 1,
    format         => 'tab-delimited txt file',
    constraintFunc => undef,
    isList         => 0, 
   }),
  stringArg({ name  => 'extDbRlsSpec',
    descr => "The ExternalDBRelease specifier for this Ontology Synonym. Must be in the format 'name|version', where the name must match an name in SRes::ExternalDatabase and the version must match an associated version in SRes::ExternalDatabaseRelease.",
    constraintFunc => undef,
    reqd           => 1,
    isList         => 0 }),
  booleanArg({name => 'append',
    descr => 'Will insert a new synonym if the ontology_term_id for SOURCE_ID exists', 
    constraintFunc => undef,
    reqd => 0,
  }),
   stringArg({name           => 'schema',
            descr          => 'GUS::Model schema for entity tables',
            reqd           => 1,
            constraintFunc => undef,
            isList         => 0, }),

   booleanArg({name => 'commit',
          descr => 'commit changes',
          reqd => 0,
          constraintFunc => undef,
          isList => 0,
         }),


  ];

my $documentation = { purpose          => "",
                      purposeBrief     => "",
                      notes            => "",
                      tablesAffected   => "",
                      tablesDependedOn => "",
                      howToRestart     => "",
                      failureCases     => "" };

# ----------------------------------------------------------------------
sub getIsReportMode { }

# ----------------------------------------------------------------------

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  $self->initialize({ requiredDbVersion => 4.0,
                      cvsRevision       => 'NA',
                      name              => ref($self),
                      argsDeclaration   => $argsDeclaration,
                      documentation     => $documentation});
  $self->{_require_tables} = \@REQUIRE_TABLES;
  $self->{_undo_tables} = \@UNDO_TABLES;
  return $self;
}

# ======================================================================

sub run {
  my ($self) = @_;

  ## ParameterizedSchema
  $self->requireModelObjects();
  $self->resetUndoTables(); # for when logRowsInserted() is called after loading
  $SCHEMA = $self->getArg('schema');
  ## 
  my $append = $self->getArg('append');

  my $attributesFile = $self->getArg('attributesFile');
  unless ( -e $attributesFile ){ $self->log("$attributesFile not found, nothing to do"); return 0 }
  my $extDbRlsId = $self->getExtDbRlsId($self->getArg('extDbRlsSpec'));
  my $commit = $self->getArg('commit');

  my $study = $self->getGusModelClass('Study')->new({external_database_release_id => $extDbRlsId});
  unless($study->retrieveFromDB){
    $self->error("Study associated with extDbRlsSpec not found");
  }
  my $studyId = $study->getId();
  unless ($studyId){
    printf STDERR ("Study not found");
    return -1; # fail
  }
  my $csv = Text::CSV->new({binary => 1, escape_char => "\\", quote_char => undef, sep_char => "\t"});
  open(my $fh, "<$attributesFile") or die "Cannot read $attributesFile:$!\n";
  
  my $hr = $csv->getline($fh);
  my $k = $hr->[0]; ## First column is source_id
  $csv->column_names($hr);
  my %vars;
  $vars{$_} = 1 for @$hr; 
### Generic hash of any columns
  my %data;
  my $x = 0;
  while(my $r = $csv->getline_hr($fh)){
    $x++;
    $data{ $r->{$k} } = $r;
    delete($data{ $r->{$k} }->{ $k }); # remove source_id from props
  }
  close($fh);
  # $self->log(sprintf("Read %d lines from file", $x));
  #
  my $count = 0;
  while( my($ontologyTermSourceId,$attrs) = each %data){
    my $attrs = $data{$ontologyTermSourceId};

    next unless($ontologyTermSourceId);
    my $ontologyTerm = GUS::Model::SRes::OntologyTerm->new({ source_id =>  $ontologyTermSourceId });
    my $isLoaded = $ontologyTerm->retrieveFromDB();
    if(!( $isLoaded || $append )) {
      $self->error("Unable to find ontology term $ontologyTermSourceId (use append=1 to load missing terms)");
    }
    elsif($append &! $isLoaded ){
      $ontologyTerm->setName($ontologyTermSourceId);
      $ontologyTerm->submit();
    }
    my $ontologyTermId = $ontologyTerm->getId;
    my $annprop = $self->getGusModelClass('AnnotationProperties')->new({
      external_database_release_id => $extDbRlsId,
      ontology_term_id => $ontologyTermId,
      study_id => $studyId,
    });
    # $synonym->setParent($ontologyTerm);
    if( $annprop->retrieveFromDB() ) { 
      $self->error(sprintf("AnnotationProperties already loaded: extDbRlsId=%d, studyId=%d, ontologyTermId=%d", $extDbRlsId, $studyId, $ontologyTermId));
    }
    foreach my $attr ( keys %$attrs ){
      $self->log("SETTING: $ontologyTermSourceId $attr = $attrs->{$attr}");
      $annprop->set($attr, $attrs->{$attr});
    }
    my $status = $annprop->submit();
    $count++;
  }
  $self->log("Loaded $count rows in $SCHEMA.AnnotationProperties");
}
1;


