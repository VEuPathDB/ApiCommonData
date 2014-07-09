package ApiCommonData::Load::PlasmoSpecialCaseQualifierHandlers;
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | absent
  # GUS4_STATUS | RAD.Analysis                   | auto   | absent
  # GUS4_STATUS | ApiDB.Profile                  | auto   | absent
  # GUS4_STATUS | Study.Study                    | auto   | absent
  # GUS4_STATUS | Dots.Isolate                   | auto   | absent
  # GUS4_STATUS | DeprecatedTables               | auto   | absent
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

use strict;
use GUS::Supported::SpecialCaseQualifierHandlers;
use GUS::Model::DoTS::ExternalNASequence;
use GUS::Model::DoTS::AASequenceEnzymeClass;
use GUS::Model::DoTS::TranslatedAASequence;
use GUS::Model::DoTS::TranslatedAAFeature;
use GUS::Model::DoTS::NAFeatureComment;
use GUS::Model::DoTS::RNAType;
use GUS::Model::DoTS::Transcript;
use GUS::Model::DoTS::ExonFeature;
use GUS::Model::DoTS::GeneFeature;
use GUS::Model::DoTS::Repeats;
use GUS::Supported::Util;

use Data::Dumper;

# this is the list of so terms that this file uses.  we have them here so we
# can check them at start up time.
my $soTerms = ({stop_codon_redefinition_as_selenocysteine => 1,
		SECIS_element => 1,
		centromere => 1,
		GC_rich_promoter_region => 1,
		tandem_repeat => 1,
		exon => 1,
	       });

# This is a pluggable module for GUS::Supported::Plugin::InsertSequenceFeatures 
sub new {
  my ($class) = @_;
  my $self = {};
  bless($self, $class);
  return $self;
}

sub setPlugin{
  my ($self, $plugin) = @_;
  $self->{plugin} = $plugin;

  return unless $plugin;

  foreach my $soTerm (keys %$soTerms){
    unless($self->{plugin}->getSOPrimaryKey($soTerm)){die "SO term $soTerm not found\n";}
  }

}

sub undoAll{
  my ($self, $algoInvocIds, $dbh) = @_;

  $self->{'algInvocationIds'} = $algoInvocIds;
  $self->{'dbh'} = $dbh;

  $self->_undoCommentNterm();
  $self->_undoRptUnit();
  $self->_undoLiterature();
  $self->_undoObsoleteProduct();
  $self->_undoNoteWithAuthor();
}



################ comment_Nterm ################################

# map a consensus comment to the rpt_unit column, ignore every other value
sub commentNterm {
  my ($self, $tag, $bioperlFeature, $feature) = @_;

  my @tagValues = $bioperlFeature->get_tag_values($tag);

  foreach my $tagValue (@tagValues){
    if ($tagValue =~ /consensus/){
      my @tagSplit = split("consensus", $tagValue);
      $tagSplit[1] =~ s/\s//g;
      $feature->setRptUnit($tagSplit[1]);
    }
  }
  return [];
}

# nothing special to do
sub _undoCommentNterm{
  my ($self) = @_;

}

################ rpt_unit ################################

# create a comma delimited list of rpt_units
sub rptUnit {
  my ($self, $tag, $bioperlFeature, $feature) = @_;

  my @tagValues = $bioperlFeature->get_tag_values($tag);
  my $rptUnit = join(", ", @tagValues);
  $feature->setRptUnit($rptUnit);
  return [];
}

# nothing special to do
sub _undoRptUnit{
  my ($self) = @_;

}



################ Literature ###############################

sub literature {
  my ($self, $tag, $bioperlFeature, $feature) = @_;

  my @dbRefNaFeatures;
  foreach my $tagValue ($bioperlFeature->get_tag_values($tag)) {
    if ($tagValue =~ /^\s*(PMID:\s*\d+)/) {
      my $pmid = $1;
      push(@dbRefNaFeatures, 
	   GUS::Supported::SpecialCaseQualifierHandlers::buildDbXRef($self->{plugin}, $pmid));
    } else {
      next;
    }
  }
  return \@dbRefNaFeatures;
}

# undo handled by undoDbXRef in GUS::Supported::Load::SpecialCaseQualifierHandler
sub _undoLiterature{
  my ($self) = @_;
  GUS::Supported::SpecialCaseQualifierHandlers::_undoDbXRef($self);
}

###################  obsolete_product  #################
sub obsoleteProduct {
  my ($self, $tag, $bioperlFeature, $feature) = @_;

  my @notes;
  foreach my $tagValue ($bioperlFeature->get_tag_values($tag)) {
    my $note = "Obsolete product name: $tagValue";
    my $arg = {comment_string => substr($note, 0, 4000)};
    push(@notes, GUS::Model::DoTS::NAFeatureComment->new($arg));

  }
  return \@notes;
}

