package ApiCommonData::Load::Plugin::InsertSyntenySpans;
@ISA = qw( GUS::PluginMgr::Plugin);

use strict;

use GUS::PluginMgr::Plugin;

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

   stringArg({name => 'seqTableA',
	      descr => 'where do we find sequence A',
	      constraintFunc => undef,
	      reqd => 1,
	      isList => 0
	     }),

   stringArg({name => 'seqTableB',
	      descr => 'where do we find sequence B',
	      constraintFunc => undef,
	      reqd => 1,
	      isList => 0
	     }),

   stringArg({name => 'extDbRlsSpecA',
	      descr => 'where do we find source_id\'s from sequence A',
	      constraintFunc => undef,
	      reqd => 1,
	      isList => 0
	     }),

   stringArg({name => 'extDbRlsSpecB',
	      descr => 'where do we find source_id\'s from sequence A',
	      constraintFunc => undef,
	      reqd => 1,
	      isList => 0
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

    $self->initialize({requiredDbVersion => 3.5,
		       cvsRevision => '$Revision$', # cvs fills this in!
		       name => ref($self),
		       argsDeclaration => $argsDeclaration,
		       documentation => $documentation
		      });

    return $self;
}

sub run {
  my ($self) = @_;

  my $file = $self->getArg('inputFile');

  my $extDbRlsIdA = $self->getExtDbRlsId($self->getArg('extDbRlsSpecA'));

  my $extDbRlsIdB = $self->getExtDbRlsId($self->getArg('extDbRlsSpecB'));

  my $synDbRlsId = $self->getExtDbRlsId($self->getArg('syntenyDbRlsSpec'));

  my $count = 0;

  open(IN, "<$file") or $self->error("Couldn't open file '$file': $!\n");
  while (<IN>) {
    chomp;
    $self->_handleSyntenySpan($_, $extDbRlsIdA, $extDbRlsIdB, $synDbRlsId);
    $count+=2;
  }
  close(IN);

  my $anchorCount = $self->insertAnchors($synDbRlsId, $extDbRlsIdA,
					 $self->getArg('extDbRlsSpecA'));
  $anchorCount += $self->insertAnchors($synDbRlsId, $extDbRlsIdB,
				       $self->getArg('extDbRlsSpecB'));
  return "inserted $count synteny spans and $anchorCount anchors ";
}

sub _handleSyntenySpan {
  my ($self, $line, $extDbRlsIdA, $extDbRlsIdB, $synDbRlsId) = @_;

  my ($a_id, $b_id,
      $a_start, $a_len,
      $b_start, $b_len,
      $strand) = split(" ", $line);

  my ($a_pk) = $self->getQueryHandle()->selectrow_array(<<EOSQL, undef, $a_id, $extDbRlsIdA);
  SELECT na_sequence_id
  FROM   @{[$self->getArg('seqTableA')]}
  WHERE  source_id = ?
    AND  external_database_release_id = ?  
EOSQL
  $self->error("Couldn't find primary key for $a_id\n") unless $a_pk;
  
  my ($b_pk) = $self->getQueryHandle()->selectrow_array(<<EOSQL, undef, $b_id, $extDbRlsIdB);
  SELECT na_sequence_id
  FROM   @{[$self->getArg('seqTableB')]}
  WHERE  source_id = ?
    AND  external_database_release_id = ?  
EOSQL
  $self->error("Couldn't find primary key for $b_id\n") unless $b_pk;
  
  my $synteny = GUS::Model::ApiDB::Synteny->new({ a_na_sequence_id => $a_pk,
						  b_na_sequence_id => $b_pk,
						  a_start => $a_start,
						  b_start => $b_start,
						  a_end   => $a_start + $a_len - 1,
						  b_end   => $b_start + $b_len - 1,
						  is_reversed => $strand eq "-",
						  external_database_release_id => $synDbRlsId,
						});
  $synteny->submit();

  # add row w/ opposite organism as ref
  my $synteny = GUS::Model::ApiDB::Synteny->new({ a_na_sequence_id => $b_pk,
						  b_na_sequence_id => $a_pk,
						  a_start => $b_start,
						  b_start => $a_start,
						  a_end   => $b_start + $b_len - 1,
						  b_end   => $a_start + $a_len - 1,
						  is_reversed => $strand eq "-",
						  external_database_release_id => $synDbRlsId,
						});
  $synteny->submit();
  $self->undefPointerCache();
}

sub insertAnchors {
  my ($self, $synDbRlsId, $extDbRlsIdA, $extDbSpec) = @_;

  $self->log("Inserting anchors, with '$extDbSpec' as reference");

  my ($gene2orthologGroup, $orthologGroup2refGenes)
    = $self->findOrthologGroups($extDbRlsIdA);

  my $findGenesStmt = $self->getFindGenesStmt();

  my $sql = "
select syn.*
from apidb.Synteny syn, dots.ExternalNaSequence seq
where syn.external_database_release_id = $synDbRlsId
and seq.na_sequence_id = syn.a_na_sequence_id
and seq.external_database_release_id = $extDbRlsIdA
";

  my $stmt = $self->getQueryHandle()->prepareAndExecute($sql);

  my $anchorCount = 0;

  while(my $syntenyRow = $stmt->fetchrow_hashref) {
  my $rev = $syntenyRow->{IS_REVERSED};

    my $refGenes = $self->findGenes($findGenesStmt,
				    $syntenyRow->{A_NA_SEQUENCE_ID},
				    $syntenyRow->{A_START},
				    $syntenyRow->{A_END});

    my $synGenes = $self->findGenes($findGenesStmt,
				    $syntenyRow->{B_NA_SEQUENCE_ID},
				    $syntenyRow->{B_START},
				    $syntenyRow->{B_END});

    # ordered by refGene loc
    my $genePairs = $self->findOrthologPairs($refGenes, $synGenes,
					     $gene2orthologGroup,
					     $orthologGroup2refGenes);

    my $syntenyObj = 
      GUS::Model::ApiDB::Synteny->new({synteny_id => $syntenyRow->{SYNTENY_ID}});

    $syntenyObj->retrieveFromDB();

    my $anchors = [];

    my $anchorsCursor = 0;

    $anchorCount += $self->addAnchor($syntenyObj,
				     $syntenyRow->{A_START},
				     $syntenyRow->{$rev? 'B_END':'B_START'},
				     $anchors, $anchorsCursor++,
				     $anchorCount,
				     0);

    foreach my $genePair (@$genePairs) {

      if ($genePair->{refStart} > $syntenyRow->{A_START}) {
	$anchorCount += $self->addAnchor($syntenyObj, 
					 $genePair->{refStart},
					 $genePair->{$rev? 'synEnd':'synStart'},
					 $anchors, $anchorsCursor++,
					 $anchorCount,
					 0);
      }

      if ($genePair->{refEnd} < $syntenyRow->{A_END}) {
	$anchorCount += $self->addAnchor($syntenyObj,
					 $genePair->{refEnd},
					 $genePair->{$rev? 'synStart':'synEnd'},
					 $anchors, $anchorsCursor++,
					 $anchorCount,
					 0);
      }
    }

    $anchorCount += $self->addAnchor($syntenyObj,
				     $syntenyRow->{A_END},
				     $syntenyRow->{$rev? 'B_START':'B_END'},
				     $anchors, $anchorsCursor++,
				     $anchorCount,
				     1);

    $syntenyObj->submit();
    $self->undefPointerCache();exit;
  }
  return $anchorCount;
}

sub getFindGenesStmt {
  my ($self) = @_;

  my $sql = "
select g.na_feature_id, l.start_min, l.end_max
from dots.GeneFeature g, dots.NaLocation l
where g.na_sequence_id = ?
and l.na_feature_id = g.na_feature_id
and l.end_max > ?
and l.start_min < ?
";
  return $self->getQueryHandle()->prepare($sql);
}

sub findOrthologGroups {
  my ($self, $extDbRlsIdA) = @_;

my $sql = "
select ssg.sequence_id, ssg.sequence_group_id, g.external_database_release_id
from dots.SequenceSequenceGroup ssg, dots.genefeature g
where g.na_feature_id = ssg.sequence_id
";
  my $stmt = $self->getQueryHandle()->prepareAndExecute($sql);

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

sub findGenes {
  my ($self, $stmt, $na_sequence_id, $start, $end) = @_;

  $stmt->execute($na_sequence_id, $start, $end);

  my @genes;
  while (my ($naFeatId, $geneStart, $geneEnd) = $stmt->fetchrow_array()) {
    push(@genes, {id=>$naFeatId, start=>$geneStart, end=>$geneEnd});
  }
  return \@genes;
}

# each pair is a hash, with these keys:
#  refStart
#  synStart 
#  refEnd
#  synEnd
sub findOrthologPairs {
  my ($self, $refGenes, $synGenes, $gene2orthologGroup, $orthologGroup2refGenes) = @_;

  my @genePairs;
  foreach my $synGene (@$synGenes) {
    my $ssgId = $gene2orthologGroup->{$synGene->{id}};
    foreach my $refGene (@$refGenes) {
      if ($orthologGroup2refGenes->{$ssgId}->{$refGene->{id}}) {
	my $genePair = {refStart=>$refGene->{start},
			refEnd=>$refGene->{end},
			synStart=>$synGene->{start},
			synEnd=>$synGene->{end}};
	push(@genePairs, $genePair);
      }
    }
  }
  my @sortedPairs = sort {$a->{refStart} <=> $b->{refStart}} @genePairs;

  return \@sortedPairs;
}

sub addAnchor {
  my ($self, $syntenyObj, $refLoc, $synLoc, $anchors, $anchorsCursor, $anchorCount, $addFinalToo) = @_;

  $anchors->[$anchorsCursor] = {prev_ref_loc=> -9999999999,
				ref_loc=> $refLoc,
				next_ref_loc=> 9999999999,
				syntenic_loc=> $synLoc};

  my $prevAnchor = $anchors->[$anchorsCursor - 1];
  my $anchor = $anchors->[$anchorsCursor];

  if ($anchorsCursor > 0) {
    $prevAnchor->{next_ref_loc} = $refLoc;
    $anchor->{prev_ref_loc} = $prevAnchor->{ref_loc};
    $self->addAnchorToGusObj($prevAnchor, $syntenyObj, $anchorCount);

    if ($addFinalToo) {
      $self->addAnchorToGusObj($anchor, $syntenyObj, $anchorCount + 1);
      return 2;
    }
    return 1;
  }

  return 0;
}

sub addAnchorToGusObj {
  my ($self, $anchor, $syntenyObj, $anchorCount) = @_;

  my $anchorObj = GUS::Model::ApiDB::SyntenyAnchor->new($anchor);
  $syntenyObj->addChild($anchorObj);
  $self->log("added $anchorCount anchors")
    if ($anchorCount && $anchorCount % 1000 == 0);
}

sub undoTables {
  return qw(ApiDB.Synteny ApiDB.SyntenyAnchor);
}

1;
