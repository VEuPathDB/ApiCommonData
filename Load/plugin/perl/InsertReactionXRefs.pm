package ApiCommonData::Load::Plugin::InsertReactionXRefs;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;
use GUS::PluginMgr::Plugin;
use GUS::Supported::Util;

use GUS::Model::ApiDB::PathwayReactionXRef;

use Data::Dumper;

my $argsDeclaration = 
[
    fileArg({name => 'inputFile',
             descr => 'Path to file containing Xrefs',
             reqd => 1,
             mustExist => 1,
             constraintFunc => undef,
             isList => 0,
             format => 'Two column tab file'
            }),

    stringArg({name => 'extDbRlsSpec',
               descr => 'External Database Release Name|Version',
               isList => 0,
               reqd => 1,
               constraintFunc => undef,
              }),
];

my $purpose  = <<PURPOSE;
Insert cross references for pathway reactions
PURPOSE

my $purposeBrief =  <<PURPOSE_BRIEF;
Insert cross references for pathway reactions
PURPOSE_BRIEF

my $notes = <<NOTES;
NOTES

my $tablesAffected = <<TABLES_AFFECTED;
Apidb.PathwayReactionXref
TABLES_AFFECTED

my $tablesDependedOn = <<TABLES_DEPENDED_ON;
Apidb.PathwayReaction
TABLES_DEPENDED_ON

my $howToRestart = <<RESTART;
There are no restart facilities available for this plugin
RESTART

my $failureCases = <<FAIL_CASES;
FAIL_CASES

my $documentation = {
                    purpose => $purpose,
                    purposeBrief => $purposeBrief,
                    notes => $notes,
                    tablesAffected => $tablesAffected,
                    tablesDependedOn => $tablesDependedOn,
                    howToRestart => $howToRestart,
                    failureCases => $failureCases,
                    };

sub new {
    my ($class) = @_;
    my $self = {};
    bless ($self, $class);

    $self->initialize({
                    requiredDbVersion => 4.0,
                    cvsRevision => '$Revision$',
                    name => ref($self),
                    argsDeclaration => $argsDeclaration,
                    documentation => $documentation,
                    });
    return $self;
}

sub run {
    my ($self) = @_;

    my $xRefFileName = $self->getArg('inputFile');
    my $reactionHash = $self->getReactions();
    my $extDbRlsSpec = $self->getArg('extDbRlsSpec');
    my $extDbRlsId = $self->getExtDbRlsId($extDbRlsSpec);
#    print Dumper ($reactionHash);
 
    open (FILE, $xRefFileName) or die "Cannot open file $xRefFileName for reading\n$!\n";

    my $header = <FILE>;

    foreach my $line (<FILE>) {
        chomp $line;
        my (@data) = split('\t', $line);
        next unless scalar(@data) >= 2;
        for (my $i=0; $i < scalar(@data); $i++) {
            next unless defined($data[$i]);
            my @firstColumnData = split(',', $data[$i]);
            # if >1 entry, do we want to xref these?? No

            for (my $j=0; $j < scalar(@data); $j++) {
                next unless defined ($data[$j]);
                next if $i==$j;
                my @secondColumnData = split(',', $data[$j]);
                foreach my $firstEntry (@firstColumnData) {
                    $firstEntry = cleanEntry($firstEntry);
                 #   $firstEntry =~ s/\.c.*//;
                 #   $firstEntry =~ s/^\s+//; #TODO trim white space at both ends
                    foreach my $secondEntry (@secondColumnData) {
                        $secondEntry =~ s/\.c.*//;
                        $secondEntry =~ s/^\s+//;
                        print "$firstEntry : $secondEntry\n";
            
                        if (exists $reactionHash->{$firstEntry} && exists $reactionHash->{$secondEntry}) {
                            my $xRef = GUS::Model::ApiDB::PathwayReactionXRef->new({
                                                                                    pathway_reaction_id => $reactionHash->{$firstEntry},
                                                                                    associated_reaction_id => $reactionHash->{$secondEntry},
                                                                                    external_database_release_id => $extDbRlsId, #assumes extDb for xrefs
                                                                                    });
                            $xRef->submit();
                            $self->undefPointerCache();
                        }
                    }
                }
            }
        } 
    }
}  

sub cleanEntry {
    my $entry = @_;
    $entry =~ s/\.c.*//;
    $entry =~ s/^\s+//;
    chomp $entry;
    return $entry;
}

sub getReactions {
    my ($self) = @_;

    my $dbh = $self->getQueryHandle();
    my $query = 'select source_id, pathway_reaction_id from apidb.pathwayreaction';
    my $sh = $dbh->prepare($query);
    $sh->execute(); #TODO close this handle

    my $reactionHash = {};
    # Handle entries with >1 source_id delimited by space
    while (my ($sourceIds, $reactionId) = $sh->fetchrow_array()) {
        foreach my $sourceId (split(' ', $sourceIds)) {
            $reactionHash->{$sourceId} = $reactionId;
        }
    }
    return $reactionHash;
}
