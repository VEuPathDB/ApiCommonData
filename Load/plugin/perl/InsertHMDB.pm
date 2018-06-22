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
                        cvsRevision => '$Revision : 89665 $',
                        name => ref($self),
                        argsDeclaration => $argsDeclaration,
                        documentation => $documentation
                    });
    return $self;
}

sub  run {
    my $self = @_;

    $self->setPointerCacheSize(100000);
    

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
        die "Metabolite with accession $accessions[0] should have only on primary accession. Please check xml.\n" if scalar @accessions != 1;

        my $accession = $accessions[0];
        #my $name = $xc->findnodes('hmdb:name')->[0];
        #my $definition = $xc->findnodes('hmdb:description')->[0];
        
        my $primaryCompound = makeCompound($xc, $accession, 1);
        $primaryCompound->retrieveFromDB();

        foreach my $secondaryAccession ($xc->findnodes('hmdb:secondary_accessions/hmdb:accession')) {
            my $secondaryCompound = &makeCompound($xc, $secondaryAccession, 0);
            $secondaryCompound->setParent_Id($primaryCompound->{'id'});
        }
    }
    # move reader to next metabolite instead of parsing all children of current node
    $reader->next;
}
        
#    print STDERR Dumper $accession->textContent();
#    print STDERR Dumper $name->textContent();
#    print STDERR Dumper $definition->textContent();

#    foreach my $accession ($xc->findnodes('hmdb:accession')) {
#        print STDERR "Primary accession:\n";
#        print Dumper $accession->nodeName();
#        print Dumper $accession->textContent();
#    }
#    print STDERR "Secondary accessions:\n";
#    foreach my $secondaryAccession ($xc->findnodes('hmdb:secondary_accessions/hmdb:accession')) {
#        print Dumper $secondaryAccession->nodeName();
#        print Dumper $secondaryAccession->textContent();
#    }
    #this way iterates through all child nodes but probably easier to extract what I want with lookups as above
    #my @nodeList = $doc->childNodes();
    #foreach my $node (@nodeList) {
    #    #need to exclude text nodes with no content here
    #    print STDERR Dumper $node->nodeName();
    #    print STDERR Dumper $node->textContent();
    #}
    #moves reader to next metabolite node rather than parsing all the children of the previous node
#    $reader->next;



sub makeCompound {
    my ($self, $xc, $accession, $isPrimary) = @_;
    my $name;
    my $definition;
    if ($isPrimary) {
        my $name = $xc->findnodes('hmdb:name')->[0];
        my $definition = $xc->findnodes('hmdb:description')->[0];
    }
    my $compound = GUS::Model::hmdb::compounds->new({name => $name, hmdb_accession => $accession, definition => $definition});
    return $compound;
}

#TODO: fill this out
sub undoTables {
    my $self = @_;
    return
}

1;


