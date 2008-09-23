package ApiCommonData::Load::Plugin::InsertMassSpecFeaturesAndSummaries;


@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use File::Find;
use FileHandle;

use GUS::PluginMgr::Plugin;

# read from
use GUS::Model::DoTS::Transcript;
use GUS::Model::DoTS::GeneFeature;
use GUS::Model::DoTS::Miscellaneous;
use GUS::Model::DoTS::TranslatedAASequence;
use GUS::Model::DoTS::TranslatedAAFeature;
use GUS::Model::SRes::SequenceOntology;

# write to
use GUS::Model::DoTS::AALocation;
use GUS::Model::DoTS::NALocation;
use GUS::Model::DoTS::MassSpecFeature;
use GUS::Model::ApiDB::MassSpecSummary;
use GUS::Model::DoTS::NAFeature;

# utility
use Bio::Location::Split;
use Bio::Location::Simple;
use Bio::Coordinate::GeneMapper;

# debugging
use Data::Dumper;

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self, $class);

  $self->initialize({
                     requiredDbVersion => 3.5,
                     cvsRevision       => '$Revision: 22807 $',
                     name              => ref($self),
                     argsDeclaration   => declareArgs(),
                     documentation     => getDocumentation(),
                    });
  return $self;
}

sub run {
  my ($self) = @_;
  $self->{featuresAdded} = $self->{summariesAdded} = $self->{summariesSkipped} = 0;
    
  my $inputFile = $self->getArg('inputFile');    
  my $record = {};
  my $recordSet = [];
  my $mss;
    
  $self->{extDbRlsId} = $self->getExtDbRlsId($self->getArg('externalDatabaseSpec'));
  $self->{geneExtDbRlsId} = $self->getExtDbRlsId($self->getArg('geneExternalDatabaseSpec'));
  my $minPMatch = $self->getArg('minPercentPeptidesToMap');
  $self->{minPepToMatch} = $minPMatch ? $minPMatch : 50;

  ##prepare the query statements
  $self->prepareSQLStatements();

  open(F, $inputFile) or die "Could not open $inputFile: $!\n";
  while (<F>) {
    chomp;
    next if m/^\s*$/;
    if (m/^# /) {
      chomp(my $ln = <F>);
      undef $record;
      $record = $self->initRecord($ln);
      push @{$recordSet}, $record;
    } else {
      m/^## / and next;
      $self->addMassSpecFeatureToRecord($_, $record);
    }
    $self->undefPointerCache();
  }
        
  ##now need to loop through records and assign to genes ..
  $self->addRecordsToGenes($recordSet);
    
  $self->pruneDuplicateAndEmptyRecords($recordSet);
  $self->pruneDuplicateAndEmptyRecords($self->{copiedRecords}) if $self->{copiedRecords};
    
  warn "inserting into db for ".scalar(@$recordSet). " records\n" if $self->getArg('mapOnly');
  $self->insertRecordsIntoDb($recordSet) unless $self->getArg('mapOnly');    
  if($self->{copiedRecords}){
    warn "inserting into db for ".scalar(@{$self->{copiedRecords}}). " copied records\n" if $self->getArg('mapOnly');
    $self->insertRecordsIntoDb($self->{copiedRecords}) unless $self->getArg('mapOnly'); 
  }

  $self->setResultDescr(<<"EOF");
    
Added $self->{featuresAdded} @{[ ($self->{featuresAdded} == 1) ? 'feature':'features' ]} and $self->{summariesAdded} @{[ ($self->{summariesAdded} == 1) ? 'summary':'summaries' ]}.
Skipped $self->{summariesSkipped} @{[ ($self->{summariesSkipped} == 1) ? 'summary':'summaries' ]}.
EOF
}

sub initRecord {
  my ($self, $ln, $record) = @_;
    
  ( $record->{proteinId},
    $record->{description},
    $record->{seqMolWt},
    $record->{seqPI},
    $record->{score},
    $record->{percentCoverage},
    $record->{sequenceCount},
    $record->{spectrumCount},
    $record->{sourcefile},
  ) = split "\t", $ln;
  # Try looking up a proper source_id and na_sequence_id. Mascot datasets
  # may contain matches to proteins for which we don't have records (and
  # therefore no na_feature_id) - we skip those.
  #    ($record->{sourceId}, $record->{naFeatureId}, $record->{naSequenceId}) = 
  #        $self->getSourceNaFeatureNaSequenceIds($record->{proteinId}, 
  #                                         $record->{description});
  #
  #    ($record->{aaSequenceId}) = 
  #        $self->getAaSequenceId($record->{naFeatureId}) 
  #        if ($record->{naFeatureId});

  return $record;
}

sub getSourceNaFeatureNaSequenceIds {
  my ($self, @candidate_ids) = @_;
    
  # in a hetergeneous data set (old Wastling data for example)
  # we need to fish for the correct record, if any.
  my $sth = $self->getQueryHandle()->prepare(<<"EOSQL");
        select m.source_id, m.na_feature_id, m.na_sequence_id
        from dots.miscellaneous m
        where (m.source_id = ?
           or  m.source_id = ?
           or  m.source_id like ?
           or  m.source_id like ?)
        union
        select g.source_id, taf.na_feature_id, t.na_sequence_id
        from dots.translatedaafeature taf,
             dots.genefeature g,
             dots.transcript t
        where taf.na_feature_id = t.na_feature_id
          and t.parent_id = g.na_feature_id 
          and (g.source_id  = ?
           or  g.source_id  = ?
           or  t.protein_id = ?
           or  t.protein_id = ?)
EOSQL

  $sth->execute(
                $candidate_ids[0], $candidate_ids[1], # look for orf by source_id
                ($candidate_ids[0]) ? $candidate_ids[0].'%' : '', # orf id may be
                ($candidate_ids[1]) ? $candidate_ids[1].'%' : '', # truncated a little
                $candidate_ids[0], $candidate_ids[1], # look for gene by source_id
                $candidate_ids[0], $candidate_ids[1], # look for gene by protein_id
               );
    
  my $res = $sth->fetchall_arrayref();
    
  if (scalar @{$res} > 1) {
    warn "$candidate_ids[0] returns more than one row. This protein will be skipped.\n"
  }
    
  return undef if (scalar @{$res} != 1);

  return ($res->[0]->[0], $res->[0]->[1], $res->[0]->[2]);
}

