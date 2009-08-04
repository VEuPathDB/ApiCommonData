package ApiCommonData::Load::Plugin::UpdateTaxonNameClass;

@ISA = qw(GUS::PluginMgr::Plugin);
use strict;


use GUS::PluginMgr::Plugin;
use GUS::Model::SRes::TaxonName;
use GUS::PluginMgr::Plugin;

sub new {
  my ($class) = @_;

  my $self = {};
  bless($self,$class);

my $purpose = <<PURPOSE;
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
PURPOSE_BRIEF

my $notes = <<NOTES;
NOTES

my $tablesAffected = <<TABLES_AFFECTED;
      ['SRes::TaxonName', ''],
    ];
TABLES_AFFECTED

my $tablesDependedOn = <<TABLES_DEPENDED_ON;
TABLES_DEPENDED_ON

my $howToRestart = <<RESTART;
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


my $argsDeclaration = 
[
   fileArg({name => 'mappingFile',
            descr => 'tab delimited file with taxon name and name_class',
            constraintFunc=> undef,
            reqd  => 1,
            isList => 0,
            mustExist => 1,
            format => '',}),
];


  $self->initialize({requiredDbVersion => 3.5,
		     cvsRevision => '$Revision$', # cvs fills this in!
		     name => ref($self),
		     argsDeclaration   => $argsDeclaration,
		     documentation     => $documentation});

  return $self;
}

sub run {

    my $self   = shift;

    my $mappingFile = $self->getArg('mappingFile');
    
    open (MAP, "$mappingFile") ||
                    die "Can't open the file $mappingFile.  Reason: $!\n"; 
    
    while (<MAP>){

    $self->undefPointerCache(); #if at bottom, not always hit

    next if /^(\s)*$/;

    chomp;

    my ($taxonName,$name_class) = split(/\t/, $_);

    $self->updateTaxonNameClass($taxonName, $name_class);
    }

    close (MAP);

}


sub updateTaxonNameClass {

  my ($self,$taxonName,$name_class)   = @_;
	  
  my $newTaxonName = GUS::Model::SRes::TaxonName->new({name => $taxonName});

  $newTaxonName->retrieveFromDB();

  $newTaxonName->setNameClass($name_class);

  $newTaxonName->submit();
}



1;



      