sub _undoObsoleteProduct {
  my ($self) = @_;
  $self->_deleteFromTable('DoTS.NAFeatureComment');
}



###################  misc_feature /note  #################
sub miscFeatureNote {
  my ($self, $tag, $bioperlFeature, $feature) = @_;

  return undef if $bioperlFeature->has_tag('algorithm');

  # map contents of note to appropriate go term
  my @notes;
  my %note2SO = ('putative centromer' =>'centromere',   # centromere or centromeric
		 'centromere, putative' => 'centromere',
		 'GC-rich' => 'GC_rich_promoter_region',
		 'GC-rcih' => 'GC_rich_promoter_region',
		 'GC rich' => 'GC_rich_promoter_region',
		 'tetrad tandem repeat' => 'tandem_repeat',
		 'Possible exon' => 'exon',
		 'Could be the last exon' => 'NO_SO_TERM',
		 'maps at the 3' => 'NO_SO_TERM',
		);
  my @keys = keys(%note2SO);


  foreach my $tagValue ($bioperlFeature->get_tag_values($tag)) {

    my $found;
    foreach my $key (@keys) {
      $found = $key if $tagValue =~ /$key/i;
      last if $found;
    }
#    die "Can't find so term for note '$tagValue'" unless $found;

    my $soTerm = $note2SO{$found};

#    if ($soTerm ne 'NO_SO_TERM') {
    if ($soTerm && $soTerm ne 'NO_SO_TERM') {
      my $soId = $self->_getSOPrimaryKey($soTerm);
      $feature->setSequenceOntologyId($soId);
    }

    my $arg = {comment_string => substr($tagValue, 0, 4000)};
    push(@notes, GUS::Model::DoTS::NAFeatureComment->new($arg));

  }
  return \@notes;
}

sub _undoMiscFeatureNote{
  my ($self) = @_;
  $self->_deleteFromTable('DoTS.NAFeatureComment');
}

################# Note with Author #################################

sub noteWithAuthor {
  my ($self, $tag, $bioperlFeature, $feature) = @_;

  foreach my $controlledCuration ($bioperlFeature->get_tag_values($tag)){
    my $html = $self->_makeHTML($controlledCuration);

    my $comment = GUS::Model::DoTS::NAFeatureComment->
                                    new({ COMMENT_STRING => $html });

    $comment->setParent($feature);
  }

return [];
}

sub _undoNoteWithAuthor{
  my ($self) = @_;
  $self->_deleteFromTable('DoTS.NAFeatureComment');
}

################# Exon Type ########################################

sub exonType {
  my ($self, $tag, $bioperlFeature, $feature) = @_;

  my ($type) = $bioperlFeature->get_tag_values($tag);

  $feature->setIsInitialExon($type eq "Single" || $type eq "Initial");
  $feature->setIsFinalExon($type eq "Single" || $type eq "Terminal");

  return [];
}

#################################################################

sub _getSOPrimaryKey {
  my ($self, $soTerm) = @_;
  die "using so term '$soTerm' which not declared at the top of this file" unless $soTerms->{$soTerm};

  return $self->{plugin}->getSOPrimaryKey($soTerm);
}

sub _deleteFromTable{
   my ($self, $tableName) = @_;

  &GUS::Supported::Plugin::InsertSequenceFeaturesUndo::deleteFromTable($tableName, $self->{'algInvocationIds'}, $self->{'dbh'});
}

sub _makeHTML{
  my($self, $controlledCuration) = @_;

  my @subTags = split(';', $controlledCuration);

  my %curation;
  my @htmls;
  my ($url, $text);
  foreach my $subTag (@subTags){
    my ($label, $data) = split('=', $subTag);
    $label =~ s/\s//g;

    $curation{$label} = $data;
  }

  foreach my $prefix (sort keys %curation) {
    my $val = $curation{$prefix};
    my $html;

    if($prefix eq "date"){
      next;
    }elsif($prefix eq "URL_display"){
      $text = $val;
    }elsif($prefix eq "URL" || $prefix eq "db_xref"){

      $url = $val;
      $url =~ s/\s//g;

    }elsif($prefix eq "dbxref"){

      ($prefix,$val) = split(":", $val);
      $html = "<b>$prefix</b>:\t$val<br>" if($val);

    }else{
      $html = "<b>$prefix</b>:\t$val<br>" if($val);
    }
    push(@htmls, $html);
  }

  if($url && $text){
    my $html = "<a href=\"$url\">$text</a><br>";
    push(@htmls, $html);
  }elsif($url){
    my $html = "<a href=\"$url\">$url</a><br>";
    push(@htmls, $html);
  }

  my $userCommentHtml = join('', @htmls);

  return $userCommentHtml;

}

1;

