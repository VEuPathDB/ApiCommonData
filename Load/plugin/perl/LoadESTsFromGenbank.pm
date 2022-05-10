package ApiCommonData::Load::Plugin::LoadESTsFromGenbank;
@ISA = qw( GUS::PluginMgr::Plugin );
use GUS::PluginMgr::Plugin;

use strict;
use warnings;
require LWP::UserAgent;
use Data::Dumper;
use Time::HiRes qw(usleep);
use JSON;
use XML::Simple;
use Date::Manip qw(UnixDate DateCalc ParseDate);
use POSIX qw/strftime/;
use Carp qw/carp cluck/;
use feature "switch";

use GUS::Model::DoTS::EST;
use GUS::Model::DoTS::Clone;
use GUS::Model::DoTS::Library;
use GUS::Model::DoTS::ExternalNASequence;
use GUS::Model::SRes::OntologyTerm;
use GUS::Model::DoTS::SequenceType;
use GUS::Model::SRes::Taxon;
use GUS::Model::SRes::TaxonName;
use GUS::Model::SRes::Contact;
use GUS::Model::SRes::ExternalDatabase;
use GUS::Model::SRes::ExternalDatabaseRelease;

## TODO Parameterize $API_KEY
my $API_KEY = '615dc38c346e6d6ad0f5754cebd39c8c7f09';
my $BASE_URL = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils";

my $SearchBatchSize = 10000;
my $FetchBatchSize = 500;
my $RETRY = 3;

my $UTILITY_URL = {
  search => "$BASE_URL/esearch.fcgi",
  fetch => "$BASE_URL/efetch.fcgi",
  summary => "$BASE_URL/esummary.fcgi",
};


sub new {
  my ($class) = @_;

  my $self = {};
  bless($self,$class);

  my $purpose = <<PURPOSE;
Load ESTs from Genbank into GUS
PURPOSE

  my $purposeBrief = <<PURPOSE_BRIEF;
Load ESTs from Genbank into GUS
PURPOSE_BRIEF

  my $notes = <<NOTES;
NOTES

  my $tablesAffected = <<TABLES_AFFECTED;
DoTS.NAExternalSequence
DoTS.Contact
DoTS.Library
DoTS.EST
TABLES_AFFECTED

  my $tablesDependedOn = <<TABLES_DEPENDED_ON;
TABLES_DEPENDED_ON

  my $howToRestart = <<RESTART;
In case of failure, this plugin may be restarted without cleanup. Accessions fetched from Genbank will be compared to ESTs loaded (getLoadedESTAccessionsBySubTaxa) and skipped if the accession is already loaded.
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


  my $argsDeclaration = 
    [
     stringArg({name => 'log',
		descr => 'log file (path relative to current/working directory)',
		constraintFunc => undef,
		reqd => 0,
		default => 'DataLoad_ESTsFromGenbank.log',
		isList => 0
	       }),
     stringArg({ name => 'extDbRlsSpec',
		 descr => 'External Database Release Spec',
		 reqd => 0,
		 constraintFunc => undef,
		 isList => 0
	       }),
     stringArg({name => 'SOExtDbRlsSpec',
		descr => 'The extDbRlsName of the Sequence Ontology to use',
		reqd => 1,
		constraintFunc => undef,
		isList => 0
	       }),
     stringArg({ name => 'ncbiTaxonId',
		 descr => 'ncbi tax id of this reference strain',
		 reqd => 0,
		 constraintFunc => undef,
		 isList => 0
	       }),
    ];

  $self->initialize({requiredDbVersion => 4.0,
		     cvsRevision => '$Revision$',	# cvs fills this in!
		     name => ref($self),
		     argsDeclaration   => $argsDeclaration,
		     documentation     => $documentation});


  return $self;
}