sub getAaSequenceId {
  my ($self, $naFeatureId) = @_;
  my $transcript = GUS::Model::DoTS::Transcript->new({ na_feature_id => $naFeatureId});
  unless ($transcript->retrieveFromDB()) {
    my $transcript = GUS::Model::DoTS::Miscellaneous->new({ na_feature_id => $naFeatureId});
    unless ($transcript->retrieveFromDB()) {
      $self->error(
                   "No GeneFeature or Miscellaneous row with na_feature_id = $naFeatureId\n");
    }
  }

  my $translatedAAFeature = $transcript->getChild("DoTS::TranslatedAAFeature", 1);

  my $aaSeq = GUS::Model::DoTS::TranslatedAASequence->new({
                                                           aa_sequence_id => $translatedAAFeature->getAaSequenceId()
                                                          });
  $aaSeq->retrieveFromDB or $self->error("No aa_sequence_id for na_feature_id = '$naFeatureId'");

  my $id = $aaSeq->getId();
    
  return $id;
}

## need to assign to official gene model if possible
## map peptides onto gene
## also setDescription of peptides
## have multiple identifiers (source_id, split("|",description))
##if none are the official annot then get overlapping genes and see if all peptides map
sub addRecordsToGenes { 
  my ($self, $recordSet) = @_;
  foreach my $record (@{$recordSet}) {
    my $official = 0;
    my @gf;
    foreach my $id ($record->{proteinId},split(/\|/,$record->{description})) {
      my $naFeature = GUS::Model::DoTS::NAFeature->new({'source_id' => $id}); 
      if ($naFeature->retrieveFromDB()) {
        if ($naFeature->getExternalDatabaseReleaseId() == $self->{geneExtDbRlsId} ) {
          ##this one is the official one ...
          $official = $naFeature;
          warn "Found GeneFeature for $id\n";
          last;
        }
        push(@gf,$naFeature);
      } 
    }
    if (!$official) { ##need to map using nalocations
      foreach my $naf (@gf) {
        my($gene_id,$perc) = $self->getGeneFromNaFeatureId($record, $naf->getNaFeatureId());
        if($perc == 100){  ##perfect match ..
          $official = GUS::Model::DoTS::GeneFeature->new({ 'na_feature_id' => $gene_id });
          $official->retrieveFromDB();
          warn "Able to map $record->{proteinId} to ".$official->getSourceId()."\n";
          last;
        }
      }
    }
   
    if (!$official) { ##failed finding an official gene model to map these to try testing all proteins
      $official = $self->testPeptidesAgainstAllProteins($record);
      if(ref($official) =~ /array/i){  #hit more than one protein
        my $first = shift(@$official);
        foreach my $f (@$official){
          $self->copyRecord($record,$f);
        }
        $official = $first;
      }
    }
    ##here want to map to the overlapping official annotation that has the most peptides mapping to it
    ##must have at least 50% by default
    if (!$official) { 
      my @m;
      foreach my $naf (@gf){
         my($gene_id,$perc) = $self->getGeneFromNaFeatureId($record, $naf->getNaFeatureId());
         push(@m,[$gene_id,$perc,$naf]);
      }
      my @sortm = sort { $b->[1] <=> $a->[1] } @m;
      if($sortm[0]->[1] >= $self->{minPepToMatch}){ ##have matched to this gene ... make it  official
        ## need to copy the record so that can also make a record for this feature
        $official = GUS::Model::DoTS::GeneFeature->new({ 'na_feature_id' => $sortm[0]->[0]});
        $official->retrieveFromDB();
        warn "Able to map $record->{proteinId} to ".$official->getSourceId()." at $sortm[0]->[1]\% of ".scalar(@{$record->{peptides}})." peptides matching\n";
        warn "Copying record for $record->{proteinId} so can insert peptides for ".$sortm[0]->[2]->getSourceId()."\n";
        $self->copyRecord($record,$sortm[0]->[2]);
      }
    }
    
    if (!$official) { ##failed finding an official gene model to map these to ...
      ##NOTE: should check to see if one of the @gf is an orf and if so then go ahead and use it
      foreach my $feat (@gf) {
        if ($self->isOrf($feat)) {
          $official = $feat if $self->checkThatAllPeptidesMatch($record,$self->getAASequenceForGene($feat));
          last;
        }
      }
    }
    if (!$self->getArg('doNotTestOrfs') && !$official) { ##failed finding an official gene model to map these to try testing all orfs >= 100 aa then 50 - 100 aa
      $official = $self->testPeptidesAgainstAllOrfs($record);
      if(ref($official) =~ /array/i){  #hit more than one orf 
        my $first = shift(@$official);
        foreach my $f (@$official){
          $self->copyRecord($record,$f);
        }
        $official = $first;
      }
    }

    ##want to assign to a genemodel even if not an official one if still haven't found an official one!!
    if(!$official){
      foreach my $naf (@gf){
        if($self->checkThatAllPeptidesMatch($record,$self->getAASequenceForGene($naf))){
          $official = $naf;
          warn "Unable to locate official gene model for $record->{proteinId} so using ".$naf->getSourceId()."\n";
          last;
        }
      }
    }

    ##lastly, check against predicted gene models
    if(!$official && $self->getArg('testPredictedGeneModels')){
      $official = $self->testPeptidesAgainstPredictedGeneModels($record);
    }
    
    if (!$official) {
      warn "Unable to find gene or ORF for $record->{proteinId} (".scalar(@{$record->{peptides}})." peptides)... discarding\n";
      $record->{failed} = 1;
      next;
    }
    ##need to map the peptides and set the identifiers ....
    $self->mapPeptidesAndSetIdentifiers($record,$official);
    $self->undefPointerCache();
  } 
}

