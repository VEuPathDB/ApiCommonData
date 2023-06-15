package ApiCommonData::Load::Entrez;

use strict;
use warnings;
require LWP::UserAgent;
use Data::Dumper;
use Time::HiRes qw(usleep);
use JSON;
use XML::Simple;
use Date::Manip qw(UnixDate DateCalc ParseDate);
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

sub getParam { return $_[0]->{$_[1]} }
sub setParam { $_[0]->{$_[1]} = $_[2]; return $_[2] }

sub getUserAgent { return $_[0]->getParam('user_agent') }

sub new {
  my ($class, $params) = @_;
  $params //= {};
  my $self = $params;
  bless($self, $class);

  my $ua = LWP::UserAgent->new;
  $ua->timeout(360); # 6 minutes
  $ua->env_proxy;
  $self->setParam('user_agent',$ua);

  while( my ($k, $v) = each %$params){ $self->setParam($k, $v) }
  

  # print $response->decoded_content;


  return $self;
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
    term => $self->getParam('term'),
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
sub getPubmedRecords {
  my ($self, $ids) = @_;
  my $idList = join(",", @$ids);
  my $params = {
    id => $idList,
    #retmode => 'json',
    db => 'pubmed',
  };
  my $result = $self->postRequest('summary', $params);
# return XMLin($result);
  my $decoded = JSON->new->utf8->decode($result);
  return $decoded;
}
sub getASN {
  my ($self, $ids) = @_;
  my $idList = join(",", @$ids);
  my $params = {
    # rettype => 'gb',
    id => $idList,
    #rettype => 'gbc',
    # retmode => 'xml',
    db => 'nucleotide',
  };
  my $result = $self->postRequest('fetch', $params);
  # return XMLin($result);
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
  my ($self, $dbh, $ncbiTaxId) = @_;
  my $sql = "select taxon_id,ncbi_tax_id from SRes.Taxon WHERE NCBI_TAX_ID < 999999999 start with ncbi_tax_id=? connect by prior taxon_id = parent_id";
  my $taxonId2ncbiTax = $self->selectHashRef($dbh,$sql,[$ncbiTaxId]);
  return $taxonId2ncbiTax
}
sub getInternalSpeciesSubTaxa {
  my ($self, $dbh, $ncbiTaxId) = @_;
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
  my $speciesResult = $self->selectHashRef($dbh,$sql,[$ncbiTaxId]);
  my ($taxonId) = keys %$speciesResult;
  $sql = "select taxon_id from SRes.Taxon WHERE NCBI_TAX_ID < 999999999 start with taxon_id=? connect by prior taxon_id = parent_id";
  my $ids = $self->selectHashRef($dbh,$sql,[$taxonId]);
  return $ids;
}

sub getSubTaxaSearchParams {
  my ($self, $dbh, $ncbiTaxId) = @_;
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
  my $speciesResult = $self->selectHashRef($dbh,$sql,[$ncbiTaxId]);
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

sub getReferenceTaxonIdsFromProject {
  my ($self, $projectDir) = @_;
  opendir(DH, $projectDir) or die "Directory: $projectDir - $@";
  my @orgConfigs = grep { /\.xml$/ } readdir(DH);
  close(DH);
  my $taxa = {};
  my $nonref = {}; # add to reference genome search taxIds
  foreach my $orgc (@orgConfigs){
    my $xml = XMLin( "$projectDir/$orgc");
    my $organismAbbrev = $xml->{constant}->{organismAbbrev}->{value};
    my $taxid = $xml->{constant}->{ncbiTaxonId}->{value};
    my $speciestaxid = $xml->{constant}->{speciesNcbiTaxonId}->{value};
    my $refStrain = $xml->{constant}->{familyRepOrganismAbbrev}->{value};
    if( $refStrain eq $organismAbbrev ){
      # found reference strain
      # printf STDERR ("Found ref: %s %s\n", $organismAbbrev, $taxid);
      $taxa->{$organismAbbrev}->{$taxid} = 1;
      $taxa->{$organismAbbrev}->{$speciestaxid} = 1;
    }
  # else {
  #   $nonref->{$refStrain}->{$organismAbbrev} = $xml->{constant}->{speciesNcbiTaxonId}->{value};
  # }
  }
  # feed nonref taxids back into refs
 #while( my ($repOrganismAbbrev, $subtax) = each %$nonref){
 #  if( $taxa->{ $repOrganismAbbrev } ){
 #    $taxa->{ $repOrganismAbbrev }->{$_} = 1 for values %$subtax;
 #  }
 #}
  # convert to arrayref
  while( my ($organismAbbrev, $tax) = each %$taxa){
    my @arr = keys %$tax;
    $taxa->{$organismAbbrev} = \@arr;
  }
  return $taxa;
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
  my($self, $dbh, $ncbiTaxId) = @_;
  my $taxa = $self->getInternalSpeciesSubTaxa($dbh,$ncbiTaxId);
 #my $t = GUS::Model::SRes::Taxon->new({ncbi_tax_id=>$ncbiTaxId});
 #die "Species not found for NCBI taxon Id $ncbiTaxId" unless ($t->retrieveFromDB());
 #my $_taxId = $t->getId();
  # printf STDERR ("Found taxon_id=%d (%d)\n", $ncbiTaxId, $_taxId);
  my $taxIdList = join(",", keys %$taxa );
  printf STDERR ("EST audit: Taxon ID %d search expanded to %d subtaxa\n",
    $ncbiTaxId, scalar keys %$taxa); 
  my $sql = <<_SQL;
SELECT DISTINCT e.ACCESSION, l.DBEST_NAME
FROM dots.est e
LEFT JOIN dots.LIBRARY l ON e.LIBRARY_ID =l.LIBRARY_ID 
WHERE l.TAXON_ID IN ($taxIdList)
_SQL
  return $self->selectHashRef($dbh,$sql);
}

sub getLoadedESTAccessionsByTaxId {
  my($self, $dbh, $ncbiTaxIds) = @_;
 #my $t = GUS::Model::SRes::Taxon->new({ncbi_tax_id=>$ncbiTaxId});
 #die "Species not found for NCBI taxon Id $ncbiTaxId" unless ($t->retrieveFromDB());
 #my $_taxId = $t->getId();
  # printf STDERR ("Found taxon_id=%d (%d)\n", $ncbiTaxId, $_taxId);
  my $taxIdList = join(",", @$ncbiTaxIds);
  my $sql = <<_SQL;
SELECT DISTINCT e.ACCESSION, l.DBEST_NAME
FROM dots.est e
LEFT JOIN dots.LIBRARY l ON e.LIBRARY_ID =l.LIBRARY_ID 
LEFT JOIN sres.TAXON t on l.TAXON_ID = t.TAXON_ID
WHERE t.NCBI_TAX_ID IN ($taxIdList)
_SQL
  return $self->selectHashRef($dbh,$sql);
}


sub downloadToFasta {
  my ($self, $fh, $_ids) = @_;
  my @ids = @$_ids; # syntax
  my $totalIds = scalar @ids;
  my $start = 0;
  my $end = $start + $FetchBatchSize - 1;
  if($end > $totalIds){ $end = $#ids } 
  while( $start < $#ids ){
    my @batch = @ids[ $start .. $end ];
    printf STDERR ("\tDownloading FASTA batch %d - %d ( %d %% )...", $start, $end, $end * 100 / $totalIds);
    my $result = $self->getFasta(\@batch);
    print $fh $result;
    last if( $end == $#ids );
    $start += $FetchBatchSize;
    $end = $start + $FetchBatchSize - 1;
    if( $end >= $totalIds ){ $end = $#ids }
    last if( $start >= $totalIds );
    usleep(333333);
  }
  return;
} 
  

sub getGenbankESTAccessionsbyTaxId {
  my($self, $ncbiTaxIds, $mindate) = @_;
### MUST FIRST SET TERM WITH $self->setParam('term', $term)
 #my $term = sprintf('is_est[filter] AND (%s)',
 #  join(" OR ", map { sprintf('txid%d[organism:noexp]',$_) } @$ncbiTaxIds)
 #);
 #$self->setParam('term',$term);
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
      is_image => '0',
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


1;
