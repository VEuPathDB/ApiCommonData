package ApiCommonData::Load::Plugin::InsertAnnotationProperties;

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

  my $attributesFile = $self->getArg('attributesFile');
  unless ( -e $attributesFile ){ $self->log("$attributesFile not found, nothing to do"); return 0 }
  my $extDbRlsId = $self->getExtDbRlsId($self->getArg('extDbRlsSpec'));
  my $commit = $self->getArg('commit');

  unless ($studyId){
    printf STDERR ("Study %s not found. Loaded:\n%s\n", $datasetName, Dumper $results);
    return -1; # fail
  }
  my $study = $self->getGusModelClass('Study')->new({external_database_release_id => $extDbRlsId});
  unless($study->retrieveFromDB){
    $self->error("Study associated with extDbRlsSpec not found");
  }
  my $studyId = $study->getId();
  my $csv = Text::CSV->new({binary => 1, escape_char => "\\", quote_char => undef, sep_char => "\t"});
  open(my $fh, "<$attributesFile") or die "Cannot read $file:$!\n";
  
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


