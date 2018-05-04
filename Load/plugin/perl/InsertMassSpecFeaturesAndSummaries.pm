package ApiCommonData::Load::Plugin::InsertMassSpecFeaturesAndSummaries;
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | fixed
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
  # GUS4_STATUS | Rethink                        | auto   | fixed
  # GUS4_STATUS | dots.gene                      | manual | fixed
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

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
use GUS::Model::SRes::OntologyTerm;

# write to
use GUS::Model::DoTS::MassSpecFeature;
use GUS::Model::DoTS::AALocation;
use GUS::Model::DoTS::NAFeature; # Misc
use GUS::Model::DoTS::NALocation;
use GUS::Model::ApiDB::MassSpecSummary; # MassSpecResults??
use GUS::Model::DoTS::PostTranslationalModFeature;
use GUS::Model::Study::Study;
use GUS::Model::Study::StudyLink;
use GUS::Model::Study::ProtocolAppNode;

# utility
use Bio::Location::Split;
use Bio::Location::Simple;
use Bio::Coordinate::GeneMapper;
use GUS::Community::GeneModelLocations;

# debugging
use Data::Dumper;
use GUS::Supported::Util;

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self, $class);

  $self->initialize({
                     requiredDbVersion => 4.0,
                     cvsRevision       => '$Revision$',
                     name              => ref($self),
                     argsDeclaration   => declareArgs(),
                     documentation     => getDocumentation(),
                    });
  return $self;
}