sub mapPeptidesAndSetIdentifiers {
  my($self,$record,$gf) = @_;
  ($record->{sourceId}, $record->{naFeatureId}, $record->{naSequenceId}, 
   $record->{aaSequenceId}, $record->{aaFeatParentId}) =
     $self->getRecordIdentifiers($gf);
  my $pSeq = $self->getAASequenceForGene($gf);
  foreach my $pep (@{$record->{peptides}}) {
    if ($self->setPepStartEnd($pep,$pSeq) == 0) {
      warn "$pep->{sequence} not found on $record->{sourceId}. Discarding this peptide...\n";
      $pep->{failed} = 1;
      $record->{sequenceCount}--;
      $record->{spectrumCount}--;  ## this crude as multiple spectra could have gone into this peptide
    }
    $self->setPepDescription($pep,$record);
  }
}

sub copyRecord {
  my($self,$record,$naf) = @_;
  my %copy = %$record;
  undef $copy{peptides};
  foreach my $pep (@{$record->{peptides}}){
    my %cp = %$pep;
    push(@{$copy{peptides}},\%cp);
  }
  my $recordCopy = \%copy;
  $self->mapPeptidesAndSetIdentifiers($recordCopy,$naf);
  push(@{$self->{copiedRecords}},$recordCopy);
}

##return genefeature if only one protein contains all peptides ...
sub testPeptidesAgainstAllProteins {
  my($self,$record) = @_;
  my @matches;
  foreach my $prot ($self->getAllProteins()){
    push(@matches,$prot) if $self->checkThatAllPeptidesMatch($record,$prot->[1]);
  }
  if(scalar(@matches == 1)){
    my $gf = GUS::Model::DoTS::GeneFeature->new({ 'na_feature_id' => $matches[0]->[0] });
    $gf->retrieveFromDB();
    warn "Able to uniquely map all peptides from $record->{proteinId} to ".$gf->getSourceId()."\n";
    return $gf;
  }elsif(scalar(@matches) > 1 && scalar(@matches) <= 20){
    warn "Peptides from $record->{proteinId} map to ".scalar(@matches)." proteins ... adding to each\n";
    return $self->getNafeatureObjsFromIds(\@matches);  
  }
  return undef;
}

sub testPeptidesAgainstAllOrfs {
  my($self,$record) = @_;
  return unless scalar(@{$record->{peptides}}) > 0; ##don't test if there are no peptides
  my @matches;
  foreach my $prot ($self->getGt100aaOrfs()){
    push(@matches,$prot) if $self->checkThatAllPeptidesMatch($record,$prot->[1]);
  }
#  if(scalar(@matches == 1)){
#    my $orf = GUS::Model::DoTS::NAFeature->new({ 'na_feature_id' => $matches[0]->[0] });
#    $orf->retrieveFromDB();
#    warn "Able to uniquely map all peptides from $record->{proteinId} to ORF ".$orf->getSourceId()."\n";
#    return $orf;
#  }
  foreach my $prot ($self->get50to100aaOrfs()){
    push(@matches,$prot) if $self->checkThatAllPeptidesMatch($record,$prot->[1]);
  }
  if(scalar(@matches == 1)){
    my $orf = GUS::Model::DoTS::NAFeature->new({ 'na_feature_id' => $matches[0]->[0] });
    $orf->retrieveFromDB();
    warn "Able to uniquely map all peptides from $record->{proteinId} to ORF ".$orf->getSourceId()."\n";
    return $orf;
  }elsif(scalar(@matches) > 1 && scalar(@matches) <= 20){
    warn "Peptides from $record->{proteinId} map to ".scalar(@matches)." ORFs ...\n";
    return $self->getNafeatureObjsFromIds(\@matches);  
  }
  return undef;
}

sub getNafeatureObjsFromIds {
  my($self,$ids) = @_;
  my @tmp;
  foreach my $id (@$ids){
    my $naf = GUS::Model::DoTS::NAFeature->new({ 'na_feature_id' => ref($id) =~ /array/i ? $id->[0] : $id });
    push(@tmp,$naf) if $naf->retrieveFromDB();
  }
  return \@tmp;
}

sub testPeptidesAgainstPredictedGeneModels {
  my($self,$record) = @_;
  my @matches;
  foreach my $prot ($self->getAllPredProteins()){
    push(@matches,$prot) if $self->checkThatAllPeptidesMatch($record,$prot->[1]);
  }
  if(scalar(@matches >= 1)){  ##there can be multiple overlapping models so more than one could be correct
    my $gf = GUS::Model::DoTS::GeneFeature->new({ 'na_feature_id' => $matches[0]->[0] });
    $gf->retrieveFromDB();
    warn "Able to map all peptides from $record->{proteinId} to predicted gene ".$gf->getSourceId()."\n";
    return $gf;
  }
  return undef;
}

sub getGt100aaOrfs {
  my($self) = @_;
  if(!$self->{all100Orfs}){
    warn "Retrieving all ORFS > 100 aa\n";
    my $orfStmt =  $self->getQueryHandle()->prepare(<<"EOSQL");
      select f.na_feature_id,aas.sequence
      from dots.nafeature f, sres.SEQUENCEONTOLOGY o, dots.translatedaafeature aaf, 
        dots.translatedaasequence aas,dots.nasequence s
      where s.external_database_release_id = $self->{geneExtDbRlsId} 
      and s.na_sequence_id = f.na_sequence_id
      and f.sequence_ontology_id = o.sequence_ontology_id
      and o.term_name = 'ORF'
      and aaf.na_feature_id = f.na_feature_id
      and aas.aa_sequence_id = aaf.aa_sequence_id
      and aas.length >= 100
EOSQL
    $orfStmt->execute();
    my $ct = 0;
    while(my $row = $orfStmt->fetchrow_arrayref()){
      warn "Processing $ct ORFS\n" if $ct++ % 20000 == 0;
      push(@{$self->{all100Orfs}},[$row->[0],$row->[1]]);
    }
    warn "Cached ".scalar(@{$self->{all100Orfs}})." Orfs from ".$self->getArg('geneExternalDatabaseSpec')." gene models\n";
  }
  return @{$self->{all100Orfs}};
}

