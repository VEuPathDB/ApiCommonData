package ApiCommonData::Load::Plugin::InsertGeneGenomicSequence;

@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use GUS::PluginMgr::Plugin;
use FileHandle;

use ApiCommonData::Load::Util;

use GUS::Model::DoTS::ExternalNASequence;
use GUS::Model::ApiDB::GeneGenomicSequence_Split;

my $argsDeclaration =
  [
      stringArg({name => 'dbRlsIds',
              descr => '',
              reqd => 1,
              isList => 1,
              constraintFunc => undef,
             }),
];

my $purpose = <<PURPOSE;
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;

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
		      cvsRevision       => '$Revision$',
		      name              => ref($self),
		      argsDeclaration   => $argsDeclaration,
		      documentation     => $documentation});
  return $self;
}


sub run {
  my ($self) = @_;

  my $dbRlsIds=  $self->getArg('dbRlsIds');
  my $dbh = $self->getQueryHandle();
  my $sql = "select gf.source_id,
             case
              when type = 'exon' and gl.is_reversed = 0
               then substr(s.sequence, gm.start_min, (gm.end_max - gm.start_min) + 1)
              when type = 'exon' and gl.is_reversed = 1
               then apidb.reverse_complement_clob(substr(s.sequence, gm.start_min, (gm.end_max - gm.start_min) + 1))
              when type = 'intron' and gl.is_reversed = 0
               then lower(substr(s.sequence, gm.start_min, (gm.end_max - gm.start_min) + 1))
              else lower(apidb.reverse_complement_clob(substr(s.sequence, gm.start_min, (gm.end_max - gm.start_min) + 1)))
             end as sequence,
             case 
	      when gl.is_reversed = 1 then -1 * gm.start_min 
              else gm.start_min 
             end as start_min
             from dots.GeneFeature gf, dots.nalocation gl, dots.NaSequence s,
             (  select 'exon' as type, ef.parent_id as na_feature_id,  el.start_min as start_min, el.end_max as end_max
             from dots.ExonFeature ef, dots.nalocation el
          where ef.na_feature_id = el.na_feature_id
        union
          select 'intron' as type, left.parent_id as na_feature_id, leftLoc.end_max + 1  as start_min, rightLoc.start_min - 1 as end_max
          from dots.ExonFeature left, dots.nalocation leftLoc,  dots.ExonFeature right, dots.nalocation rightLoc
          where left.parent_id = right.parent_id
            and (left.order_number = right.order_number - 1 or left.order_number = right.order_number + 1)
            and leftLoc.start_min < rightLoc.start_min
            and left.na_feature_id = leftLoc.na_feature_id
            and right.na_feature_id = rightLoc.na_feature_id ) gm
  where gm.na_feature_id = gf.na_feature_id
    and s.na_sequence_id = gf.na_sequence_id
    and gf.na_feature_id = gl.na_feature_id
    and gf.external_database_release_id in ($dbRlsIds)";


  my $sh = $dbh->prepare($sql);
  $sh->execute();

  while(my ($source_id, $gene_genomic_sequence, $start_min) = $sh->fetchrow_array()) {
    my %h;
    $h{$srcId}=$anchor_num;
    push (@rmp_contigs, \%h);
  }




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

  my $stmt = $dbh->prepare("SELECT distinct gene FROM apidb.GeneAlias WHERE lower(alias) = lower(?) ");
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







1;

