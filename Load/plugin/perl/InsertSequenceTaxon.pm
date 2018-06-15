package ApiCommonData::Load::Plugin::InsertSequenceTaxon;

@ISA = qw(GUS::PluginMgr::Plugin);
use GUS::PluginMgr::Plugin;
use strict;

use XML::Simple;

use GUS::Model::ApiDB::SequenceTaxonString;
use GUS::Model::ApiDB::TaxonString;

use Data::Dumper;

my $argsDeclaration =
  [

 fileArg({   name           => 'sequenceToTaxonHierarchyFile',
	     descr          => 'The file that maps an otu identifier to a string specifying a path through the taxonomy',
	     reqd           => 1,
	     constraintFunc => undef,
             mustExist      => 1,
             format         => "<OTU ID><tab><taxon string>",
             isList         => 0 }),

 fileArg({   name           => 'taxonMappingFile',
	     descr          => 'The XML file of override mappings from taxon hierarchy strings to NCBI taxon ID mapping overrides',
	     reqd           => 1,
	     constraintFunc => undef,
             mustExist      => 1,
             format         => "XML",
             isList         => 0 }),

 stringArg({ name           => 'dbRlsSpec',
             descr          => 'The external db name and db release version, separated by a pipe',
             reqd           => 1,
             constraintFunc => undef,
             isList         => 0
           }),

  ];

my $documentation = { purpose          => "",
                      purposeBrief     => "",
                      notes            => "",
                      tablesAffected   => "",
                      tablesDependedOn => "",
                      howToRestart     => "",
                      failureCases     => "" };

# ----------------------------------------------------------------------

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  $self->initialize({ requiredDbVersion => 4.0,
                      cvsRevision       => '$Revision$',
                      name              => ref($self),
                      argsDeclaration   => $argsDeclaration,
                      documentation     => $documentation});

  return $self;
}

# ======================================================================

