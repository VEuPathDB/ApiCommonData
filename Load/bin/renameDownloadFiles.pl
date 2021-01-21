#!/usr/bin/perl

use strict;
use lib "$ENV{GUS_HOME}/lib/perl";
use DBI;
use Getopt::Long; 
use CBIL::Util::PropertySet;
use Data::Dumper;

my $gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config";
my $stagingDir = "/eupath/data/apiSiteFilesStaging";

my ($commit,$workflowVersion,$help);
GetOptions( "workflowVersion=s" => \$workflowVersion,
	    "commit!" => \$commit,
            "help!" => \$help );

usage() if $help || ! $workflowVersion;

my $dbh = getDbh($gusConfigFile);
my $organisms = getOrganisms($dbh);
$dbh->disconnect();

my $project = getProject($organisms);

## change GFF and FASTA files
## all are appended with annotation version except *Genome.fasta files which are appended with genome version
my $folderString = "$stagingDir/$project/$workflowVersion/real/downloadSite/$project/release-CURRENT/*/*/data";
my @folders = glob($folderString);
foreach my $folder (@folders) {
    my $currentOrganism;
    if ($folder =~ /release-CURRENT\/([^\/]+)\//) {
	$currentOrganism = $1;
	if (! exists $organisms->{$currentOrganism}) {
	    print "ERROR: This organism has a GFF or FASTA folder but is not in the database.\n";
	    print "Folder: $folder\nOrganism: $currentOrganism\n";
	    exit;
	}
    } else {
	die "ERROR: Did not find organism name in the path: $folder\n";
    }
    print "\nDirectory: $folder\n";
    chdir($folder);
    opendir(my $dh1, $folder) or die "Could not open '$folder' for reading: $!\n";
    my @files = readdir($dh1);
    foreach my $file (@files) {
	my $newText;
	if ($file =~ /^\./) {
	    next;
	} elsif ( $file eq "Orf50.gff" ) {
	    print "    Skipping: $file\n";
	    next;
	} elsif ( $file =~ /Genome.fasta$/) {
	    $newText = $currentOrganism."_".$organisms->{$currentOrganism}->{genome};
	} elsif ( $file =~ /.gff$/ || $file =~ /.fasta$/ ) {
	    $newText = $currentOrganism."_".$organisms->{$currentOrganism}->{annotation};
	} else {
	    print "ERROR: Did not expect this file: $file\n";
	    exit;
	}
	my $newFileName = $file;
	$newFileName =~ s/$currentOrganism/$newText/;
	my $cmd = "mv $file $newFileName";
	print "    $cmd\n";
	system($cmd) if $commit;
    }
}


## change txt,transcriptExpression and gaf files
## all are appended with annotation version
my $folderString = "$stagingDir/$project/$workflowVersion/real/downloadSite/$project/release-CURRENT/*/gaf";
my @folders = glob($folderString);
$folderString = "$stagingDir/$project/$workflowVersion/real/downloadSite/$project/release-CURRENT/*/txt";
push @folders, glob($folderString);
$folderString = "$stagingDir/$project/$workflowVersion/real/downloadSite/$project/release-CURRENT/*/transcriptExpression";
push @folders, glob($folderString);

foreach my $folder (@folders) {
    my $currentOrganism;
    if ($folder =~ /release-CURRENT\/([^\/]+)\//) {
	$currentOrganism = $1;
	if (! exists $organisms->{$currentOrganism}) {
	    print "ERROR: This organism has a transcriptExpression, txt, or gaf folder but is not in the database.\n";
	    print "Folder: $folder\nOrganism: $currentOrganism\n";
	    exit;
	}
    } else {
	die "ERROR: Did not find organism name in the path: $folder\n";
    }
    print "\nDirectory: $folder\n";
    chdir($folder);
    opendir(my $dh1, $folder) or die "Could not open '$folder' for reading: $!\n";
    my @files = readdir($dh1);
    foreach my $file (@files) {
	my $newText;
	if ($file =~ /^\./) {
	    next;
	} elsif ( $file =~ /.gaf$/ || $file =~ /.txt$/ ) {
	    $newText = $currentOrganism."_".$organisms->{$currentOrganism}->{annotation};
	} else {
	    print "ERROR: Did not expect this file: $file\n";
	    exit;
	}
	my $newFileName = $file;
	$newFileName =~ s/$currentOrganism/$newText/;
	my $cmd = "mv $file $newFileName";
	print "    $cmd\n";
	system($cmd) if $commit;
    }
}

exit;




sub getProject {
    my ($organisms) = @_;
    my $project = "";
    foreach my $organism (keys %{$organisms}) {
	my $currentProject = $organisms->{$organism}->{project};
	die "Only expect one project but got more: '$project','$currentProject'" if ($project ne "" && $project ne $currentProject);
	$project = $currentProject;
    }
    return $project;
}


sub getOrganisms {
    my ($dbh) = @_;

    my $sql ="
SELECT o.name_for_filenames,o.project_name,prop.value AS genome_version,v.annotation_version
FROM (SELECT dataset_presenter_id,
            MAX(annotation_version) KEEP (DENSE_RANK LAST ORDER BY build_number) annotation_version
      FROM (SELECT pres.dataset_presenter_id,dh.build_number,dh.annotation_version
           FROM ApidbTuning.DatasetHistory dh,
                ApidbTuning.DatasetPresenter pres
           WHERE dh.dataset_presenter_id = pres.dataset_presenter_id
                 AND pres.name LIKE '%_primary_genome_RSRC')
       GROUP BY dataset_presenter_id) v,
       apidbtuning.datasetnametaxon dnt,
       apidb.organism o,
       apidbTuning.DatasetProperty prop
WHERE o.taxon_id = dnt.taxon_id
      AND dnt.dataset_presenter_id = v.dataset_presenter_id
      AND dnt.dataset_presenter_id = prop.dataset_presenter_id
      AND prop.property = 'genomeVersion'";

    my $sth = $dbh->prepare($sql);
    $sth->execute();

    my $organisms;
    while(my ($fileName,$project,$genomeVersion,$annotationVersion) = $sth->fetchrow_array()) {
	$organisms->{$fileName}->{project} = $project;
	$organisms->{$fileName}->{genome} = $genomeVersion;
	$organisms->{$fileName}->{annotation} = $annotationVersion;
    }
    return $organisms;
}


sub usage {
    my $usage = "
This script renames genome download files by adding the genome version
or structural annotation version, to be performed before each release.

Example usage:
  renameDownloadFiles.pl --workflowVersion 49 [--commit] [--help]
  Note: 1. Source GUS_HOME first,
        2. Use --commit to change file names. If absent, changes will only be printed for review.
           It is recommended that you first run without --commit.
        3. Use --help to show this help message.\n\n";
    print $usage;
    exit;
}


sub getDbh {
    my ($gusConfigFile) = @_;
    my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, [], 1);
    my $user = $gusconfig->{props}->{databaseLogin};
    my $pass = $gusconfig->{props}->{databasePassword};
    my $dsn  = $gusconfig->{props}->{dbiDsn};
    my $dbh  = DBI->connect($dsn, $user, $pass) or die DBI::errstr;
    return $dbh;
}
