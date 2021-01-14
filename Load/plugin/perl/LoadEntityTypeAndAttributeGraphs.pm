package ApiCommonData::Load::Plugin::LoadEntityTypeAndAttributeGraphs;

@ISA = qw(GUS::PluginMgr::Plugin);
use strict;
use GUS::PluginMgr::Plugin;

use GUS::Model::ApiDB::AttributeGraph;
use GUS::Model::ApiDB::EntityTypeGraph;

use ApiCommonData::Load::StudyUtils qw(queryForOntologyTerms);

my $purposeBrief = 'Read ontology and study tables and insert tables which store parent child relationships for entitytypes and attributes';
my $purpose = $purposeBrief;

my $tablesAffected =
    [ ['ApiDB::Attribute', ''],
      ['ApiDB::AttributeValue', '']
    ];

# TODO
my $tablesDependedOn =
    [['ApiDB::Study',''],
     ['ApiDB::EntityAttributes',  ''],
     ['ApiDB::ProcessAttributes',  ''],
     ['ApiDB::ProcessType',  ''],
     ['ApiDB::EntityType',  ''],
     ['ApiDB::AttributeUnit',  ''],
     ['SRes::OntologyTerm',  ''],
     ['ApiDB::ProcessType',  ''],
    ];

my $howToRestart = ""; 
my $failureCases = "";
my $notes = "";

my $documentation = { purpose => $purpose,
                      purposeBrief => $purposeBrief,
                      tablesAffected => $tablesAffected,
                      tablesDependedOn => $tablesDependedOn,
                      howToRestart => $howToRestart,
                      failureCases => $failureCases,
                      notes => $notes
};

my $argsDeclaration =
[
   fileArg({name           => 'logDir',
            descr          => 'directory where to log sqlldr output',
            reqd           => 1,
            mustExist      => 1,
            format         => '',
            constraintFunc => undef,
            isList         => 0, }),

 stringArg({ name            => 'extDbRlsSpec',
	     descr           => 'ExternalDatabaseSpec for the Entity Graph',
	     reqd            => 1,
	     constraintFunc  => undef,
	     isList          => 0 }),

 stringArg({ name            => 'ontologyExtDbRlsSpec',
	     descr           => 'ExternalDatabaseSpec for the Associated Ontology',
	     reqd            => 1,
	     constraintFunc  => undef,
	     isList          => 0 }),

];


sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  $self->initialize({requiredDbVersion => 4.0,
		     cvsRevision => '$Revision$', # cvs fills this in!
		     name => ref($self),
		     argsDeclaration   => $argsDeclaration,
		     documentation     => $documentation
		    });
  return $self;
}


$| = 1;

sub run {
  my $self  = shift;

  chdir $self->getArg('logDir');

  my $extDbRlsId = $self->getExtDbRlsId($self->getArg('extDbRlsSpec'));
  
  my $studies = $self->sqlAsDictionary( Sql  => "select study_id, max_attr_length from apidb.study where external_database_release_id = $extDbRlsId");

  $self->error("Expected one study row.  Found ". scalar keys %{$studies}) unless(scalar keys %$studies == 1);

  $self->getQueryHandle()->do("alter session set nls_date_format = 'yyyy-mm-dd hh24:mi:ss'") or die $self->getQueryHandle()->errstr;

  my ($attributeCount, $attributeValueCount, $entityTypeGraphCount);
  while(my ($studyId, $maxAttrLength) = each (%$studies)) {
    my $ontologyTerms = &queryForOntologyTerms($self->getQueryHandle(), $self->getExtDbRlsId($self->getArg('ontologyExtDbRlsSpec')));

    $attributeCount = $attributeCount + $self->constructAndSubmitAttributeGraphsForOntologyTerms($studyId, $ontologyTerms);

    $entityTypeGraphCount = $entityTypeGraphCount + $self->constructAndSubmitEntityTypeGraphsForStudy($studyId);
  }

  return "Loaded $attributeValueCount rows into ApiDB.AttributeValue, $attributeCount rows into ApiDB.Attribute and $entityTypeGraphCount rows into ApiDB.EntityTypeGraph";
}



