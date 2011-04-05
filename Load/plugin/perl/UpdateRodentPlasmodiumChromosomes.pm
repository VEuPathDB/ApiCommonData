package ApiCommonData::Load::Plugin::UpdateRodentPlasmodiumChromosomes;

@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use GUS::PluginMgr::Plugin;
use FileHandle;

use ApiCommonData::Load::Util;

use GUS::Model::DoTS::ExternalNASequence;
use GUS::Model::ApiDB::RodentChrColors;

my $argsDeclaration =
  [
   fileArg({name => 'mappingFile',
	    descr => 'A tab-delimited file with header row, mapping Rodent Malaria genome with Pfal genes',
	    reqd => 1,
	    mustExist => 1,
	    format => 'VI      1       light blue      #CCFFFF 0       MAL6P1.23       132606  MAL6P1.283      648830',
	    constraintFunc => undef,
	    isList => 0, }),
   stringArg({name => 'extDbNames',
              descr => 'list of External Database Names of rodent species for which chromosomes need to be assigned',
              reqd => 1,
              isList => 1,
              constraintFunc => undef,
             }),
   booleanArg({name => 'addChrColorTable',
	       descr => "populate the table iof RMP chromosome and color",
	       reqd => 0,
	       default => 1
	   }),
   
];

my $purpose = <<PURPOSE;
The purpose of this plugin is to assign chromsomes to RMP (rodent malaria parasite) contigs. Taco Kaoij's spreadsheet provides the mapping of RMP contigs to Pfal genes. Using (most of) this mapping and synteny data generated from Mercator,  RMP contigs will be assigned Rodent chromsosome numbers.
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
The purpose of this plugin is to assign chromsome to RMP contigs.
PURPOSE_BRIEF

my $notes = <<NOTES;
NOTES

my $tablesAffected = <<TABLES_AFFECTED;
TABLES_AFFECTED

my $tablesDependedOn = <<TABLES_DEPENDED_ON;
TABLES_DEPENDED_ON

my $howToRestart = <<RESTART;
No Restart utilities for this plugin.
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
		      cvsRevision       => '$Revision: 22515 $',
		      name              => ref($self),
		      argsDeclaration   => $argsDeclaration,
		      documentation     => $documentation});
  return $self;
}


sub run {
  my ($self) = @_;

  # method to read data into an array
  my @all_data =   $self->readFile();

  if ($self->getArg('addChrColorTable')) {
    $self->addChromosomeColorTable(@all_data);
  }

  my %mappingArray;
  my $mappingref = \%mappingArray;

  for my $href (@all_data){
    # method to get the active source_id (as all pfal source_id in input file are not current)
    $href->{gene_left} = $self->getActiveGeneId($href->{gene_left});
    $href->{gene_right} = $self->getActiveGeneId($href->{gene_right});

    # method to assign genomic locations in the hash
    if ($href->{is_reversed}){
      $href->{min_position} = $self->getMinGenomicPosition($href->{gene_right});
      $href->{max_position} = $self->getMaxGenomicPosition($href->{gene_left});
    }else{
      $href->{min_position} = $self->getMinGenomicPosition($href->{gene_left});
      $href->{max_position} = $self->getMaxGenomicPosition($href->{gene_right});
    }

    # the array of External Database Names of rodent species
    my @RMP_ext_db_names =@{$self->getArg('extDbNames')};

    for my $db_name (@RMP_ext_db_names) {
      # method to look at synteny data and find RMP contigs
      my $contigsRef = $self->getRMPContigs($href->{pfal_chr}, $href->{min_position}, $href->{max_position}, $db_name);

      # method to collect the full list of which RMP contig goes with what RMP chromosome/s.
      $mappingref = $self->mapContigWithChromosome($href->{rmp_chr}, $contigsRef, $mappingref);
    }
  }

  # method to assign chromosomes to the contigs; *only* done for the unambiguous cases
  my $ct = $self->makeChromosomeAssignments($mappingref);

  $self->getQueryHandle()->commit(); # ga no longer doing this by default
  return("$ct contigs assigned chromosome");
}


