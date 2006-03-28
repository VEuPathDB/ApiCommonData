package ApiCommonData::Load::Plugin::InsertPhylogeneticProfile;

@ISA = qw(GUS::PluginMgr::Plugin);

# ----------------------------------------------------------------------

use strict;
use GUS::PluginMgr::Plugin;
use FileHandle;

use GUS::Model::ApiDB::PhylogeneticProfile;


my $argsDeclaration =
[

   fileArg({name           => 'OrthologFile',
            descr          => 'Ortholog Data (ortho.mcl). OrthologGroupName followed by a colon then the ids for the members of the group',
            reqd           => 1,
            mustExist      => 1,
	    format         => 'ORTHOMCL9(446 genes,1 taxa): osa1088(osa) osa1089(osa) osa11015(osa)...',
            constraintFunc => undef,
            isList         => 0, 
           }),

   fileArg({name           => 'MappingFile',
            descr          => 'File mapping orthoFile ids to source ids',
            reqd           => 1,
            mustExist      => 1,
	    format         => 'Space separators... first column is the orthoId and the second column is the sourceId',
            constraintFunc => undef,
            isList         => 0, 
           }),

];

my $purpose = <<PURPOSE;
The purpose of this plugin is to insert rows intot ApiDB::PhylogeneticProfile representing orthologous groups.  Each row in this table mappes a source_id (gene) to a long string representing its profile.  Only source_ids contained in the mapping file are entered.  The long string includes every species contained anywhere in the OrthologFile.
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;

PURPOSE_BRIEF

my $notes = <<NOTES;

NOTES

my $tablesAffected = <<TABLES_AFFECTED;
ApiDB::PhylogeneticProfile
TABLES_AFFECTED

my $tablesDependedOn = <<TABLES_DEPENDED_ON;
TABLES_DEPENDED_ON

my $howToRestart = <<RESTART;
There are no restart facilities for this plugin
RESTART

my $failureCases = <<FAIL_CASES;
FAIL_CASES

my $documentation = { purpose          => $purpose,
                      purposeBrief     => $purposeBrief,
                      notes            => $notes,
                      tablesAffected   => $tablesAffected,
                      tablesDependedOn => $tablesDependedOn,
                      howToRestart     => $howToRestart,
                      failureCases     => $failureCases };

# ----------------------------------------------------------------------

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  $self->initialize({ requiredDbVersion => 3.5,
                      cvsRevision       => '$Revision$',
                      name              => ref($self),
                      argsDeclaration   => $argsDeclaration,
                      documentation     => $documentation});

  return $self;
}

# ======================================================================

sub run {
  my ($self) = @_;

  my $mapping = $self->_getMapping();

  open(FILE, $self->getArg('OrthologFile')) || die "Could Not open Ortholog File for reading: $!\n";

  my ($counter, %geneProfiles, @fullProfile);

  while(my $line = <FILE>) {
    chomp($line);

    if($counter++ % 1000 == 0) {
      $self->log("Processed $counter lines From OrthoFile");
    }

    my ($orthoName, $restOfLine) = split(':', $line);
    my @elements = split(" ", $restOfLine);

    my $orthoProfileList = $self->_getOrthoProfile(\@elements);

    foreach my $species (@$orthoProfileList) {
      next if($self->_isContained(\@fullProfile, $species));
      push(@fullProfile, $species);
    }

    my $foundIds = $self->_findElementIDs($mapping, \@elements);
    next if(scalar(@$foundIds) == 0);

    foreach(@$foundIds) {
      $geneProfiles{$_} = $orthoProfileList;
    }
  }
  close(FILE);

  @fullProfile = sort(@fullProfile);

  my $numberLoaded = $self->_makePhylogeneticProfiles(\%geneProfiles, \@fullProfile);

  return("Loaded $numberLoaded ApiDB::PhylogeneticProfile entries");
}

# ----------------------------------------------------------------------

=pod

=item C<_getOrthoProfile>

