package ApiCommonData::Load::Plugin::InsertEpitopeNAFeature;
use lib "$ENV{GUS_HOME}/lib/perl";
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;
use JSON;
use Bio::Tools::GFF;
use GUS::PluginMgr::Plugin;
use GUS::Supported::Util;
use GUS::Model::ApiDB::NAFeatureEpitope;
use Data::Dumper;
use ApiCommonData::Load::AnalysisConfigRepeatFinder qw(displayAndBaseName);

sub getArgsDeclaration {
    my $argsDeclaration  =
	
       [

	fileArg({ name => 'peptideResultFile',
		     descr => 'peptide analysis results file in text format containing the blast and exact matches',
		     constraintFunc=> undef,
		     reqd  => 1,
		     isList => 0,
		     mustExist => 1,
		     format=>'Text',
             })
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
Load epitopes analyis results to the database.
PURPOSE
	
	my $purposeBrief = <<PURPOSEBRIEF;
Load epitopes analysis results to the database. Results contains both the exact match search and blast analysis.
PURPOSEBRIEF
	
	my $syntax = <<SYNTAX;
SYNTAX
	
	my $notes = <<NOTES;
NOTES
	
	my $tablesAffected = <<AFFECT;
ApiDB.NAFeatureEpitope
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
	my $peptideResultFile = $self->getArg('peptideResultFile');
	$self->loadEpitopes($peptideResultFile)	

}


sub loadEpitopes {

	my ($self, $epitopeFile) = @_;
	my $extDbSpec = $self->getArg('extDbSpec');
  	my $extDbRlsId = $self->getExtDbRlsId($extDbSpec) or die "Couldn't find source db: $extDbSpec";		
	
	open(my $peptides, $peptideResultFile) or die "Could not open file '$peptideResultFile' $!";

		
		while (my $row = <$h>) {
       		chomp $row;
        	my @counts_list = split("\t", $row);
        	my $protein = $counts_list[0];
        	my $peptide = $counts_list[1];
        	my $pepLen = $counts_list[2];
        	my $indetity = $counts_list[3];
        	my $matchStart = $counts_list[4];
        	my $matchEnd = $counts_list[5];
        	my $alignmentLength = $counts_list[6];
        	my $bitScore = $counts_list[7];
        	my $refSeq = $counts_list[8];
        	my $hitSeq = $counts_list[9];
        	my $alignment = $counts_list[10];
        	my $MatchType = $counts_list[11];
        
        
        
       # print($protein, "\t", $peptide, "\t", $pepLen, "\t", $indetity, "\t", $matchStart, "\t", $matchEnd, "\t", $alignmentLength, "\t", $bitScore, "\t", $refSeq,  "\t", $hitSeq, "\t", $alignment, "\t", $MatchType, "\n",)

 }


		my $row_peptide = GUS::Model::ApiDB::NAFeatureEpitope->new({
								peptideAccession => $peptideAccession,
								peptidesSequence => $peptidesSequence,
								peptidesGene => $peptidesGene,
								external_database_release_id => $extDbRlsId});
	 	$row_peptide->submit();
		$self->undefPointerCache();
		}
	
}
	
sub undoTables {
  my ($self) = @_;

  return ('ApiDB.NAFeatureEpitope');
}

1;