sub constructAndSubmitAttributeGraphsForOntologyTerms {
  my ($self, $studyId, $ontologyTerms) = @_;

  my $attributeCount;

  foreach my $sourceId (keys %$ontologyTerms) {
    my $ontologyTerm = $ontologyTerms->{$sourceId};
    
    my $attributeGraph = GUS::Model::ApiDB::AttributeGraph->new({study_id => $studyId,
                                                                 ontology_term_id => $ontologyTerm->{ONTOLOGY_TERM_ID},
                                                                 stable_id => $sourceId,
                                                                 parent_stable_id => $ontologyTerm->{PARENT_SOURCE_ID},
                                                                 parent_ontology_term_id => $ontologyTerm->{PARENT_ONTOLOGY_TERM_ID},
                                                                 provider_label => $ontologyTerm->{PROVIDER_LABEL},
                                                                 display_name => $ontologyTerm->{DISPLAY_NAME}, 
                                                                 term_type => $ontologyTerm->{TERM_TYPE}, 
                                                                });
    $attributeGraph->submit();
    $attributeCount++;
  }

  return $attributeCount;
}




sub constructAndSubmitEntityTypeGraphsForStudy {
  my ($self, $studyId) = @_;

  my $dbh = $self->getQueryHandle();
  $dbh->{FetchHashKeyName} = 'NAME_lc';

  my $extDbRlsId = $self->getExtDbRlsId($self->getArg('ontologyExtDbRlsSpec'));

  # TODO: Add Plural when available
  my $sql = "select et.parent_id
                  , et.parent_stable_id
                  , t.name display_name
                  , t.entity_type_id
                  , t.internal_abbrev
                  ,  ot.source_id as stable_id
                  , nvl(os.definition, ot.definition) as description
                  , s.study_id
                  , s.stable_id as study_stable_id
from (
select distinct s.study_id, iot.source_id as parent_stable_id, it.ENTITY_TYPE_ID as parent_id, ot.entity_type_id out_entity_type_id
from apidb.processattributes p
   , apidb.entityattributes i
   , apidb.entityattributes o
   , apidb.entitytype it
   , apidb.study s
   , apidb.entitytype ot
   , sres.ontologyterm iot
where s.study_id = $studyId 
and it.STUDY_ID = s.study_id
and ot.STUDY_ID = s.study_id
and it.ENTITY_TYPE_ID = i.entity_type_id
and ot.entity_type_id = o.entity_type_id
and p.in_entity_id = i.ENTITY_ATTRIBUTES_ID
and p.OUT_ENTITY_ID = o.ENTITY_ATTRIBUTES_ID 
and it.type_id = iot.ontology_term_id (+)
) et, apidb.entitytype t
   , apidb.study s
   , sres.ontologyterm ot
   , (select * from sres.ontologysynonym where external_database_release_id = $extDbRlsId) os
where s.study_id = $studyId 
 and s.study_id = t.study_id
 and t.study_id = et.study_id (+)
 and t.entity_type_id = out_entity_type_id (+)
 and t.type_id = ot.ontology_term_id (+)
 and ot.ontology_term_id = os.ontology_term_id (+)
";


  my $sh = $dbh->prepare($sql);
  $sh->execute();
  my $ct;

  while(my $row= $sh->fetchrow_hashref()) {
    $row->{'study_id'} = $studyId;

    my $etg = GUS::Model::ApiDB::EntityTypeGraph->new($row);

    $etg->submit();
    $ct++
  }

  return $ct;
}

sub undoTables {
  my ($self) = @_;
  return (
    'ApiDB.AttributeGraph',
    'ApiDB.EntityTypeGraph',
      );
}

1;