# method to read input file and save all the data in an array of hashes
sub readFile {
  my ($self) = @_;
  open(FILE, $self->getArg('mappingFile')) || die "Could Not open File for reading: $!\n";

  my $index = -1; #count of the number of break points
  my @data;       #array of data, between the break points
  my $file =  $self->getArg('mappingFile') ;
  open(FILE, $self->getArg('mappingFile')) || die "Could Not open File for reading: $!\n";

  while(<FILE>) {
    $index++;
    next if $index<1; #discard header row in file
    chomp;
    my %piece;
    my $temp; # going to ignore the Pfal gene positions
    ($piece{pfal_chr}, $piece{rmp_chr}, $piece{colorName}, $piece{colorValue}, $piece{is_reversed}, $piece{gene_left}, $temp, $piece{gene_right}, $temp) = split('\t', $_);
    push (@data, \%piece);
  }
  close(FILE);
  return(@data);
}


sub addChromosomeColorTable {
  my ($self, @arrData) = @_;
  my (%name, %color);

  for my $row (@arrData){
    my %row = %{$row};
    $name{$row{rmp_chr}} = $row{colorName};
    $color{$row{rmp_chr}} = $row{colorValue};
  }

  foreach my $key (sort keys(%name)) {
    my ($name, $value) = ($name{$key}, $color{$key});
    $self->log("COLORS: $key, $name, $value");
     my $profile = GUS::Model::ApiDB::RodentChrColors->
	      new({chromosome => $key,
		   color => $name,
		   value => $value
		   });
	  $profile->submit();
  }
}


# get the active source_id of the pfal_gene
sub getActiveGeneId {
  my ($self, $gene_id) = @_;
  my $dbh = $self->getQueryHandle();

  my $stmt = $dbh->prepare("SELECT distinct gene FROM apidb.GeneId WHERE lower(id) = lower(?) and unique_mapping = 1");
  $stmt->execute($gene_id);
  my ($id) = $stmt->fetchrow_array();

  $self->undefPointerCache();
  return $id;
}


# if is_reversed =0, get start_min of left gene; if if reversed =1, get start_min of right gene
sub getMinGenomicPosition {
  my ($self, $gene_id) = @_;

  my $dbh = $self->getQueryHandle();
  my $stmt = $dbh->prepare("SELECT nal.start_min FROM dots.GeneFeature gf, dots.NALocation nal WHERE  gf.source_id = ? AND  nal.na_feature_id = gf.na_feature_id");

  $stmt->execute($gene_id);
  my ($startm) = $stmt->fetchrow_array();
  $self->undefPointerCache();
  return $startm;
}


# if is_reversed =0, get end_max of right gene; if if reversed =1, get end_max of left gene
sub getMaxGenomicPosition {
  my ($self, $gene_id) = @_;

  my $dbh = $self->getQueryHandle();
  my $stmt = $dbh->prepare("SELECT nal.end_max FROM dots.GeneFeature gf, dots.NALocation nal WHERE  gf.source_id = ? AND  nal.na_feature_id = gf.na_feature_id");

  $stmt->execute($gene_id);
  my ($end) = $stmt->fetchrow_array();

  $self->undefPointerCache();
  return $end;
}


