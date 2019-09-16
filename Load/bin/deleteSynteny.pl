#!/usr/bin/perl
use strict;
use warnings;
use lib "$ENV{GUS_HOME}/lib/perl";
use DBI;
use Getopt::Long qw(GetOptions);
use CBIL::Util::PropertySet;
use Data::Dumper;

my ($gusConfig, $organismAbbrev, $commit);

GetOptions(
	'o|organismAbbrev=s' => \$organismAbbrev,
	'g|gus_config=s' => \$gusConfig,
	'c|commit' => \$commit,
);

unless($organismAbbrev) {
  print STDERR "usage:  perl deleteSynteny.pl --organismAbbrev <organismAbbrev>\n";
  exit;
}


unless($gusConfig && -e $gusConfig) {
  # print STDERR "gus.config not found... using default\n";
  $gusConfig = $ENV{GUS_HOME} ."/config/gus.config";
}

my $gusconfig = CBIL::Util::PropertySet->new($gusConfig, undef, 1);

my $u = $gusconfig->{props}->{databaseLogin};
my $pw = $gusconfig->{props}->{databasePassword};
my $dsn = $gusconfig->{props}->{dbiDsn};

my $dbh = DBI->connect($dsn, $u, $pw, {AutoCommit => 0}) or die DBI::errstr;

#########################################################
### get database and release ids before deleting anything
my $sql = <<SQL;
select s.synteny_id, d.name, d.EXTERNAL_DATABASE_ID, s.external_database_release_id
from apidb.organism o
	, dots.nasequence nas
	, apidb.synteny s
	, sres.externaldatabaserelease r
	, SRES.EXTERNALDATABASE d
where o.abbrev = ? 
	and s.EXTERNAL_DATABASE_RELEASE_ID = r.EXTERNAL_DATABASE_RELEASE_ID
	and r.EXTERNAL_DATABASE_ID = d.EXTERNAL_DATABASE_ID
	and o.taxon_id = nas.taxon_id
	and (nas.na_sequence_id = s.A_NA_SEQUENCE_ID OR nas.na_sequence_id = s.b_na_sequence_id)
SQL
my $sh = $dbh->prepare($sql);
$sh->execute($organismAbbrev) or die $sh->errstr;
my %dbids;
my %relids;
my @synids;
while(my $row = $sh->fetchrow_arrayref){
	push(@synids, $$row[0]);
	$dbids{$$row[2]} = 1;
	$relids{$$row[3]} = 1;
}
unless( 0 < $sh->rows ){
	printf STDERR ("Nothing found for organism %s, exiting\n", $organismAbbrev);
	$dbh->disconnect;
	exit;
}
my @dbid = sort keys %dbids; ## not used, but could be useful for debugging
my @relid = sort keys %relids; ## not used, but could be useful for debugging


#########################################################
## delete rows from apidb.syntentyanchor
printf STDERR ("Deleting from apidb.syntenicgene by synteny_id for %s\n", $organismAbbrev);
$sql = <<SQL;
delete from apidb.syntenicgene where synteny_id in (
	select distinct(s.synteny_id)
	from apidb.organism o
		, dots.nasequence nas
		, apidb.synteny s
		, sres.externaldatabaserelease r
		, sres.externaldatabase d
	where o.abbrev = ? 
		and s.external_database_release_id = r.external_database_release_id
		and o.taxon_id = nas.taxon_id
		and (nas.na_sequence_id = s.a_na_sequence_id or nas.na_sequence_id = s.b_na_sequence_id)
)
SQL
my $start = time();
$sh = $dbh->prepare($sql);
$sh->execute($organismAbbrev) or die $sh->errstr;
my $took = time() - $start;
printf STDERR ("Deleted %d rows from apidb.syntenicgene (%d seconds\n", $sh->rows, $took);


#########################################################
## delete rows from apidb.syntenty 
printf STDERR ("Deleting from apidb.synteny for %s\n", $organismAbbrev);
$sql = <<SQL;
delete from apidb.synteny where external_database_release_id in (
	select distinct(s.external_database_release_id)
	from apidb.organism o
		, dots.nasequence nas
		, apidb.synteny s
		, sres.externaldatabaserelease r
	where o.abbrev = ? 
		and s.external_database_release_id = r.external_database_release_id
		and o.taxon_id = nas.taxon_id
		and (nas.na_sequence_id = s.a_na_sequence_id or nas.na_sequence_id = s.b_na_sequence_id)
)
SQL
$sh = $dbh->prepare($sql);
$sh->execute($organismAbbrev) or die $sh->errstr;
printf STDERR ("Deleted %d rows from apidb.synteny\n", $sh->rows);


#########################################################
## delete rows from sres.externaldatabaserelease
printf STDERR ("Deleting from sres.externaldatabaserelease by external_database_release_id (%d ids) for %s\n", scalar @relid, $organismAbbrev);
$sql = 'delete from sres.externaldatabaserelease where external_database_release_id=?';
$sh = $dbh->prepare($sql);
$sh->bind_param_array(1,\@relid);
$sh->execute_array({ ArrayTupleStatus => \my @tuple_status } );
printf STDERR ("Deleted %d rows from sres.externaldatabaserelease\n", $sh->rows);


#########################################################
## delete rows from sres.externaldatabase
printf STDERR ("Deleting from sres.externaldatabase by external_database_id for %s\n", $organismAbbrev);
$sql = 'delete from sres.externaldatabase where external_database_id=?';
$sh = $dbh->prepare($sql);
$sh->bind_param_array(1,\@dbid);
$sh->execute_array({ ArrayTupleStatus => \@tuple_status } );
printf STDERR ("Deleted %d rows from sres.externaldatabase\n", $sh->rows);


#########################################################
if($commit){
	print STDERR ("Committing database changes before exiting\n");
	$dbh->commit;
}
else	{
	print STDERR ("No commit: Rolling back all database changes before exiting\n");
	$dbh->rollback();
}
$dbh->disconnect;
exit;









