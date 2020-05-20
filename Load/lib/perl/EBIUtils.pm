package ApiCommonData::Load::EBIUtils;
use strict;
use warnings;

use lib $ENV{GUS_HOME} . "/lib/perl";

#use Exporter qw(import);
#our @EXPORT_OK = qw(getGenomicSequenceIdMapSql);

use Getopt::Long;
use File::Temp qw/ tempfile /;
use DBI;
use DBD::Oracle;
use CBIL::Util::PropertySet;
use File::Copy;

sub getGenomicSequenceIdMapSql{

my ($organismAbbrev)  = shift;

##Create db handle

my $gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config";
 
my @properties;
my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);

my $dbiDsn = $gusconfig->{props}->{dbiDsn};
my $dbiUser = $gusconfig->{props}->{databaseLogin};
my $dbiPswd = $gusconfig->{props}->{databasePassword};

my $dbh = DBI->connect($dbiDsn, $dbiUser, $dbiPswd) or die DBI->errstr;
$dbh->{RaiseError} = 1;
$dbh->{AutoCommit} = 0;

my $sql = "select s.source_id, s.secondary_identifier 
from dots.externalnasequence s, apidb.organism o
where s.taxon_id = o.taxon_id
and abbrev = '$organismAbbrev'
and secondary_identifier is not null";

my $sh = $dbh->prepare($sql);
$sh->execute();

my %map;
while(my ($sequenceId, $seqRegionName) = $sh->fetchrow_array()) {
  $map{$seqRegionName} = $sequenceId;
}

$sh->finish();

$dbh->disconnect;


return \%map;

}

1;
