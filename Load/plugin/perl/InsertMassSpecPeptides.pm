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

    open(my $fh, "gzip -dc $dataFile |") or die "Could not open '$dataFile': $!";
    my $gffIo = Bio::Tools::GFF->new(-fh => $fh, -gff_version => 3);

    my $linesProcessed = 0;
    my $linesInserted  = 0;

    while (my $feature = $gffIo->next_feature()) {
        my $primaryTag = $feature->primary_tag;

        next unless $primaryTag eq 'ms_peptide' || $primaryTag eq 'modified_peptide';

        my $attributes = $feature->attributes;
        my $seqId = $feature->seq_id;
        my $start = $feature->start;
        my $end   = $feature->end;

        if ($primaryTag eq 'ms_peptide') {
            my $peptide = GUS::Model::ApiDB::MassSpecPeptide->new({
                protein_source_id            => $seqId,
                peptide_start                => $start,
                peptide_end                  => $end,
                spectrum_count               => $attributes->{spectrumCount}[0],
                sample                       => $attributes->{sample}[0],
                peptide_sequence             => $attributes->{peptideSequence}[0],
                external_database_release_id => $extDbRlsId,
            });

            $peptide->submit();
            $linesInserted++;
        }
        elsif ($primaryTag eq 'modified_peptide') {
            my $modifiedPeptide = GUS::Model::ApiDB::ModifiedMassSpecPeptide->new({
                protein_source_id            => $seqId,
                peptide_start                => $start,
                peptide_end                  => $end,
                spectrum_count               => $attributes->{spectrumCount}[0],
                sample                       => $attributes->{sample}[0],
                peptide_sequence             => $attributes->{peptideSequence}[0],
                external_database_release_id => $extDbRlsId,
                residue                      => $attributes->{residue}[0],
                residue_location             => $attributes->{residueLocation}[0],
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

