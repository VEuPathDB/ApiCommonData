package ApiCommonData::Load::EBIUtils;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(getGenomicSequenceIdMapSql);
use strict;
use warnings;

use lib $ENV{GUS_HOME} . "/lib/perl";
use Getopt::Long;
use DBI;
use CBIL::Util::PropertySet;

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

    my $sql = "select s.source_id
    , s.secondary_identifier 
    from dots.externalnasequence s
    , apidb.organism o
    where s.taxon_id = o.taxon_id
    and abbrev = '$organismAbbrev'
    ";

    my $sh = $dbh->prepare($sql);
    $sh->execute();
    my %map;
    my %sourceID;
    while(my ($sequenceId, $seqRegionName) = $sh->fetchrow_array()) {
        #Check if SecondaryID is null and if so assign it the SourceID
	my $suffix = $sequenceId."\.1";
        if (not defined $seqRegionName){
        $seqRegionName = $suffix;
        }
      $map{$seqRegionName} = $sequenceId;
      $sourceID{$seqRegionName} = $sequenceId;
    }

    my @missing;
    foreach (keys %map) {
    push (@missing, $sourceID{$_}) unless exists ($map{$_}) ;
    }
    chomp @missing;
    #If the identifiers exist ie @missing is empty return %map
    if (!@missing){
    $sh->finish();
    $dbh->disconnect;
    return \%map;
    }
    #If identifiers do not exist
    else{
        my @stillMissing;
        my %newMap;
        foreach(@missing){
        #Remove the suffix
        my $trimmed = $_ =~ s/\.{1}[0-9]+//r;
        #Check against sourceID once again
        my $secondCheck = $sourceID{$trimmed};
        push (@stillMissing, $trimmed) unless exists $sourceID{$trimmed};
        $newMap{$sourceID{$trimmed}} = $trimmed;
        }
                #If the identifiers exist ie @stillMissing is empty return %map
                if (!@stillMissing){
                $sh->finish();
                $dbh->disconnect;
                return \%newMap;
                }
                #Otherwise exit and throw error
                else{
                $sh->finish();
                $dbh->disconnect;
		print "ERROR: There is a problem with the sequence ID's in the VCF file.\n";
                exit;
                }
        }

}

1;
