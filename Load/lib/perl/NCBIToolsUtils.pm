package ApiCommonData::Load::NCBIToolsUtils;

## a useful collection of subroutine that be used for NCBI tools
## use ApiCommonData::Load::NCBIToolsUtils;

use LWP::Simple;
use strict;

use List::Util qw[min max];  ## the min and max subroutine that will take min or max of more than 2 items
use XML::Simple;


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
    $esearch = "$utils/esearch.fcgi?api_key=f2006d7a9fa4e92b2931d964bb75ada85a08&db=$database&term=$query&usehistory=y";
    print STDERR "\$esearch = $esearch\n";

    $result = get($esearch);
    #print STDERR "$result";

    $uid = $1 if ($result =~ /<Id>(\d+)<\/Id>/);
    if (!$uid) {
#      die "Can not find NCBI taxonomy ID for '$query', please try an upper level\n";
      warn "Can not find NCBI taxonomy ID for '$query', please try an upper level\n";
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

sub getNcbiTaxonIdFromOrganismName {
  my ($query) = @_;

  my ($esearch, $efetch, $result, $uid);
  my $utils = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils";

    $query =~ s/\"|\'//g;
    $query =~ s/\s+/\+/g;  ## replace a space sign " " with a plus sign +

    ## using esearch to find uid
    $esearch = "$utils/esearch.fcgi?api_key=f2006d7a9fa4e92b2931d964bb75ada85a08&db=taxonomy&term=$query&usehistory=y";
#    print STDERR "\$esearch = $esearch\n";

    $result = get($esearch);
#    print STDERR "$result";

    $uid = $1 if ($result =~ /<Id>(\d+)<\/Id>/);
    if (!$uid) {
      warn "Can not find NCBI taxonomy ID for '$query', please try an upper level\n";
    }

  ## to obtain an uid, use efetch or esummary to either retrieve the full or summary record
  $efetch = "$utils/efetch.fcgi?db=taxonomy&id=$uid";
  $result = get($efetch);

  ## use xmlParser
  my $simple = XML::Simple->new();
  my $tree = $simple->XMLin($result);
  foreach my $tree (sort keys %{$tree}) {
#    print STDERR "\$tree = $tree\n";
  }

  return $tree->{Taxon}->{TaxId};
}

sub eSearch4OrganismId {
  my ($query) = @_;

  my $db = "taxonomy";
  my ($esearch, $result, $uid);
  my $utils = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils";

  $query =~ s/\"|\'//g;
  $query =~ s/\s+/\+/g;  ## replace a space sign " " with a plus sign +

  ## using esearch to find uid
  $esearch = "$utils/esearch.fcgi?api_key=f2006d7a9fa4e92b2931d964bb75ada85a08&db=$db&term=$query&usehistory=y";
  $result = get($esearch);
#  print STDERR "\$result = $result\n";

  die "Don't get result for\n  $esearch\n" if (!$result);

  my $xmlResult = xmlParser4Taxonomy ($result);

  return $xmlResult->{IdList}->{Id};
}

sub eFetch4ResultPage {
  my ($query) = @_;

  my $utils = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils";
  my $db = "taxonomy";

  my $uid = ($query =~ /^\d+$/) ? $query : eSearch4OrganismId ($query);

  ## to obtain an uid, use efetch or esummary to retrieve either the full or summary record
  my $efetch = "$utils/efetch.fcgi?db=$db&id=$uid";
  my $result = get($efetch);

  return xmlParser4Taxonomy($result);
}

sub xmlParser4Taxonomy {
  my ($query) = @_;

  my $simple = XML::Simple->new();
  my $tree = $simple->XMLin($query);

  return $tree;
}

sub getTaxonId {
  my ($xmlHash) = @_;

#  print STDERR "To check: $xmlHash->{Taxon}->{TaxId}\n";
  return $xmlHash->{Taxon}->{TaxId};
}

sub getSpeciesName {
  my ($xmlHash) = @_;

#  print STDERR "To check: $query->{Taxon}->{LineageEx}->{Taxon}->[1]->{ScientificName}\n";
  foreach my $lineage (@{$xmlHash->{Taxon}->{LineageEx}->{Taxon}}) {
    if ($lineage->{Rank} eq "species") {
      return $lineage->{ScientificName};
    }
  }
}

sub getSpeciesTaxonId {
  my ($xmlHash) = @_;

  foreach my $lineage (@{$xmlHash->{Taxon}->{LineageEx}->{Taxon}}) {
    if ($lineage->{Rank} eq "species") {
      return $lineage->{TaxId};
    }
  }
}

sub getGenusName {
  my ($xmlHash) = @_;

  foreach my $lineage (@{$xmlHash->{Taxon}->{LineageEx}->{Taxon}}) {
    #print "\$lineage = $lineage->{ScientificName}\n";
    if ($lineage->{Rank} eq "genus") {
      return $lineage->{ScientificName};
    }
  }
}

sub getGenusTaxonId {
  my ($xmlHash) = @_;

#  print "To check: $xmlHash->{Taxon}->{LineageEx}->{Taxon}->[1]->{ScientificName}\n";
  foreach my $lineage (@{$xmlHash->{Taxon}->{LineageEx}->{Taxon}}) {
    if ($lineage->{Rank} eq "genus") {
      return $lineage->{TaxId};
    }
  }
}

sub getFamilyName {
  my ($xmlHash) = @_;

  foreach my $lineage (@{$xmlHash->{Taxon}->{LineageEx}->{Taxon}}) {
    if ($lineage->{Rank} eq "family") {
      return $lineage->{ScientificName};
    }
  }
}

sub getFamilyTaxonId {
  my ($xmlHash) = @_;

  foreach my $lineage (@{$xmlHash->{Taxon}->{LineageEx}->{Taxon}}) {
    if ($lineage->{Rank} eq "family") {
      return $lineage->{TaxId};
    }
  }
}


1;
