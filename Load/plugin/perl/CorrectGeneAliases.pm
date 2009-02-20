package ApiCommonData::Load::Plugin::CorrectGeneAliases;

@ISA = qw(GUS::PluginMgr::Plugin);


use strict;
use GUS::PluginMgr::Plugin;
use GUS::Model::DoTS::NAFeatureNAGene;
use GUS::Model::DoTS::NAGene;

my $argsDeclaration =
[

   fileArg({name           => 'mappingFiles',
	    descr          => 'A list of files mapping synonyms to source_ids',
	    reqd           => 0,
	    mustExist      => 1,
	    format         => 'Tab delimited.  First column is alias, second source_id.  First row can optionally be a header, with headings of "alias" and "sourceid"',
	    constraintFunc => undef,
	    isList         => 1, }),


];

my $purpose = <<PURPOSE;
Insert aliases provided in zero, one or more mapping files and delete inconsistent aliases.  An alias is inconsistent if (1) it is identical to a source_id or (2) it points to more than one source_id.  Alias mappings provided in the mapping file are assumed to be correct, and so are never considered inconsistent.  If an alias is present in the mapping file(s) more than once and points to more than one source_id, or is identical to a source_id, an error is thrown.

The objective of the clean up is to guarantee a 1-m relationship between genes and aliases.  We preserve this so that annotation is never assigned to incorrect genes, and to allow applications to trust the 1-m relationship.

The problem aliases are broken into categories:
  * complete duplicate: single row in NAGene is linked to single row in
       GeneFeature with more than one rows in NAFeatureNAGene.  All but one 
       NAFeatureNAGenes are removed.  NAGene is left alone.
  * pretender alias: alias is the name of a real source id.  The NAGene and
       all related NAFeatureNAGenes are removed.
  * superceded by files: alias in db is provided in file, so is superceded. 
       The NAGene and its related NAFeatureNAGenes are removed.
  * duplicate: more than one row in NAGene contain the same name.  The NAGenes
       and related NAFeatureNAGenes are removed.

Use --verbose to get a report of the problem aliases
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
Insert aliases provided in mapping files and clean out any duplicate aliases.

PURPOSE_BRIEF

my $notes = <<NOTES;
NOTES

my $tablesAffected =
[
 ["DoTS::NAGene", '']
];


my $tablesDependedOn =
[
 ["DoTS::NAGene", ''],
 ["DoTS::GeneFeature", '']
];

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
		      cvsRevision       => '$Revision: 9726 $',
		      name              => ref($self),
		      argsDeclaration   => $argsDeclaration,
		      documentation     => $documentation});

  return $self;
}