sub get50to100aaOrfs {
  my($self) = @_;
  if(!$self->{all50to100Orfs}){
    warn "Retrieving all ORFS 50to100 aa\n";
    my $orfStmt =  $self->getQueryHandle()->prepare(<<"EOSQL");
      select f.na_feature_id,aas.sequence
      from dots.nafeature f, sres.SEQUENCEONTOLOGY o, dots.translatedaafeature aaf, 
        dots.translatedaasequence aas,dots.nasequence s
      where s.external_database_release_id = $self->{geneExtDbRlsId} 
      and s.na_sequence_id = f.na_sequence_id
      and f.sequence_ontology_id = o.sequence_ontology_id
      and o.term_name = 'ORF'
      and aaf.na_feature_id = f.na_feature_id
      and aas.aa_sequence_id = aaf.aa_sequence_id
      and aas.length < 100
      and aas.length >= 50
EOSQL
    $orfStmt->execute();
    my $ct = 0;
    while(my $row = $orfStmt->fetchrow_arrayref()){
      warn "Processing $ct ORFS\n" if $ct++ % 20000 == 0;
      push(@{$self->{all50to100Orfs}},[$row->[0],$row->[1]]);
    }
    warn "Cached ".scalar(@{$self->{all50to100Orfs}})." Orfs from ".$self->getArg('geneExternalDatabaseSpec')." gene models\n";
  }
  return @{$self->{all50to100Orfs}};
}

sub getAllProteins {
  my($self) = @_;
  if(!$self->{allProteins}){
    warn "Retrieving all Proteins\n";
    my $protStmt =  $self->getQueryHandle()->prepare(<<"EOSQL");
      select gf.na_feature_id,aas.sequence
      from dots.genefeature gf, dots.transcript t, dots.translatedaafeature taaf, dots.translatedaasequence aas
      where gf.external_database_release_id = $self->{geneExtDbRlsId}
      and gf.na_feature_id = t.parent_id
      and taaf.na_feature_id = t.na_feature_id
      and aas.aa_sequence_id = taaf.aa_sequence_id
EOSQL
    $protStmt->execute();
    while(my $row = $protStmt->fetchrow_arrayref()){
      push(@{$self->{allProteins}},[$row->[0],$row->[1]]);
    }
    warn "Cached ".scalar(@{$self->{allProteins}})." proteins from ".$self->getArg('geneExternalDatabaseSpec')." gene models\n";
  }
  return @{$self->{allProteins}};
}

sub getAllPredProteins {
  my($self) = @_;
  if(!$self->{predProteins}){
    warn "Retrieving pred Proteins\n";
    my $protStmt =  $self->getQueryHandle()->prepare(<<"EOSQL");
      select gf.na_feature_id,aas.sequence
      from dots.genefeature gf, dots.transcript t, dots.translatedaafeature taaf, dots.translatedaasequence aas,sres.sequenceontology o
      where o.term_name = 'protein_coding'
      and o.sequence_ontology_id = gf.sequence_ontology_id
      and gf.external_database_release_id != $self->{geneExtDbRlsId}
      and gf.na_feature_id = t.parent_id
      and taaf.na_feature_id = t.na_feature_id
      and aas.aa_sequence_id = taaf.aa_sequence_id
EOSQL
    $protStmt->execute();
    while(my $row = $protStmt->fetchrow_arrayref()){
      push(@{$self->{predProteins}},[$row->[0],$row->[1]]);
    }
    warn "Cached ".scalar(@{$self->{predProteins}})." proteins from predicted gene models\n";
  }
  return @{$self->{predProteins}};
}

sub getAASequenceForGene {
  my($self,$gf) = @_;
  my $taaf = $self->isOrf($gf) ? $gf->getChild('DoTS::TranslatedAAFeature',1) :
    $gf->getChild('DoTS::Transcript',1)->getChild('DoTS::TranslatedAAFeature',1);
  return unless $taaf;
  my $seq = $taaf->getParent('DoTS::TranslatedAASequence',1);
  return $seq->get('sequence'); ##so doesn't get from nafeature if null as we are using Transcript rather than RNAFeature
}

sub getRecordIdentifiers {
  my($self,$gf) = @_;
  my $transAAFeat = $self->isOrf($gf) ? $gf->getChild('DoTS::TranslatedAAFeature',1) :
    $gf->getChild('DoTS::Transcript',1)->getChild('DoTS::TranslatedAAFeature',1);
  return($gf->getSourceId(),$gf->getNaFeatureId(),$gf->getNaSequenceId(),$transAAFeat->getAaSequenceId(),$transAAFeat->getAaFeatureId());
}

sub prepareSQLStatements {
  my($self) = @_;
  $self->{mapStmt} = $self->getQueryHandle()->prepare(<<"EOSQL");
        select gf.na_feature_id, taas.sequence, gf.external_database_release_id
        from
        dots.nafeature orf,
        dots.genefeature gf,
        dots.transcript t,
        dots.nalocation gfnal,
        dots.nalocation orfnal,
        dots.translatedaafeature taaf,
        dots.translatedaasequence taas
        where
        orf.na_feature_id = ?
        and gf.na_feature_id = gfnal.na_feature_id
        and orf.na_feature_id = orfnal.na_feature_id
        and orf.na_sequence_id = gf.na_sequence_id
        and gfnal.start_min <= orfnal.end_max
        and gfnal.end_max >= orfnal.start_min
        and gf.external_database_release_id = $self->{geneExtDbRlsId}  
        and gf.na_feature_id = t.parent_id
        and t.na_feature_id = taaf.na_feature_id
        and taaf.aa_sequence_id = taas.aa_sequence_id
        and orfnal.is_reversed = gfnal.is_reversed
EOSQL
}