sub run {
  my($self,) = @_;
  my $dbh = $self->getQueryHandle();
  my $ncbiTaxonId = $self->getArg('ncbiTaxonId');
  die("ncbiTaxonId must be a number") unless( $ncbiTaxonId =~ /^[0-9]+$/);
  printf STDERR ("Auditing NCBI Taxon ID (%d)\n", $ncbiTaxonId);
  $self->{sequence_ontology_id} = $self->getSequenceOntologyId();
  $self->{ext_db_rls_id} = $self->getExtDbRlsId($self->getArg('extDbRlsSpec'));

  my $ez = $self; # an alias, tagging functions that could be moved to a package
  $ez->initUserAgent(); 
  # open(CMT, "> commentstr.txt");
  
  my $loadedAx = $ez->getLoadedESTAccessionsBySubTaxa($dbh,$ncbiTaxonId);
  printf STDERR ("Got %d loaded ESTs\n", scalar keys %$loadedAx);
  
  my $term = $ez->getSubTaxaSearchParams($dbh,$ncbiTaxonId);
  unless($term){
    printf STDERR ("No subtaxa found, done with $ncbiTaxonId\n");
    next;
  }
  $ez->setInternalParam('term', $term);
  printf STDERR ("Search term: %s\n", $term);
  my $accessionsFromGenbank = $ez->getGenbankESTAccessionsbyTaxId();
  
  printf STDERR ("Checking %d loaded versus %s fetched\n",
    scalar keys %$loadedAx,
    scalar keys %$accessionsFromGenbank);
  
  my %seqsFetch;
  # my $logfile = strftime("log/txid${ncbiTaxonId}_%Y%m%d_%H%M.log", localtime());
  # open(LOG, "> $logfile");
  # my $written = 0;
  foreach my $acc ( keys %$accessionsFromGenbank ){
    if($loadedAx->{$acc}){
      # printf STDERR ("OK found $acc\n");
    }
    else {
      # printf STDERR ("NEW!!! $acc\n");
  #   $written++;
  #   printf LOG ("%s\n", join("\t",
  #     $accessionsFromGenbank->{$acc}->{taxid} || 'NA',
  #     $acc,
  #     $accessionsFromGenbank->{$acc}->{ver},
  #     $accessionsFromGenbank->{$acc}->{gi},
  #     $accessionsFromGenbank->{$acc}->{title},
  #     $accessionsFromGenbank->{$acc}->{length})
  #   );
      my $accver = sprintf("%s.%s", $acc,
        $accessionsFromGenbank->{$acc}->{ver});
      $seqsFetch{$accver} = 1;
    }
  }
  my @ids = sort keys %seqsFetch;
  next unless 0 < scalar @ids;
  $ez->loadFromGenbank(\@ids);
# close(LOG);
# unless($written){
#   printf STDERR ("Deleting log %s, empty\n", $logfile);
#   unlink($logfile);
# }
}

sub getInternalParam { return $_[0]->{$_[1]} }
sub setInternalParam { $_[0]->{$_[1]} = $_[2]; return $_[2] }

sub getUserAgent { return $_[0]->getInternalParam('user_agent') }

sub initUserAgent {
  my ($self, $params) = @_;
  my $ua = LWP::UserAgent->new;
  $ua->timeout(360); # 6 minutes
  $ua->env_proxy;
  $self->setInternalParam('user_agent',$ua);
  while( my ($k, $v) = each %$params){ $self->setInternalParam($k, $v) }
}