sub run {
  my ($self) = @_;
  $self->{featuresAdded} = $self->{summariesAdded} = $self->{summariesSkipped} = 0;
  
  my @inputFiles;
  my $sampleConfig;
  my $inputFileDirectory = $self->getArg('inputDir');
  my $fileNameRegex = $self->getArg('fileNameRegex');

  my $dbiDb = $self->getDb();
  $dbiDb->setMaximumNumberOfObjects(100000);

  my $extDbSpec = $self->getArg('externalDatabaseSpec');
  $self->{extDbRlsId} = $self->getExtDbRlsId($extDbSpec);

  my $studyName = "Mass Spec Peptides from $extDbSpec";

  my $study = GUS::Model::Study::Study->new({name => $studyName, external_database_release_id => $self->{extDbRlsId}});

  my $protocolType = 'mass spectrometry analysis';
  my $ontologyTerm = GUS::Model::SRes::OntologyTerm->new({name => $protocolType});
  unless($ontologyTerm->retrieveFromDB()) {
    $self->error("Required Ontology Term $protocolType not found in database");
  }

  opendir (INDIR, $inputFileDirectory) or die "could not open $inputFileDirectory: $!/n";

  my $nodeNumber = 1;
  while (my $file = readdir(INDIR)) {
    next unless($file=~m/$fileNameRegex/);
    push(@inputFiles, $file);

    my $protocolAppNodeName = "$file (MS Summary)";

    my $protocolAppNode = GUS::Model::Study::ProtocolAppNode->new({name => $protocolAppNodeName, node_order_num => $nodeNumber, type_id => $ontologyTerm->getId()});
    $self->{_protocol_app_nodes}->{$file} = $protocolAppNode;

    my $studyLink = GUS::Model::Study::StudyLink->new();
    $studyLink->setParent($protocolAppNode);
    $studyLink->setParent($study);

    $nodeNumber++;
  }
  closedir INDIR;

  $study->submit();

  unless(scalar @inputFiles > 0) {
    $self->error("No files found in $inputFileDirectory matching the regex /$fileNameRegex/");
  }

  my $record = {};
  my $recordSet = [];
  my $mss;
  my $peptide;
  my $state;
    

  $self->{geneExtDbRlsId} = join ',', map{ $self->getExtDbRlsId($_) } split (/,/,$self->getArg('geneExternalDatabaseSpec'));

  $self->{geneModelLocations} = GUS::Community::GeneModelLocations->new($self->getQueryHandle(), $self->{geneExtDbRlsId}, 0);

  my $minPMatch = $self->getArg('minPercentPeptidesToMap');
  $self->{minPepToMatch} = $minPMatch ? $minPMatch : 50;
  ##prepare the query statements
  $self->prepareSQLStatements();
  
  foreach my $inputFile (@inputFiles) {
    warn "now reading input file $inputFile \n";
    my $inputFileLocation = $inputFileDirectory.'/'.$inputFile;
    $inputFileLocation =~s/\/*/\//;
    open(F, $inputFileLocation) or die "Could not open $inputFile: $!\n";
    while (<F>) {
      chomp;
      
      next if /^\s*$/;
      if (/^# /) {
        $state = 'gene';
        next;
      } elsif(/^## start/) {
        $state = 'peptide';
        undef $peptide;
        next;
      } elsif(/^## relative_position/) {
        $state = 'residue';
        next;
      } elsif($state eq 'gene') {
        $record = $self->initRecord($_);
        $record->{file}=$inputFile;
        push @{$recordSet}, $record;
      } elsif($state eq 'peptide') {
        $peptide = $self->addMassSpecFeatureToRecord($_, $record);
      } elsif($state eq 'residue') {
        &addResidueToPeptide($_, $peptide);
      } else {
        die "Something wrong in the file on this line: $_\n";
      }
      $self->undefPointerCache();
    }
    close F;
  }


  ##now need to loop through records and assign to genes ..
  $self->addRecordsToGenes($recordSet);

  $recordSet = $self->{copiedRecords};

  unless($recordSet) {
    $self->error("Failure:  Did not map any peptides to any proteins");
  }

  $self->pruneDuplicateAndEmptyRecords($recordSet);

  my $recordsById = $self->unionPeptidesForRecords($recordSet);
  
  foreach my $key (keys%{$recordsById}){
    my $good = 0;
    my $failed = 0;
    foreach my $rec (@{$recordsById->{$key}}){
      if($rec->{failed}){
        $failed++;
      }else{
        $good++;
      }
    }
    unless($good == 1){
      print STDERR "CheckDups: '$key' ($recordsById->{$key}->[0]->{sourceId}) good=$good, failed=$failed\n";
      foreach my $rec (@{$recordsById->{$key}}){
        print STDERR "\t".$self->recordToString($rec)."\n";
      }
      print "\n";
    }
  }

  warn "inserting into db for ".scalar(@$recordSet). " records ($self->{countGoodRecords} unique)\n" if $self->getArg('mapOnly');
  $self->insertRecordsIntoDb($recordSet) unless $self->getArg('mapOnly');    
  
  $self->setResultDescr(<<"EOF");
    
Added $self->{featuresAdded} @{[ ($self->{featuresAdded} == 1) ? 'feature':'features' ]} and $self->{summariesAdded} @{[ ($self->{summariesAdded} == 1) ? 'summary':'summaries' ]}.
Skipped $self->{summariesSkipped} @{[ ($self->{summariesSkipped} == 1) ? 'summary':'summaries' ]}.
EOF
}


sub unionPeptidesForRecords {
  my ($self, $recordSet) = @_;

  my %recordsById;


  # fill in the hashmap so we can lookup records by aaSequenceId
  for(my $i = 0; $i < scalar @$recordSet; $i++) {
    my $record = $recordSet->[$i];
    $record->{recordIndex} = $i;

    my $aaSequenceId = $record->{aaSequenceId};
    ##there seem to be some records without an aa_sequence_id so need to deal with it here
    unless($aaSequenceId){
#      print STDERR "WARNING: record has no aa_sequence_id\n\t".$self->recordToString($record)."\n" unless $record->{failed};
      $record->{failed} = 1;
      next;
    }
    my $file = $record->{file};

    my $key = $aaSequenceId . "_" . $file;

    push @{$recordsById{$key}}, $record;
  }



  # loop through the records for each aaSequence;  push all peptides onto the first; mark rest as failed
  foreach my $aaSequenceId (keys %recordsById) {
    my $unionRecords = $recordsById{$aaSequenceId};

    my $firstPassed;
    my $keepMe;
    foreach my $rec (@$unionRecords) {
      next if($rec->{failed});
      unless(defined $rec->{peptides}){
        $rec->{failed} = 1;
        next;
      }

      if(!$firstPassed) {
        $firstPassed = 1;
        $keepMe = $rec;
        # null these out; these don't make sense if we union peptides from different groups
        $keepMe->{percentCoverage} = undef;
        $keepMe->{score} = undef;
        # the following are sequence attributes so we should keep
        # $keepMe->{description} = undef;
        # $keepMe->{seqMolWt} = undef;
        # $keepMe->{seqPI} = undef;

        # sequence count and peptide count will be calculated after union peptides
        $keepMe->{spectrumCount} = undef;
        $keepMe->{sequenceCount} = undef;
        next;
      }
      

      # keepMe and deleteMe should be the same gene (same naFeature Id and aaFeatParentId 
      unless($keepMe->{naFeatureId} == $rec->{naFeatureId} && $keepMe->{aaFeatParentId} == $rec->{aaFeatParentId}) {
        die "Cannot union peptides from records which do not map to the same gene";
      }
      
      eval {
      
#      push @{$recordSet->[$keepIndex]->{peptides}}, @{$rec->[$deleteIndex]->{peptides}};
      push(@{$keepMe->{peptides}}, @{$rec->{peptides}});
      };

      if($@) {
        print Dumper "KEEPME\t";
        print Dumper $keepMe;
        print Dumper "DELETEME\t";
        print Dumper $rec;

        print Dumper $recordsById{$aaSequenceId};

        die $@;
      }
      $rec->{failed} = 1;
    }
    ##now have all peptides in $keepMe so can mark dups ...
    unless($keepMe){
      print STDERR "WARNING: unable to union peptides for '$aaSequenceId'\n";
      next;
    }
    $self->{countGoodRecords}++;
    
    for(my $i = 0; $i < scalar(@{$keepMe->{peptides}}); $i++) {
      my $peptideA = $keepMe->{peptides}->[$i];
      next if($peptideA->{failed});
      die "spectrum count not provided for " . $peptideA->{sequence} unless $peptideA->{spectrum_count};

      for(my $j = $i + 1; $j < scalar @{$keepMe->{peptides}}; $j++) {  ##only need to compare remaining peptides as previous ones already done.
        
        my $peptideB = $keepMe->{peptides}->[$j];
        next if($peptideB->{failed});
        die "spectrum count not provided for " . $peptideB->{sequence} unless $peptideB->{spectrum_count};
        
        if($peptideA->{sequence} eq $peptideB->{sequence} && $self->sameResidues($peptideA, $peptideB)) {
          
          
          ##what to do if spectrum counts differ??
          ## possibly should sum the spectrum counts as could represent different spectra mapped to same peptide??

          print STDERR "WARNING: duplicate peptide sequence w/ unequal spectrum counts: $peptideA->{sequence}=$peptideA->{spectrum_count}, $peptideB->{sequence}=$peptideB->{spectrum_count}.\n" if($self->getArg('veryVerbose')); #unless($peptideA->{spectrum_count} == $peptideB->{spectrum_count});

          $peptideA->{spectrum_count_diff} += $peptideB->{spectrum_count};
          
          $peptideB->{failed} = 1;
          
          # keep the peptide attributes if they are equal;
          foreach my $attr("observed", "mr_expect", "ions_score", "miss", "delta", "mr_calc") {
            $peptideA->{$attr} = $self->peptideAttribute($peptideA, $peptideB, $attr);
          }
          
        }
      }
    }

    # counts we care about for the aaSequence
    my ($spectrumCount, $sequenceCount);

    foreach my $pep (@{$keepMe->{peptides}}) {
      next if($pep->{failed});

      $spectrumCount = $spectrumCount + $pep->{spectrum_count}; # + $pep->{spectrum_count_diff};
      $sequenceCount++;
    }

    $keepMe->{spectrumCount} = $spectrumCount;
    $keepMe->{sequenceCount} = $sequenceCount;
  }
  return \%recordsById;
}

sub recordToString {
  my($self,$record) = @_;
  return "invalid record" unless $record;
  my @ret;
  foreach my $key (sort{$a <=> $b}keys%{$record}){
    if(ref($record->{$key}) =~ /array/i){
      push(@ret,"$key=".scalar(@{$record->{$key}}));
    }elsif(ref($record->{$key}) =~ /hash/i){
      push(@ret,"$key=".scalar(keys %{$record->{$key}}));
    }else{
      push(@ret,"$key=$record->{$key}");
    }
  }
  return join(", ",@ret);
}


sub sameResidues {
  my ($self, $peptideA, $peptideB) = @_;

  if(!$peptideA->{residues} && !$peptideB->{residues}) {
    return 1;
  }

  if(($peptideA->{residues} && !$peptideB->{residues}) || ($peptideB->{residues} && !$peptideA->{residues})) {
    return 0;
  }


  unless(scalar @{$peptideA->{residues}} == scalar @{$peptideB->{residues}}){
#    print STDERR "WARNING: same peptide sequence different number of residues for $peptideA->{sequence}\n";
    return 0;
  }

  for(my $i = 0; $i < scalar @{$peptideA->{residues}}; $i++) {
    my $residueA = $peptideA->{residues}->[$i];
    my $residueB = $peptideB->{residues}->[$i];

    unless(scalar keys %{$residueA} == scalar keys %{$residueB}){
      print STDERR "WARNING: different attributes for peptide residue for $peptideA->{sequence}\n";
      return 0;
    }

    foreach my $key (keys %{$residueA}) {
      unless($residueA->{$key} eq $residueB->{$key}) {
        return 0;
      }
    }
  }

  return 1;
}


sub peptideAttribute {
  my ($self, $peptideA, $peptideB, $attr) = @_;

  if($peptideA->{$attr} eq $peptideB->{$attr}) {
    return $peptideA->{$attr};
  }
  if($peptideA->{$attr} && !$peptideB-{$attr}){
    return $peptideA->{$attr};
  }elsif ($peptideB->{$attr} && !$peptideA->{$attr}){
    return $peptideB->{$attr};
  }
  my $peptideA_attr = $peptideA->{$attr};
  my $peptideB_attr = $peptideB->{$attr};
  print STDERR "WARNING: $attr value mismatch: peptideA $attr = $peptideA_attr, peptideB $attr = $peptideB_attr. The greater value will be kept\n";
  return $peptideA->{$attr} > $peptideB->{$attr} ?  $peptideA->{$attr} : $peptideB->{$attr};
  return "";
}



sub initRecord {
  my ($self, $ln, $record) = @_;
    
  ( $record->{sourceId},
    $record->{description},
    $record->{seqMolWt},
    $record->{seqPI},
    $record->{score},
    $record->{percentCoverage},
    $record->{sequenceCount},
    $record->{spectrumCount},
    $record->{sourcefile},
  ) = split "\t", $ln;

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
    print STDERR "WARNING: $candidate_ids[0] returns more than one row. This protein will be skipped.\n"
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

  my $proteinMatchCuttoff = 50;

  foreach my $record (@{$recordSet}) {

    my $wasFound;

    my $id = $record->{sourceId};

    # most often the identifier will be a gene source id
    my $aaSeqIds =  GUS::Supported::Util::getAASeqIdsFromGeneId($self, $id, $self->{geneExtDbRlsId}, $self->getArg('organismAbbrev')) ;

    if(ref($aaSeqIds) eq 'ARRAY') {

      foreach my $aaSeqId (@$aaSeqIds) {
        foreach my $prot ($self->getAllProteins()){
          next unless($prot->[0] == $aaSeqId);

          # ensure that all peptides match on to this protein

          my $proteinMatchPercent = $self->checkThatPeptidesMatch($record,$prot->[1]);
          if($proteinMatchPercent >= $proteinMatchCuttoff) {
#          if($self->checkThatAllPeptidesMatch($record,$prot->[1])) {
            $wasFound = 1;
            $self->copyRecord($record, $aaSeqId);
          }else{
			     warn "For $record->{sourceId} (".scalar(@{$record->{peptides}})." peptides), only $proteinMatchPercent % of peptides matched, less than $proteinMatchCuttoff %, now try testing all proteins.\n";
          } 
        }
      }
    }
   
    unless ($wasFound) { ##failed finding from source id...  try testing all proteins

      my $result = $self->testPeptidesAgainstAllProteins($record);

      if(ref($result) eq 'ARRAY'){  #hit more than one protein
        $wasFound = 1;

        foreach my $f (@$result){
          $self->copyRecord($record,$f);
        }

      }
    }

    
    unless ($wasFound) {


      warn "Unable to find gene for $record->{sourceId} (".scalar(@{$record->{peptides}})." peptides)... discarding\n";
      $record->{failed} = 1;
      next;
    }

    ##need to map the peptides and set the identifiers ....
    # $self->mapPeptidesAndSetIdentifiers($record,$official);
    $self->undefPointerCache();

  }

}



sub mapPeptidesAndSetIdentifiers {
  my($self,$record, $aaSeqId) = @_;

  $record->{aaSequenceId} = $aaSeqId;

  my $aaSeq = $self->getAASequence($aaSeqId);
  my $pSeq =  $aaSeq->get('sequence');

  my $taf = $aaSeq->getChild("DoTS::TranslatedAAFeature", 1);
  my $transcript = $taf->getParent("DoTS::Transcript", 1);
  my $geneFeature = $transcript->getParent("DoTS::GeneFeature", 1);

  $record->{geneSourceId} = $geneFeature->getSourceId();
  $record->{naSequenceId} = $geneFeature->getNaSequenceId();
  $record->{geneNaFeatureId} = $geneFeature->getId();

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
  my($self,$record,$aaSeqId) = @_;
  my %copy = %$record;
  undef $copy{peptides};
  foreach my $pep (@{$record->{peptides}}){
    my %cp = %$pep;
    push(@{$copy{peptides}},\%cp);
  }
  my $recordCopy = \%copy;

  $self->mapPeptidesAndSetIdentifiers($recordCopy,$aaSeqId);
  push(@{$self->{copiedRecords}},$recordCopy);

  return $recordCopy;
}

##return genefeature if only one protein contains all peptides ...
sub testPeptidesAgainstAllProteins {
  my($self,$record) = @_;
  my @matches;

  # getAllProteins method currently brings back a gene na feautre id. Should bring back the protein id
  foreach my $prot ($self->getAllProteins()){
    push(@matches, $prot) if $self->checkThatAllPeptidesMatch($record,$prot->[1]);
  }


  if(scalar(@matches) > 0 && scalar(@matches) <= 20) {
    my @aaSeqIds = map { $_->[0] } @matches;
    return \@aaSeqIds;
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





sub getAllProteins {
  my($self) = @_;

  if(!$self->{allProteins}){
    warn "Retrieving all Proteins\n";
    my $protStmt =  $self->getQueryHandle()->prepare(<<"EOSQL");
      select aas.aa_sequence_id, aas.sequence
      from dots.genefeature gf, dots.transcript t, dots.translatedaafeature taaf, dots.translatedaasequence aas
      where gf.external_database_release_id in ($self->{geneExtDbRlsId})
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
      from dots.genefeature gf, dots.transcript t, dots.translatedaafeature taaf, dots.translatedaasequence aas,sres.ontologyterm o
      where o.name = 'protein_coding'
      and o.ontology_term_id = gf.sequence_ontology_id
      and gf.external_database_release_id not in ($self->{geneExtDbRlsId})
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

sub getAASequence {
  my($self,$aaSeqId) = @_;


  my $seq = GUS::Model::DoTS::TranslatedAASequence->new({aa_sequence_id => $aaSeqId});
  if($seq->retrieveFromDB) {
    return $seq;
  }
  $self->error("Error Retrieving TranslatedAASequence w/ aa_sequence_id:  $aaSeqId");
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
        and gf.external_database_release_id in ($self->{geneExtDbRlsId})  
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
    unless($protSeq =~ /$pep->{sequence}/i) {
      return 0;
    }
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
  my $ont = $naFeature->getParent("SRes::OntologyTerm",1);
  return ($ont && $ont->getName() =~ /orf/i);
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

    $pep->{ions_score},

    $pep->{spectrum_count}
  ) = split "\t", $ln;

  $self->userError("required peptide attribute spectrum_count not provided") unless($pep->{spectrum_count});

  #    $self->setPepStartEnd($pep, $record->{aaSequenceId}) if (!$pep->{start} or !$pep->{end});
    
  #    if ($pep->{start} == 0) {
  #        warn "$pep->{sequence} not found on $record->{sourceId}. Discarding this peptide...\n";
  #        return;
  #    }


  push @{$record->{peptides}}, $pep;

  return $pep;
}

sub addResidueToPeptide {
  my ($ln, $pep) = @_;

  my $residue = {};
  ( $residue->{relative_position},
    $residue->{order},
    $residue->{description},
    $residue->{modification_type}
  ) = split "\t", $ln;

  push @{$pep->{residues}}, $residue;

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
  if($proteinSeq =~ /$pep->{sequence}/i){
    $pep->{start} = $-[0]+1;
    $pep->{end} = $+[0];
    return 1;
  }
  return 0;
}

sub insertRecordsIntoDb {
  my ($self, $recordSet) = @_;
  warn "Inserting records into the db for ".scalar(@{$recordSet})." records ($self->{countGoodRecords} unique)\n";
  my $ct = 0;
  for my $record (@{$recordSet}) {
    warn "processing record $ct\n" if $ct++ % 50 == 0;
    if (!defined $record || $record->{failed}) {
      $self->{summariesSkipped}++;
      next;
    }
    my $mss = $self->insertMassSpecSummary($record);
    next unless $mss;
    $self->insertMassSpecFeatures($record, $mss);
    $self->undefPointerCache();
  }
}


sub insertMassSpecSummary {
  my ($self, $record) = @_;
  return unless $record->{aaSequenceId};
    
  my $aaSeq = GUS::Model::DoTS::TranslatedAASequence->new({
                                                           aa_sequence_id => $record->{aaSequenceId}
                                                          });
  unless($aaSeq->retrieveFromDB){
    print STDERR "WARNING: Unable to retrieve $record->{aaSequenceId} from db for $record->{sourceId} -> $record->{sourceId}... skipping\n\t".$self->recordToString($record)."\n"; 
    return;
  }

  $record->{seqLength}    = $aaSeq->getLength();

  ## want to load the number of distinct peptides as the number_of_spans
  my %peps;
  foreach my $pep (@{$record->{peptides}}) {
    next if $pep->{failed};
    $peps{"$pep->{start}"."$pep->{end}"} = 1;
  }

  my $mss = GUS::Model::ApiDB::MassSpecSummary->new({
                                                     'aa_sequence_id'                => $record->{aaSequenceId},
                                                     'protocol_app_node_id'                => $self->{_protocol_app_nodes}->{$record->{file}}->getId(),
                                                     'sequence_count'                => $record->{sequenceCount},
                                                     'number_of_spans'               => scalar(keys%peps),
                                                     'prediction_algorithm_id'       => $self->getPredictionAlgId,
                                                     'spectrum_count'                => $record->{spectrumCount},
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
  if($record->{seqLength}){
    return int($cov / $record->{seqLength} * 1000) / 10;
  }else{
    warn "amino acid sequence $record->{aaSequenceId} has 0 length";
  }
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
#                                                            'developmental_stage'     => $record->{devStage},
                                                            'description'             => $pep->{description},
                                                            'spectrum_count'          => $pep->{spectrum_count},
                                                            'source_id'               => $mss->getMassSpecSummaryId,
                                                            'is_predicted'            => 1,
                                                           });
        
    my $aaLoc = GUS::Model::DoTS::AALocation->new({
                                                   'start_min' => $pep->{start},
                                                   'start_max' => $pep->{start},
                                                   'end_min'   => $pep->{end},
                                                   'end_max'   => $pep->{end},
                                                  });
    

    $msFeature->addChild($aaLoc);    
 
    unless($self->{_na_locations}->{$record->{geneNaFeatureId}}->{$pep}) {

      my $naFeature = $self->addNAFeatureAndLocations (
        $record->{geneSourceId} . "-ms.$ct",
        $record->{geneSourceId},
        $record->{naSequenceId},
        $pep);

      $msFeature->setParent($naFeature);
      
      $self->{_na_locations}->{$record->{geneNaFeatureId}}->{$pep} = 1;
                               
    }
        

    ## insert residues data into PostTranslationalModFeature and AALocation
    for my $res (@{$pep->{residues}}) {
      $self->fetchSequenceOntologyId($res, $res->{modification_type});
      my $resFeature = GUS::Model::DoTS::PostTranslationalModFeature->new({
                                                            'aa_sequence_id'               => $record->{aaSequenceId},
                                                            'parent_id'                    => $msFeature->getAaFeatureId(),
                                                            'prediction_algorithm_id'      => $self->getPredictionAlgId,
                                                            'external_database_release_id' => $self->{extDbRlsId},
                                                            'sequence_ontology_id'         => $res->{sequenceOntologyId},
                                                            'is_predicted'                 => 0,
                                                            'description'                  => $res->{description},
                                                           });
        
      my $aaLoc = GUS::Model::DoTS::AALocation->new({ 'start_min' => $pep->{start} + $res->{relative_position} - 1,
                                                      'start_max' => $pep->{start} + $res->{relative_position} - 1, 
                                                      'end_min'   => $pep->{start} + $res->{relative_position} - 1,
                                                      'end_max'   => $pep->{start} + $res->{relative_position} - 1,
                                                    });
      $resFeature->setParent($msFeature);    
      $resFeature->addChild($aaLoc);    

    } 

    $msFeature->submit();
    $self->{featuresAdded}++;
  } 
}

sub fetchSequenceOntologyId {
  my ($self, $res, $name) = @_; 

  my $SOTerm = GUS::Model::SRes::OntologyTerm->new({'name' => $name }); 
  $SOTerm->retrieveFromDB;
  $res->{sequenceOntologyId} = $SOTerm->getId();

  if (! $SOTerm->getId()) {
    $self->error("Error: Can't find SO term '$name' in database.");
  } 
}

sub addNAFeatureAndLocations {
  my ($self, $sourceId, $geneSourceId, $naSequenceId, $pep) = @_;

  if (! $pep->{start} and ! $pep->{end}) {
    warn "WARNING: pepStart and pepEnd coordinates not available for $pep->{sequence} ... discarding";
    return undef;
  }


  my $naLocations = $self->mapToNASequence(
                                           $geneSourceId, $pep->{start}, $pep->{end}
                                          );
    
  if (! $naLocations) {
    warn "Peptide at $pep->{start}..$pep->{end} not found on $pep->{sequence}. Discarding this peptide...\n";
    return undef;
  }


  my $naFeature = GUS::Model::DoTS::Miscellaneous->new({
                                                    na_sequence_id                  => $naSequenceId,
                                                    name                            => 'located_sequence_feature',
                                                    external_database_release_id    => $self->{extDbRlsId},
                                                    source_id    => $sourceId,
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

sub mapToNASequence{
  my ($self, $geneSourceId, $pepStart, $pepEnd) = @_;
  my $naLocations = [];

  my %mapped;

  my $geneModelLocations = $self->{geneModelLocations};

  foreach my $transcriptSourceId (@{$geneModelLocations->getTranscriptIdsFromGeneSourceId($geneSourceId)}) {
    foreach my $proteinSourceId (@{$geneModelLocations->getProteinIdsFromTranscriptSourceId($transcriptSourceId)}) {

      my $mapper = $geneModelLocations->getProteinToGenomicCoordMapper($proteinSourceId);

      my $peptideCoords = Bio::Location::Simple->new (
        -start => $pepStart,
        -end   => $pepEnd,
          );
      
      my $map = $mapper->map($peptideCoords);
      return undef if ! $map;

      foreach (sort { $a->start <=> $b->start } $map->each_Location ) {
        my $key = $_->start. "_" . $_->end . "_" . $_->strand;

        unless($mapped{$key}) { # already seen this in a different protein for this gene
          push @$naLocations, [$_->start, $_->end, $_->strand];
        }

        $mapped{$key} = 1;
      }
    }
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
    return undef;
  }


  unless (@exons) {
    $self->error(<<"EOF")
      Can not find an exon/CDS for transcript $id.
      Cannot map its peptide hits to the chromosome.\n
EOF
  }

  for my $exon (@exons) {
    my ($exonStart, $exonEnd, $exonIsReversed) = $exon->getFeatureLocation();

# TODO:  Remove these lines they are unused
#    my $codingStart = ($exon->isValidAttribute('coding_start')) ?
#      $exon->getCodingStart() || $exonStart :
#        $exonStart;

#    my $codingEnd = ($exon->isValidAttribute('coding_end')) ?
#      $exon->getCodingEnd() || $exonEnd :
#        $exonEnd;

    my $strand = ($exonIsReversed) ? -1 : 1;
        
#    ($codingStart > $codingEnd) && 
#      (($codingStart, $codingEnd) = ($codingEnd, $codingStart));

    push @$exonCoords, [$exonStart, $exonEnd, $strand];
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

   directoryArg({
            name            =>  'inputDir',
            descr           =>  'Name of file directory containing the mass spec features input files',
            constraintFunc  =>  undef,
            reqd            =>  1,
            isList          =>  0,
            mustExist       =>  1,
           }),

   stringArg({
              name            =>  'fileNameRegex', 
              descr           =>  'pattern to match for al files in the inputDir',
              constraintFunc  =>  undef,
              reqd            =>  1,
              isList          =>  0
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
               descr           =>  'External Database release `name1|version1,name2|version2` for the gene models to which will be attaching these peptides',
               constraintFunc  =>  undef,
               reqd            =>  1,
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

   stringArg({
              name            =>  'developmentalStage',
              descr           =>  'organism developmental stage analyzed',
              constraintFunc  =>  undef,
              reqd            =>  0,
              isList          =>  0
             }),

   stringArg({name => 'organismAbbrev',
	      descr => 'if supplied, use a prefix to use for tuning manager tables',
	      reqd => 0,
	      constraintFunc => undef,
	      isList => 0,
	     }),
  ];

}

sub undoTables {
  qw(
    ApiDB.MassSpecSummary
    DoTS.AALocation
    DoTS.PostTranslationalModFeature
    DoTS.MassSpecFeature
    DoTS.NALocation
    DoTS.NAFeature
    Study.StudyLink
    Study.ProtocolAppNode
    Study.Study
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
## start	end	observed	mr_expect	mr_calc	delta	miss	sequence	modification	query	hit	ions_score	spectrum
301	309	530.12	1058.23	1057.54	0.69	0	VNADLLEER		11	1	88
311	320	588.39	1174.77	1175.59	-0.81	0	VLVGEMEIDR	Oxidation (M) 	14	1	29
# source_id	description	seqMolWt	seqPI	score	percentCoverage	sequenceCount	spectrumCount	sourcefile
Liv070540	AAEE01000003-3-1125870-1128359	92046	4.49	430	17	9	9	CrypProt LTQ spot L Protein View.htm
## start	end	observed	mr_expect	mr_calc	delta	miss	sequence	modification	query	hit	ions_score	spectrum
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
      'DoTS.PostTranslationalModFeature' =>
      'PostTranslationalModFeature handles the phosphorylated residue - score, residue and modification type.'
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
      'SRes.OntologyTerm' =>
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
                             
