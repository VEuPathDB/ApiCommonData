package ApiCommonData::Load::Plugin::InsertCustomOntologyEntries;

@ISA = qw(GUS::PluginMgr::Plugin);

use GUS::Model::Study::OntologyEntry;

# ----------------------------------------------------------------------

use strict;
use GUS::PluginMgr::Plugin;

my $argsDeclaration =
  [

   fileArg({name           => 'file',
            descr          => 'file for the sample data',
            reqd           => 1,
            mustExist      => 1,
            format         => '',
            constraintFunc => undef,
            isList         => 0, }),
            
  ];


my $documentation = { purpose          => "",
                      purposeBrief     => "",
                      notes            => "",
                      tablesAffected   => "",
                      tablesDependedOn => "",
                      howToRestart     => "",
                      failureCases     => "" };

# ----------------------------------------------------------------------

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  $self->initialize({ requiredDbVersion => 3.6,
                      cvsRevision       => '$Revision$',
                      name              => ref($self),
                      argsDeclaration   => $argsDeclaration,
                      documentation     => $documentation});

  return $self;
}

# ======================================================================

sub run {
 my ($self) = @_;

 my $file = $self->getArg('file');
 my $categories = [];
 my $values = [];
 
 open(FILE, $file) or $self->error("Cannot open file $file for reading: $!");
 
 my $count = 0;
 while(<FILE>) {
    chomp;
    my ($category, $value) = split(/\t/, $_);
	next unless $category;

    my $oe = GUS::Model::Study::OntologyEntry->new({ category=> $category, 
	                                                 value=> $value,
                                           });
	unless($oe->retrieveFromDB()) {
          my $sql = <<EOSQL;
   select id from (
            select parent_id as id, count(parent_id) as id_count 
                 from study.ontologyEntry oe
                where oe.category ='$category'
                group by parent_id
              union
              select distinct ontology_entry_id, 0 as id_count 
               from study.ontologyEntry oe
                where oe.value ='$category'
                order by id_count desc
                )
                where ROWNUM = 1           
EOSQL
  my $dbh = $self->getQueryHandle();
  my $sth = $dbh->prepareAndExecute($sql);

  my $parent_id = $sth->fetchrow_array();

	my $parent = GUS::Model::Study::OntologyEntry->new({ ontology_entry_id=> $parent_id, 
                                           }); 
	$self->error("Category $category is not found in the database: $!") unless($parent->retrieveFromDB());

	$oe->setParent($parent);
	$oe->submit()
      }
  }
}
 
sub undoTables {
  my ($self) = @_;

  return ('Study.OntologyEntry'
     );
}

1;
