# originally developed for SILVA
# Works for cleaned up lineages
use strict;
use warnings;
use DBI;

package ApiCommonData::Load::Biom::NcbiTaxons;
sub new {
  my ($class, $dbh) = @_;
  my $self = {};
  $self->{taxonsByNameSth} = $dbh->prepare(<<SQL) or die $dbh->errstr;
    select t.taxon_id, t.parent_id, t.ncbi_tax_id
    from sres.TaxonName tn, sres.Taxon t
    where tn.name = ?
      and tn.taxon_id = t.taxon_id
SQL
  $self->{taxonByIdSth} = $dbh->prepare(<<SQL)  or die $dbh->errstr;
    select tn.name, t.parent_id
    from sres.TaxonName tn, sres.Taxon t
    where t.taxon_id = ?
      and tn.taxon_id = t.taxon_id
SQL
  return bless $self, $class;
}

sub idOfAncestorThatHasName {
  my ($self, $id, $queryName) = @_;
  L:
  return unless $id;
  $self->{taxonByIdSth}->execute($id);
  my ($name, $nextId) = $self->{taxonByIdSth}->fetchrow_array;
  if ($name =~ /$queryName/){
#     say STDERR "taxonByIdSth($id): name=$name, nextId=$nextId\n";
    return $id;
  } else {
    $id = $nextId;
    goto L;
  }
}
sub findTaxonForLineage {
  my ($self, $lineage) = @_;
  return unless $lineage;

  my ($l, @ls) = map {
    # Make sure a few popular results get mapped as we want them to
    $_ =~ s{^Escherichia[-/]Shigella$}{Escherichia};
    $_ =~ s{ group$}{};
    $_ =~ s{^Clostridium sensu stricto \d+$}{Clostridium};
    $_ } reverse split ";", $lineage;

  # Get taxon nodes whose name matches the last part of the lineage
  $self->{taxonsByNameSth}->execute($l);
  my @results = map {
    ({resultTaxonId => $_->[0], ancestorIdAux => $_->[1], resultNcbiTaxId => $_->[2], lastNameMatchedAux => $ls[0]})
  } @{$self->{taxonsByNameSth}->fetchall_arrayref};

  # If a single node matches the last part of the lineage, take it, even if the rest doesn't match
  # but if there are multiple nodes returned, resolve it by looking at names of their parents
  while(@results > 1 ){
  #   say STDERR join " ",$ApiCommonData::Load::c++, "\t", $ls[0] // "_", "\t", map {"$_->{resultNcbiTaxId},ancestor $_->{ancestorIdAux} / $_->{nameAux}"} @results;
     unless (@ls){
       @results = ();
     }
     @results = map {
       my $id = $self->idOfAncestorThatHasName($_->{ancestorIdAux}, $ls[0]);
       ({
         resultTaxonId => $_->{resultTaxonId},
         resultNcbiTaxId => $_->{resultNcbiTaxId},
         ancestorIdAux => $id // "",
         lastNameMatchedAux => $id ? $ls[0] : ""
       })
     } @results;

     my @ys = map { $_->{lastNameMatchedAux} eq $ls[0] ? $_ : ()} @results;

     if (@ys){
       # We've found a match among the parents
       @results = @ys;
       # if we're not done, then the multiple nodes with the same name also have parents with the same name, and we need to look at parents of those
       shift @ls;
     } else {
       # No parent matches, no more ancestors to look at
       @results = ();
     }
  }
  # @results > 1 is no longer true, so there can be 0 or 1 result; 
  return unless @results;
  return $results[0]->{resultTaxonId}; # change resultTaxonId->resultNcbiTaxId for debugging
}
1;
