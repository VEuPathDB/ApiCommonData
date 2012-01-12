
package ApiCommonData::Load::Plugin::InsertSyntenySpans;
@ISA = qw( GUS::PluginMgr::Plugin);

use strict;

use GUS::PluginMgr::Plugin;

use GUS::Model::DoTS::NASequence;

use GUS::Model::ApiDB::Synteny;
use GUS::Model::ApiDB::SyntenyAnchor;
use Data::Dumper;

my $argsDeclaration = 
  [
   fileArg({ name           => 'inputFile',
	     descr          => 'tab-delimited synteny span data',
	     reqd           => 1,
	     mustExist      => 1,
	     format         => 'custom',
	     constraintFunc => undef,
	     isList         => 0,
	   }),


   stringArg({name => 'syntenyDbRlsSpec',
	      descr => 'what is the external database release info for the synteny data being loaded',
	      constraintFunc => undef,
	      reqd => 1,
	      isList => 0
	     }),


  ];

my $purposeBrief = <<PURPOSEBRIEF;
Create entries for genomic synteny spans.
PURPOSEBRIEF
    
my $purpose = <<PLUGIN_PURPOSE;
Create entries for genomic synteny spans.
PLUGIN_PURPOSE

my $tablesAffected = "ApiDB.Synteny";


my $tablesDependedOn = [];

my $howToRestart = <<PLUGIN_RESTART;
Simply reexecute the plugin.
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
None.
PLUGIN_FAILURE_CASES

my $notes = <<PLUGIN_NOTES;
None.
PLUGIN_NOTES

my $documentation = { purpose=>$purpose,
		      purposeBrief=>$purposeBrief,
		      tablesAffected=>$tablesAffected,
		      tablesDependedOn=>$tablesDependedOn,
		      howToRestart=>$howToRestart,
		      failureCases=>$failureCases,
		      notes=>$notes
		    };

sub new {
    my ($class) = @_;
    my $self = {};
    bless($self,$class);

    $self->initialize({requiredDbVersion => 3.6,
		       cvsRevision => '$Revision$', # cvs fills this in!
		       name => ref($self),
		       argsDeclaration => $argsDeclaration,
		       documentation => $documentation
		      });

    return $self;
}

#--------------------------------------------------------------------------------

sub run {
  my ($self) = @_;

  my $file = $self->getArg('inputFile');

  my $synDbRlsId = $self->getExtDbRlsId($self->getArg('syntenyDbRlsSpec'));

  my $count = 0;

  open(IN, "<$file") or $self->error("Couldn't open file '$file': $!\n");

  my (@synA, @synB);

  while (<IN>) {
    chomp;

    my ($synA, $synB) = $self->_handleSyntenySpan($_, $synDbRlsId);

    push(@synA, $synA);
    push(@synB, $synB);

    $count++;

    if($count && $count % 500 == 0) {
      $self->log("Read $count lines... Inserted " . $count*2 . " ApiDB::Synteny");
    }

    $self->undefPointerCache();
  }
  close(IN);

  $self->insertAnchors(\@synA);
  $self->insertAnchors(\@synB);

  my $anchorCount = $self->getAnchorCount();

  return "inserted $count synteny spans and $anchorCount anchors ";
}

#--------------------------------------------------------------------------------

sub getAnchorCount {$_[0]->{anchor_count}}

sub countAnchor {
  my ($self) = @_;

  my $count = $self->{anchor_count}++;

  $self->log("Inserted $count rows into ApiDb::SyntenyAnchor") if ($count && $count % 1000 == 0);
}

#--------------------------------------------------------------------------------

=head2 Subroutines

=over 4

=item I<_handleSyntenySpan>

B<Parameters:>

 $self(_PACKAGE_):
 $line(STRING): ex: "MAL13   ctg_7202        111895  790019  115060  856803  +"
 $extDbRlsIdA(NUMBER): SRes::ExternalDatabaseRelease id for the Genome in the first column
 $extDbRlsIdB(NUMBER): SRes::ExternalDatabaseRelease id for the Genome in the second column
 $synDbRlsId(NUBER): SRes::ExternalDatabaseRelease id for the results

B<Return Type:> ARRAY

 2 Elements, Both are ApiDB.Synteny Objects... the second being the opposite of the first

=cut

