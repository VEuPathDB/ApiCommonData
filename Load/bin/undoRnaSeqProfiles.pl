#!/usr/bin/perl

#This script runs an undo of RNAseq profiles and DESeq2 data only, for use in patch build updates

use strict;
use warnings;
use lib "$ENV{GUS_HOME}/lib/perl";

use Getopt::Long;
use GUS::ObjRelP::DbiDatabase;
use CBIL::Util::PropertySet;
use CBIL::Util::Utils;
use Data::Dumper;

my ($datasetName, $commit, $gusConfigFile);

&GetOptions("datasetName|d=s" => \$datasetName,
            "commit" => \$commit,
            "gusConfigFile=s" => \$gusConfigFile
            );
&usage() unless ($datasetName);


if (!$gusConfigFile) {                                                                                                                                                                                                                                                                           
    $gusConfigFile = $ENV{GUS_HOME}."/config/gus.config";
}

my $rowAlgInvId = &getRowAlgInvId($datasetName, $gusConfigFile);

print STDERR "Undoing rows from results.nafeatureexpression and results.nafeaturediff result with row algorithm invocation id: $rowAlgInvId\n";
if ($commit) {
    print STDERR "Running undo with commit\n";
}

my $cmd = "ga GUS::Community::Plugin::Undo --plugin ApiCommonData::Load::Plugin::InsertRnaSeqPatch --algInvocationId $rowAlgInvId";

$cmd = $commit ? $cmd . " --commit": $cmd;

print STDERR "Undo command: $cmd\n";

&runCmd($cmd); 



sub getRowAlgInvId {
    my ($datasetName, $gusConfigFile) = @_;
    my @properties = ();
    die "Config file $gusConfigFile does not exist" unless -e $gusConfigFile;

    my $gusConfig = CBIL::Util::PropertySet -> new ($gusConfigFile, \@properties, 1);

    my $db = GUS::ObjRelP::DbiDatabase-> new($gusConfig->{props}->{dbiDsn},                                                                                                                                                                                                                          
                                         $gusConfig->{props}->{databaseLogin},
                                         $gusConfig->{props}->{databasePassword},
                                         0,0,1, # verbose, no insert, default
                                         $gusConfig->{props}->{coreSchemaName},
                                         );
    my $dbh = $db->getQueryHandle();
    my $sql = "select distinct pan.row_alg_invocation_id
               from study.protocolappnode pan
               , study.studylink sl
               , study.study s
               where s.name = '$datasetName'
               and sl.study_id = s.study_id
               and pan.protocol_app_node_id = sl.protocol_app_node_id
               and pan.name like '%(RNASeqEbi)'";

    my $sqlStmt = $dbh->prepare($sql);
    $sqlStmt->execute();
    my $data = $sqlStmt->fetchall_arrayref();
    $dbh->disconnect();
    die ("More than one row algorithm invocation id was found.\n") if scalar @$data > 1;
    die ("No row algorithm invocation id was found.\n") if scalar @$data < 1;

    my $rowAlgInvId = $data->[0]->[0];

    return $rowAlgInvId;
}
    

sub usage {
    print STDERR "undoRnaSeqProfiles.pl --datasetName <dataset name for experiment to undo> --commit <run undo plugin in commit model> --gusConfigFile <Optional if not using default>\n";
    exit;
}