sub run {
  my ($self) = @_;

  $self->{external_database_release_id} = $self->getExtDbRlsId($self->getArg('dbRlsSpec'));

  # $self->{external_database_release_id} = 1234;
  my %taxonStringMap;
  $self->setOverrideMapping(\%taxonStringMap);

  my %sequenceIdMap;
  $self->setSequenceIdMapping(\%sequenceIdMap);

  my $dbh = $self->getQueryHandle();

  my $taxonStringIdQ = $dbh->prepare(<<SQL) or die $dbh->errstr;
    select taxon_string_id
    from apidb.taxonstring
    where taxon_id = ?
SQL

  # prepare first-pass query, which searches for a single name
  my $singleTaxonQ = $dbh->prepare(<<SQL) or die $dbh->errstr;
    select count(*) as taxon_count, max(tn.taxon_id) as taxon_id, max(t.rank) as rank
    from sres.TaxonName tn, sres.Taxon t
    where tn.name = ?
      and tn.taxon_id = t.taxon_id
      and t.rank = ?
      and t.ncbi_tax_id not in (-- avoid specific problem names:
                    629395,   -- 'Bacteria', a genus of stick insect
                    551299,   -- 'Spirulina', a suborder of molluscs
                    210425,   -- 'Proteus', a genus of salamanders
                    169215,   -- 'Bosea', a genus of flowering plants
                    79255,    -- 'Gordonia', a genus of flowering plants
                    46073,    -- 'Buchnera', a genus of flowering plants
                    177871, 177878, -- two different wrong kinds of "Leptonema"
                    177878,   -- and other eukaryotes
                    40929, 1661425, 1260513, 55087, 1445919, 869314,
                    1091138, 108061, 444888, 508215, 141190, 132406,
                    90690, 249411, 164984, 177871,
                    -1        -- nonsense so I can leave the comma on the previous line
                                )
SQL

  # prepare fallback query, which uses an (ancestor/descendant) taxon-name pair
  my $doubleTaxonQ = $dbh->prepare(<<SQL) or die $dbh->errstr;
    with candidate -- a taxon_id for the input descendant-name string
         as (  select distinct taxon_id
               from sres.TaxonName
               where name = ? -- descendant taxon name
             minus
               select taxon_id
               from sres.Taxon
               where ncbi_tax_id in ( -- taxa we don't want to consider as the intended taxon
                                     629395  -- 'Bacteria', a genus of stick insect
                                    )
            ),
         taxonTree -- ancestor-descendant taxon_id pairs from Taxon
         as (select connect_by_root t.taxon_id as descendant_taxon_id, t.parent_id as ancestor_taxon_id
             from sres.Taxon t
             start with t.taxon_id in (select taxon_id from candidate)
             connect by t.taxon_id = prior t.parent_id),
         match -- ancestor-descendant pairs from the taxonTree subquery where the ancestor has the name we want
         as (select ancestor_taxon_id, descendant_taxon_id
             from taxonTree
             where ancestor_taxon_id in (select taxon_id
                                         from sres.TaxonName
                                         where name = ?) -- given ancestor name
            ),
         summary
         as (select count(distinct descendant_taxon_id) as descendant_count,
                    max(descendant_taxon_id) as descendant_taxon_id,
                    max(ancestor_taxon_id) as ancestor_taxon_id
             from match)
    select case descendant_count
             when 0 then 'ancestor name not found'
             when 1 then 'match'
             when 2 then 'multiple matches'
           end as status,
           ancestor_taxon_id, descendant_taxon_id
    from summary
SQL

  my $filename = $self->getArg('sequenceToTaxonHierarchyFile');
  open (my $fh, "<", $filename) or die "can't open file \"$filename\"";

  my $failFlag;
  my $count = 0;

  while (<$fh>) {
    chomp;
    $count++;
    unless ($count % 5000) {
      $self->log("Processed $count records.");
      $self->undefPointerCache();
    }

    #checks how many cols we have and if its only one assume it is taxonList
    my ($id, $taxonList) = split /\t/;
    my $na_sequence_id;
    if ($taxonList) {
      # find na_sequence_id corresponding to Greengenes ID
      $na_sequence_id = $sequenceIdMap{$id};
      unless ($na_sequence_id) {
        $self->log("WARN: Can't find Greengenes ID \"$id\" as an NaSequence.source_id");
        next;
      }
    } else {
      $taxonList = $id;
      $id = undef;
      $na_sequence_id = undef;
    }

    if ($taxonStringMap{$taxonList}) {
      my $st = GUS::Model::ApiDB::TaxonString->
        new({'taxon_id' => $taxonStringMap{$taxonList},
             'taxon_string' => $taxonList});
      $st->submit();
      if ($na_sequence_id) {
        $taxonStringIdQ->execute($taxonStringMap{$taxonList}) or die $dbh->errstr;
        my ($taxonStringId) = $taxonStringIdQ->fetchrow_array();
        $taxonStringIdQ->finish() or die $dbh->errstr;
        my $st = GUS::Model::ApiDB::SequenceTaxonString->
          new({'na_sequence_id' => $na_sequence_id,
	       'external_database_release_id' => $self->{external_database_release_id},
               'taxon_string_id' => $taxonStringId});
        $st->submit();
      }
      next;  
    }

    my @taxa = split(/; /, $taxonList);

    # if we get a genus and species, we must also look in TaxonName for their
    # concatenation
    if ($taxonList =~ /; g__(.*); s__(.*)$/) {
      if ($1 && $2) {
	push(@taxa, "X__$1 $2");
      }
    }

    my %rankMapping = ("k", "superkingdom",
		       "p", "phylum",
		       "c", "class",
		       "o", "order",
		       "f", "family",
		       "g", "genus",
		       "s", "species",
		       "X", "species",
		      );

    while (@taxa) {
      my $taxonString = pop(@taxa);
      my $taxon = substr($taxonString, 3);
      next unless $taxon;
      my $rankCode = substr($taxonString, 0, 1);

      # if the name is entirely surrounded by square brackets, strip 'em off
      if ($taxon =~ /^\[(.*)\]$/) {
	$taxon = $1;
      }

      $singleTaxonQ->execute($taxon, $rankMapping{$rankCode}) or die $dbh->errstr;
      my ($taxonCount, $taxonId, $rank) = $singleTaxonQ->fetchrow_array();
      $singleTaxonQ->finish() or die $dbh->errstr;

      if ($taxonCount == 1) {
	# success: we uniquely identified this taxon

	# store this (sequence-taxon) pair
	my $st = GUS::Model::ApiDB::TaxonString->
        new({'taxon_id' => $taxonId,
             'taxon_string' => $taxonList});
        $st->submit();
        if ($na_sequence_id) {
          $taxonStringIdQ->execute($taxonStringMap{$taxonList}) or die $dbh->errstr;
          my ($taxonStringId) = $taxonStringIdQ->fetchrow_array();
          $taxonStringIdQ->finish() or die $dbh->errstr;
          my $st = GUS::Model::ApiDB::SequenceTaxonString->
            new({'na_sequence_id' => $na_sequence_id,
                 'external_database_release_id' => $self->{external_database_release_id},
                 'taxon_string_id' => $taxonStringId});
          $st->submit();
        }

	# cache this taxon string->taxon ID mapping for the rest of the run
	$taxonStringMap{$taxonList} = $taxonId;

	# stop looping through the taxon names in this list
	@taxa = undef;
      } elsif ($taxonCount > 1) {

	$self->log("non-unique name \"$taxon\"");

	unless (@taxa) {
	  # multiple taxa matched, and we're out of ancestors to disambiguate them by
	  $failFlag = 1;
	  $self->log("Failed to differentiate taxa with shared name \"$taxon\" in Greengenes taxon string \"$taxonList\"");
	}

	while (@taxa) {
	  my $ancestor = substr(pop(@taxa), 3);
	  next unless $ancestor;
	  $doubleTaxonQ->execute($taxon, $ancestor) or die $dbh->errstr;
	  my ($status, $taxonId, $descendantTaxonId) = $doubleTaxonQ->fetchrow_array();
	  $doubleTaxonQ->finish() or die $dbh->errstr;

	  $self->log("status \"$status\" from doubleTaxonQ(\"$taxon\", \"$ancestor\")");
	  if ($status eq "match") {
	    # success: we uniquely identified this taxon

	    # store this (sequence-taxon) pair
            my $st = GUS::Model::ApiDB::TaxonString->
            new({'taxon_id' => $taxonId,
                 'taxon_string' => $taxonList});
            $st->submit();
            if ($na_sequence_id) {
              $taxonStringIdQ->execute($taxonStringMap{$taxonList}) or die $dbh->errstr;
              my ($taxonStringId) = $taxonStringIdQ->fetchrow_array();
              $taxonStringIdQ->finish() or die $dbh->errstr;
              my $st = GUS::Model::ApiDB::SequenceTaxonString->
                new({'na_sequence_id' => $na_sequence_id,
                     'external_database_release_id' => $self->{external_database_release_id},
                     'taxon_string_id' => $taxonStringId});
              $st->submit();
            }

	    # cache this taxon string->taxon ID mapping for the rest of the run
	    $taxonStringMap{$taxonList} = $taxonId;

	    # stop looping through the taxon names in this list
	    @taxa = undef;
	  }

	} # while seeking two-name match
      } else {
	# $self->log("can't find taxon \"$taxon\" of rank \"$rankMapping{$rankCode}\" for taxon string \"$taxonString\"");
	if (scalar(@taxa) == 0) {
	  # multiple taxa matched, and we're out of ancestors to disambiguate them by
	  $failFlag = 1;
	  $self->log("Failed to find a unique taxon name in Greengenes taxon string \"$taxonList\"");
	}
      }

    } # WHILE seeking one-name match

  } # WHILE looping through file

  die "parsing Greengenes taxon strings" if $failFlag;

  my $result = "Run finished; processed $count records in input file.";
  return $result;
}