sub _handleSyntenySpan {
  my ($self, $line, $synDbRlsId) = @_;

  my ($a_id, $b_id,
      $a_start, $a_len,
      $b_start, $b_len,
      $strand) = split(" ", $line);

  my $a_pk = $self->getNaSequenceId($a_id);
  my $b_pk = $self->getNaSequenceId($b_id);

  my $a_end = $a_start + $a_len - 1;
  my $b_end = $b_start + $b_len - 1;
  my $isReversed = $strand eq "-" ? 1 : 0;

  my $synteny = $self->makeSynteny($a_pk, $b_pk, $a_start, $b_start, $a_end, $b_end, $isReversed, $synDbRlsId);
  my $reverse = $self->makeSynteny($b_pk, $a_pk, $b_start, $a_start, $b_end, $a_end, $isReversed, $synDbRlsId);

  return($synteny, $reverse);
}

#--------------------------------------------------------------------------------

=item I<makeSynteny>

B<Parameters:>

 $self(_PACKAGE_):
 $a_pk(NUMBER): na_sequence_id
 $b_pk(NUMBER): na_sequence_id
 $a_start(NUMBER): Genomic coordinate where synteny begins
 $b_start(NUMBER): Genomic coordinate where synteny begins
 $a_end(NUMBER): Genomic coordinate where synteny ends
 $b_end(NUMBER): Genomic coordinate where synteny ends
 $isReversed(BOOLEAN): 1 for - strand; 0 for + strand
 $synDbRlsId(NUMBER): SRes::ExternalDatabaseRelease Id for the Synteny object

B<Return Type:> ARRAY

 2 Elements, Both are ApiDB.Synteny Objects... the second being the opposite of the first

=cut

sub makeSynteny {
  my ($self, $a_pk, $b_pk, $a_start, $b_start, $a_end, $b_end, $isReversed, $synDbRlsId) = @_;

  my $synteny = GUS::Model::ApiDB::Synteny->new({ a_na_sequence_id => $a_pk,
						  b_na_sequence_id => $b_pk,
						  a_start => $a_start,
						  b_start => $b_start,
						  a_end   => $a_end,
						  b_end   => $b_end,
						  is_reversed => $isReversed,
						  external_database_release_id => $synDbRlsId,
						});
  return $synteny;
}

#--------------------------------------------------------------------------------

sub getNaSequenceId {
  my ($self, $sourceId) = @_;

  my $dbh = $self->getQueryHandle();

  my $sql = "SELECT s.na_sequence_id FROM dots.nasequence s, sres.sequenceontology so
             WHERE  so.sequence_ontology_id = s.sequence_ontology_id and s.source_id = ? 
              and so.term_name in ( 'supercontig','chromosome','contig','mitochondrial_chromosome','apicoplast_chromosome')";

  my $sh = $dbh->prepare($sql);

  my @ids = $self->sqlAsArray( Handle => $sh, Bind => [$sourceId] );


  if(scalar @ids != 1) {
    $self->error("Sql Should return only one value: $sql\n for values: $sourceId");
  }
  return $ids[0];
}

#--------------------------------------------------------------------------------

sub insertAnchors {
  my ($self, $synRows) = @_;

  my $gene2orthologGroup = $self->findOrthologGroups();

  my $genesLocStmt = $self->prepareGenesLocStmt();

  foreach my $syntenyObj (@$synRows) {

    my $refGenes = $self->findGenes($genesLocStmt,
				    $syntenyObj->getANaSequenceId(),
				    $syntenyObj->getAStart(),
				    $syntenyObj->getAEnd()
                                    );

    my $synGenes = $self->findGenes($genesLocStmt,
				    $syntenyObj->getBNaSequenceId(),
				    $syntenyObj->getBStart(),
				    $syntenyObj->getBEnd()
                                   );

    # ordered by refGene loc
    my $genePairs = $self->findOrthologPairs($refGenes, $synGenes,
					     $gene2orthologGroup);

    my $anchors = $self->createSyntenyAnchors($syntenyObj, $genePairs);

    foreach my $anchor (@$anchors) {
      $self->addAnchorToGusObj($anchor, $syntenyObj);
    }

    $syntenyObj->submit();
    $self->undefPointerCache();
  }
  return 1;
}

#--------------------------------------------------------------------------------


