
package ApiCommonData::Load::Plugin::InsertSyntenySpans;
@ISA = qw( GUS::PluginMgr::Plugin);

use strict;

use GUS::PluginMgr::Plugin;

use GUS::Model::DoTS::NASequence;

use GUS::Model::ApiDB::Synteny;
use GUS::Model::ApiDB::SyntenyAnchor;

use CBIL::Util::V;

use GUS::Supported::Util;

use File::Temp;
use File::Basename;

use Bio::Coordinate::Pair;
use Bio::Location::Simple;

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


   fileArg({ name           => 'gffFileA',
	     descr          => 'gff file for exon locations which was input to mercator',
	     reqd           => 1,
	     mustExist      => 1,
	     format         => 'gff',
	     constraintFunc => undef,
	     isList         => 0,
	   }),

   fileArg({ name           => 'gffFileB',
	     descr          => 'gff file for exon locations which was input to mercator',
	     reqd           => 1,
	     mustExist      => 1,
	     format         => 'gff',
	     constraintFunc => undef,
	     isList         => 0,
	   }),

     stringArg({ name => 'gffVersion',
                 descr => '[1,2,3]',
                 constraintFunc=> undef,
                 isList => 0,
                 reqd => 0,
                 default => 3,
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

#--------------------------------------------------------------------------------

sub setGeneLocations {$_[0]->{_gene_locations} = $_[1]}
sub getGeneLocations {$_[0]->{_gene_locations}}

sub getAgpCoords {$_[0]->{_agp_coords}}

#--------------------------------------------------------------------------------

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

  my $geneLocations = $self->readGeneLocationsFromGFFs();
  $self->setGeneLocations($geneLocations);

  my $file = $self->getArg('inputFile');

  my $dirname = dirname($file);
  my $basename = basename($file);
  $basename =~ s/\.align-synteny//;
  my $alignDir = "$dirname/alignments";

  unless(-d $alignDir) {
    $self->userError("Input Directory must contain alignments sub directory");
  }

  my ($organismAbbrevB, $organismAbbrevA) = split(/-/, $basename);
  my $orgAAgp = "$dirname/$organismAbbrevA.agp";
  my $orgBAgp = "$dirname/$organismAbbrevB.agp";

  $self->addCoordPairs($orgAAgp, $organismAbbrevA);
  $self->addCoordPairs($orgBAgp, $organismAbbrevB);

  my $synDbRlsId = $self->getExtDbRlsId($self->getArg('syntenyDbRlsSpec'));

  my $count = 0;

  open(IN, "<$file") or $self->error("Couldn't open file '$file': $!\n");

  my (@synA, @synB);

  while (<IN>) {
    chomp;

    my ($synA, $synB) = $self->_handleSyntenySpan($_, $synDbRlsId, $organismAbbrevA, $organismAbbrevB, $alignDir);

    # 2 Synteny rows each
    $count = $count + 2;

    if($count && $count % 500 == 0) {
      $self->log("Read $count lines... Inserted " . $count*2 . " ApiDB::Synteny");
    }

    $self->undefPointerCache();
  }
  close(IN);

  my $anchorCount = $self->getAnchorCount();

  return "inserted $count synteny spans and $anchorCount anchors ";
}

#--------------------------------------------------------------------------------

sub addCoordPairs {
  my ($self, $agp, $organismAbbrev) = @_;

  open(AGP, $agp) or $self->error("Could not open file $agp for reading: $!");

  while(<AGP>) {
    chomp;
    my @a = split(/\t/, $_);

    next if($a[4] eq 'N');

    my $ctg = Bio::Location::Simple->new( -seq_id => $a[5],
                                          -start => $a[6], 
                                          -end =>  $a[7],
                                          -strand => $a[8] eq '-' ? -1 : +1,
        );


    my $assem = Bio::Location::Simple->new( -seq_id =>  $a[0],
                                             -start => $a[1],
                                             -end =>  $a[2],
                                             -strand => '+1' ,
        );
    
    my $agp = Bio::Coordinate::Pair->new( -in  => $assem, -out => $ctg );

    push @{$self->{_agp_coords}->{$organismAbbrev}}, $agp;
  }

  close AGP;
}

#--------------------------------------------------------------------------------

sub readGeneLocationsFromGFFs {
  my ($self) = @_;

  my $gffFileA = $self->getArg('gffFileA');
  my $gffFileB = $self->getArg('gffFileB');

  my $gffVersion = $self->getArg('gffVersion');

  my $allFeatureLocations = {};
  GUS::Supported::Util::addGffFeatures($allFeatureLocations, $gffFileA, $gffVersion);
  GUS::Supported::Util::addGffFeatures($allFeatureLocations, $gffFileB, $gffVersion);

  my $geneLocations = {};
  foreach my $seqId (keys %$allFeatureLocations) {
    foreach my $gene (keys %{$allFeatureLocations->{$seqId}}) {
      foreach my $strand (keys %{$allFeatureLocations->{$seqId}->{$gene}}) {
        my $min = CBIL::Util::V::min(@{$allFeatureLocations->{$seqId}->{$gene}->{$strand}});
        my $max = CBIL::Util::V::max(@{$allFeatureLocations->{$seqId}->{$gene}->{$strand}});

        push @{$geneLocations->{$seqId}}, {gene => $gene,
                                           min => $min,
                                           max => $max,
                                          };
      }
    }
  }

  return $geneLocations;
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
  my ($self, $line, $synDbRlsId, $organismAbbrevA, $organismAbbrevB, $alignDir) = @_;

  print STDERR "ORGA=$organismAbbrevA\n";
  print STDERR "ORGB=$organismAbbrevB\n";

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

  my @sortedGeneLocations = sort {$a->{min} <=> $b->{min}}  @{$self->findGenes($a_pk, $a_start, $a_end)};

  my $fh = File::Temp->new();
  my $filename = $fh->filename();

  foreach my $loc (@sortedGeneLocations) {
    my $min = $loc->{min};
    my $max = $loc->{max};

    print $fh "$a_id $min $max +\n";
#    print  "$a_id $min $max +\n";
  }

  print STDERR "cat $filename|sliceAlignment $alignDir $organismAbbrevA 2>/dev/null|grep '>'\n";

  my @output = `cat $filename|sliceAlignment $alignDir $organismAbbrevA 2>/dev/null|grep '>'`;

  my @pairsA;
  my @pairsB;
  my ($locA, $locB);

  foreach my $line(@output) {
    chomp $line;
    next if($line =~ /Interval not in map/);

    if($line =~  /$organismAbbrevA/) {
      $locA = $self->getSliceAlignLineLocation($line, $organismAbbrevA);
    }
    if($line =~ /$organismAbbrevB/) {
      $locB = $self->getSliceAlignLineLocation($line, $organismAbbrevB);
    }

    unless($locA && $locB) {
      next;
    }

    push @pairsA, [$locA->{a},$locB->{a} ];
    push @pairsA, [$locA->{b},$locB->{b} ];

    push @pairsB, [$locB->{a},$locA->{a} ];
    push @pairsB, [$locB->{b},$locA->{b} ];

    $locA = undef;
    $locB = undef;
  }

  
  my @sortedPairsA = sort {$a->[0] <=> $b->[0] } @pairsA;
  $self->createSyntenyAnchors($synteny, \@sortedPairsA);  

  my @sortedPairsB = sort {$a->[0] <=> $b->[0] } @pairsB;
  $self->createSyntenyAnchors($reverse, \@sortedPairsB);  

  return($synteny, $reverse);
}


#--------------------------------------------------------------------------------

sub getSliceAlignLineLocation {
  my ($self, $line, $expectGenome) = @_;

  if($line eq ">$expectGenome") {
    return;
  }

  my ($genome, $contig, $start, $end, $strand) = $line =~ />([a-zA-Z0-9_]+) (\S*?):(\d+)-(\d+)([-+])/;

  if($genome ne $expectGenome) {
    print STDERR "Genome [$genome] does not match [$expectGenome] for line:  $line\n";
    $self->error("error reading output from sliceAlign");
  }

  my $agpLocations = $self->getAgpCoords();
  my ($rv, $count);

  foreach my $agp (@{$agpLocations->{$genome}}) {
    my $assemStart = $agp->in()->start();
    my $assemEnd = $agp->in()->end();
    my $assemSeqId = $agp->in()->seq_id();

    if($contig eq $assemSeqId && $start >= $assemStart && $end <= $assemEnd) {

      my $matchOnAssem = Bio::Location::Simple->
          new( -seq_id => 'hit', -start =>   $start, -end =>  $end, -strand => +1 );

      my $matchOnContig = $agp->map($matchOnAssem);
      $rv = {a => $matchOnContig->start(), b => $matchOnContig->end()};


      $count++;
    }
  }

  if($count != 1) {
    $self->error("could not find agp row containing $genome");
  }

  return $rv;
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
              and so.term_name in ('random_sequence','supercontig','chromosome','contig','mitochondrial_chromosome','apicoplast_chromosome')";

  my $sh = $dbh->prepare($sql);

  my @ids = $self->sqlAsArray( Handle => $sh, Bind => [$sourceId] );


  if(scalar @ids != 1) {
    $self->error("Sql Should return only one value: $sql\n for values: $sourceId");
  }

  $self->{_nasequence_source_ids}->{$ids[0]} = $sourceId;

  return $ids[0];
}

#--------------------------------------------------------------------------------

sub insertAnchors {
  my ($self, $synRows) = @_;

  my $gene2orthologGroup = $self->findOrthologGroups();

  foreach my $syntenyObj (@$synRows) {

    my $refGenes = $self->findGenes($syntenyObj->getANaSequenceId(),
				    $syntenyObj->getAStart(),
				    $syntenyObj->getAEnd()
                                    );

    my $synGenes = $self->findGenes($syntenyObj->getBNaSequenceId(),
				    $syntenyObj->getBStart(),
				    $syntenyObj->getBEnd()
                                   );

    my $pairs = $self->findAnchorPairs($refGenes, $synGenes,
                                       $gene2orthologGroup, $syntenyObj);


    $self->createSyntenyAnchors($syntenyObj, $pairs);

    $syntenyObj->submit();
    $self->undefPointerCache();
  }
  return 1;
}

#--------------------------------------------------------------------------------

sub createSyntenyAnchors {
  my ($self, $syntenyObj, $sortedPairs) = @_;

  my @sortedPairs = @$sortedPairs;


  my $prevRefLoc = -9999999999;
  my $lastRefLoc = 9999999999;

  for(my $i = 0; $i < scalar @sortedPairs; $i++) {
    my $nextRefLoc;
    if($i == scalar(@sortedPairs) - 1) {
      $nextRefLoc = $lastRefLoc;
    }
    else {
      $nextRefLoc = $sortedPairs[$i+1]->[0];
    }

    my $refLoc = $sortedPairs[$i]->[0];
    my $synLoc = $sortedPairs[$i]->[1];

    my $anchor = {prev_ref_loc=> $prevRefLoc,
                  ref_loc=> $refLoc,
                  next_ref_loc=> $nextRefLoc,
                  syntenic_loc=> $synLoc
                 };

    $self->addAnchorToGusObj($anchor, $syntenyObj);

    $prevRefLoc = $refLoc;
  }

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

my $sql = "select g.source_id as sequence_id, to_char(ssg.group_id) as sequence_group_id, g.external_database_release_id
    from apidb.CHROMOSOME6ORTHOLOGY ssg, dots.genefeature g
    where g.source_id = ssg.source_id
    UNION
    select g.source_id, to_char(ssg.sequence_group_id), g.external_database_release_id
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
  my ($self, $na_sequence_id, $start, $end) = @_;

  my $seqId = $self->{_nasequence_source_ids}->{$na_sequence_id};
  my $allLocations = $self->getGeneLocations();

  my @genes;

  foreach my $geneLocation (@{$allLocations->{$seqId}}) {
    if($geneLocation->{min} > $start && $geneLocation->{max} < $end) {
      push @genes, $geneLocation;
    }
  }

  return \@genes;
}

#--------------------------------------------------------------------------------

=item I<findAnchorPairs>

B<Parameters:>

 $self(_PACKAGE_)
 $refGenes(ARRAYREF): ARRAYREF, Each element is a hash of genes (id, start, end)
 $synGenes(HASHREF): ARRAYREF, Each element is a hash of genes (id, start, end)
 $gene2orthologGroup(HASHREF): na_feature_id to SequenceSequenceGroup sequence_group_id
 $orthologGroup2refGenes(HASHREF): second tracks which na_feature_ids are from the reference.

B<Return Type:> ARRAYREF

 ArrayRef of GenePairs for a Syntenic Region.  Each pair is a hash with keys: refStart, synStart, refEnd, synEnd

=cut

sub findAnchorPairs {
  my ($self, $refGenes, $synGenes, $gene2orthologGroup, $syntenyObj) = @_;

  my $genePairsHashRef = {};
  foreach my $synGene (@$synGenes) {
    my $ssgId = $gene2orthologGroup->{$synGene->{gene}};
    next unless($ssgId);

    foreach my $refGene (@$refGenes) {
      my $ssgIdRef = $gene2orthologGroup->{$refGene->{gene}};

      if ($ssgId eq $ssgIdRef) {
        push @{$genePairsHashRef->{start}->{$refGene->{min}}}, ($synGene->{min}, $synGene->{max});
        push @{$genePairsHashRef->{end}->{$refGene->{max}}}, ($synGene->{min}, $synGene->{max});
      }
    }
  }

  my @pairs;

  foreach my $refStart (keys %{$genePairsHashRef->{start}}) {
    my $synStart;
    if($syntenyObj->getIsReversed()) {
      $synStart = CBIL::Util::V::max(@{$genePairsHashRef->{start}->{$refStart}});
    }
    else {
      $synStart = CBIL::Util::V::min(@{$genePairsHashRef->{start}->{$refStart}});
    }
    push @pairs, [$refStart,$synStart];
  }

  foreach my $refEnd (keys %{$genePairsHashRef->{end}}) {
    my $synEnd;
    if($syntenyObj->getIsReversed()) {
      $synEnd = CBIL::Util::V::min(@{$genePairsHashRef->{end}->{$refEnd}});
    }
    else {
      $synEnd = CBIL::Util::V::max(@{$genePairsHashRef->{end}->{$refEnd}});
    }
    push @pairs, [$refEnd,$synEnd];
  }

  if($syntenyObj->getIsReversed()) {
    push @pairs, [$syntenyObj->getAStart(), $syntenyObj->getBEnd()];
    push @pairs, [$syntenyObj->getAEnd(), $syntenyObj->getBStart()];
  }
  else {
    push @pairs, [$syntenyObj->getAStart(), $syntenyObj->getBStart()];
    push @pairs, [$syntenyObj->getAEnd(), $syntenyObj->getBEnd()];
  }

  return \@pairs;
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