sub getRMPContigs {
  my ($self, $pf_ch, $min, $max, $ext_db) = @_;
  my @rmp_contigs;
  my $pf_seq_id = $self->getNaSeqId($pf_ch);

  ($min, $max) = ($max, $min) if $min > $max;
  my $dbh = $self->getQueryHandle();
  my $sql = "SELECT count(*), source_id, na_sequence_id FROM (
               SELECT b.source_id, b.na_sequence_id
               FROM apidb.synteny syn,apidb.syntenyAnchor anch,
                    dots.externalnasequence a, dots.externalnasequence b,
                    sres.externaldatabaserelease edr,sres.externaldatabase ed
               WHERE ed.name = '$ext_db'
               AND edr.external_database_id = ed.external_database_id
               AND syn.external_database_release_id = edr.external_database_release_id
               AND syn.a_start <= $max
               AND syn.a_end >= $min
               AND syn.a_na_sequence_id = $pf_seq_id
               AND a.na_sequence_id = syn.a_na_sequence_id
               AND b.na_sequence_id = syn.b_na_sequence_id
               AND anch.synteny_id = syn.synteny_id
             ) GROUP BY source_id, na_sequence_id";
  my $sh = $dbh->prepare($sql);
  $sh->execute();

  while(my ($anchor_num, $srcId, $naSeqId) = $sh->fetchrow_array()) {
    my %h;
    $h{$srcId}=$anchor_num;
    push (@rmp_contigs, \%h);
  }
  # return reference to array of hashes, whose keys are the RMP contigs and values are the anchor_num
  return(\@rmp_contigs);
}


sub getNaSeqId {
  my ($self, $src_id) = @_;

  my $dbh = $self->getQueryHandle();
  my $stmt = $dbh->prepare("SELECT na_sequence_id FROM dots.ExternalNASequence WHERE source_id = ?");
  $stmt->execute($src_id);
  my ($seq_id) = $stmt->fetchrow_array();
  $self->undefPointerCache();

  return $seq_id;
}


sub mapContigWithChromosome {
  my ($self, $chr, $ctgref, $mapref) = @_;

  my %chromo = %$mapref;

  for my $ctgHashRef (@$ctgref){
    my %ctgHash = %$ctgHashRef;
    my @ctgArray = %ctgHash;
    my ($ctgKey, $ctgAnchors) = @ctgArray;

    my @chr_list;
    if (my $test = $chromo{$ctgKey}) {
      @chr_list = @$test;
    }
    push (@chr_list, $chr."|".$ctgAnchors);
    $chromo{$ctgKey} = \@chr_list;

 }
  # return reference to hash, whose keys are RMP contigs, and values are RMP_chr|anchor_num
  return(\%chromo);
}


sub makeChromosomeAssignments {
  my ($self, $mapref2) = @_;

  my $count=0;
  my %map = %{$mapref2};
  my @keyed = keys(%map);
  $self->log("TOTAL NUM OF RMP CONTIGS: $#keyed");

  # log just the contigs for which there is more than 1 chr assignment
  foreach my $key (@keyed) {
    my @bar = @{$map{$key}};
    my %h;

    if ($#bar > 0) {
      # split on ! and save h{rmp_chr} = anchor_count hash
      foreach my $val (@bar) {
	my ($a1, $a2)= split('\|', $val);
	$h{$a1} = $a2;
      }
      my @a = %h;
      my $c=$#a;
      if (($c+1)/2 == 1){   # 1 distinct chr for contig
	$self->assignChromosomesToContigs($key, $a[0]);
	$count++;
      } else {
	$self->log("AMBIGUOUS... contig:$key, chr and anchor_count array: @a");
      }
    } else {
      # 1 contig going to just 1 chr
      my ($a1, $a2)= split('\|', $bar[0]);

      $self->assignChromosomesToContigs($key, $a1);
      $count++;
    }
  }
  return $count;
}


sub assignChromosomesToContigs {
  my ($self, $src_id, $chr) = @_;

  my $dbh = $self->getQueryHandle();
  my $stmt = $dbh->prepare("SELECT na_sequence_id FROM DoTS.ExternalNASequence WHERE  source_id = ?");

  $stmt->execute($src_id);
  my ($seq_id) = $stmt->fetchrow_array();

  my $sql = "UPDATE DoTS.ExternalNASequence SET chromosome='$chr' WHERE na_sequence_id = $seq_id";
  my $sh = $dbh->prepare($sql);
  $sh->execute();

  #  $stmt->execute($chr, $seq_id);
  $self->log("Assign $chr to $seq_id ($src_id)");

  $self->undefPointerCache();

  return $seq_id;
}
1;