sub createSyntenyAnchors {
  my ($self, $syntenyObj, $genePairs) = @_;

  my $rev = $syntenyObj->getIsReversed();

  my $anchors = [];

  my $anchorsCursor = 0;

  my $synLoc = $rev ? $syntenyObj->getBEnd() : $syntenyObj->getBStart();
  $self->addAnchor($syntenyObj->getAStart(),
                   $synLoc,
                   $anchors, 
                   $anchorsCursor++,
                   0);

  foreach my $genePair (@$genePairs) {

    if ($genePair->{refStart} > $syntenyObj->getAStart()) {
      $self->addAnchor($genePair->{refStart},
                       $genePair->{$rev? 'synEnd':'synStart'},
                       $anchors, $anchorsCursor++,
                       0);
    }

    if ($genePair->{refEnd} < $syntenyObj->getAEnd()) {
      $self->addAnchor($genePair->{refEnd},
                       $genePair->{$rev? 'synStart':'synEnd'},
                       $anchors, $anchorsCursor++,
                       0);
    }
  }

  $synLoc = $rev ? $syntenyObj->getBStart() : $syntenyObj->getBEnd();
  $self->addAnchor($syntenyObj->getAEnd(),
                   $synLoc,
                   $anchors, $anchorsCursor++,
                   1);
  return $anchors;
}

#--------------------------------------------------------------------------------

sub prepareGenesLocStmt {
  my ($self) = @_;

  my $sql = "select f.na_feature_id, l.start_min, l.end_max
             from dots.nalocation l, dots.genefeature f
             where l.na_feature_id = f.na_feature_id
             and f.na_sequence_id = ?
             and l.start_min > ?
             and l.end_max < ?";

  return $self->getDbHandle()->prepare($sql);
}

#--------------------------------------------------------------------------------

=item I<findOrthologGroups>

B<Parameters:>

 $self(_PACKAGE_):
 $extDbRlsIdA(NUMBER): SRes::ExternalDatabaseRelease id for the Reference Genome

B<Return Type:> ARRAY

2 elements, each are HASHREFS.  
   The first maps GeneFeature na_feature_id to SequenceSequenceGroup sequence_group_id
   The second tracks which na_feature_ids are from the reference.

=cut

sub findOrthologGroups {
  my ($self) = @_;

my $sql;




    $sql = "select g.na_feature_id as sequence_id, to_char(ssg.group_id) as sequence_group_id, g.external_database_release_id
    from apidb.CHROMOSOME6ORTHOLOGY ssg, dots.genefeature g
    where g.source_id = ssg.source_id
    UNION
    select ssg.sequence_id, to_char(ssg.sequence_group_id), g.external_database_release_id
    from dots.SequenceSequenceGroup ssg, dots.genefeature g, Core.TableInfo t
    where t.name = 'GeneFeature'
    and g.na_feature_id = ssg.sequence_id
    and t.table_id = ssg.source_table_id
    ";



  my $stmt = $self->getDbHandle()->prepareAndExecute($sql);

  my $gene2orthologGroup = {};

  while (my ($geneFeatId, $ssgId, $extDbRlsId) = $stmt->fetchrow_array()) {
     $gene2orthologGroup->{$geneFeatId} = $ssgId;
  }
  return $gene2orthologGroup
}

#--------------------------------------------------------------------------------

=item I<findGenes>

B<Parameters:>

 $self(_PACKAGE_):
 $stmt(prepared dbi statement handle): Find all genes (and their start/end) for given genomic coordinates
 $na_sequence_id(NUMBER): Dots::NaSequence pk (contig/chromosome where were looking)
 $start(NUMBER): Where the synteny begins
 $end(NUMBER): Where the synteny ends

B<Return Type:> ARRAYREF

 Each element is a HASH of genes with keys id, start, end. (id is the na_feature_id)

=cut

sub findGenes {
  my ($self, $stmt, $na_sequence_id, $start, $end) = @_;

  $stmt->execute($na_sequence_id, $start, $end);

  my @genes;
  while (my ($naFeatId, $geneStart, $geneEnd) = $stmt->fetchrow_array()) {
    push(@genes, {id => $naFeatId, start => $geneStart, end => $geneEnd});
  }

  return \@genes;
}

#--------------------------------------------------------------------------------

=item I<findOrthologPairs>

B<Parameters:>

 $self(_PACKAGE_)
 $refGenes(ARRAYREF): ARRAYREF, Each element is a hash of genes (id, start, end)
 $synGenes(HASHREF): ARRAYREF, Each element is a hash of genes (id, start, end)
 $gene2orthologGroup(HASHREF): na_feature_id to SequenceSequenceGroup sequence_group_id
 $orthologGroup2refGenes(HASHREF): second tracks which na_feature_ids are from the reference.

