package ApiCommonData::Load::LineageTaxonLinkingTable;

@ISA = (GUS::PluginMgr::Plugin);

use strict;
use warnings;
use GUS::PluginMgr::Plugin;
use GUS::Model::Results::LineageTaxon;
use feature 'say';

my $documentation = { purpose =>"Map results using other taxonomies to the NCBI taxonomy",
                      purposeBrief     =>"",
                      notes            =>"",
                      tablesAffected   =>"Results.LineageTaxon",
                      tablesDependedOn =>"sres.TaxonName, sres.Taxon, Results.LineageAbundance",
                      howToRestart     =>"",
                      failureCases     =>"", };
sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);
  $self->initialize({ requiredDbVersion => 4.0,
                      cvsRevision       => '$Revision$',
                      name              => ref($self),
                      argsDeclaration   => [],
                      documentation     => $documentation});
  return $self;
}
sub taxonSths {
  my ($dbh) = @_;
  my $taxonsByNameSth = $dbh->prepare(<<SQL) or die $dbh->errstr;
    select t.taxon_id, t.parent_id, t.ncbi_tax_id
    from sres.TaxonName tn, sres.Taxon t
    where tn.name = ?
      and tn.taxon_id = t.taxon_id
SQL
  my $taxonByIdSth = $dbh->prepare(<<SQL)  or die $dbh->errstr;
    select tn.name, t.parent_id
    from sres.TaxonName tn, sres.Taxon t
    where t.taxon_id = ?
      and tn.taxon_id = t.taxon_id
SQL
  return $taxonsByNameSth, $taxonByIdSth;
}

sub idOfAncestorThatHasName {
  my ($taxonByIdSth, $id, $queryName) = @_;
  L:
  return unless $id;
  $taxonByIdSth->execute($id);
  my ($name, $nextId) = $taxonByIdSth->fetchrow_array;
  if ($name =~ /$queryName/){
#    say STDERR "taxonByIdSth($id): name=$name, nextId=$nextId\n";
    return $id;
  } else {
    $id = $nextId;
    goto L;
  }
}

sub findTaxonForLineage {
  my ($taxonsByNameSth, $taxonByIdSth, $lineage) = @_;
  my ($l, @ls) = map {
    # Make sure a few popular results get mapped as we want them to
    $_ =~ s{^Escherichia[-/]Shigella$}{Escherichia};
    $_ =~ s{ group$}{};
    $_ =~ s{^Clostridium sensu stricto \d+$}{Clostridium};
    $_ } reverse split ";", $lineage;

  # Get taxon nodes whose name matches the last part of the lineage
  $taxonsByNameSth->execute($l);
  my @results = map {
    ({resultTaxonId => $_->[0], ancestorIdAux => $_->[1], resultNcbiTaxId => $_->[2], lastNameMatchedAux => $ls[0]})
  } @{$taxonsByNameSth->fetchall_arrayref};

  # If a single node matches the last part of the lineage, take it, even if the rest doesn't match
  # but if there are multiple nodes returned, resolve it by looking at names of their parents
  while(@results > 1 ){
  #   say STDERR join " ",$ApiCommonData::Load::c++, "\t", $ls[0] // "_", "\t", map {"$_->{resultNcbiTaxId},ancestor $_->{ancestorIdAux} / $_->{nameAux}"} @results;
     unless (@ls){
       @results = ();
     }
     @results = map {
       my $id = idOfAncestorThatHasName($taxonByIdSth, $_->{ancestorIdAux}, $ls[0]);
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
  return map {$_->{resultTaxonId}} @results; # change resultTaxonId->resultNcbiTaxId for debugging
}

sub run {
  my ($self) = @_;

  my $dbh = $self->getQueryHandle;

  my $countTaxaSth = $dbh->prepare('select count(*) from sres.Taxon');
  $countTaxaSth->execute;
  my ($numTaxa) = $countTaxaSth->fetchrow_array;
  if ($numTaxa){
    $self->log("$numTaxa taxon entries available in sres.Taxon");
  } else {
    $self->error("No taxons in sres.Taxon - can't create linking table");
  }

  my $lineagesSth = $dbh->prepare('select distinct lineage from results.LineageAbundance');
  $lineagesSth->execute; 
  my $lineages = $lineagesSth->fetchall_arrayref;
  my $numLineages = scalar @{$lineages};
  if ($numLineages){
    $self->log("Finding taxa for $numLineages lineages in results.LineageAbundance");
  } else {
    $self->error("No lineages in results.LineageAbundance - can't create linking table");
  }
  my @taxonSths = taxonSths($dbh);
  my $lineageTaxonSubmitted;
  LINEAGE:
  for my $lineage (map {@{$_}} @{$lineages}){
     my ($taxonId) = findTaxonForLineage(@taxonSths, $lineage);
     next LINEAGE unless $taxonId;
     GUS::Model::Results::LineageTaxon->new({lineage => $lineage, taxon_id => $taxonId})->submit;
     $lineageTaxonSubmitted++;
  }
  if ($lineageTaxonSubmitted){
    $self->log("Found taxa for $lineageTaxonSubmitted/$numLineages lineages");
  } else {
    $self->error("Complete fiasco: no taxa found for $numLineages lineages");
  }
}

sub undoTables {
  return (
    'Results.LineageTaxon'
  );
}
1;
