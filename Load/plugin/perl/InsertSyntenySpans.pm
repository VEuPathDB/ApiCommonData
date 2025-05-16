package ApiCommonData::Load::Plugin::InsertSyntenySpans;
@ISA = qw( GUS::PluginMgr::Plugin);

use strict;

use GUS::PluginMgr::Plugin;

use GUS::Model::DoTS::NASequence;

use ApiCommonData::Load::Fifo;
use ApiCommonData::Load::Psql;

use GUS::Model::ApiDB::Synteny;
use GUS::Model::ApiDB::Synteny_Table;

use GUS::Model::ApiDB::SyntenicGene;
use GUS::Model::ApiDB::SyntenicGene_Table;

#use CBIL::Util::V;
use POSIX qw(strftime);

use GUS::Supported::Util;

use File::Temp;
use File::Basename;

use Bio::Coordinate::Pair;
use Bio::Location::Simple;

use POSIX;

use Data::Dumper;

my $argsDeclaration = 
  [
   fileArg({ name           => 'inputDirectory',
	     descr          => 'directory for mercator results',
	     reqd           => 1,
	     mustExist      => 0,
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

   fileArg({ name           => 'outputSyntenyDatFile',
             descr          => '',
             reqd           => 0,
             mustExist      => 0,
             format         => 'custom',
             constraintFunc => undef,
             isList         => 0,
           }),

   # fileArg({ name           => 'outputSyntenyCtrlFile',
   #           descr          => '',
   #           reqd           => 0,
   #           mustExist      => 0,
   #           format         => 'custom',
   #           constraintFunc => undef,
   #           isList         => 0,
   #         }),
   fileArg({ name           => 'outputSyntenicGeneDatFile',
             descr          => '',
             reqd           => 0,
             mustExist      => 0,
             format         => 'custom',
             constraintFunc => undef,
             isList         => 0,
           }),
   # fileArg({ name           => 'outputSyntenicGeneCtrlFile',
   #           descr          => '',
   #           reqd           => 0,
   #           mustExist      => 0,
   #           format         => 'custom',
   #           constraintFunc => undef,
   #           isList         => 0,
   #         }),

booleanArg({name => 'loadWithPsql',
       descr => 'write files for sqlloader',
       constraintFunc=> undef,
       reqd  => 0,
       isList => 0,
       default => 0,
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

sub setOutputFileHandles {$_[0]->{_output_file_handles} = $_[1]}
sub getOutputFileHandles {$_[0]->{_output_file_handles}}

sub getAgpCoords {$_[0]->{_agp_coords}}


sub setSyntenyFields {$_[0]->{_synteny_fields} = $_[1]}
sub getSyntenyFields {$_[0]->{_synteny_fields} }

sub setSyntenicGeneFields {$_[0]->{_syntenic_gene_fields} = $_[1]}
sub getSyntenicGeneFields {$_[0]->{_syntenic_gene_fields} }


#--------------------------------------------------------------------------------

sub new {
    my ($class) = @_;
    my $self = {};
    bless($self,$class);

    $self->initialize({requiredDbVersion => 4.0,
		       cvsRevision => '$Revision$', # cvs fills this in!
		       name => ref($self),
		       argsDeclaration => $argsDeclaration,
		       documentation => $documentation
		      });

    return $self;
}

#--------------------------------------------------------------------------------

sub error {
  my ($self, $msg) = @_;
  print STDERR "\nERROR: $msg\n";

  foreach my $pid (@{$self->getActiveForkedProcesses()}) {
    kill(9, $pid);
  }

  $self->SUPER::error($msg);
}

sub getActiveForkedProcesses {
  my ($self) = @_;

  return $self->{_active_forked_processes} || [];
}

sub addActiveForkedProcess {
  my ($self, $pid) = @_;

  push @{$self->{_active_forked_processes}}, $pid;
}


sub run {
  my ($self) = @_;

  my $dbiDb = $self->getDb();
  $dbiDb->setMaximumNumberOfObjects(100000);

  my $dirname = $self->getArg('inputDirectory');

  my ($sdat, $sgdat);

  my ($syntenyFifo,$syntenicGeneFifo);
  
  if($self->getArg('loadWithPsql')) {

    $self->setPsqlLogin();
    $self->setPsqlPassword();
    $self->setPsqlHostname();
    $self->setPsqlDatabase();
    $self->setModificationDate();

    my $syntenyDatFile = $self->getArg('outputSyntenyDatFile');
    my $syntenicGeneDatFile = $self->getArg('outputSyntenicGeneDatFile');

    
    $syntenyFifo = ApiCommonData::Load::Fifo->new($syntenyDatFile);
    my $syntenyTable = GUS::Model::ApiDB::Synteny_Table->new();
    my $syntenyPsqlObj = $self->makePsqlObj('ApiDB.Synteny', $syntenyDatFile, $syntenyTable->getAttributeList());
    my $syntenyPsqlProcessString = $syntenyPsqlObj->getCommandLine();
    my $syntenyPsqlPid = $syntenyFifo->attachReader($syntenyPsqlProcessString);


    print "syntenyPsqlPid=$syntenyPsqlPid\n";
    $self->addActiveForkedProcess($syntenyPsqlPid);
    $syntenicGeneFifo = ApiCommonData::Load::Fifo->new($syntenicGeneDatFile);
    my $syntenicGeneTable = GUS::Model::ApiDB::SyntenicGene_Table->new();
    my $syntenicGenePsqlObj = $self->makePsqlObj('ApiDB.SyntenicGene', $syntenicGeneDatFile, $syntenicGeneTable->getAttributeList());
    my $syntenicGenePsqlProcessString = $syntenicGenePsqlObj->getCommandLine();
    my $syntenicGenePsqlPid = $syntenicGeneFifo->attachReader($syntenicGenePsqlProcessString);       
    $self->addActiveForkedProcess($syntenicGenePsqlPid);

    my %fileHandles;
    $fileHandles{'synteny.dat'} = $syntenyFifo->attachWriter();
    $fileHandles{'syntenic_gene.dat'} = $syntenicGeneFifo->attachWriter();
    $self->setOutputFileHandles(\%fileHandles);
  }

  my $alignDir = "$dirname/alignments";
  my $genomesFile = "$alignDir/genomes";
  my $mapFile = "$alignDir/map";

  unless(-d $alignDir) {
    $self->userError("Input Directory must contain alignments sub directory");
  }

  open(GENOMES, $genomesFile) or die "Cannot open map file $genomesFile for reading:$!";
  my $genomes = <GENOMES>;
  close GENOMES;

  chomp $genomes;
  my ($organismAbbrevA, $organismAbbrevB) = split(/\t/, $genomes);

  $self->lookupNaSeqIdsByAbbrev($organismAbbrevA, $organismAbbrevB);

  my $orgAAgp = "$dirname/$organismAbbrevA.agp";
  my $orgBAgp = "$dirname/$organismAbbrevB.agp";

  $self->addCoordPairs($orgAAgp, $organismAbbrevA);
  $self->addCoordPairs($orgBAgp, $organismAbbrevB);

  my $synDbRlsId = $self->getExtDbRlsId($self->getArg('syntenyDbRlsSpec'));

  my $agpLocations = $self->getAgpCoords();  

  my $count = 0;

  my $dbh = $self->getQueryHandle(); 
  $self->{_syntenic_genes_sh} = $dbh->prepare("select sequence_source_id, feature_source_id, na_feature_id, start_min, end_max, is_reversed
                                                 from apidb.genelocation
                                                where na_sequence_id = ? and end_max >= ? and start_min <= ?
                                                 and is_top_level = 1");


  $self->getDb()->manageTransaction(0, 'begin') unless($self->getArg('loadWithPsql'));


  open(MAP, $mapFile) or die "Cannot open map file $mapFile for reading:$!";
  while(<MAP>) {
    chomp;
    #1       assembled7      14891   39021   +       assembled34     2947    27303   +
    my ($subdir, $assemA, $startA, $endA, $strandA, $assemB, $startB, $endB, $strandB) = split(/\t/, $_);

#    next unless($assemA eq 'assembled6' && $assemB eq 'assembled73');

    my $constraints = $self->readConstraints("$alignDir/$subdir/cons");

    # Get Assem Coords
    my $adjustedConstraintsA = $self->adjustConstraints($constraints, $organismAbbrevA, $startA, $endA, $strandA);
    my $adjustedConstraintsB = $self->adjustConstraints($constraints, $organismAbbrevB, $startB, $endB, $strandB);

    unless(scalar @$adjustedConstraintsA == scalar @$adjustedConstraintsB) {
      $self->error("Expected Pairs of Constraints");
    }

    my $syntenyLocsA = $self->mapSyntenicLocation($agpLocations->{$organismAbbrevA}, $assemA, $startA, $endA, $strandA);
    my $syntenyLocsB = $self->mapSyntenicLocation($agpLocations->{$organismAbbrevB}, $assemB, $startB, $endB, $strandB);

    my $synteny = $self->separateByAnchors($adjustedConstraintsA, $adjustedConstraintsB, $agpLocations, $organismAbbrevA, $organismAbbrevB, $assemA, $assemB);
    my $seqIdStats = $self->makeSeqStats($synteny);

    foreach my $pk (keys %$synteny) {
      my $seqIdA = $synteny->{$pk}->{$organismAbbrevA}->{seq_id};
      my $seqIdB = $synteny->{$pk}->{$organismAbbrevB}->{seq_id};

      my $anchorsA = $synteny->{$pk}->{$organismAbbrevA}->{locations};
      my $anchorsB = $synteny->{$pk}->{$organismAbbrevB}->{locations};

      my $fullSyntenyLocA = $syntenyLocsA->{$seqIdA};
      my $fullSyntenyLocB = $syntenyLocsB->{$seqIdB};

      my ($syntenyA, $syntenyB);

      if($seqIdStats->{$seqIdA}->{counts} == 1) {
        $syntenyA = $fullSyntenyLocA;
      } else {
        my $syntenyStartA = $synteny->{$pk}->{$organismAbbrevA}->{synteny_start};
        my $syntenyEndA = $synteny->{$pk}->{$organismAbbrevA}->{synteny_end};
        $syntenyA = $self->findPartialSyntenyLoc($fullSyntenyLocA, $syntenyStartA, $syntenyEndA);
      }

      if($seqIdStats->{$seqIdB}->{counts} == 1) {
        $syntenyB = $fullSyntenyLocB;
      } else {
        my $syntenyStartB = $synteny->{$pk}->{$organismAbbrevB}->{synteny_start};
        my $syntenyEndB = $synteny->{$pk}->{$organismAbbrevB}->{synteny_end};

        $syntenyB = $self->findPartialSyntenyLoc($fullSyntenyLocB, $syntenyStartB, $syntenyEndB);
      }


#      print "SyntenyA: " . $syntenyA->seq_id . " " . $syntenyA->start . " " . $syntenyA->end . "\n";
#      print "SyntenyB: " . $syntenyB->seq_id . " " . $syntenyB->start . " " . $syntenyB->end . "\n";

      my @pairs;

      my ($sas, $sae) = $self->getSyntenyStartEndAnchors($syntenyA);
      my ($sbs, $sbe) = $self->getSyntenyStartEndAnchors($syntenyB);

      push @pairs, [$sas, $sbs];
      push @pairs, [$sae, $sbe];


      for(my $i = 0; $i < scalar @$anchorsA; $i++) {
        push @pairs, [$anchorsA->[$i],$anchorsB->[$i]];
      }

      my $syntenyObjA = $self->makeSynteny($syntenyA, $syntenyB, \@pairs, 0, $synDbRlsId, $organismAbbrevB);
      $syntenyObjA->submit(undef, 1) unless($self->getArg('loadWithPsql'));

      my $syntenyObjB = $self->makeSynteny($syntenyB, $syntenyA, \@pairs, 1, $synDbRlsId, $organismAbbrevA);
      $syntenyObjB->submit(undef, 1) unless($self->getArg('loadWithPsql'));

      if($count && $count % 500 == 0) {
        $self->log("Read $count lines... Inserted " . $count*2 . " ApiDB::Synteny");
      }

      if($count && $count % 1000 == 0) {
        $self->getDb()->manageTransaction(0, 'commit') unless($self->getArg('loadWithPsql'));
        $self->getDb()->manageTransaction(0, 'begin') unless($self->getArg('loadWithPsql'));
      }

      $self->undefPointerCache();

      $count++;
    }

  }
  close MAP;

  $self->getDb()->manageTransaction(0, 'commit') unless($self->getArg('loadWithPsql'));
  my $syntenicGeneCount = $self->getSyntenicGeneCount();

  if($self->getArg('loadWithPsql')) {
    $syntenyFifo->cleanup();
    $syntenicGeneFifo->cleanup();
  }
  # if($self->getArg('loadWithPsql')) {
  #   my $outputFileHandles = $self->getOutputFileHandles();
  #   foreach(keys %$outputFileHandles) {
  #     close $outputFileHandles->{$_};
  #   }
  # }

  return "inserted $count synteny spans and $syntenicGeneCount syntenic genes ";
}

sub getModificationDate() { $_[0]->{_modification_date} }
sub setModificationDate {
  my ($self) = @_;
  my $modificationDate = strftime "%m-%d-%Y", localtime();
  $self->{_modification_date} = $modificationDate;
}


sub getPsqlLogin() { $_[0]->{_psql_login} }
sub setPsqlLogin() {
  my ($self) = @_;
  $self->{_psql_login} = $self->getDb->getLogin();
}
sub getPsqlPassword() { $_[0]->{_psql_password} }
sub setPsqlPassword() {
  my ($self) = @_;
  $self->{_psql_password} = $self->getDb->getPassword();
}
sub getPsqlDatabase() { $_[0]->{_psql_database} }
sub setPsqlDatabase {
  my ($self) = @_;

  my $dbiDsn      = $self->getDb->getDSN();
  $dbiDsn =~ /(:|;)dbname=((\w|\.)+);?/ ;
  my $db = $2;
  $self->{_psql_database} = $db;
}
sub getPsqlHostname() { $_[0]->{_psql_hostname} }
sub setPsqlHostname {
  my ($self) = @_;

  my $dbiDsn      = $self->getDb->getDSN();
  $dbiDsn =~ /(:|;)host=((\w|\.)+);?/ ;
  my $hostName = $2;
  $self->{_psql_hostname} = $hostName;
}

sub getNaSequenceMap {$_[0]->{_na_sequence_map}}
sub lookupNaSeqIdsByAbbrev {
  my ($self, $organismAbbrevA, $organismAbbrevB) =  @_;


  my $dbh = $self->getQueryHandle();

  my $sql = "SELECT s.source_id, s.na_sequence_id 
             FROM dots.nasequence s, sres.ontologyterm so, apidb.organism o
             WHERE  so.ontology_term_id = s.sequence_ontology_id
              and so.name in ('random_sequence','supercontig','chromosome','contig','mitochondrial_chromosome','apicoplast_chromosome')
              and o.taxon_id = s.taxon_id
              and o.abbrev in ('$organismAbbrevA', '$organismAbbrevB')";

  my $sh = $dbh->prepare($sql);
  $sh->execute();

  while(my ($sourceId, $naSequenceId) = $sh->fetchrow_array()) {
    $self->{_na_sequence_map}->{$sourceId} = $naSequenceId;
  }
  $sh->finish();

}



#--------------------------------------------------------------------------------

sub getSyntenyStartEndAnchors {
  my ($self, $synteny) = @_;

  if($synteny->strand() == 1) {
    return($synteny->start(), $synteny->end());
  }
  return($synteny->end(), $synteny->start());

}

#--------------------------------------------------------------------------------

sub makeSynteny {
  my ($self, $syntenyA, $syntenyB, $pairs, $index, $synDbRlsId, $synOrganismAbbrev) = @_;


  my $naSequenceMap = $self->getNaSequenceMap();

  my $isReversed = $syntenyA->strand == $syntenyB->strand ? 0 : 1;

  my $dbiDatabase = $self->getDb();

  my $synteny = GUS::Model::ApiDB::Synteny->new({ a_na_sequence_id => $naSequenceMap->{$syntenyA->seq_id},
                                                  b_na_sequence_id => $naSequenceMap->{$syntenyB->seq_id},
                                                  a_start => $syntenyA->start,
                                                  b_start => $syntenyB->start,
                                                  a_end   => $syntenyA->end,
                                                  b_end   => $syntenyB->end,,
                                                  is_reversed => $isReversed,
                                                  external_database_release_id => $synDbRlsId,
                                                  row_group_id => $dbiDatabase->getDefaultGroupId(),
                                                  row_user_id => $dbiDatabase->getDefaultUserId(),
                                                  row_project_id => $dbiDatabase->getDefaultProjectId(),
                                                  row_alg_invocation_id => $dbiDatabase->getDefaultAlgoInvoId(),
                                                  user_read => $dbiDatabase->getDefaultUserRead(),
                                                  user_write =>  $dbiDatabase->getDefaultUserWrite(),
                                                  group_read => $dbiDatabase->getDefaultGroupRead(),
                                                  group_write => $dbiDatabase->getDefaultGroupWrite(),
                                                  other_read => $dbiDatabase->getDefaultOtherRead(),
                                                  other_write => $dbiDatabase->getDefaultOtherWrite(),
                                                  modification_date => $self->getModificationDate(),
                                                });


  if($self->getArg('loadWithPsql')) {
    $synteny->getNextID();
    my @values = map { $synteny->get($_)} @{$self->getSyntenyFields()};
    my $fh = $self->getOutputFileHandles()->{'synteny.dat'};
    print $fh join("\t", @values) . "\n";
  }

  my @sortedPairs = sort {$a->[$index] <=> $b->[$index]} @$pairs;


  my $synIndex = $index == 1 ? 0 : 1;

#  $self->createSyntenyAnchors($synteny, \@sortedPairs, $index, $synIndex);

  $self->createSyntenicGenesInReferenceSpace($synteny, $pairs, $index, $synIndex, $naSequenceMap->{$syntenyA->seq_id}, $synOrganismAbbrev);

  return $synteny;
}

#--------------------------------------------------------------------------------


sub makeSeqStats {
  my ($self, $synteny) = @_;

  my %seqIdStats;

  foreach my $pk (keys %$synteny) {
    foreach my $oa (keys %{$synteny->{$pk}}) {
      my $seqId = $synteny->{$pk}->{$oa}->{seq_id};
      $seqIdStats{$seqId}->{counts}++;

#      my $max = CBIL::Util::V::max(@{$synteny->{$pk}->{$oa}->{locations}});
#      my $min = CBIL::Util::V::min(@{$synteny->{$pk}->{$oa}->{locations}});
        
#      $seqIdStats{$seqId}->{coverage} += $max - $min;
    }
  }
  return \%seqIdStats;
}

#--------------------------------------------------------------------------------

sub separateByAnchors {
  my ($self, $adjustedConstraintsA, $adjustedConstraintsB, $agpLocations, $organismAbbrevA, $organismAbbrevB, $assemA, $assemB) = @_;

  my %synteny;
  my ($prevSeqA, $prevSeqB, $prevAnchorA, $prevAnchorB);
  my $synPk = 1;

  for(my $i = 0; $i < scalar @$adjustedConstraintsA; $i++) {
    my $conA = $adjustedConstraintsA->[$i];
    my $conB = $adjustedConstraintsB->[$i];

    my $locA = $self->disassemble($agpLocations->{$organismAbbrevA}, $assemA, $conA);
    my $locB = $self->disassemble($agpLocations->{$organismAbbrevB}, $assemB, $conB);

    unless(defined($locA)) {
      print STDERR "WARN:  Could Not Map:  $organismAbbrevA, $assemA, $conA\n";
    }
    unless(defined($locB)) {
      print STDERR "WARN:  Could Not Map:  $organismAbbrevB, $assemB, $conB\n";
    }

    next unless(defined($locA) && defined($locB));

    # Test for a breakpoint
    if($prevSeqA && ($locA->seq_id() ne $prevSeqA || $locB->seq_id() ne $prevSeqB)) {
      my $isReversedA = $prevAnchorA > $locA->start() ? 1 : 0;
      my $isReversedB = $prevAnchorB > $locB->start() ? 1 : 0;

      my $additionA = sprintf("%.0f", abs($locA->start() - $prevAnchorA) / 2);
      my $additionB = sprintf("%.0f", abs($locB->start() - $prevAnchorB) / 2);

      my $syntenyEndA = $isReversedA ? $prevAnchorA - $additionA : $prevAnchorA + $additionA;
      my $syntenyEndB = $isReversedB ? $prevAnchorB - $additionB : $prevAnchorB + $additionB;

      $synteny{$synPk}->{$organismAbbrevA}->{synteny_end} = $prevSeqA eq $locA->seq_id ? $syntenyEndA : undef;
      $synteny{$synPk}->{$organismAbbrevB}->{synteny_end} = $prevSeqB eq $locB->seq_id ? $syntenyEndB : undef;

      # Here is where we switch to the next row of synteny
      $synPk++;

      my $syntenyStartA = $isReversedA ? $locA->start() + $additionA : $locA->start() - $additionA;
      my $syntenyStartB = $isReversedB ? $locB->start() + $additionB : $locB->start() - $additionB;

      $synteny{$synPk}->{$organismAbbrevA}->{synteny_start} = $prevSeqA eq $locA->seq_id ? $syntenyStartA : undef;
      $synteny{$synPk}->{$organismAbbrevB}->{synteny_start} = $prevSeqB eq $locB->seq_id ? $syntenyStartB : undef;
    }
      
    $synteny{$synPk}->{$organismAbbrevA}->{seq_id} = $locA->seq_id;
    $synteny{$synPk}->{$organismAbbrevB}->{seq_id} = $locB->seq_id;

    push @{$synteny{$synPk}->{$organismAbbrevA}->{locations}}, $locA->start();
    push @{$synteny{$synPk}->{$organismAbbrevB}->{locations}}, $locB->start();

    $prevSeqA = $locA->seq_id();
    $prevSeqB = $locB->seq_id();
    $prevAnchorA = $locA->start();
    $prevAnchorB = $locB->start();
  }

  return \%synteny;
}


#--------------------------------------------------------------------------------

sub findPartialSyntenyLoc {
  my ($self, $synteny, $fragStart, $fragEnd) = @_;

  my $start = $synteny->start();
  my $end = $synteny->end();

  my ($newStart, $newEnd);
  if($synteny->strand == 1) {
    $newStart = defined($fragStart) ? $fragStart : $start;
    $newEnd = defined($fragEnd) ? $fragEnd : $end;
  }
  else {
    $newStart = defined($fragEnd) ? $fragEnd : $start;
    $newEnd = defined($fragStart) ? $fragStart : $end;
  }

  my $rv = Bio::Location::Simple->
      new( -seq_id => $synteny->seq_id, -start => $newStart, -end => $newEnd, -strand => $synteny->strand());

  return $rv;
}

#--------------------------------------------------------------------------------

sub mapSyntenicLocation {
  my ($self, $agps, $assem, $assemStart, $assemEnd, $strand) = @_;

  my %locations;

  my $bpStrand = $strand eq '+' ? +1 : -1;

  foreach my $agp (@$agps) {
    my $seqId = $agp->in()->seq_id();
    my $start = $agp->in()->start();
    my $end = $agp->in()->end();

    my $assemMatch;
    # assembly matches the full contig
    if($assem eq $seqId && $assemStart < $start && $assemEnd > $end) {
      $assemMatch = Bio::Location::Simple->
          new( -seq_id => 'hit', -start =>   $start, -end =>  $end, -strand => $bpStrand );
    }

    # assembly match is fully contained in a single contig 
    elsif($assem eq $seqId && $assemStart >= $start && $assemEnd <= $end) {
      $assemMatch = Bio::Location::Simple->
          new( -seq_id => 'hit', -start =>   $assemStart, -end =>  $assemEnd, -strand => $bpStrand );
    }

    # assembly match is paritally contained...run off the end
    elsif($assem eq $seqId && $assemStart <= $end && $assemEnd >= $end) {
      $assemMatch = Bio::Location::Simple->
          new( -seq_id => 'hit', -start =>   $assemStart, -end =>  $end, -strand => $bpStrand );
    }

    # assembly match is paritally contained...run off the start
    elsif($assem eq $seqId && $assemStart <= $start && $assemEnd >= $start) {
      $assemMatch = Bio::Location::Simple->
          new( -seq_id => 'hit', -start =>   $start, -end =>  $assemEnd, -strand => $bpStrand );
    }

    else {}

    if($assemMatch) {
      my $match = $agp->map( $assemMatch );
      foreach my $location ($match->each_match()) {
        my $seqId = $location->seq_id();

        $locations{$seqId} = $location;
      }
    }
  }

  return \%locations;
}
#--------------------------------------------------------------------------------

sub disassemble {
  my ($self, $agps, $assem, $loc) = @_;

  foreach(@$agps) {
    my $seqId = $_->in()->seq_id();
    my $start = $_->in()->start();
    my $end = $_->in()->end();

    if($assem eq $seqId && $loc >= $start && $loc <= $end) {
      my $assemMatch = Bio::Location::Simple->
          new( -seq_id => 'hit', -start =>   $loc, -end =>  $loc, -strand => +1 );

      my $match = $_->map( $assemMatch );
      return $match;
    }
  }
  return undef;
}

#--------------------------------------------------------------------------------

sub adjustConstraints {
  my ($self, $constraints, $organismAbbrev, $start, $end, $strand) = @_;

  my @rv;

  foreach my $con(@{$constraints->{$organismAbbrev}}) {
    if($strand eq '+') {
      push @rv, $start + $con;
    }
    elsif($strand eq '-') {
      push @rv, $end - $con;
    }
    else {
      $self->error("Strand $strand not defined correctly in map file");
    }
  }

  return \@rv;
}

#--------------------------------------------------------------------------------

sub readConstraints {
  my ($self, $file) = @_;

  open(CONS, "sort -k 2n $file|") or die "Cannot opoen file $file for reading: $!";

  my %rv;

  while(<CONS>) {
    chomp;

    my ($orgA, $startA, $endA, $orgB, $startB, $endB) = split(/ /, $_);

    push @{$rv{$orgA}}, $startA;
    push @{$rv{$orgA}}, $endA;

    push @{$rv{$orgB}}, $startB;
    push @{$rv{$orgB}}, $endB;
  }

  close CONS;
  return \%rv;
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

sub getSyntenicGeneCount {$_[0]->{syntenic_gene_count}}

sub countSyntenicGenes {
  my ($self) = @_;

  my $count = $self->{syntenic_gene_count}++;

  $self->log("Inserted $count rows into ApiDb::SyntenicGene") if ($count && $count % 1000 == 0);
}

#--------------------------------------------------------------------------------

sub createSyntenicGenesInReferenceSpace {
  my ($self, $syntenyObj, $pairs, $refIndex, $synIndex, $refNaSequenceId, $synOrganismAbbrev) = @_;

  my ($features, $sortedLocations) = $self->getSyntenicGenes($syntenyObj);

  my $syntenyIsReversed = $syntenyObj->getIsReversed();

  my %mappedCoords;

  my $loc = pop @$sortedLocations;

  my @sortedPairs = sort {$a->[$synIndex] <=> $b->[$synIndex]} @$pairs;

  my $length = scalar @sortedPairs;

  for(my $i = 1; $i < $length; $i++) {

    my $refLocStart = $sortedPairs[$i-1]->[$refIndex];
    my $synLocStart = $sortedPairs[$i-1]->[$synIndex];
    my $refLocEnd = $sortedPairs[$i]->[$refIndex];
    my $synLocEnd = $sortedPairs[$i]->[$synIndex];

    my $refLength = abs($refLocEnd - $refLocStart) + 1;
    my $synLength = abs($synLocEnd - $synLocStart) + 1;

    while($loc && (($loc >= $synLocStart && $loc <= $synLocEnd) || ($i == 1 && $loc < $synLocStart) || ($i == $length-1 && $loc > $synLocEnd))) {
      my $synPct = ($loc - $synLocStart + 1) / ($synLocEnd - $synLocStart + 1);

      my $newLocation;

      if($refLocStart < $refLocEnd) {
        $newLocation = int(($synPct * ($refLocEnd - $refLocStart + 1)) + $refLocStart);

        if($newLocation < $refLocStart) {
          $mappedCoords{$loc} = $refLocStart;
        }
        elsif($newLocation > $refLocEnd) {
          $mappedCoords{$loc} = $refLocEnd;
        }
        else {
          $mappedCoords{$loc} = $newLocation;
        }
      }
      else {
        $newLocation = int($refLocStart - ($synPct * ($refLocStart - $refLocEnd + 1)));

        if($newLocation < $refLocEnd) {
          $mappedCoords{$loc} = $refLocEnd;
        }
        elsif($newLocation > $refLocStart) {
          $mappedCoords{$loc} = $refLocStart;
        }
        else {
          $mappedCoords{$loc} = $newLocation;
        }
      }


      $loc = pop @$sortedLocations;
    }

    next if scalar @$sortedLocations == 0;

    if($loc < $synLocStart) {
      die "should never be here";
    }
  }

  die "did not process all locations" if scalar @$sortedLocations > 0;

  foreach my $geneId (keys %$features) {
    my $gene = $features->{$geneId};

    $self->loadSyntenicGene($gene, $synOrganismAbbrev, \%mappedCoords, $syntenyIsReversed, $refNaSequenceId, $syntenyObj);
  }
}

#--------------------------------------------------------------------------------

sub mapSyntenicGeneCoords {
  my ($self, $row, $mappedCoords, $syntenyIsReversed) = @_;

  my $origStart = $row->{START_MIN};
  my $origEnd = $row->{END_MAX};

  my $start = $mappedCoords->{$origStart};
  my $end = $mappedCoords->{$origEnd};

  if($start > $end) {
    my $tmp = $end;
    $end = $start;
    $start = $tmp;
  }

  unless(defined($start) && defined($end)) {
    print Dumper $row;
    die "start or end not defined" ;
  }

  my $rowIsReversed = $row->{IS_REVERSED};

  my $isReversed;
  if($syntenyIsReversed == 0) {
    $isReversed = $rowIsReversed == 0 ? 0 : 1;
  }
  else {
    $isReversed = $rowIsReversed == 0 ? 1 : 0;
  }
  return ($start, $end, $isReversed);

}


#--------------------------------------------------------------------------------

sub loadSyntenicGene {
  my ($self, $gene, $synOrganismAbbrev, $mappedCoords, $syntenyIsReversed, $refNaSequenceId, $syntenyObj) = @_;

  my $geneRow = $gene->{gene};

  my $geneStart = $geneRow->{START_MIN};
  my $geneEnd = $geneRow->{END_MAX};

  my ($mappedStart, $mappedEnd, $isReversed) = $self->mapSyntenicGeneCoords($geneRow, $mappedCoords, $syntenyIsReversed);

  my $geneLength = $geneEnd - $geneStart - 1;
  my $mappedLength = $mappedEnd - $mappedStart - 1;

  my $synNaFeatureId = $geneRow->{NA_FEATURE_ID};

  my $dbiDatabase = $self->getDb();
  my $syntenicGeneObj = GUS::Model::ApiDB::SyntenicGene->new({na_sequence_id => $refNaSequenceId,
                                                              start_min => $mappedStart,
                                                              end_max => $mappedEnd,
                                                              is_reversed => $isReversed,
                                                              syn_na_feature_id => $synNaFeatureId,
                                                              syn_organism_abbrev => $synOrganismAbbrev,
                                                              row_group_id => $dbiDatabase->getDefaultGroupId(),
                                                              row_user_id => $dbiDatabase->getDefaultUserId(),
                                                              row_project_id => $dbiDatabase->getDefaultProjectId(),
                                                              row_alg_invocation_id => $dbiDatabase->getDefaultAlgoInvoId(),
                                                              user_read => $dbiDatabase->getDefaultUserRead(),
                                                              user_write =>  $dbiDatabase->getDefaultUserWrite(),
                                                              group_read => $dbiDatabase->getDefaultGroupRead(),
                                                              group_write => $dbiDatabase->getDefaultGroupWrite(),
                                                              other_read => $dbiDatabase->getDefaultOtherRead(),
                                                              other_write => $dbiDatabase->getDefaultOtherWrite(),
                                                              modification_date => $self->getModificationDate(),
                                                             });



  if($self->getArg('loadWithPsql')) {
    $syntenicGeneObj->getNextID();
    $syntenicGeneObj->setSyntenyId($syntenyObj->getId());
    my @values = map { $syntenicGeneObj->get($_)} @{$self->getSyntenicGeneFields()};
    my $fh = $self->getOutputFileHandles()->{'syntenic_gene.dat'};
    print $fh join("\t", @values) . "\n";
  }



  $syntenyObj->addChild($syntenicGeneObj);
  $self->countSyntenicGenes();
}

#--------------------------------------------------------------------------------

sub getSyntenicGenes {
  my ($self, $syntenyObj) = @_;

  my $naSequenceId = $syntenyObj->getBNaSequenceId();
  my $start = $syntenyObj->getBStart();
  my $end = $syntenyObj->getBEnd();

  my $sh = $self->{_syntenic_genes_sh};
  $sh->execute($naSequenceId, $start, $end);

  my (%locations, %rows);
  while(my $hash = $sh->fetchrow_hashref()) {
    my $id = $hash->{NA_FEATURE_ID};

    my $start = $hash->{START_MIN};
    my $end = $hash->{END_MAX};

    $rows{$id}->{gene} = $hash;

    $locations{$start}++;
    $locations{$end}++;
  }

  $sh->finish();

  my @sortedLocations = sort { $b <=> $a } keys %locations;

  return \%rows, \@sortedLocations;
}


#--------------------------------------------------------------------------------

sub createSyntenyAnchors {
  my ($self, $syntenyObj, $sortedPairs, $refIndex, $synIndex) = @_;

  my @sortedPairs = @$sortedPairs;


  my $prevRefLoc = -9999999999;
  my $lastRefLoc = 9999999999;

  for(my $i = 0; $i < scalar @sortedPairs; $i++) {
    my $nextRefLoc;
    if($i == scalar(@sortedPairs) - 1) {
      $nextRefLoc = $lastRefLoc;
    }
    else {
      $nextRefLoc = $sortedPairs[$i+1]->[$refIndex];
    }

    my $refLoc = $sortedPairs[$i]->[$refIndex];
    my $synLoc = $sortedPairs[$i]->[$synIndex];

    my $anchor = {prev_ref_loc=> $prevRefLoc,
                  ref_loc=> $refLoc,
                  next_ref_loc=> $nextRefLoc,
                  syntenic_loc=> $synLoc
                 };

    $self->addAnchorToGusObj($anchor, $syntenyObj);

    $prevRefLoc = $refLoc;
  }

}


sub addAnchorToGusObj {
  my ($self, $anchor, $syntenyObj) = @_;

  if($anchor->{prev_ref_loc} > $anchor->{ref_loc} || $anchor->{ref_loc} > $anchor->{next_ref_loc}){
      print STDERR "Error in synteny object: ";
      print STDERR Dumper $syntenyObj->toString();
      $self->error("Anchor locations: prev_ref_loc = $anchor->{prev_ref_loc}, ref_loc = $anchor->{ref_loc}, next_ref_loc = $anchor->{next_ref_loc}");
  }
  my $anchorObj = GUS::Model::ApiDB::SyntenyAnchor->new($anchor);
  $syntenyObj->addChild($anchorObj);

}

#--------------------------------------------------------------------------------



sub makePsqlObj {
  my ($self, $tableName, $datFileName, $attributeList) = @_;

  my $psqlObj = ApiCommonData::Load::Psql->new({
    _login => $self->getPsqlLogin(),
    _password => $self->getPsqlPassword(),
    _database => $self->getPsqlDatabase(),
    _hostName=> $self->getPsqlHostname(),
    _quiet => 0,
  });


  $psqlObj->setInfileName($datFileName);
  $psqlObj->setTableName($tableName);
  $psqlObj->setFieldDelimiter("\t");
  
  my @dataFields = map { lc($_) } grep { lc($_) ne 'tstarts' && lc($_) ne 'blocksizes'} @$attributeList;
  if($tableName eq 'ApiDB.Synteny') {
    $self->setSyntenyFields(\@dataFields);
  }
  elsif($tableName eq 'ApiDB.SyntenicGene') {
    $self->setSyntenicGeneFields(\@dataFields);
  }
  else {
    $self->error("Invalid tableName $tableName:  expected ApiDB.Synteny or ApiDB.SynetenicGene");
  }

  $psqlObj->setFields(\@dataFields);
  
  return $psqlObj;

}




sub undoTables {
  return (#"ApiDB.SyntenyAnchor",
          "ApiDB.SyntenicGene",
          #"ApiDB.SyntenicScale",
          "ApiDB.Synteny");
}

1;