B<Return Type:> ARRAYREF

 ArrayRef of GenePairs for a Syntenic Region.  Each pair is a hash with keys: refStart, synStart, refEnd, synEnd

=cut

sub findOrthologPairs {
  my ($self, $refGenes, $synGenes, $gene2orthologGroup) = @_;

  my @genePairs;
  foreach my $synGene (@$synGenes) {
    my $ssgId = $gene2orthologGroup->{$synGene->{id}};
    next unless($ssgId);

    foreach my $refGene (@$refGenes) {
      my $ssgIdRef = $gene2orthologGroup->{$refGene->{id}};

      if ($ssgId eq $ssgIdRef) {
	my $genePair = {refStart=>$refGene->{start},
			refEnd=>$refGene->{end},
			synStart=>$synGene->{start},
			synEnd=>$synGene->{end}};

	push(@genePairs, $genePair);
      }
    }
  }

  # Sort by ref first then syn
  my @sortedPairs = sort { $a->{refStart} <=> $b->{refStart} || 
                             $a->{synStart} <=> $b->{synEnd} } @genePairs;

  my @sortedPairsFiltered;

  my $prevRefStart = 0;
  my $prevRefEnd = 0;


  foreach my $sortedPair (@sortedPairs){
      if($sortedPair->{refStart} > $prevRefEnd){
	  push(@sortedPairsFiltered,$sortedPair);
	  $prevRefStart = $sortedPair->{refStart};
	  $prevRefEnd = $sortedPair->{refEnd};
      }else{
	  print STDERR "This gene pair has been removed because of overlap with another gene :";
	  print STDERR Dumper $sortedPair;
      }

  }

  return \@sortedPairsFiltered;

}

#--------------------------------------------------------------------------------

sub addAnchor {
  my ($self, $refLoc, $synLoc, $anchors, $anchorsCursor, $addFinalToo) = @_;

  my $rightEdge = 9999999999;
  my $leftEdge = -9999999999;

  my $anchor = {prev_ref_loc=> $leftEdge,
                ref_loc=> $refLoc,
                next_ref_loc=> $rightEdge,
                syntenic_loc=> $synLoc};

  $anchors->[$anchorsCursor] = $anchor;

  my $prevAnchor = $anchors->[$anchorsCursor - 1];
  my $prevGeneAnchor = $anchorsCursor - 2 > 0 ? $anchors->[$anchorsCursor - 2] : undef;

  if ($anchorsCursor > 0) {

    # paralog group
    if($prevGeneAnchor && $anchor->{ref_loc} == $prevGeneAnchor->{ref_loc}) {
      $prevGeneAnchor->{next_ref_loc} = $leftEdge;
      $prevAnchor->{next_ref_loc} = $leftEdge;
      $anchor->{prev_ref_loc} = $rightEdge;
    }
    else {
      $prevAnchor->{next_ref_loc} = $refLoc;
      $anchor->{prev_ref_loc} = $prevAnchor->{ref_loc}; 
    }

    # take care of the last in a paralog group 
    if($prevGeneAnchor && $anchor->{ref_loc} != $prevGeneAnchor->{ref_loc} && $prevAnchor->{prev_ref_loc} == $rightEdge) {
      $prevGeneAnchor->{next_ref_loc} = $prevAnchor->{ref_loc};
    }
  }
}

#--------------------------------------------------------------------------------

sub addAnchorToGusObj {
  my ($self, $anchor, $syntenyObj) = @_;

  if($anchor->{prev_ref_loc} > $anchor->{ref_loc} || $anchor->{ref_loc} > $anchor->{next_ref_loc}){
      print STDERR "Error in synteny object: ";
      print STDERR Dumper $syntenyObj->toString();
      $self->error("Anchor locations: prev_ref_loc = $anchor->{prev_ref_loc}, ref_loc = $anchor->{ref_loc}, next_ref_loc = $anchor->{next_ref_loc}");
  }
  my $anchorObj = GUS::Model::ApiDB::SyntenyAnchor->new($anchor);
  $syntenyObj->addChild($anchorObj);
  $self->countAnchor();
}

#--------------------------------------------------------------------------------

sub undoTables {
  return qw(ApiDB.SyntenyAnchor ApiDB.Synteny);
}

1;
