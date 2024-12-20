package ApiCommonData::Load::Plugin::InsertMassSpecPeptides;

@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;
use Bio::Tools::GFF;
use GUS::PluginMgr::Plugin;
use GUS::Model::ApiDB::MassSpecPeptide;
use GUS::Model::ApiDB::ModifiedMassSpecPeptide;

# Load Arguments
sub getArgsDeclaration {
    my $argsDeclaration = [
        fileArg({ name => 'gff_file',
                  descr => 'GFF file containing peptide annotations, compressed as .gz',
                  constraintFunc => undef,
                  reqd => 1,
                  isList => 0,
                  mustExist => 1,
                  format => 'gzip' }),
        stringArg({ name => 'extDbRlsSpec',
                    descr => 'External database release spec in format "dbName|version"',
                    constraintFunc => undef,
                    reqd => 1,
                    isList => 0 }),
    ];

    return $argsDeclaration;
}

sub getDocumentation {
    my $description = <<NOTES;
NOTES

    my $syntax = <<SYNTAX;
Standard plugin syntax.
SYNTAX

    my $purpose = <<PURPOSE;
Load mass spectrometry peptide data from a GFF file into two tables: MassSpecPeptide and ModifiedMassSpecPeptide.
PURPOSE

    my $purposeBrief = <<PURPOSEBRIEF;
Load mass spectrometry peptides from a GFF file.
PURPOSEBRIEF

    my $notes = <<NOTES;
The plugin expects a GFF file compressed as .gz and extracts peptide data and modifications for storage in the respective tables.
NOTES

    my $tablesAffected = <<AFFECTED;
ApiDB.MassSpecPeptide, ApiDB.ModifiedMassSpecPeptide
AFFECTED

    my $tablesDependedOn = <<TABD;
dots.translatedaasequence or another view of dots.aasequenceimp.  TMHMM server takes AA sequences in fasta format with GUS Ids as input.
TABD

    my $howToRestart = <<RESTART;
None.
RESTART

    my $failureCases = <<FAIL;
None anticipated.
FAIL

    my $documentation = {purpose=>$purpose, purposeBrief=>$purposeBrief,tablesAffected=>$tablesAffected,tablesDependedOn=>$tablesDependedOn,howToRestart=>$howToRestart,failureCases=>$failureCases,notes=>$notes};

    return $documentation;
}

sub new {
    my ($class) = @_;
    my $self = {};
    bless($self, $class);

    my $documentation = &getDocumentation();
    my $args = &getArgsDeclaration();

    $self->initialize({
        requiredDbVersion => 4.0,
        cvsRevision       => '$Revision$',
        cvsTag            => '$Name$',
        name              => ref($self),
        argsDeclaration   => $args,
        documentation     => $documentation,
    });

    return $self;
}

# Main routine
sub run {
    my ($self) = @_;

    $self->logAlgInvocationId;
    $self->logCommit;

    # Parse arguments
    my $dataFile = $self->getArg('gff_file');
    my $extDbRlsSpec = $self->getArg('extDbRlsSpec');

    my ($dbName, $version) = split(/\|/, $extDbRlsSpec);
    unless ($dbName && $version) {
        $self->error("Invalid format for extDbRlsSpec: expected 'dbName|version'");
    }

    my $extDbRlsId = $self->getExtDbRlsId($dbName, $version);

    my $fh;
    if($dataFile =~ /\.gz$/) {
        open($fh, "gzip -dc $dataFile |") or die "Could not open '$dataFile': $!";
    }
    else {
        open($fh, $dataFile) or die "Could not open '$dataFile': $!";
    }
    my $gffIo = Bio::Tools::GFF->new(-fh => $fh, -gff_version => 3);

    my $linesProcessed = 0;
    my $linesInserted  = 0;

while (my $feature = $gffIo->next_feature()) {
    my $primaryTag = $feature->primary_tag;

    next unless $primaryTag eq 'ms_peptide' || $primaryTag eq 'modified_peptide';

    my $seqId = $feature->seq_id;
    my $start = $feature->start;
    my $end   = $feature->end;

    # Extract attributes using get_tag_values
    my $spectrumCount = ($feature->has_tag('spectrum_count') ? ($feature->get_tag_values('spectrum_count'))[0] : undef);
    my $sample = ($feature->has_tag('sample_name') ? ($feature->get_tag_values('sample_name'))[0] : undef);
    my $peptideSequence = ($feature->has_tag('peptide') ? ($feature->get_tag_values('peptide'))[0] : undef);

    if ($primaryTag eq 'ms_peptide') {
        my $peptide = GUS::Model::ApiDB::MassSpecPeptide->new({
            protein_source_id            => $seqId,
            peptide_start                => $start,
            peptide_end                  => $end,
            spectrum_count               => $spectrumCount,
            sample                       => $sample,
            peptide_sequence             => $peptideSequence,
            external_database_release_id => $extDbRlsId,
        });

        $peptide->submit();
        $linesInserted++;
    }
    elsif ($primaryTag eq 'modified_peptide') {
        my $residue = ($feature->has_tag('residue') ? ($feature->get_tag_values('residue'))[0] : undef);
        my $residueLocation = ($feature->has_tag('residueLocation') ? ($feature->get_tag_values('residueLocation'))[0] : undef);

        my $modifiedPeptide = GUS::Model::ApiDB::ModifiedMassSpecPeptide->new({
            protein_source_id            => $seqId,
            peptide_start                => $start,
            peptide_end                  => $end,
            spectrum_count               => $spectrumCount,
            sample                       => $sample,
            peptide_sequence             => $peptideSequence,
            external_database_release_id => $extDbRlsId,
            residue                      => $residue,
            residue_location             => $residueLocation,
        });

        $modifiedPeptide->submit();
        $linesInserted++;
    }

    $linesProcessed++;
    $self->undefPointerCache();
}

    my $resultDescription = "Processed $linesProcessed lines, inserted $linesInserted rows.";
    $self->setResultDescr($resultDescription);
    $self->logData($resultDescription);
}

sub undoTables {
    return ('ApiDB.MassSpecPeptide', 'ApiDB.ModifiedMassSpecPeptide');
}

1;
