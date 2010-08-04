package ApiCommonData::Load::Plugin::InsertPairwiseSyntenySpans;
@ISA = qw( GUS::PluginMgr::Plugin);

use strict;

use GUS::PluginMgr::Plugin;

use GUS::Model::ApiDB::Synteny;
use GUS::Model::ApiDB::SyntenyAnchor;
use CBIL::Util::PropertySet;
use Data::Dumper;

my $argsDeclaration = 
  [
   fileArg({ name           => 'mercatorDir',
	     descr          => 'the root directory under which all the pairwise directories are located',
	     reqd           => 1,
	     mustExist      => 1,
	     format         => 'custom',
	     constraintFunc => undef,
	     isList         => 0,
	   }),

   enumArg({name => 'organism',
              descr => 'Species to insert synteny data for',
              constraintFunc=> undef,
              reqd  => 1,
              isList => 0,
              enum => "Plasmodium, Toxoplasma, Cryptosporidium, TriTryp, Giardia, Entamoeba, Microsporidia",
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

    $self->initialize({requiredDbVersion => 3.5,
		       cvsRevision => '$Revision: 36282 $', # cvs fills this in!
		       name => ref($self),
		       argsDeclaration => $argsDeclaration,
		       documentation => $documentation
		      });

    return $self;
}

#--------------------------------------------------------------------------------

sub run {
  my ($self) = @_;

  my $mercatorDir = $self->getArg('mercatorDir');

  opendir(DIR,"$mercatorDir") or $self-error("Could not open directory $mercatorDir\n");

  foreach my $subdir (readdir DIR){
  
      next if ($subdir eq '.') or ($subdir eq '..');

      my ($file, $seqTableA, $seqTableB, $specA, $specB, $syntenySpec, $agpFile) = $self->readConfigFile("$mercatorDir/$subdir/config.txt");

      my(@extDbRlsIdA, @extDbRlsIdB);

      foreach my $extDbRlsSpecA (@{$specA}){
	  push(@extDbRlsIdA,$self->getExtDbRlsId($extDbRlsSpecA));
      }
      my $extDbRlsIdA = join(",",@extDbRlsIdA);
      
      foreach my $extDbRlsSpecB (@{$specB}){
	  push(@extDbRlsIdB,$self->getExtDbRlsId($extDbRlsSpecB));
      }
      my $extDbRlsIdB = join(",",@extDbRlsIdB);
      
      my $synDbRlsId = $self->getExtDbRlsId($syntenySpec);
      
      my $count = 0;

      open(IN, "<$file") or $self->error("Couldn't open file '$file': $!\n");

      while (<IN>) {
	  chomp;

	  $self->_handleSyntenySpan($_, $extDbRlsIdA, $extDbRlsIdB, $synDbRlsId,$seqTableA,$seqTableB);
	  $count++;

	  if($count && $count % 500 == 0) {
	      $self->log("Read $count lines... Inserted " . $count*2 . " ApiDB::Synteny");
	  }

	  $self->undefPointerCache();
      }
      close(IN);

      $self->insertAnchors($synDbRlsId, $extDbRlsIdA);
      $self->insertAnchors($synDbRlsId, $extDbRlsIdB);

      my $anchorCount = $self->getAnchorCount();

      $self->log("inserted $count synteny spans and $anchorCount anchors ");
  }
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
  my ($self, $line, $extDbRlsIdA, $extDbRlsIdB, $synDbRlsId,$seqTableA,$seqTableB) = @_;

  my ($a_id, $b_id,
      $a_start, $a_len,
      $b_start, $b_len,
      $strand) = split(" ", $line);

  my $a_pk = $self->getNaSequenceId($a_id, $extDbRlsIdA, $seqTableA);
  my $b_pk = $self->getNaSequenceId($b_id, $extDbRlsIdB, $seqTableB);

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
  $synteny->submit();

  return $synteny;
}

#--------------------------------------------------------------------------------

sub getNaSequenceId {
  my ($self, $sourceId, $extDbRlsId, $seqTable) = @_;

  my $dbh = $self->getQueryHandle();

  my $sql = "SELECT na_sequence_id FROM $seqTable
             WHERE  source_id = ? AND external_database_release_id IN ($extDbRlsId)";

  my $sh = $dbh->prepare($sql);

  my @ids = $self->sqlAsArray( Handle => $sh, Bind => [$sourceId] );


  if(scalar @ids != 1) {
    $self->error("Sql Should return only one value: $sql\n for values: $sourceId and $extDbRlsId");
  }
  return $ids[0];
}

#--------------------------------------------------------------------------------

sub insertAnchors {
  my ($self, $synDbRlsId, $extDbRlsIdA, $extDbSpec) = @_;

  my $algorithmInvocation = $self->getAlgInvocation();
  my $algorithmInvocationId = $algorithmInvocation->getId();

  $self->log("Inserting anchors, with '$extDbSpec' as reference");

  my ($gene2orthologGroup, $orthologGroup2refGenes)
    = $self->findOrthologGroups($extDbRlsIdA);

  my $genesLocStmt = $self->prepareGenesLocStmt();

  my $retrieveSyntenySql = "
select syn.*
from apidb.Synteny syn, dots.NaSequence seq
where syn.external_database_release_id = $synDbRlsId
and seq.na_sequence_id = syn.a_na_sequence_id
and seq.external_database_release_id IN ($extDbRlsIdA)
and syn.row_alg_invocation_id = $algorithmInvocationId
";


  my $syntenyStmt = $self->getDbHandle()->prepareAndExecute($retrieveSyntenySql);

  while(my $syntenyRow = $syntenyStmt->fetchrow_hashref) {

    my $refGenes = $self->findGenes($genesLocStmt,
				    $syntenyRow->{A_NA_SEQUENCE_ID},
				    $syntenyRow->{A_START},
				    $syntenyRow->{A_END});

    my $synGenes = $self->findGenes($genesLocStmt,
				    $syntenyRow->{B_NA_SEQUENCE_ID},
				    $syntenyRow->{B_START},
				    $syntenyRow->{B_END});

    # ordered by refGene loc
    my $genePairs = $self->findOrthologPairs($refGenes, $synGenes,
					     $gene2orthologGroup,
					     $orthologGroup2refGenes);

    my $syntenyObj = GUS::Model::ApiDB::Synteny->new({synteny_id => $syntenyRow->{SYNTENY_ID}});
    $syntenyObj->retrieveFromDB();

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

  my $sql = "select na_feature_id, start_min, end_max
from apidb.FEATURELOCATION
where feature_type = 'GeneFeature'
and na_sequence_id = ?
and start_min > ?
and end_max < ?";

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
  my ($self, $extDbRlsIdA) = @_;

my $sql;



if($self->getArg('organism') eq 'PlasmoDB' || $self->getArg('organism') eq 'TriTrypDB' || $self->getArg('organism') eq 'ToxoDB'|| $self->getArg('organism') eq 'GiardiaDB' ||$self->getArg('organism') eq 'AmoebaDB'||$self->getArg('organism') eq 'MicrosporidiaDB'){
    $sql = "
    select ga.na_feature_id as sequence_id, ga.orthomcl_name as sequence_group_id, gf.external_database_release_id
    from apidb.geneattributes ga, dots.genefeature gf
    where ga.na_feature_id = gf.na_feature_id
    ";
  }elsif($self->getArg('organism') eq 'CryptoDB'){
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
  }


  my $stmt = $self->getDbHandle()->prepareAndExecute($sql);

  my $gene2orthologGroup = {};
  my $orthologGroup2refGenes = {};
  while (my ($geneFeatId, $ssgId, $extDbRlsId) = $stmt->fetchrow_array()) {
     $gene2orthologGroup->{$geneFeatId} = $ssgId;
     if ($extDbRlsId = $extDbRlsIdA) {
       $orthologGroup2refGenes->{$ssgId}->{$geneFeatId} = 1;
     }
  }
  return ($gene2orthologGroup, $orthologGroup2refGenes);
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
  my ($self, $refGenes, $synGenes, $gene2orthologGroup, $orthologGroup2refGenes) = @_;

  my @genePairs;
  foreach my $synGene (@$synGenes) {
    my $ssgId = $gene2orthologGroup->{$synGene->{id}};

    foreach my $refGene (@$refGenes) {
      my $geneFeatureId = $refGene->{id};

      if ($orthologGroup2refGenes->{$ssgId}->{$geneFeatureId}) {
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


sub readConfigFile {
  my ($self,$configFile) = @_;

  my ($inFile, $seqTableA, $seqTableB, $specA, $specB, $syntenySpec, $agpFile);
  open(CONFIG_FILE, $configFile);


  while (<CONFIG_FILE>) {
    chomp;
    my ($tag,$values) = split(/=/, $_);

    $values =~ s/^\s+//;
    $values =~ s/\s+$//;

    $tag =~ s/^\s+//;
    $tag =~ s/\s+$//;

    if($tag eq "inputFile"){
	$inFile = $values;
    }

    if($tag eq "seqTableA"){
	$seqTableA = $values;
    }


    if($tag eq "seqTableB"){
	$seqTableB = $values;
    }


    if($tag eq "extDbSpecA"){

        my @values = split(/\|\|/,$values);
	$seqTableA = \@values;
    }

    if($tag eq "extDbSpecB"){

        my @values = split(/\|\|/,$values);
	$seqTableB = \@values;
    }

    if($tag eq "syntenySpec"){
	$syntenySpec = $values;
    }

    if($tag eq "agpFile"){
	$agpFile = $values;
    }


  }
  close(CONFIG_FILE);

  return($inFile, $seqTableA, $seqTableB, $specA, $specB, $syntenySpec, $agpFile);

}

1;