Given the list of genes in an ORTHOLOG Group... makes a nonRedundant list
of species (3 letter abbrev).  This is done for every line of the OrthoGroup file.

B<Parameters:>

- $elements(arrayRef): list of genes in the format [geneName(species) ...]

B<Return type:> C<arrayRef>

Non Redundant list of species contained in elements.

=cut

sub _getOrthoProfile {
  my ($self, $elements) = @_;

  my @elements = @$elements;

  my @rv;

  foreach my $name(@elements) {
    $name =~ /(\(.+\))/; #match inside ()
    $name = $1;

    $name =~ s/[\(\)]//g; #remove ( and )

    next if($self->_isContained(\@rv, $name));
    push(@rv, $name);
  }
  return(\@rv);
}

# ----------------------------------------------------------------------

=pod

=item C<_isContained>

Asks whether the value is contained in the array.

B<Parameters:>

- $ar(arrayRef):
- $val(scalar):  

B<Return type:> C<boolean>

=cut

sub _isContained {
  my ($self, $ar, $val) = @_;

  return(0) if(!$ar);

  foreach(@$ar) {
    return(1) if($_ eq $val);
  }
  return(0);
}


# ----------------------------------------------------------------------

=pod

=item C<_getMapping>

Read from mapping file, generate a hash which mapps the Ids contained
in the OrthologFile to Database Source Ids

B<Return type:> C<hashRef>

=cut

sub _getMapping {
  my ($self) = @_;

  my %rv;

  open(MAP, $self->getArg('MappingFile')) || die "Could Not open Mapping File for reading: $!\n";

  while(<MAP>) {
    chomp;

    my ($orthoId, $sourceId) = split(" ", $_);
    $rv{$orthoId} = $sourceId;
  }
  close(MAP);
  
  return(\%rv);
}

# ----------------------------------------------------------------------

=pod

=item C<_findElements>

Loops through an arrayRef of 'elements' and makes a new array if the element
is mapped to a value.

B<Parameters:>

- $mapping(hashRef):  
- $elements(arrayRef):  List of elements from OrthologFile

B<Return type:> C<arrayRef>

List of Database Source Ids

=cut

sub _findElementIDs {
  my ($self, $mapping, $elements) = @_;

  my @rv;

  foreach my $name(@$elements) {
    $name =~ s/\(.+\)//g; #get rid of anything inside ()'s

    if(my $id = $mapping->{$name}) {
      push(@rv, $id);
    }
  }
  return(\@rv);
}

# ----------------------------------------------------------------------

=pod

=item C<_makePhylogeneticProfiles>

Generates the profile string and submitts the phylogeneticProfiles

B<Parameters:>

- $geneProfiles(hashRef): map of source_id to a list of species 
- $fullProfile(arrayRef): list of the entire set of species (3 letter Abbrev)

B<Return type:> C<scalar>

Number of entries which were inserted

=cut

sub _makePhylogeneticProfiles {
  my ($self, $geneProfiles, $fullProfile) = @_;

  my $count;

  foreach my $gene (keys %$geneProfiles) {
    my $profileString;
    my @geneYesList = @{$geneProfiles->{$gene}};

    foreach my $species (@$fullProfile) {
      if($self->_isContained(\@geneYesList, $species)) {
        $profileString = $profileString.$species.':Y-';
      }
      else {
        $profileString = $profileString.$species.':N-';
      }
    }
    chop($profileString); #remove the last -

    my $profile = GUS::Model::ApiDB::PhylogeneticProfile->
      new({source_id => $gene,
           profile_string => $profileString
          });
    $profile->submit();

    if($count % 100 == 0) {
      $self->log("Inserted $count Entries into PhylogeneticProfile");
    }

    $count++;

    $self->undefPointerCache();
  }
  return($count);
}

# ----------------------------------------------------------------------

sub undoTables {
  my ($self) = @_;

  return ('ApiDB.PhylogeneticProfile',
	 );
}

1;