sub setOverrideMapping {
  # pre-load taxon string to taxon ID mapping from a file

  my ($self, $overrideHashref) = @_;

  my $simple = XML::Simple->new();
  my $overrideMapping = $simple->XMLin($self->getArg('taxonMappingFile'));

  # prepare query to turn NCBI taxon IDs in override file into GUS taxon IDs
  my $dbh = $self->getQueryHandle();
  my $taxonIdQ = $dbh->prepare(<<SQL) or die $dbh->errstr;
    select taxon_id
    from sres.Taxon
    where ncbi_tax_id = ?
SQL

  foreach my $mapping (@{$overrideMapping->{mapping}}) {
    my $taxonList = $mapping->{taxonList};
    my $ncbiTaxonId = $mapping->{ncbiTaxonId};
    $taxonIdQ->execute($ncbiTaxonId) or die $dbh->errstr;
    my ($taxonId) = $taxonIdQ->fetchrow_array() or die $dbh->errstr;
    ${$overrideHashref}{$taxonList} = $taxonId;
    $taxonIdQ->finish();
  }
}

sub setSequenceIdMapping {
  # cache (source_id, na_sequence_id) pairs
  # (the former are Greengenes IDs)

  my ($self, $sequenceHashref) = @_;

  my $dbh = $self->getQueryHandle();
  my $seqIdQ = $dbh->prepare(<<SQL) or die $dbh->errstr;
    select source_id, na_sequence_id
    from dots.ExternalNaSequence
    order by source_id
SQL

  $seqIdQ->execute() or die $dbh->errstr;
  while (my ($sourceId, $naSequenceId) = $seqIdQ->fetchrow_array()) {
    ${$sequenceHashref}{$sourceId} = $naSequenceId;
  }
  $seqIdQ->finish();

}

sub undoTables {
  my ($self) = @_;

  return (
    'ApiDB.SequenceTaxonString',
     );
}

1;

