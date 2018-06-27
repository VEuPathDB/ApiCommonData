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

#TODO fill  these out
my $argsDeclaration = [];

my $purpose = <<PURPOSE;
Insert HMDB metabolites
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
Insert HMDB metabolites
PURPOSE_BRIEF

my $notes;
my $tablesAffected;
my $tablesDependedOn;
my $howToRestart;
my $failureCases;
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

    my $reader = XML::LibXML::Reader->new(location => "/home/crouchk/hmdb_metabolites_minusOntology.xml")
        or die "cannot read file '/home/crouchk/hmdb_metabolites_minusOntology.xml': $!\n";


    while($reader->read) {
        ## start element nodes only
        next unless $reader->nodeType == 1;
        next unless $reader->name eq 'metabolite';
        print STDERR "Parsing next metabolite\n";
        #copies current node and all children to a DOM element object
        my $doc = $reader->copyCurrentNode(1);
        #register an xpath context for node lookups
        my $xc = XML::LibXML::XPathContext->new($doc);
        $xc->registerNs('hmdb', 'http://www.hmdb.ca');

        my @accessions = $xc->findnodes('hmdb:accession');
        die "Metabolite with accession $accessions[0] should have only one primary accession. Please check xml.\n" if scalar @accessions != 1;

        my $accession = $accessions[0]->textContent();
        print STDERR "Inserting primary accesssion...\n";  
        my $primaryCompound = makeCompound($xc, $accession, 1);

        print STDERR "Inserting secondary accessions...\n";
        foreach my $secondaryAccession ($xc->findnodes('hmdb:secondary_accessions/hmdb:accession')) {
            my $secondaryCompound = &makeCompound($xc, $secondaryAccession->textContent(), 0);
            $secondaryCompound->setParent($primaryCompound->{'id'});
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


        $primaryCompound->submit();
        $self->undefPointerCache();
        #exit;
    }
    # move reader to next metabolite instead of parsing all children of current node
    $reader->next;
}
        

sub makeCompound {
    my ($xc, $accession, $isPrimary) = @_;
    my $name;
    my $definition;
    if ($isPrimary) {
        $name = $xc->findnodes('hmdb:name')->[0]->textContent();
        $definition = $xc->findnodes('hmdb:description')->[0]->textContent();
    }
    print STDERR Dumper $accession;
    print STDERR Dumper $name;
    print STDERR Dumper $definition;
    my $compound = GUS::Model::hmdb::compounds->new({name => $name, hmdb_accession => $accession, definition => $definition, source => 'HMDB'});
    return $compound;
}

sub makeName {
    my ($name, $type, $compound) = @_;
    print STDERR Dumper $name;
    print STDERR Dumper $type;
    my $gusName = GUS::Model::hmdb::names->new({name => $name, type => $type, source => 'HMDB'});
    $gusName->setParent($compound);
    return $gusName;
}

sub addChemicalData {
    my ($property, $type, $compound) = @_;
    print STDERR Dumper $property;
    print STDERR Dumper $type;
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
        print STDERR Dumper $xref;
        print STDERR Dumper $xrefAccession;
        print STDERR Dumper $source;
        my $databaseAccession = GUS::Model::hmdb::database_accession->new({accession_number => $xrefAccession, source => $source, type => $source." accession"}); 
        $databaseAccession->setParent($compound);
        return $databaseAccession;
    }
}

sub addStructureFromXml {
    my ($structure, $type, $compound) = @_;
    print STDERR Dumper $structure;
    print STDERR Dumper $type;
    my $gusStructure = GUS::Model::hmdb::structures->new({structure => $structure, type => $type, dimension => '1D'});
    $gusStructure->setParent($compound);

    my $autogenStructure = GUS::Model::hmdb::autogen_structures->new();
    $autogenStructure->setParent($gusStructure);
    return $gusStructure;
}

#TODO: fill this out
sub undoTables {
    my $self = @_;
    return (
        'hmdb.autogen_structures',
        'hmdb.structures',
        'hmdb.database_accession',
        'hmdb.chemical_data',
        'hmdb.names',
        'hmdb.compounds'
    )
}

1;


