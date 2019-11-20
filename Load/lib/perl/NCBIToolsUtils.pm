package ApiCommonData::Load::NCBIToolsUtils;

## a useful collection of subroutine that be used for NCBI tools
## use ApiCommonData::Load::NCBIToolsUtils;

use LWP::Simple;
use strict;

use List::Util qw[min max];  ## the min and max subroutine that will take min or max of more than 2 items


## pass organism name or ncbi taxonomy id then return ncbi taxonomy id, genetic code, and mito- genetic code
## getGeneticCodeFromNcbiTaxonomy($query, $database)

sub getGeneticCodeFromNcbiTaxonomy {
  my ($query, $database) = @_;

  my ($esearch, $efetch, $result, $uid);
  my $utils = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils";

  if ($query =~ /^\d+/) {
    $uid = $query;

  } else {
    $query =~ s/\"|\'//g;
    $query =~ s/\s+/\+/g;  ## replace space " " with a plus sign +

    ## using esearch to find uid
    $esearch = "$utils/esearch.fcgi?db=$database&term=$query";
    print STDERR "\$esearch = $esearch\n";

    $result = get($esearch);
    #  print STDERR "$result";

    $uid = $1 if ($result =~ /<Id>(\d+)<\/Id>/);
    if (!$uid) {
      die "Can not find NCBI taxonomy ID for '$query', please try an upper level\n";
    }
  }

  ## to obtain an uid, use efetch or esummary to either retrieve the full or summary record
  $efetch = "$utils/efetch.fcgi?db=$database&id=$uid";
  print STDERR "\$efetch = $efetch\n";

  $result = get($efetch);
  #print STDERR "$result";

  my $gc = $1 if ($result =~ /<GCId>(\d+)<\/GCId>/);
  my $mgc = $1 if ($result =~ /<MGCId>(\d+)<\/MGCId>/);

  return ($uid, $gc, $mgc);
}

1;