sub getGeneFromNaFeatureId {
  my ($self, $record, $naFeatureId) = @_;
  # Given an nafeature, find gene it belongs to:
  #    Find gene whose coordinates overlap with feature.
  #    Declare match if all peptide seqs are substrings of protein seq.
  #       Strictly, an feature may not wholly belong to the gene model, but if
  #       all the peptides match then we have the gene we are really after.

#  warn "getGeneFromNaFeatureid ... na_feature_id = $naFeatureId\n";
  
  $self->{mapStmt}->execute($naFeatureId);
  my $res = $self->{mapStmt}->fetchall_arrayref();
  return unless scalar(@$res) > 0;
  my @tmp;
  foreach my $a (@$res){
    push(@tmp,[$a->[0],$self->checkThatPeptidesMatch($record,$a->[1])]);
  }
  my @sort = sort { $b->[1] <=> $a->[1] } @tmp;
  return ($sort[0]->[0],$sort[0]->[1]);
}

sub checkThatAllPeptidesMatch {
  my($self,$record,$protSeq) = @_;
  foreach my $pep (@{$record->{peptides}}) {
    return 0 unless $protSeq =~ /$pep->{sequence}/i;
  }
  return 1;
}

sub checkThatPeptidesMatch {
  my($self,$record,$protSeq) = @_;
  my $num = scalar(@{$record->{peptides}});
  return 0 unless $num;  ##avoid erroneous div by 0
  my $ct = 0;
  foreach my $pep (@{$record->{peptides}}) {
    $ct++ if $protSeq =~ /$pep->{sequence}/i;
  }
  return int(0.5 + ($ct / $num * 100));
}
sub isOrf {
  my ($self,$naFeature) = @_;

#  my $naFeature;
#  if(ref($naFeatureId) !~ /hash/i){
#    $naFeature = GUS::Model::DoTS::NAFeature->new({'na_feature_id' => $naFeatureId}); 
#    $naFeature->retrieveFromDB() || die "Failed to retrieve na_feature_id '$naFeatureId'";;
#  }else{
#    $naFeature = $naFeatureId;
#  }
  my $ont = $naFeature->getParent("SRes::SequenceOntology",1);
  return ($ont && $ont->getTermName() =~ /orf/i);
}

sub addMassSpecFeatureToRecord {
  my ($self, $ln, $record) = @_;
    
  my $pep = {};
  ( $pep->{start},
    $pep->{end},
    $pep->{observed},
    $pep->{mr_expect},
    $pep->{mr_calc},
    $pep->{delta},
    $pep->{miss},
    $pep->{sequence},
    $pep->{modification},
    $pep->{query},
    $pep->{hit},
    $pep->{ions_score}
  ) = split "\t", $ln;

  #    $self->setPepStartEnd($pep, $record->{aaSequenceId}) if (!$pep->{start} or !$pep->{end});
    
  #    if ($pep->{start} == 0) {
  #        warn "$pep->{sequence} not found on $record->{sourceId}. Discarding this peptide...\n";
  #        return;
  #    }


  push @{$record->{peptides}}, $pep;
}

sub setPepDescription {
  my($self,$pep,$record) = @_;
  $pep->{description} = join '', (
                                  ($record->{sourceId} && "match: $record->{sourceId}\n"),
                                  ($pep->{ions_score} && "score: $pep->{ions_score}\n"),
                                  ($pep->{modification} && "modification: $pep->{modification}\n"),
                                  ($record->{sourcefile} && "report: '$record->{sourcefile}\n")
                                 );
}

sub setPepStartEnd {
  my ($self, $pep, $proteinSeq) = @_;
  $pep->{start} = index($proteinSeq, $pep->{sequence}) +1;
  $pep->{end} = length($pep->{sequence}) + $pep->{start} -1;
  return $pep->{start};         ##will be 0 if failed ...
}

sub insertRecordsIntoDb {
  my ($self, $recordSet) = @_;
  warn "Inserting records into the db for ".scalar(@{$recordSet})." records\n";
  my $ct = 0;
  for my $record (@{$recordSet}) {
    warn "processing record $ct\n" if $ct++ % 50 == 0;
    if (!defined $record || $record->{failed}) {
      $self->{summariesSkipped}++;
      next;
    }
    my $mss = $self->insertMassSpecSummary($record);
    $self->insertMassSpecFeatures($record, $mss);
    $self->undefPointerCache();
  }
}


sub insertMassSpecSummary {
  my ($self, $record) = @_;
    
  my $aaSeq = GUS::Model::DoTS::TranslatedAASequence->new({
                                                           aa_sequence_id => $record->{aaSequenceId}
                                                          });
  $aaSeq->retrieveFromDB;

  $record->{seqLength}    = $aaSeq->getLength();
  $record->{devStage}     = $self->getArg('developmentalStage') || 'unknown';

  ## want to load the number of distinct peptides as the number_of_spans
  my %peps;
  foreach my $pep (@{$record->{peptides}}) {
    next if $pep->{failed};
    $peps{"$pep->{start}"."$pep->{end}"} = 1;
  }

  my $mss = GUS::Model::ApiDB::MassSpecSummary->new({
                                                     'aa_sequence_id'                => $record->{aaSequenceId},
                                                     'is_expressed'                  => 1,
                                                     'developmental_stage'           => $record->{devStage},
                                                     'sequence_count'                => $record->{sequenceCount},
                                                     'number_of_spans'                => scalar(keys%peps),
                                                     'prediction_algorithm_id'       => $self->getPredictionAlgId,
                                                     'spectrum_count'                => $record->{spectrumCount},
                                                     'aa_seq_length'                 => $record->{seqLength},
                                                     'aa_seq_molecular_weight'       => $record->{seqMolWt},
                                                     'aa_seq_pi'                     => $record->{seqPI},
                                                     'aa_seq_percent_covered'        => $self->computeSequenceCoverage($record),
                                                     'external_database_release_id'  => $self->{extDbRlsId},
                                                    });

  $mss->submit();
  $self->{summariesAdded}++;
    
  return $mss;
}

