package ApiCommonData::Load::Plugin::InsertHMDB;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;
use lib "$ENV{GUS_HOME}/lib/perl";

use CBIL::Util::Disp;
use GUS::PluginMgr::Plugin;
use GUS::Supported::Util;

use GUS::Model::hmdb::compounds;
use GUS::Model::hmdb::names;
use GUS::Model::hmdb::chemical_data;
use GUS::Model::hmdb::database_accession;
use GUS::Model::hmdb::structures;
use GUS::Model::hmdb::autogen_structures;
use GUS::Model::hmdb::default_structures;

use XML::LibXML::Reader;
use XML::LibXML::XPathContext;
use XML::LibXML;
use Data::Dumper;

my $argsDeclaration = [
    fileArg({   name            => 'xmlFile',
                descr           => 'XML dump of all compounds from HMDB',
                reqd            => 1,
                mustExist       => 1,
                format          => 'xml',
                constraintFunc  => undef,
                isList          => 0,
            }),

    fileArg({   name            => 'sdfFile',
                descr           => 'Structure for HMDB compounds in SDF format',
                reqd            => 1,
                mustExist       => 1,
                format          => 'sdf',
                constraintFunc => undef,
                isList          => 0,
            }),
];

my $purpose = <<PURPOSE;
Insert HMDB metabolites
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
Insert HMDB metabolites
PURPOSE_BRIEF

my $notes = <<NOTES;
NOTES

my $tablesAffected = <<TABLES_AFFECTED;
hmdb.default_structures
hmdb.autogen_structures,
hmdb.structures,
hmdb.database_accession,
hmdb.chemical_data,
hmdb.names,
hmdb.compounds'
TABLES_AFFECTED

my $tablesDependedOn = <<TABLES_DEPENDED_ON;
TABLES_DEPENDED_ON

my $howToRestart = <<RESTART;
There are no restart facilities for this plugin
RESTART

my $failureCases = <<FAIL_CASES;
FAIL_CASES

my $documentation = {   purpose => $purpose,
                        purposeBrief => $purposeBrief,
                        notes => $notes,
                        tablesAffected => $tablesAffected,
                        tablesDependedOn => $tablesDependedOn,
                        howToRestart => $howToRestart,
                        failureCases => $failureCases};


sub new {
    my ($class) = @_;
    my $self = {};
    bless($self, $class);

    $self->initialize({ requiredDbVersion => 4.0,
                        cvsRevision => '$Revision$',
                        name => ref($self),
                        argsDeclaration => $argsDeclaration,
                        documentation => $documentation
                    });
    return $self;
}

sub  run {
    my ($self) = @_;

    $self->setPointerCacheSize(100000);
    
    my $xrefSourceMap = {chebi => 'ChEBI', kegg => 'KEGG COMPOUND', pubchem_compound => 'PubChem'};
    
    #parse sdf file and make hash of id:mol to load later
    my $sdfFile = $self->getArg('sdfFile');
    my $molStructures;

    do {
        open(SDF, $sdfFile) or die "Cannot open SDF file for reading\n$!\n";
        #reset record input separator to slurp one record at a time - should only be reset in this scope
        local $/ = '$$$$';
        while (<SDF>) {
            my $record = $_;
            my @entries = split('> <', $record);
            my $hmdbId;
            foreach my $entry (@entries) {
                if ($entry =~ /DATABASE_ID/) {
                    $hmdbId = (split('\n', $entry))[1];
                }
            }
            my $mol = $entries[0];
            $mol =~ s/^\n+//;

            if (defined $hmdbId) {
                $molStructures->{$hmdbId} = $mol;
            }
        }
        close SDF;
    };

    my $xmlFile = $self->getArg('xmlFile');

    my $reader = XML::LibXML::Reader->new(location => $xmlFile)
        or die "cannot read file $xmlFile: $!\n";


    while($reader->read) {
        ## start element nodes named metabolite only
        next unless $reader->nodeType == 1;
        next unless $reader->name eq 'metabolite';
        #copies current node and all children to a DOM element object
        my $doc = $reader->copyCurrentNode(1);
        #register an xpath context for node lookups
        my $xc = XML::LibXML::XPathContext->new($doc);
        $xc->registerNs('hmdb', 'http://www.hmdb.ca');

        my @accessions = $xc->findnodes('hmdb:accession');
        die "Metabolite with accession $accessions[0] should have only one primary accession. Please check xml.\n" if scalar @accessions != 1;

        my $accession = $accessions[0]->textContent();
        my $primaryCompound = &makeCompound($xc, $accession, 1);

        foreach my $secondaryAccession ($xc->findnodes('hmdb:secondary_accessions/hmdb:accession')) {
            my $secondaryCompound = &makeCompound($xc, $secondaryAccession->textContent(), 0);
            $secondaryCompound->setParent($primaryCompound);
        }

        my @names =  $xc->findnodes('hmdb:name');
        die "Metabolite with accession $accession should have only one name.  Please check xml.\n" if scalar @names != 1;
        &makeName($names[0]->textContent(), 'NAME', $primaryCompound);

        my @iupacNames = $xc->findnodes('hmdb:iupac_name');
        die "Metabolite with accession $accession should only have one IUPAC name.  Please check xml.\n" if scalar @iupacNames != 1;
        &makeName($names[0]->textContent(), 'IUPAC NAME', $primaryCompound);

        foreach my $synonym ($xc->findnodes('hmdb:synonyms/hmdb:synonym')) {
            &makeName($synonym->textContent(), 'SYNONYM', $primaryCompound);
        }

        my $formula = $xc->findnodes('hmdb:chemical_formula')->[0]->textContent();
        &addChemicalData($formula, 'FORMULA', $primaryCompound) unless ($formula eq '');

        my $mass = $xc->findnodes('hmdb:average_molecular_weight')->[0]->textContent();
        &addChemicalData($mass, 'MASS', $primaryCompound) unless ($mass eq '');

        my $charge;
        foreach my $property ($xc->findnodes('hmdb:predicted_properties/hmdb:property')) {
            foreach my $node ($property->getChildrenByTagName('kind')) {
                if ($node->textContent() eq 'formal_charge') {
                    $charge = $property->getChildrenByTagName('value')->[0]->textContent();
                }
            }
        }
        &addChemicalData($charge, 'CHARGE', $primaryCompound) unless (! defined $charge || $charge eq '');

        #For now, just load chebi, pubchem and kegg xrefs
        my @xrefs = ('chebi', 'pubchem_compound', 'kegg'); 
        foreach my $xref (@xrefs) {
            &addXrefs($xc, $xref, $primaryCompound, $xrefSourceMap);
        }

        my $inchi = $xc->findnodes('hmdb:inchi')->[0]->textContent();
        &addStructureFromXml($inchi, 'InChI', $primaryCompound) unless ($inchi eq '');

        my $inchikey = $xc->findnodes('hmdb:inchikey')->[0]->textContent();
        &addStructureFromXml($inchikey, 'InChIKey', $primaryCompound) unless ($inchikey eq '');

        my $smiles = $xc->findnodes('hmdb:smiles')->[0]->textContent();
        &addStructureFromXml($smiles, 'SMILES', $primaryCompound) unless ($smiles eq '');

        #lookup mol data from hash and load
        if (exists $molStructures->{$accession}) {
            my $mol = $molStructures->{$accession};
            chomp $mol;
            my $gusStructure = GUS::Model::hmdb::structures->new({structure => $mol, type => 'mol', dimension => '2D'});
            $gusStructure->setParent($primaryCompound);
        
            my $defaultStructure = GUS::Model::hmdb::default_structures->new();
            $defaultStructure->setParent($gusStructure);
        }

        $primaryCompound->submit();
        $self->undefPointerCache();

        # move reader to next metabolite instead of parsing children of current node
        $reader->next;
    }
}
        