sub run {
  my ($self) = @_;

  # get source_id -> na_feature_id mapping from db
  #
  my %sourceId2NaFeatureId;
  my $sql = "SELECT source_id, na_feature_id FROM dots.genefeature";
  my $sth = $self->prepareAndExecute($sql);
  while (my ($sourceId, $na_feature_id) = $sth->fetchrow_array()) {
    $sourceId2NaFeatureId{$sourceId} = $na_feature_id;
  }

  # capture aliases from file;  validate along the way.
  #
  my %fileAlias2SourceId;

  if ($self->getArg('mappingFiles')){
  
  foreach my $file (@{$self->getArg('mappingFiles')}) {
    open(FILE, $file) 
      || $self->userError("Can't open mapping file '$file' for reading");
    while (<FILE>) {
      next if /alias\tsource/;
      chomp;
      my @line = split(/\t/);
      scalar(@line) == 2
	|| $self->userError("File $file has line with more than one tab: '$_'");
      my ($alias, $sourceId) = @line;
      ($fileAlias2SourceId{$alias}
       && $fileAlias2SourceId{$alias} ne $sourceId)
	&& $self->userError("File $file introduces a duplicate alias '$alias'");

      $sourceId2NaFeatureId{$alias}
	&& $self->userError("File $file has alias '$alias' that is a source_id");
      $fileAlias2SourceId{$alias} = $sourceId;
    }
  }
}
  # 
  my %alias2NaFeatureId;
  my @completeDuplicates;
  my @pretenderAliases;
  my @duplicatedWithFileAliases;
  my @duplicatedAliases;
  my %firstGuys;

  $sql = "
SELECT nag.name, nag.na_gene_id, nfng.na_feature_id, nfng.na_feature_na_gene_id
FROM Dots.NAGene nag, Dots.NaFeatureNaGene nfng
WHERE nfng.na_gene_id = nag.na_gene_id "; 

  $sth = $self->prepareAndExecute($sql);
  while (my ($alias, $na_gene_id, $na_feature_id, $na_f_na_g_id)
	 = $sth->fetchrow_array()) {

    my $a = [$alias, $na_f_na_g_id, $na_gene_id];

    if (!$firstGuys{$alias}) {
      $firstGuys{$alias} = $a;
    }

    if ($alias2NaFeatureId{$alias} == $na_feature_id) {
      push(@completeDuplicates, $a);
    } elsif ($sourceId2NaFeatureId{$alias}) {
      push(@pretenderAliases, $a);
    } elsif ($fileAlias2SourceId{$alias}) {
      push(@duplicatedWithFileAliases, $a);
    } elsif ($alias2NaFeatureId{$alias}) {
      push(@duplicatedAliases, $firstGuys{$alias});
      push(@duplicatedAliases, $a);
    } else {
      $alias2NaFeatureId{$alias} = $na_feature_id;
    }
  }

  $self->getAlgInvocation()->manageTransaction(undef,'begin');

  $self->deleteNAFeatureNAGene("complete duplicates",
			       \@completeDuplicates, 0);
  $self->deleteNAFeatureNAGene("pretender aliases",
			     \@pretenderAliases, 1);
  $self->deleteNAFeatureNAGene("superceded by files ",
			      \@duplicatedWithFileAliases, 1);
  $self->deleteNAFeatureNAGene("duplicates ", 
			       \@duplicatedAliases, 1);

  # and now delete from NAGene
  $self->deleteNAGene();

  # insert aliases from files
  $self->log("  Inserting " . scalar(keys %fileAlias2SourceId) . " aliases from mapping files");
  while (my ($alias, $sourceId) = (each %fileAlias2SourceId)) {
    my $na_feat_id = $sourceId2NaFeatureId{$sourceId};
    my $NAGene = GUS::Model::DoTS::NAGene->new({name => $alias,
						is_verified => 1});
    my $NAFeatureNAGene = GUS::Model::DoTS::NAFeatureNAGene->new({na_feature_id => $na_feat_id});
    $NAGene->addChild($NAFeatureNAGene);
    $NAGene->submit(undef,1);
    $NAGene->undefPointerCache();
  }

  $self->getAlgInvocation()->manageTransaction(undef,'commit');

  my @total = (@completeDuplicates, @pretenderAliases, 
	       @duplicatedWithFileAliases, @duplicatedAliases);
  return "Inserted " . scalar(keys %fileAlias2SourceId) . " aliases.  Deleted "
    . scalar(@total) . " duplicate aliases";
}

sub deleteNAFeatureNAGene {
  my ($self, $name, $set, $deleteNAGene) = @_;
  $self->log("  Deleting " . scalar(@$set) . " $name from NAFeatureNAGene");
  $self->logVerbose("    " . "alias\tna_feature_na_gene_id\tna_gene_id");
  foreach my $dup (@$set) {
      $self->logVerbose("    " . join("\t", @{$dup}));

      $self->{naGenesToDelete}->{$dup->[2]} = 1 if $deleteNAGene;

      my $NAFeatureNAGene = GUS::Model::DoTS::NAFeatureNAGene->
	new({na_feature_na_gene_id => $dup->[1]});
      if ($NAFeatureNAGene->retrieveFromDB()) {
	$NAFeatureNAGene->markDeleted(1);
	$NAFeatureNAGene->submit(undef,1);
      }
      $NAFeatureNAGene->undefPointerCache();
    }
}

sub deleteNAGene {
  my ($self) = @_;

  my @toDelete = keys(%{$self->{naGenesToDelete}});
  $self->log("  Deleting " . scalar(@toDelete) . " aliases from NAGene");
  foreach my $naGeneId (@toDelete) {
      my $NAGene = GUS::Model::DoTS::NAGene->
	new({na_gene_id => $naGeneId});
      $NAGene->retrieveFromDB();
      $NAGene->markDeleted(1);
      $NAGene->submit(undef,1);
      $NAGene->undefPointerCache();
    }
}

1;
