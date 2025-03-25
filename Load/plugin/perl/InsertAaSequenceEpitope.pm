package ApiCommonData::Load::Plugin::InsertAaSequenceEpitope;
use lib "$ENV{GUS_HOME}/lib/perl";
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use Bio::Tools::GFF;
use GUS::PluginMgr::Plugin;

use GUS::Model::ApiDB::AASequenceEpitope;
use Data::Dumper;

sub getArgsDeclaration {
    my $argsDeclaration  =

        [

         fileArg({ name => 'peptideResultFile',
                   descr => 'peptide analysis results file in text format containing the blast and exact matches',
                   constraintFunc=> undef,
                   reqd  => 1,
                   isList => 0,
                   mustExist => 1,
                   format=>'gff',
                 }),

         stringArg({name => 'genomeExtDbRlsSpec',
                    descr => 'ExternalDatabase release spec for the primary genome',
                    constraintFunc=> undef,
                    reqd  => 1,
                    isList => 0
                   }),

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
ApiDB.AASequenceEpitope
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
	my $resultString = $self->loadEpitopes($peptideResultFile);

    return ($resultString);
}


sub fetchAASequenceIdFromSourceID {
    my ($self, $origSourceId) = @_;

    if($self->{aa_sequence_id}->{$origSourceId}) {
        return $self->{aa_sequence_id}->{$origSourceId};
    }

    my $extDbRlsSpec = $self->getArg("genomeExtDbRlsSpec");
    my $extDbRlsId = $self->getExtDbRlsId($extDbRlsSpec);

    my $sql = "select aa_sequence_id, source_id from dots.translatedaasequence where external_database_release_id = ?";
    my $dbh = $self->getQueryHandle();
    my $sh = $dbh->prepare($sql);
    $sh->execute($extDbRlsId);

    while(my ($aaSequenceId, $sourceId) = $sh->fetchrow_array()) {
        $self->{aa_sequence_id}->{$sourceId} = $aaSequenceId;
    }
    $sh->finish();

    return $self->{aa_sequence_id}->{$origSourceId};

}



sub loadEpitopes {

    my ($self, $peptideResultFile) = @_;

    my $fh;
    if($peptideResultFile =~ /\.gz$/) {
        open($fh, "gzip -dc $peptideResultFile |") or die "Could not open '$peptideResultFile': $!";
    }
    else {
        open($fh, $peptideResultFile) or die "Could not open '$peptideResultFile': $!";
    }

    my $gffIo = Bio::Tools::GFF->new(-fh => $fh, -gff_version => 3);

    my $count;
    while (my $feature = $gffIo->next_feature()) {

        my $primaryTag = $feature->primary_tag();
        my $sourceTag = $feature->source_tag();

        my $proteinSourceId = $feature->seq_id();
        my $aaSeqId = $self->fetchAASequenceIdFromSourceID($proteinSourceId);

        my ($iedb) = $feature->get_tag_values('iedb');
        my ($matchesTaxon) = $feature->get_tag_values('matchesTaxon');
        my ($matchesFullLengthProtein) = $feature->get_tag_values('matchesFullLengthProtein');
        my ($mismatches) = $feature->get_tag_values('mismatches');

        my $aaSequenceEpitope = GUS::Model::ApiDB::AASequenceEpitope->new({
            aa_sequence_id => $aaSeqId,
            iedb_id => $iedb,
            mismatches => $mismatches,
            protein_match => $matchesFullLengthProtein,
            taxon_match => $matchesTaxon,
            start_min => $feature->start(),
            end_max => $feature->end(),
            });


        $aaSequenceEpitope->submit();
        $self->undefPointerCache();

        $count++;
    }

    return "Loaded $count rows into AASequenceEpitope";
}


sub undoTables {
  my ($self) = @_;

  return ('ApiDB.AASequenceEpitope');
}

1;