sub makeCompound {
    my ($xc, $accession, $isPrimary) = @_;
    my $name;
    my $definition;
    if ($isPrimary) {
        $name = $xc->findnodes('hmdb:name')->[0]->textContent();
        $definition = $xc->findnodes('hmdb:description')->[0]->textContent();
    }
    my $compound = GUS::Model::hmdb::compounds->new({name => $name, hmdb_accession => $accession, definition => $definition, source => 'HMDB'});
    return $compound;
}

sub makeName {
    my ($name, $type, $compound) = @_;
    my $gusName = GUS::Model::hmdb::names->new({name => $name, type => $type, source => 'HMDB'});
    $gusName->setParent($compound);
    return $gusName;
}

sub addChemicalData {
    my ($property, $type, $compound) = @_;
    my $chemicalData = GUS::Model::hmdb::chemical_data->new({chemical_data => $property, type => $type, source => 'HMDB'});
    $chemicalData->setParent($compound);
    return $chemicalData;
}

sub addXrefs {
    my ($xc, $xref, $compound, $xrefSourceMap) = @_;
    my $xmlTag = "hmdb:".$xref."_id";
    my $xrefAccession = $xc->findnodes($xmlTag)->[0]->textContent();
    if (defined $xrefAccession && $xrefAccession ne '') {
        my $source = $xrefSourceMap->{$xref};
        my $databaseAccession = GUS::Model::hmdb::database_accession->new({accession_number => $xrefAccession, source => $source, type => $source." accession"}); 
        $databaseAccession->setParent($compound);
        return $databaseAccession;
    }
}

sub addStructureFromXml {
    my ($structure, $type, $compound) = @_;
    my $gusStructure = GUS::Model::hmdb::structures->new({structure => $structure, type => $type, dimension => '1D'});
    $gusStructure->setParent($compound);

    my $autogenStructure = GUS::Model::hmdb::autogen_structures->new();
    $autogenStructure->setParent($gusStructure);
    return $gusStructure;
}

# Deletes self-referencing FKs from hmdb.compounds to allow undo
sub undoPreprocess {
    my ($self, $dbh, $rowAlgInvocationList) = @_;
    my $rowAlgInvocations = join(',', @{$rowAlgInvocationList});

    my $sql = "UPDATE hmdb.compounds
               SET parent_id = NULL
               WHERE row_alg_invocation_id in ($rowAlgInvocations)";
    
    my $sh = $dbh->prepare($sql);
    $sh->execute();
    $sh->finish();
}


sub undoTables {
    my $self = @_;
    return (
        'hmdb.default_structures',
        'hmdb.autogen_structures',
        'hmdb.structures',
        'hmdb.database_accession',
        'hmdb.chemical_data',
        'hmdb.names',
        'hmdb.compounds'
    )
}

1;


