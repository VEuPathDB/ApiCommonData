package ApiCommonData::Load::Plugin::InsertEpitopeAccession;
use lib "$ENV{GUS_HOME}/lib/perl";
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;
use JSON;
use Bio::Tools::GFF;
use GUS::PluginMgr::Plugin;
use GUS::Supported::Util;
use GUS::Model::ApiDB::IEDBEpitope;
use Data::Dumper;
use ApiCommonData::Load::AnalysisConfigRepeatFinder qw(displayAndBaseName);

sub getArgsDeclaration {
    my $argsDeclaration  =
	
       [

	fileArg({ name => 'epitopeFile',
		     descr => 'peptide file for the species in tab format',
		     constraintFunc=> undef,
		     reqd  => 1,
		     isList => 0,
		     mustExist => 1,
		     format=>'Text',
             }),
	stringArg({name => 'extDbSpec',
                     descr => 'External database from whence this data came|version',
                     constraintFunc=> undef,
                     reqd  => 1,
                     isList => 0
             })
	];
    
    return $argsDeclaration;
}


sub getDocumentation {
    
    my $description = <<NOTES;
Load the epitopes amino acids and the given accession by the IEDB database and the NCBI accession number of the gene the petpide is found.
NOTES
	
	my $purpose = <<PURPOSE;
Load epitopes accession numbers and associated accessions.
PURPOSE
	
	my $purposeBrief = <<PURPOSEBRIEF;
Load epitopes accession numbers.
PURPOSEBRIEF
	
	my $syntax = <<SYNTAX;
SYNTAX
	
	my $notes = <<NOTES;
NOTES
	
	my $tablesAffected = <<AFFECT;
ApiDB.IEDBEpitope
AFFECT
	
	my $tablesDependedOn = <<TABD;
TABD
	
	my $howToRestart = <<RESTART;
There are no restart facilities for this plugin
RESTART
	
	my $failureCases = <<FAIL;
FAIL
	
	my $documentation = {purpose=>$purpose, purposeBrief=>$purposeBrief,tablesAffected=>$tablesAffected,tablesDependedOn=>$tablesDependedOn,howToRestart=>$howToRestart,failureCases=>$failureCases,notes=>$notes};
    
    return ($documentation);
}



sub new {
    my $class = shift;
    my $self = {};
    bless($self, $class);
    
    my $documentation = &getDocumentation();
    
    my $args = &getArgsDeclaration();
    
    $self->initialize({requiredDbVersion => 4.0,
		       cvsRevision => '$Revision$',
		       name => ref($self),
		       argsDeclaration   => $args,
		       documentation     => $documentation
		      });
    return $self;
}

sub run {
	my ($self) = @_;
	my $epitopeFile = $self->getArg('epitopeFile');
	$self->loadEpitopepsAccession($epitopeFile)	

}


sub loadEpitopepsAccession {

	my ($self, $epitopeFile) = @_;
	my $extDbSpec = $self->getArg('extDbSpec');
  	my $extDbRlsId = $self->getExtDbRlsId($extDbSpec) or die "Couldn't find source db: $extDbSpec";		
	
	open(my $epitope, $epitopeFile) or die "Could not open file '$epitopeFile' $!";

		

		while (my $row = <$epitope>) {
  	      	chomp $row;
        	my @counts_list = split /\s+/,$row;
        	my $peptideAccession = $counts_list[1];
        	my $epitopeSequence = $counts_list[3];
        	my $epitopeGene = $counts_list[0];

		 	

		my $row_peptide = GUS::Model::ApiDB::IEDBEpitope->new({
								iedb_id => $peptideAccession,
								peptide_sequence => $epitopeSequence,
								peptide_gene_accession => $epitopeGene,
								external_database_release_id => $extDbRlsId});
	 	$row_peptide->submit();
		$self->undefPointerCache();
		

	}
}
	

	
sub undoTables {
  my ($self) = @_;

  return ('ApiDB.IEDBEpitope');
}

1;