sub postRequest {
  my ($self, $util, $params) = @_;
  my $url = $UTILITY_URL->{$util};
  ###
  my %default = (
    api_key => $API_KEY,
    #format => 'json',
  );
  while( my ($k,$v) = each %default){ $params->{$k} //= $v }
  my $try = $RETRY; 
  my $response;
  while($try--){
    $response = $self->getUserAgent()->post($url, $params);
    if ($response->is_success) {
      return $response->decoded_content;
    }
    else {
      printf STDERR ("WARNING request failed: %s\n", Dumper $response->status_line);
    }
  }
  die(sprintf("Request failed after %d tries.\n%s\n",$RETRY, Dumper $response));
}

sub getSearchResultIdList {
  my ($self, $limit) = @_;
  my $searchUrl = "$BASE_URL/esearch.fcgi";
  if(defined($limit) && $SearchBatchSize > $limit){ $SearchBatchSize = $limit }

  # get some stats first
  my $params = {
    api_key => $API_KEY,
    format => 'json',
    retmax => 1,
    retstart => 0, ## updated each iteration below
    db => 'nucleotide',
    term => $self->getInternalParam('term'),
  };
printf STDERR ("DEBUG test esearch params\n");
  my $qinfo = from_json($self->postRequest('search', $params));
  if( $qinfo->{esearchresult}->{ERROR} ){
    die $qinfo->{esearchresult}->{ERROR};
  }
  my $totalToFetch = $limit || $qinfo->{esearchresult}->{count};

printf STDERR ("DEBUG esearch params OK, fetching batch size %d ...\n", $SearchBatchSize);
  # Now fetch id list

  $params->{ retmax } = $SearchBatchSize;
  my $count = 0;
  my @ids;
  while($count < $totalToFetch){
    my $result = from_json($self->postRequest('search', $params));
    if( $result->{esearchresult}->{ERROR} ){
      die $result->{esearchresult}->{ERROR};
    }
    unless($count || $limit){
      #printf STDERR Dumper $result; # for dev when you need to see the result structure
      $totalToFetch = $result->{esearchresult}->{count};
      printf STDERR ("Fetching %d IDs\n", $totalToFetch);
    }
    my $results = $result->{esearchresult}->{idlist} ;
    push(@ids, @$results);
    $count += @$results;
    #printf STDERR ("Fetched %d, %d remain\n", $count, $totalToFetch - $count);
    #printf("%s\n", join("\n", @ids));
    $params->{retstart} += $SearchBatchSize;
  # nap for a third of a second to observe NCBI's three-request-per-second limit
    last if (scalar @ids >= $totalToFetch);
    usleep(333333);
  }
  printf STDERR ("Total %d IDs\n", $count);
  return \@ids;
}

sub getSummary {
  my ($self, $ids) = @_;
  my $idList = join(",", @$ids);
  my $params = {
    # rettype => 'gb',
    id => $idList,
    #rettype => 'gbc',
    retmode => 'xml',
    db => 'nucleotide',
  };
  my $result = $self->postRequest('summary', $params);
  return XMLin($result);
  return $result;
}
sub getGenbank {
  my ($self, $ids) = @_;
  my $idList = join(",", @$ids);
  my $params = {
    id => $idList,
    retmode => 'xml',
    db => 'nucleotide',
  };
  my $result = $self->postRequest('fetch', $params);
  return XMLin($result);
  return $result;
}
sub getFasta {
  my ($self, $ids) = @_;
  my $idList = join(",", @$ids);
  my $params = {
    rettype => 'fasta',
    id => $idList,
    #retmode => 'xml',
    db => 'nucleotide',
  };
  my $result = $self->postRequest('fetch', $params);
  return $result;
}

sub getSubTaxa {
  my ($self, $dbh, $ncbiTaxonId) = @_;
  my $sql = "select taxon_id,ncbi_tax_id from SRes.Taxon WHERE NCBI_TAX_ID < 999999999 start with ncbi_tax_id=? connect by prior taxon_id = parent_id";
  my $taxonId2ncbiTax = $self->selectHashRef($dbh,$sql,[$ncbiTaxonId]);
  return $taxonId2ncbiTax
}
sub getInternalSpeciesSubTaxa {
  my ($self, $dbh, $ncbiTaxonId) = @_;
  my $sql = <<_SQL;
select taxon_id,ncbi_tax_id
   from
  (select taxon_id, ncbi_tax_id, rank 
   from sres.taxon
   connect by taxon_id = prior parent_id
   start with taxon_id = 
  (SELECT o.taxon_id FROM apidb.organism o 
  LEFT JOIN sres.TAXON t ON o.TAXON_ID =t.TAXON_ID 
WHERE t.NCBI_TAX_ID = ? 
)
  ) t
   where t.rank = 'species'
_SQL
  # printf STDERR ("DEBUG: Searching with params: %s\n", Dumper $ncbiTaxonId);
  my $speciesResult = $self->selectHashRef($dbh,$sql,[$ncbiTaxonId]);
  my ($taxonId) = keys %$speciesResult;
  $sql = "select taxon_id from SRes.Taxon WHERE NCBI_TAX_ID < 999999999 start with taxon_id=? connect by prior taxon_id = parent_id";
  my $ids = $self->selectHashRef($dbh,$sql,[$taxonId]);
  return $ids;
}

sub getSubTaxaSearchParams {
  my ($self, $dbh, $ncbiTaxonId) = @_;
#  my $sql = "select ncbi_tax_id from SRes.Taxon WHERE NCBI_TAX_ID < 999999999 start with ncbi_tax_id=? connect by prior taxon_id = parent_id";
#
#  This query finds the first species above this organism in the taxonomy tree
 my $sql = <<_SQL;
select ncbi_tax_id, taxon_id
   from
  (select taxon_id, ncbi_tax_id, rank 
   from sres.taxon
   connect by taxon_id = prior parent_id
   start with taxon_id = 
  (SELECT o.taxon_id FROM apidb.organism o 
  LEFT JOIN sres.TAXON t ON o.TAXON_ID =t.TAXON_ID 
WHERE t.NCBI_TAX_ID = ? 
)
  ) t
   where t.rank = 'species'
_SQL
  my $speciesResult = $self->selectHashRef($dbh,$sql,[$ncbiTaxonId]);
  my ($spTaxId) = keys %$speciesResult;
  printf STDERR ("DB: looking for subtaxa for species $spTaxId\n");
# This query finds all subtaxa of the species (note: not subtaxa of the reference organism)
  $sql = "select ncbi_tax_id from SRes.Taxon WHERE NCBI_TAX_ID < 999999999 start with ncbi_tax_id=? connect by prior taxon_id = parent_id";
  my $ids = $self->selectHashRef($dbh,$sql,[$spTaxId]);
  return undef unless( 0 < scalar keys %$ids);
  my $termList = sprintf("(%s) AND is_est[filter]", 
    join(" OR ", map { sprintf("txid%d[organism:noexp]",$_) } sort keys %$ids));
  return $termList
}

sub getTaxonIdsFromFile {
  my ($self, $dbh, $file) = @_;
  my %ids;
  open(FH, "<$file") or die "$!\n";
  while(<FH>){
    chomp;
    my @ids = split(/,/);
    $ids{$_} = 1 for @ids;
  }
  close(FH);
  my $sql = sprintf("select ncbi_tax_id, '1' from sres.taxon where taxon_id in (%s)",
    join(",", sort keys %ids));
  my $result = $self->selectHashRef($dbh,$sql);
  my @x = sort keys %$result;
  return \@x;
}
sub getReferenceStrainsFromDB {
  my ($self,$dbh) = @_;
  my $sql = <<_SQL;
SELECT o.ABBREV, t.NCBI_TAX_ID 
FROM apidb.ORGANISM o 
LEFT JOIN sres.taxon t ON o.TAXON_ID =t.taxon_id
WHERE o.IS_REFERENCE_STRAIN =1
AND t.NCBI_TAX_ID < 9000000000
_SQL
  my $results = $self->selectHashRef($dbh,$sql);
  my %hash;
  while(my ($abbrev, $row) = each $results){
    $hash{$abbrev} = $row->{NCBI_TAX_ID}
  }
  return \%hash;
}


## first column in results should be a unique key
sub selectHashRef {
  my ($self, $dbh, $sql, $args) = @_;
  my $sth = $dbh->prepare($sql);
  if(defined($args)){ $sth->execute(@$args) }
  else { $sth->execute() }
  my @cols = @{$sth->{NAME}}; 
  return $sth->fetchall_hashref($cols[0]);
}

sub getLoadedESTAccessionsBySubTaxa{
  my($self, $dbh, $ncbiTaxonId) = @_;
  my $taxa = $self->getInternalSpeciesSubTaxa($dbh,$ncbiTaxonId);
 #my $t = GUS::Model::SRes::Taxon->new({ncbi_tax_id=>$ncbiTaxonId});
 #die "Species not found for NCBI taxon Id $ncbiTaxonId" unless ($t->retrieveFromDB());
 #my $_taxId = $t->getId();
  # printf STDERR ("Found taxon_id=%d (%d)\n", $ncbiTaxonId, $_taxId);
  my $taxIdList = join(",", keys %$taxa );
  printf STDERR ("EST audit: Taxon ID %d search expanded to %d subtaxa\n",
    $ncbiTaxonId, scalar keys %$taxa); 
  my $sql = <<_SQL;
SELECT DISTINCT e.ACCESSION, l.DBEST_NAME
FROM dots.est e
LEFT JOIN dots.LIBRARY l ON e.LIBRARY_ID =l.LIBRARY_ID 
WHERE l.TAXON_ID IN ($taxIdList)
_SQL
  return $self->selectHashRef($dbh,$sql);
}

sub loadFromGenbank {
  ## Every Genbank ID passed to this function is new
  my ($self, $_ids) = @_;
  my $soId = $self->getSequenceOntologyId();
  my @ids = @$_ids;
  my $totalIds = scalar @ids;
  my $start = 0;
  my $end = $start + $FetchBatchSize - 1;
  if($end > $totalIds){ $end = $#ids } 
  printf STDERR ("Loading %d IDs from Genbank\n", $totalIds);
  my %outcomes;
  while( $start < $#ids ){
    my @batch = @ids[ $start .. $end ];
    my $gbseqs = $self->getGenbank(\@batch);
    foreach my $seq (@{$gbseqs->{GBSeq}}){
      my $data = $self->parseEstResult($seq);
    ## NA Sequence is the primary/parent object of all,
    ## however EST is the index to use for maintaining integrity --
    ## If this plugin resumes without cleaning up, we can skip it.
    ## EST object is finally loaded at the end of this loop. 
      my $est = GUS::Model::DoTS::EST->new({accession => $data->{est}->{accession}});
      if($est->retrieveFromDB()){
        #printf STDERR ("EST was already loaded: %s\n", $est->getAccession);
        #$self->undefPointerCache();
        #next;
      }
      else {
        $est = GUS::Model::DoTS::EST->new($data->{est});
      }
      my $taxon = GUS::Model::SRes::Taxon->new($data->{taxon});
      unless($taxon->retrieveFromDB()){
        die sprintf("Taxon not loaded for ncbi_tax_id = %d\n", $data->{taxon}->{ncbi_tax_id});
      }
      else { 
        #printf STDERR ("Taxon found %d for ncbi_tax_id %d\n", $taxon->getId(), $taxon->getNcbiTaxId());
      }

      my $seq = GUS::Model::DoTS::ExternalNASequence->new({source_id => $data->{sequence}->{source_id}});
      if($seq->retrieveFromDB()){
        # check version
        if($seq->getSequenceVersion eq $data->{sequence}->{sequence_version}){
          # printf STDERR ("EST already loaded: %s.%d\n", $seq->getSourceId,$data->{sequence}->{sequence_version});
          $self->undefPointerCache();
          $outcomes{skipped}{ $data->{est}->{accession} } = 1;
          next;
        }
        else {
          # printf STDERR ("EST will be updated: %s.%d\n", $seq->getSourceId,$data->{sequence}->{sequence_version});
          $outcomes{updated}{ $data->{est}->{accession} } = 1;
        }
      }
      $seq->setLength($data->{length});
      $seq->setSequenceVersion($data->{sequence}->{sequence_version});
      $seq->setExternalDatabaseReleaseId($self->{ext_db_rls_id});
      $seq->setSequenceOntologyId($self->{sequence_ontology_id});
      # do not check (memory buffer issue), just assume it is new
      #unless($seq->retrieveFromDB()){
      $seq->setSequence($data->{nucleotide_seq});
      $seq->submit();
        #printf STDERR ("DEBUG ExternalNASequence: Inserted %d\n", $seq->getId());
      #}
      $est->setParent($seq);

      $data->{library}->{taxon_id} = $taxon->getTaxonId();
      # printf STDERR ("DEBUG Library: %s\n", Dumper $data->{library});
      my $library = $self->getLoadedLibrary($taxon,$data->{library});
      unless($library){
        $library = GUS::Model::DoTS::Library->new($data->{library});
       #$library->setTaxonId($taxon->getId);
       #$library->setIsImage(int($data->{library}->{is_image}));
        $library->setParent($taxon);
        $library->submit();
        $self->addLoadedLibrary($library);
        printf STDERR ("DEBUG Library Inserted %d\n", $library->getId());
      }

      my $contact = GUS::Model::SRes::Contact->new($data->{contact});
      unless($contact->retrieveFromDB()){
        $contact->submit();
      }

      ## Finally, load EST
      ## $est->setNaSequenceId($seq->getNaSequenceId);
      $est->setLibraryId($library->getLibraryId);
      $est->setContactId($contact->getContactId);
      $est->submit();
      printf STDERR ("DEBUG EST Inserted %d\n", $est->getId());
    }
    $self->undefPointerCache();

    last if( $end == $#ids );
    $start += $FetchBatchSize;
    $end = $start + $FetchBatchSize - 1;
    if( $end >= $totalIds ){ $end = $#ids }
    last if( $start >= $totalIds );
    usleep(333333);
  }
  printf STDERR ("%d ESTs skipped (already loaded)\n", scalar keys $outcomes{skipped}) if $outcomes{skipped};
  printf STDERR ("%d ESTs updated\n", scalar keys $outcomes{updated}) if $outcomes{updated};
  return;
} 

sub getGenbankESTAccessionsbyTaxId {
  my($self, $ncbiTaxonIds, $mindate) = @_;
### MUST FIRST SET TERM WITH $self->setInternalParam('term', $term)
 #my $term = sprintf('is_est[filter] AND (%s)',
 #  join(" OR ", map { sprintf('txid%d[organism:noexp]',$_) } @$ncbiTaxonIds)
 #);
 #$self->setInternalParam('term',$term);
  # my @ids = @{ $self->getIdListRef() };
  my $maxdate;
  my $mindelta = 0;
  my @ids = @{$self->getSearchResultIdList()};
  my $totalIds = scalar @ids;
  my $accessions = {};
  printf STDERR ("\tEntrez found %s IDs (gi); now reading accessions and checking for replacements\n", $totalIds);
  unless($totalIds){ return {} }
  #if($FetchBatchSize > $totalIds){ $FetchBatchSize = $totalIds}
  my $start = 0;
  my $end = $start + $FetchBatchSize - 1;
  if($end > $totalIds){ $end = $#ids } 
  while( $start < $#ids ){
    my @batch = @ids[ $start .. $end ];
    printf STDERR ("\tBatch %d - %d ( %d %% )...", $start, $end, $end * 100 / $totalIds);
    my $result = $self->getSummary(\@batch);
    printf STDERR ("summary fetched.\n");
    my $hash = $self->getSummaryHash($result);
    while( my($id, $attrs) = each %$hash ){
      my ($acc,$ver) = split(/\./, $attrs->{AccessionVersion});
      my $title = $attrs->{Title};
      my $taxid = $attrs->{TaxId};
      die Dumper $attrs unless $taxid;
      my $length = $attrs->{Length};
##################################
### Validation tests (if/else) ###
#1. replaced
      if($attrs->{ReplacedBy}){
        printf STDERR ("\tFound REPLACED: %s.%s, ReplacedBy=%s\n", $acc,$ver,$attrs->{ReplacedBy});
      }
#2. newer than last dbEST update
      elsif($mindate){
        my $updated = $attrs->{UpdateDate} || $attrs->{CreateDate};
        my $delta = $self->dateDiff($mindate,$updated);
        # track newest date 
        if(!$maxdate || $mindelta < $delta){
          $mindelta = $delta; $maxdate = $updated; 
        }
        if($delta <= 0){
          my ($acc,$ver) = split(/\./, $attrs->{AccessionVersion});
        # printf STDERR ("\tSKIPPING OLDIE: %s.%s %s < %s\n", $acc,$ver, $updated,$mindate  );
        }
        elsif (defined($accessions->{$acc})) {
          # not annotated as replaced but already exists!
          printf STDERR ("\tFound DUPLICATE RESULT %s.%s, ReplacedBy=%s\n", $acc,$ver,$attrs->{ReplacedBy} || "EMPTYVAL");
        }
        else{
          printf STDERR ("\tNO SKIP! $acc.$ver: $mindate < $updated (d = $delta)\n");
          $accessions->{$acc} = { taxid => $taxid, title => $title, ver => $ver, gi => $id, length => $length };
        }
      }
#3. duplicate (may not even be possible)
      elsif (defined($accessions->{$acc})) {
        # not annotated as replaced but already exists!
        printf STDERR ("\tFound DUPLICATE RESULT %s.%s, ReplacedBy=%s\n", $acc,$ver,$attrs->{ReplacedBy} || "EMPTYVAL");
      }
      else { ## is valid
        $accessions->{$acc} = { taxid => $taxid, title => $title, ver => $ver, gi => $id, length => $length };
      }
######## End Validation ##########
##################################
    }
    last if( $end == $#ids );
    $start += $FetchBatchSize;
    $end = $start + $FetchBatchSize - 1;
    if( $end >= $totalIds ){ $end = $#ids }
    last if( $start >= $totalIds );
    usleep(333333);
  }
  if($mindate){ printf STDERR ("INFO: mindate=$mindate, maxdate=$maxdate ($mindelta)\n") }
  return $accessions;
}

sub getSummaryHash {
  my ($self, $raw) = @_;
  my $hash = {};
  foreach my $entity ( @{$raw->{DocSum}} ){
    my $id = $entity->{Id};
    foreach my $datum ( @{ $entity->{Item} } ){
      if($hash->{ $id }->{ $datum->{Name} }){
        printf STDERR ("WARNING! %s %s has multiple values: %s\n", $id, $datum->{Name}, $datum->{content});
      }
      $hash->{ $id }->{ $datum->{Name} } = $datum->{content};
    }
  }
  return $hash;
}

sub dateDiff {
  my($self, $var1, $var2) = @_;
  if($var1 && $var2){
    my $start = ParseDate($var1);
    my $end = ParseDate($var2);
    my @delta = split(/:/, DateCalc($start,$end));
    return int(($delta[4] / 24) + 0.5);
  }
  return undef;
}

sub parseEstResult {
  my ($self, $res) = @_;
  my $def = $res->{GBSeq_definition};    
  # my ($locusId, $libId, $title,$clone) = ($def =~ m/^(\w+)\s+(\w+)\s+clone\s+(.+)$/i);
  my ($accession,$version) = split(/\./, $res->{'GBSeq_accession-version'});

  ## flatten these
  my $atts = {};
  foreach my $qual(@{$res->{'GBSeq_feature-table'}->{GBFeature}->{GBFeature_quals}->{GBQualifier}}){
    $atts->{ $qual->{GBQualifier_name} } ||= []; 
    push( @{$atts->{ $qual->{GBQualifier_name} }}, $qual->{GBQualifier_value} );
  }
  # skip  if( $res->{GBSeq_comment} && $res->{GBSeq_comment} =~ /replaced by/i){
   
  # concatenate values
  foreach my $k (keys %$atts){ $atts->{$k} = join(",", @{$atts->{$k}}) }
  # qualifiers like 'isolate' may have multiple values, e.g. 3D7,58F
  my ($contact) = ($res->{GBSeq_comment} =~ /contact:\s*(.*)$/i);
  my $replaced = 0;
  if( $res->{GBSeq_comment} && $res->{GBSeq_comment} =~ /replaced by/i){
    $replaced = 1;
  }
  my $comment = $res->{GBSeq_comment};
  my $cmttype = ref($comment) || 'SCALAR';
  unless(ref($comment) eq 'ARRAY'){ $comment = [$comment] }

  # required fields in DoTS
  my ($ncbiTaxonId) = grep { /^taxon:\d+$/ } split(/,/, $atts->{db_xref});
  $ncbiTaxonId =~ s/taxon://;
  my $data = {
    ## replaced: DONTCARE we already filtered out replaced seqs
    # replaced => $replaced,
    taxon => {
      ncbi_tax_id => $ncbiTaxonId
    },
    library => {
      dbest_name => $atts->{clone_lib}, ## probably in format [biosampleId] [actual Id]
                                        ## the old dbEST name was just [actual Id]
      dbest_organism => $res->{GBSeq_source},
      strain => $atts->{isolate},
      is_image => "0",
    },
    clone => {
      dbest_clone_uid => $atts->{clone},
    },
    contact => {
      name => substr($contact,0,254)
    },
    est => { 
      accession => $accession,
      seq_length => $res->{GBSeq_length},
      quality_start => 1,
      possibly_reversed => 0,
      putative_full_length_read => 0,
      trace_poor_quality => 0,
    },
    sequence_check => {
      source_id => $accession,
      subclass_view => 'ExternalNASequence',
    },
    sequence => {
      sequence_version => $version || 1,
      length => $res->{GBSeq_length},
      source_id => $accession,
      subclass_view => 'ExternalNASequence',
    },
    ## keep nuc seq separate, for loading
    nucleotide_seq => $res->{GBSeq_sequence},
    comment => { type => $cmttype, str => $comment },
  };
  return $data
}

sub addLoadedLibrary {
  my ($self, $library) = @_;
  printf STDERR ("************DEBUG: ADDING library %s\n", $library->getDbestName());
  push(@{$self->{_libraries}}, $library);
}
sub getLoadedLibrary {
  my ($self, $taxon, $data) = @_;
  my @libs;
  unless(defined($self->{_libraries})){
    @libs = $taxon->getChildren('GUS::Model::DoTS::Library',1);
    foreach my $lib( @libs ){
      $self->addLoadedLibrary($lib);
    }
  }
  else { @libs = @{$self->{_libraries}} }
  foreach my $lib (@libs){
    my $dbest_name = $lib->getDbestName(); 
    if($dbest_name && ($dbest_name ne $data->{dbest_name})){
      next; # no match
    }
    my $dbest_organism = $lib->getDbestOrganism();
    if($dbest_organism && ($dbest_organism ne $data->{dbest_organism})){
      next; # no match
    }
    my $strain = $lib->getStrain();
    if($strain && ($strain ne $data->{strain})){
      next; # no match
    }
    # match
    return $lib;
  }
  return undef;
}

sub getSequenceOntologyId {
  my ($self) = @_;

  my $name = "EST";

  my $extDbRlsSpec = $self->getArg('SOExtDbRlsSpec');
  my $extDbRlsId = $self->getExtDbRlsId($extDbRlsSpec);
      
  my $sequenceOntology = GUS::Model::SRes::OntologyTerm->new({"name" => $name, "EXTERNAL_DATABASE_RELEASE_ID" => $extDbRlsId});

  $sequenceOntology->retrieveFromDB() || $self->error ("Unable to obtain ontology_term_id from sres.ontologyterm with term_name = EST");

  my $sequence_ontology_id = $sequenceOntology->getId();

  return $sequence_ontology_id;
}

sub undoTables {
  my ($self) = @_;

  return ('DoTS.EST',
#	  'DoTS.Clone',
	  'DoTS.Library',
	  'SRes.Contact',
	  'DoTS.NASequenceImp',
#	  'SRes.ExternalDatabaseRelease',
	 );
}

1;
