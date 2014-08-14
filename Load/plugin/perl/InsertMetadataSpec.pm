package ApiCommonData::Load::Plugin::InsertMetadataSpec;

@ISA = qw(GUS::Supported::Plugin::InsertOntologyTermsAndRelationships);

# ----------------------------------------------------------------------

use strict;

use UNIVERSAL qw(isa);

use FileHandle;


use GUS::PluginMgr::Plugin;
use GUS::PluginMgr::PluginUtilities;

use GUS::Supported::Plugin::InsertOntologyTermsAndRelationships;

use GUS::Model::ApiDB::MetadataSpec;

use Data::Dumper;

my $argsDeclaration =
[

 fileArg({name           => 'metadataSpecFile',
	  descr          => 'A tab file containing descriptive information about ontology terms.',
	  reqd           => 1,
	  mustExist      => 1,
	  format         => 'tab_file',
	  constraintFunc => undef,
	  isList         => 0, 
	 }),

 stringArg({ descr => 'Name of the External Database',
	     name  => 'extDbRlsSpec',
	     isList    => 0,
	     reqd  => 1,
	     constraintFunc => undef,
	   }),

];

my $purpose = <<PURPOSE;
The purpose of this plugin is to parse a tab file and load metadata spec info.  
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
The purpose of this plugin is to load Metadata Specifications for OntologyTerms.
PURPOSE_BRIEF

my $notes = <<NOTES;

NOTES

my $tablesAffected = <<TABLES_AFFECTED;
Apidb::MetadataSpec
TABLES_AFFECTED

my $tablesDependedOn = <<TABLES_DEPENDED_ON;
SRes::OntologyTerm
TABLES_DEPENDED_ON

my $howToRestart = <<RESTART;
No Restart utilities for this plugin.
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

my $numRelationships = 0;

# ----------------------------------------------------------------------

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

# ----------------------------------------------------------------------

=head2 Subroutines

=over 4

=item C<run>

Main method which Reads in the Owl File,
Converts to SRes::OntologyTerm and SRes::OntologyRelationships

B<Return type:> 

 C<string> Descriptive statement of how many rows were entered

=cut

sub run {
  my ($self) = @_;

  my $file = $self->getArg('metadataSpecFile');


  my $extDbRlsId = $self->getExtDbRlsId($self->getArg('extDbRlsSpec'));
  $self->setExtDbRls($extDbRlsId);

  my $isHeader = 1;
  my $lineNum = 0 ;
  my $specHash = {};

  my $sqlCheck = "Select name,ontology_term_id 
                         from sres.ontologyTerm
                         where lower(name) = ? 
                           and external_database_release_id = ?
                           ";

  my $dbh        = $self->getQueryHandle();
  my $sth        = $dbh->prepare($sqlCheck);

  my @metadataSpecs;

  open(FILE,$file);

  foreach my $line (<FILE>) {
    chomp;
    next if $line=~/^\s$/ || !defined($line);
    if ($isHeader) {
      $isHeader = 0;
      next;
    }

    $lineNum = $lineNum + 1;
    my ($type,$filter);
    my $row = [split( "\t", $line )];
    my $term = $row ->[0];
    my $lowerTerm = lc($term);

    my $external_database = $self->getArg('extDbRlsSpec');
    $sth->execute($lowerTerm,$extDbRlsId);
    my ($term,$ont_term_id) = $sth->fetchrow_array() or $self->error("no term $term in the db for external database release id $external_database"); 
    my $variable_type = $row->[1];
    unless ( $variable_type =~ /^boolean$/i ||
             $variable_type =~/^date$/i ||
             $variable_type =~/^number$/i ||
             $variable_type =~/^controlled_vocab$/i ||
             $variable_type =~/^string$/i ||
             $variable_type =~/^id$/i
           ) {
      $self->log("unrecognized variable_type $variable_type on line $lineNum of $file");
      
    }
    
    my $units = undef;
    $units = $row->[2] if scalar(@$row)>2;
    
    my $metadataSpec = GUS::Model::ApiDB::MetadataSpec->
      new({name => $term,
           ontology_term_id => $ont_term_id,
           variable_type => $variable_type,
           units => $units,
          });
  push (@metadataSpecs,$metadataSpec); 
  } 
  submitObjectList(\@metadataSpecs);
  $self->log("added $lineNum rows to Apidb.MetadataSpec");
        
  $self->undefPointerCache();
}
#--------------------------------------------------------------------------------

sub submitObjectList {
  my ($self, $list) = @_;

  foreach my $gusObj (@$list) {
    $gusObj->submit();
  }

}

#--------------------------------------------------------------------------------

sub undoTables {
  my ($self) = @_;

  return ('ApiDB.MetadataSpec');
}

1;