sub computeSequenceCoverage {
  my($self,$record) = @_;
  my $cov = 0;
  my $prev;
  foreach my $pep (sort{$a->{start} <=> $b->{start}} @{$record->{peptides}}) {
    next if $pep->{failed};
    next if $prev && $pep->{end} <= $prev->{end};  #contained within ... nothing new
    $cov += !$prev || $pep->{start} > $prev->{end} ? $pep->{end} - $pep->{start} + 1 : $pep->{end} - $prev->{end};
    $prev = $pep;
  }
  return int($cov / $record->{seqLength} * 1000) / 10;
}

sub insertMassSpecFeatures {
  my ($self, $record, $mss) = @_;
    
  my $ct;
  for my $pep (@{$record->{peptides}}) {
    next if $pep->{failed};
    $ct++;
        
    my $msFeature = GUS::Model::DoTS::MassSpecFeature->new({
                                                            'aa_sequence_id'          => $record->{aaSequenceId},
                                                            'parent_id'               => $record->{aaFeatParentId},
                                                            'prediction_algorithm_id' => $self->getPredictionAlgId,
                                                            'external_database_release_id' => $self->{extDbRlsId},
                                                            'developmental_stage'     => $record->{devStage},
                                                            'description'             => $pep->{description},
                                                            'source_id'               => $mss->getMassSpecSummaryId,
                                                            'is_predicted'            => 1,
                                                           });
        
    my $aaLoc = GUS::Model::DoTS::AALocation->new({
                                                   'start_min' => $pep->{start},
                                                   'start_max' => $pep->{start},
                                                   'end_min'   => $pep->{end},
                                                   'end_max'   => $pep->{end},
                                                  });
    
    my $naLoc = $self->addNALocation(
                                     $record->{sourceId}."-ms.$ct", 
                                     $record->{naFeatureId},
                                     $record->{naSequenceId},
                                     $pep
                                    );
        
    next if ! $naLoc;           # peptide not found on protein 
    # (eg. annotation changed since analysis)
        
    $msFeature->setParent($naLoc);
    $msFeature->addChild($aaLoc);    
        
    $msFeature->submit();
        
    $self->{featuresAdded}++;
  }

}

sub addNALocation {
  my ($self, $sourceId, $naFeatureId, $naSequenceId, $pep) = @_;

  if (! $pep->{start} and ! $pep->{end}) {
    $self->error("pepStart and pepEnd coordinates not available for $sourceId");
  }

  my $naLocations = $self->mapToNASequence(
                                           $naFeatureId, $pep->{start}, $pep->{end}
                                          );
    
  if (! $naLocations) {
    warn "Peptide at $pep->{start}..$pep->{end} not found on $sourceId. Discarding this peptide...\n";
    return undef;
  }
    
  my $naFeature = GUS::Model::DoTS::NAFeature->new({
                                                    na_sequence_id                  => $naSequenceId,
                                                    name                            => 'located_sequence_feature',
                                                    external_database_release_id    => $self->{extDbRlsId},
                                                    source_id                       => $sourceId,
                                                    prediction_algorithm_id         => $self->getPredictionAlgId,
                                                   });

  foreach (@$naLocations) {
    $naFeature->addChild(
                         GUS::Model::DoTS::NALocation->new({
                                                            'start_min'   => $_->[0],
                                                            'start_max'   => $_->[0],
                                                            'end_min'     => $_->[1],
                                                            'end_max'     => $_->[1],
                                                            'is_reversed' => $_->[2] == -1 ? 1 : 0,
                                                           })
                        );
  }
  $naFeature->submit();
  return $naFeature;
}

sub mapToNASequence {
  my ($self, $naFeatureId, $pepStart, $pepEnd) = @_;
  my $naLocations = [];

  my $exons = $self->getExons($naFeatureId) or $self->error("no exons for na_feature_id '$naFeatureId'\n");

  # CDS in chromosome coordinates
  my $cds = new Bio::Location::Split;
  foreach (@{$exons}) {
    $cds->add_sub_Location(new Bio::Location::Simple(
                                                     -start  =>  @$_[0],
                                                     -end    =>  @$_[1],
                                                     -strand =>  @$_[2]
                                                    ));
  }

  my $gene = Bio::Coordinate::GeneMapper->new(
                                              -in    => 'peptide',
                                              -out   => 'chr',
                                              -exons => [$cds->sub_Location],
                                             );


  my $peptideCoords = Bio::Location::Simple->new (
                                                  -start => $pepStart,
                                                  -end   => $pepEnd,
                                                 );

  my $map = $gene->map($peptideCoords);
    
  return undef if ! $map;
    
  foreach (sort { $a->start <=> $b->start } $map->each_Location ) {
    push @$naLocations, [$_->start, $_->end, $_->strand];
  }

  return $naLocations;
}

# duplicate records have same na_feature_id and same set of peptide sequences
# and are from the same sourcefile.
sub pruneDuplicateAndEmptyRecords {
  my ($self, $recordSet) = @_;
  my %seen;
  my $i = 0;
 REC:
  for (my $i=0; $i < @{$recordSet}; $i++) {
    my $r = @{$recordSet}[$i];
        
    if (scalar @{$r->{peptides}} == 0) {
      warn "$r->{sourceId} has no peptides. removing.\n";
      next REC;
    }

    if (my $existingRec = $seen{$r->{naFeatureId}}) {

      my @oldSeqs = map {$_->{sequence}} @{$existingRec->{peptides}};
      sort @oldSeqs;

      my @newSeqs = map {$_->{sequence}} @{$r->{peptides}};
      sort @newSeqs;

      next REC if (
                   (scalar @oldSeqs != scalar @newSeqs) or
                   ($existingRec->{sourcefile} ne $r->{sourcefile}
                    && !$existingRec->{orfId} && !$r->{orfId})
                  );

      for (my $i=0; $i < @newSeqs; $i++) {
        next REC if ($oldSeqs[$i] ne $newSeqs[$i]);
      }

      warn "record $i ($r->{sourceId}) is duplicate; removing.\n" if $self->getArg('veryVerbose');
      delete $recordSet->[$i];
    } else {
      $seen{$r->{naFeatureId}} = $r;
    }
  }
}



