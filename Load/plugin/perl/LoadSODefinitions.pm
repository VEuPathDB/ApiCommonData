package ApiCommonData::Load::Plugin::LoadSODefinitions;
@ISA = qw(GUS::PluginMgr::Plugin);
 
use strict;
use FileHandle;
use GUS::ObjRelP::DbiDatabase;
use GUS::Model::SRes::SequenceOntology;

#Note, this requires two schema changes from GUS3.0, sres.sequenceontology.so_id must be a varchar2
#and definition needs to have a field lenght of 4000.

$| = 1;

sub new {
    my ($class) = @_;
    my $self = {};
    bless($self, $class);
    my $usage = 'Loads Sequence Ontology Definition file into SRes.SequenceOntology';
    my $easycsp =
        [{o => 'inputFile',
          t => 'string',
          h => 'name of the file',
          },

          { h => 'repository version of SeqOntology',
          t => 'string',
          o => 'so_cvs_version',

         },];

     $self->initialize({requiredDbVersion => {Core => '3'},
                       cvsRevision => '$Revision$', #CVS fills this in
                       cvsTag => '$Name$', #CVS fills this in
                       name => ref($self),
                       revisionNotes => 'make consistent with GUS 3.0',
                       easyCspOptions => $easycsp,
                       usage => $usage
                      });
    return $self;
}

sub run {
        my $self = shift;
        my $version;
	my $term;
        my $id;
        my $definition;

        $self->getArgs()->{'commit'} ? $self->log("***COMMIT ON***\n") : $self->log("**COMMIT TURNED OFF**\n");
        $self->getArgs->{'inputFile'};
        my $so_cvs_version = $self->getArgs->{'so_cvs_version'};

        if (!$self->getArgs->{'inputFile'}) {
          die "provide --inputFile name on the command line\n"; }

        my $Input = FileHandle->new('<' . $self->getArgs->{inputFile});

        print "If there is no structure in the world, then there is no world to strucuture.\n\n\n";
        while (<$Input>){
           #I could do this with splits or pattern extraction, but I'm treating as a fixed length data field
           if (substr($_,1,7) eq 'version') { $version = substr($_,20,5); }
           if (substr($_,0,4) eq 'term') {
                                 $term = substr($_,5); }
           if (substr($_,0,2) eq 'id') {
                                 $id = substr($_,7,7); }
           if (substr($_,0,11) eq 'definition:') {
                                 $definition = substr($_,11); 
              my $SOentry = GUS::Model::SRes::SequenceOntology->new({'ontology_name' => 'sequence',
                                                                     'so_id' => $id, 
                                                                     'so_version' => $version,
                                                                     'term_name' => $term, 
                                                                     'definition' =>  $definition,
                                                                     'so_cvs_version' => $so_cvs_version, }); 

             unless ($SOentry->retrieveFromDB()) {
                              $SOentry->submit(); }      }
       } 
       $Input->close;
       return "LoadedSOontologyFromFile";
}


return 1;

