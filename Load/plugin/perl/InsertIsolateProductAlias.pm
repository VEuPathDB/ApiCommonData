package ApiCommonData::Load::Plugin::InsertIsolateProductAlias;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use CBIL::Util::Disp;
use GUS::PluginMgr::Plugin;


use GUS::Model::Study::Characteristic;
use SRes::OntologyTerm;

use GUS::Supported::Util;


my $argsDeclaration =
  [
   fileArg({name           => 'productsFile',
	    descr          => 'file with accessions of reference',
	    reqd           => 1,
	    mustExist      => 1,
	    format         => 'Tab file with header',
	    constraintFunc => undef,
	    isList         => 0, }),
   stringArg({name => 'extDbSpec',
	      descr => 'External database of isolates loaded from a dataset|version',
	      constraintFunc=> undef,
	      reqd  => 1,
	      isList => 0
	     }),
];

my $purpose = <<PURPOSE;
Add annotatedProduct characteristic for isolates.
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
Add annotatedProduct characteristic for isolates.
PURPOSE_BRIEF

my $notes = <<NOTES;
NOTES

my $tablesAffected = <<TABLES_AFFECTED;
SRes::OntologyTerm
Study::Characteristic
TABLES_AFFECTED

my $tablesDependedOn = <<TABLES_DEPENDED_ON;
SRes::OntologyTerm
Study::Characteristic
Study::ProtocolAppNode
TABLES_DEPENDED_ON

  my $howToRestart = <<RESTART;
There are no restart facilities for this plugin
RESTART

my $failureCases = <<FAIL_CASES;
FAIL_CASES

my $documentation = { purpose          => $purpose,
		      purposeBrief     => $purposeBrief,
		      notes            => $notes,
		      tablesAffected   => $tablesAffected,
		      tablesDependedOn => $tablesDependedOn,
		      howToRestart     => $howToRestart,
		      failureCases     => $failureCases };

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  $self->initialize({ requiredDbVersion => 4.0,
		      cvsRevision       => '$Revision$',
		      name              => ref($self),
		      argsDeclaration   => $argsDeclaration,
		      documentation     => $documentation});

  return $self;
}

sub run {
  my ($self) = @_;

  my $extDbRlsSpec = $self->getArg('extDbSpec');
  my $extDbRlsId = $self->getExtDbRlsId($extDbRlsSpec);

  my $sql =
    "SELECT pan.protocol_app_node_id, c.value
       FROM Study.protocolAppNode pan, Study.characteristic c, SRes.OntologyTerm ot
      WHERE pan.external_database_release_id = $extDbRlsId
        AND pan.protocol_app_node_id = c.protocol_app_node_id
        AND ot.name='product'
        AND c.qualifier_id=ot.ontology_term_id";


  my %popsets;
  my $dbh = $self->getQueryHandle();
  my $sh  = $dbh->prepare($sql);
  $sh->execute();

  while (my ($id,$prod) = $sh->fetchrow_array()){
    $popsets{$id} = $prod;
  }


  # make ontology term
  my $annProd= GUS::Model::SRes::OntologyTerm->new({name=>'annotatedProduct'});
  $annProd->submit();

  my %prods;
  my $qualifierId = $annProd->getId();
  my $configFile = $self->getArg('productsFile');
  open (IN, $configFile);
  while (<IN>){
    chomp;
    my($product,$newProduct) = split(/\t/,$_);
    $prods{$product} = $newProduct;
  }

  foreach my $panId (keys %popsets) {
    my $val = $popsets{panId};
    if ($prods{$val}){ # when there is entry (of annotated product) in the file
      # add an entry of the automated_product
      my $characteristic = 
	GUS::Model::Study::Characteristic->new({protocol_app_node_id => $panId,
						qualifier_id => $qualifierId,
						value => 1
					       });
      $characteristic->submit();
    }


  }
}