# Return AoA ref of exon coordinates for the encoding NA seq. An ORF has one 'exon'.
# ORFs are assumed to not have an exonfeature. So some fishing is required.
sub getExons {
  my ($self, $id) = @_;
  my @exons; my $exonCoords = [];
  my $exonParent;
    
  my $gf = GUS::Model::DoTS::GeneFeature->new({ na_feature_id => $id });
  if ($gf->retrieveFromDB()) {
    # is a gene
    $exonParent = $gf;
    @exons = $gf->getChildren("DoTS::ExonFeature", 1);
  } else {
    # should be an orf
    $exonParent = GUS::Model::DoTS::NAFeature->new({ na_feature_id => $id });
    unless ($exonParent->retrieveFromDB()) {
      $self->logVerbose(
                        "No Transcript or Miscellaneous row was fetched with na_feature_id = $id\n");
      return undef;
    }
    @exons = ($exonParent);
  }


  unless (@exons) {
    $self->error(<<"EOF")
      Can not find an exon/CDS for transcript $id.
      Can't map its peptide hits to the chromosome.\n
EOF
  }

  for my $exon (@exons) {
    my ($exonStart, $exonEnd, $exonIsReversed) = $exon->getFeatureLocation();

    my $codingStart = ($exon->isValidAttribute('coding_start')) ?
      $exon->getCodingStart() || $exonStart :
        $exonStart;

    my $codingEnd = ($exon->isValidAttribute('coding_end')) ?
      $exon->getCodingEnd() || $exonEnd :
        $exonEnd;

    my $strand = ($exonIsReversed) ? -1 : 1;
        
    ($codingStart > $codingEnd) && 
      (($codingStart, $codingEnd) = ($codingEnd, $codingStart));

    push @$exonCoords, [$codingStart, $codingEnd, $strand];
  }
  return $exonCoords;
}

sub getPredictionAlgId {
  my ($self) = @_;
  $self->{predictionAlgId} and return $self->{predictionAlgId};
  my $pid = GUS::Model::Core::Algorithm->
    new({ name        => 'Mascot',
          description => 'Matrix Science mass spectrometry search' });

  $pid->submit() unless $pid->retrieveFromDB();
  $self->{predictionAlgId} = $pid->getId;
}

sub nextRecord {
  my ($self, $fileptr) = @_;
  my $pos;
  my $ln = readline $fileptr;
  while ($ln && $ln !~ m/^# /) {
    $pos = tell $fileptr;
    $ln = readline $fileptr;
  }
  seek($fileptr, $pos, 0);
}

#######################################################################
#######################################################################

sub declareArgs {
  [

   fileArg({
            name            =>  'inputFile',
            descr           =>  'Name of file containing the mass spec features',
            constraintFunc  =>  undef,
            reqd            =>  1,
            isList          =>  0,
            mustExist       =>  1,
            format          =>  'Text'
           }),

   stringArg({
              name            =>  'externalDatabaseSpec', # For proteome
              descr           =>  'external database release `name|version` for these data',
              constraintFunc  =>  undef,
              reqd            =>  1,
              isList          =>  0
             }),

   integerArg({
              name            =>  'minPercentPeptidesToMap', # For proteome
              descr           =>  'Minimum percent of peptides that must match a gene to consider a match [50]',
              constraintFunc  =>  undef,
              reqd            =>  0,
              isList          =>  0
             }),

   stringArg({
               name            =>  'geneExternalDatabaseSpec', 
               descr           =>  'External Databzse release `name|version` for the gene models to which will be attaching these peptides',
               constraintFunc  =>  undef,
               reqd            =>  1,
               isList          =>  0
              }),

   booleanArg({
               name            =>  'doNotTestOrfs', 
               descr           =>  'if true then do not retrieve all orfs and test peptides against them.',
               reqd            =>  0,
               isList          =>  0
              }),

   booleanArg({
               name            =>  'testPredictedGeneModels', 
               descr           =>  'if true then tests peptides against predicted gene models if can not assign elsewhere.',
               reqd            =>  0,
               isList          =>  0
              }),

   booleanArg({
               name            =>  'mapOnly', 
               descr           =>  'Only map the features onto existing and print log statements ... do not insert into the db.',
               reqd            =>  0,
               isList          =>  0
              }),

   stringArg({
              name            =>  'developmentalStage',
              descr           =>  'organism developmental stage analyzed',
              constraintFunc  =>  undef,
              reqd            =>  0,
              isList          =>  0
             }),

  ];

}

sub undoTables {
  qw(
    ApiDB.MassSpecSummary
    DoTS.AALocation
    DoTS.MassSpecFeature
    DoTS.NALocation
    DoTS.NAFeature
    Core.AlgorithmParam
    Core.AlgorithmInvocation
    );
}


sub getDocumentation {
  my $purpose = <<PURPOSE;
Load tab delimited data culled from Mascot Protein Views.
Genome NaLocations corresponding to the peptides will be added iff sequence 
ontologies are set for protein sequences. This iteration trolls for genefeatures
from old releases and maps the peptides onto the current genefeatures
PURPOSE

  my $purposeBrief = <<PURPOSEBRIEF;
Load tab delimited data culled from Mascot Protein Views.
PURPOSEBRIEF

  my $notes = <<NOTES;

One MassSpecFeature is created for each peptide entry in the file. Even when
two peptides have the same sequence and map to the same location they are 
treated as two features because they were derived from different analyses.

Open reading frame reports are converted to genes when possible 
and the orf-associated peptide coordinates are adjusted.

BPB change:  the description contains additional identifiers delimited by '|'

Sample tab-delimited input:
# source_id	description	seqMolWt	seqPI	score	percentCoverage	sequenceCount	spectrumCount	sourcefile
Liv008927	AAEL01000002-1-20221-21813	60509	4.82	117	3	2	2	CrypProt LTQ spot k2 Protein View.htm
## start	end	observed	mr_expect	mr_calc	delta	miss	sequence	modification	query	hit	ions_score
301	309	530.12	1058.23	1057.54	0.69	0	VNADLLEER		11	1	88
311	320	588.39	1174.77	1175.59	-0.81	0	VLVGEMEIDR	Oxidation (M) 	14	1	29
# source_id	description	seqMolWt	seqPI	score	percentCoverage	sequenceCount	spectrumCount	sourcefile
Liv070540	AAEE01000003-3-1125870-1128359	92046	4.49	430	17	9	9	CrypProt LTQ spot L Protein View.htm
## start	end	observed	mr_expect	mr_calc	delta	miss	sequence	modification	query	hit	ions_score
79	85	422.79	843.57	842.44	1.13	0	LFGFFGR		8	1	30
164	182	648.42	1942.22	1940.88	1.35	0	SAPAPVAEHFDGESSSEPK		39	8	7
205	217	621.99	1241.96	1242.65	-0.68	0	GAIPGIVSEESGK		22	1	63
258	274	907.65	1813.28	1812.92	0.36	0	SLQEGLPESVVLNEGSR		36	1	91
387	409	839.66	2515.95	2516.07	-0.11	1	YLEDTADDSKEGSEASTADLEDR		50	1	43
462	468	439.03	876.04	876.47	-0.43	0	VPTEYIR		9	1	46
555	574	745.40	2233.16	2233.03	0.13	1	ESEVTNREESVSVPAEESQK		46	2	14
575	598	881.96	2642.85	2642.23	0.62	1	AAVESSVEEESEKPEELPDNNKGR		51	1	97
793	806	766.35	1530.69	1530.77	-0.08	0	NLLVSAPSQEQMAK	Oxidation (M) 	30	1	46

NOTES

  my $tablesAffected =
    [
     [
      'DoTS.AALocation' =>
      'Protein coordinate location of the mass spec feature (peptide)'
     ],
     [
      'DoTS.MassSpecFeature' =>
      'Mass spec predicted peptides'
     ],
     [
      'DoTS.MassSpecSummary' =>
      'Summary information from the protein hit in one Mascot Search Result. Has one or more MassSpecFeatures.'
     ],
     [
      'DoTS.NALocation' =>
      'Genomic coordinate location encoding a peptide.'
     ],
     [
      'DoTS.NAFeature' =>
      'NALocations are associated with MassSpecFeatures by NAFeature.'
     ],
     [
      'Core.Algorithm' =>
      'An entry for `Mascot` will be added if one does not already exist.'
     ],
    ];


  my $tablesDependedOn =
    [
     [
      'DoTS.Transcript' =>
      'Id of the matched protein is looked up in Transcript. If the id is not found then that Mascot search match is skipped.'
     ],
     [
      'DoTS.TranslatedAAFeature' =>
      'TranslatedAASequences are associated with Transcripts by TranslatedAAFeatures.'
     ],
     [
      'DoTS.TranslatedAASequence' =>
      'For protein sequence length.'
     ],
     [
      'SRes.SequenceOntology' =>
      'Used to distinguish ORF sequences from sequences which have ExonFeatures.'
     ],
    ];

  my $howToRestart = <<RESTART;
RESTART

  my $failureCases = <<FAIL;
The id of a matched protein must be in DoTS.Transcript.source_id otherwise
that match will be skipped.

Any ORF sequences must have a Sequence Ontology term name of 'ORF' otherwise
the mapping of peptide to genome will fail and all further processing will stop.

FAIL

  my $documentation = {
                       purpose          => $purpose,
                       purposeBrief     => $purposeBrief,
                       tablesAffected   => $tablesAffected,
                       tablesDependedOn => $tablesDependedOn,
                       howToRestart     => $howToRestart,
                       failureCases     => $failureCases,
                       notes            => $notes
                      };
}
1;

__END__

select aa_location_id, start_min, end_max, mss.MASS_SPEC_SUMMARY_ID
  from apidb.massspecsummary mss,
  dots.massspecfeature msf,
  dots.aalocation aal,
  dots.translatedaafeature taaf,
  dots.nafeature misc
  where mss.mass_spec_summary_id = msf.source_id
  and msf.aa_feature_id = aal.aa_feature_id
  and mss.aa_sequence_id = taaf.aa_sequence_id
  and taaf.na_feature_id = misc.na_feature_id
  and misc.source_id = 'AAEE01000014-3-77790-78011'


  select aa_location_id, start_min, end_max, mss.MASS_SPEC_SUMMARY_ID
  from apidb.massspecsummary mss,
  dots.massspecfeature msf,
  dots.aalocation aal,
  dots.translatedaafeature taaf,
  dots.transcript t,
  dots.genefeature gf
  where mss.mass_spec_summary_id = msf.source_id
  and msf.aa_feature_id = aal.aa_feature_id
  and mss.aa_sequence_id = taaf.aa_sequence_id
  and taaf.na_feature_id = t.na_feature_id
  and t.parent_id = gf.na_feature_id
  and gf.source_id = 'cgd3_1540'

 
  select na_location_id, start_min, end_max
  from apidb.massspecsummary mss,
  dots.massspecfeature msf,
  dots.nalocation nal,
  dots.translatedaasequence taas,
  dots.translatedaafeature taaf,
  dots.transcript t
  where mss.mass_spec_summary_id = msf.source_id
  and msf.nA_FEATURE_ID = nal.nA_FEATURE_ID
  and mss.aa_sequence_id = taas.aa_sequence_id
  and taas.aa_sequence_id = taaf.aa_sequence_id
  and taaf.na_feature_id = t.na_feature_id
  and t.source_id = 'AAEL01000400-5-3912-3475'



  MassSpecSummary ----------- Algorithm
  /|\                    /
  / | \                  /
  F  F  MassSpecFeature(F)
  |  |     |              \
  |  |     |               \ 
  L  L     AALocation(L)    \
  NAFeature
  /    |   \
  N     N    NALocation(N)  [may be split across intron]
                             
