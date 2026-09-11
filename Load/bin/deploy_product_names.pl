#!/usr/bin/perl
#
# deploy_product_names.pl
#
# For every organism file packaged in a zip archive, this script:
#
#   1. Copies the file to:
#        $manualDeliveryDirBase/$project/$orgAbbrev/function/${name}_product_names/$version/final/products.txt
#      (creating the directory tree if it does not already exist)
#
#   2. Appends a <dataset class="productNames"> block to the organism's
#      dataset xml file:
#        $VEuPathDatasetsBase/Datasets/lib/xml/datasets/$project/$orgAbbrev.xml
#
# $orgAbbrev is taken from the file's basename (extension stripped).
# $project is looked up from a tab-delimited org2project file
# (column 1 = project, column 2 = orgAbbrev).
#
# Usage:
#   perl deploy_product_names.pl \
#       --zip organisms_build70_v4.zip \
#       --org2project org2project.txt \
#       --manualDeliveryDirBase /path/to/manualDelivery \
#       --veupathDatasetsBase   /path/to/veupathDatasetsBase \
#       --version 2026-09-11 \
#       --name productNames \
#       [--dryRun] [--force]
#
# Notes:
#   * --dryRun prints what would happen without touching the filesystem.
#   * --force re-copies the products.txt file and re-inserts the xml block
#     even if they already appear to exist/be present (default is to skip
#     xml insertion if an identical block is already there, and to skip
#     copying if products.txt already exists).
#
use strict;
use warnings;

use Getopt::Long;
use File::Path   qw(make_path);
use File::Copy   qw(copy);
use File::Basename qw(basename);
use File::Find;
use File::Temp   qw(tempdir);

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
my ($zip, $org2projectFile, $manualDeliveryDirBase, $veupathDatasetsBase,
    $version, $name, $dryRun, $force, $help);

GetOptions(
    "zip=s"                   => \$zip,
    "org2project=s"           => \$org2projectFile,
    "manualDeliveryDirBase=s" => \$manualDeliveryDirBase,
    "veupathDatasetsBase=s"   => \$veupathDatasetsBase,
    "version=s"               => \$version,
    "name=s"                  => \$name,
    "dryRun"                  => \$dryRun,
    "force"                   => \$force,
    "help"                    => \$help,
) or usage("Error parsing command-line options");

usage() if $help;
usage("--zip is required")                    unless $zip;
usage("--org2project is required")             unless $org2projectFile;
usage("--manualDeliveryDirBase is required")   unless $manualDeliveryDirBase;
usage("--veupathDatasetsBase is required")     unless $veupathDatasetsBase;
usage("--version is required")                 unless $version;
usage("--name is required")                    unless $name;

usage("Zip file not found: $zip")                       unless -e $zip;
usage("org2project file not found: $org2projectFile")   unless -e $org2projectFile;

# Strip any trailing slashes from the base dirs so path-joining is predictable
$manualDeliveryDirBase =~ s{/+$}{};
$veupathDatasetsBase   =~ s{/+$}{};

# ---------------------------------------------------------------------------
# Load org2project mapping: orgAbbrev -> project
# ---------------------------------------------------------------------------
my %orgToProject;
open(my $mapFh, "<", $org2projectFile)
    or die "Cannot open $org2projectFile: $!\n";
while (my $line = <$mapFh>) {
    chomp $line;
    next unless length $line;
    my ($project, $orgAbbrev) = split(/\t/, $line);
    next unless defined $project && defined $orgAbbrev;
    $project =~ s/^\s+|\s+$//g;
    $orgAbbrev =~ s/^\s+|\s+$//g;
    next unless length $project && length $orgAbbrev;
    $orgToProject{$orgAbbrev} = $project;
}
close $mapFh;
printf "Loaded %d organism -> project mappings from %s\n",
    scalar(keys %orgToProject), $org2projectFile;

# ---------------------------------------------------------------------------
# Extract the zip to a temp directory and collect the organism files
# ---------------------------------------------------------------------------
my $tmpDir = tempdir(CLEANUP => 1);
system("unzip", "-o", "-q", $zip, "-d", $tmpDir) == 0
    or die "Failed to extract $zip into $tmpDir: $!\n";

my @orgFiles;
find(sub {
    return unless -f $_;
    # skip macOS AppleDouble resource-fork artifacts (e.g. "._foo.tsv")
    # and other hidden/system files that sometimes end up in zips
    return if basename($_) =~ /^\./;
    push @orgFiles, $File::Find::name;
}, $tmpDir);

die "No files found inside $zip\n" unless @orgFiles;
printf "Found %d organism file(s) in %s\n\n", scalar(@orgFiles), $zip;

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------
my $countCopied  = 0;
my $countXmlEdit = 0;
my $countSkipped = 0;

for my $srcFile (sort @orgFiles) {
    my $baseName = basename($srcFile);
    (my $orgAbbrev = $baseName) =~ s/\.[^.]+$//;   # strip extension -> orgAbbrev

    my $project = $orgToProject{$orgAbbrev};
    if (!$project) {
        warn "WARNING: no project found for orgAbbrev '$orgAbbrev' (file $baseName) - skipping\n";
        $countSkipped++;
        next;
    }

    print "-- $orgAbbrev (project: $project) --\n";

    # ---- Step 1: copy file into manual delivery location ----------------
    my $targetDir = "$manualDeliveryDirBase/$project/$orgAbbrev/function/"
                  . "${name}_product_names/$version/final";
    my $targetFile = "$targetDir/products.txt";

    if (-e $targetFile && !$force) {
        print "   products.txt already exists at $targetFile (skipping copy; use --force to overwrite)\n";
    } else {
        if ($dryRun) {
            print "   [dryRun] would create dir: $targetDir\n";
            print "   [dryRun] would copy $srcFile -> $targetFile\n";
        } else {
            make_path($targetDir) unless -d $targetDir;
            copy($srcFile, $targetFile)
                or die "   ERROR: could not copy $srcFile to $targetFile: $!\n";
            print "   copied -> $targetFile\n";
        }
        $countCopied++;
    }

    # ---- Step 2: update dataset xml --------------------------------------
    my $xmlFile = "$veupathDatasetsBase/Datasets/lib/xml/datasets/$project/$orgAbbrev.xml";

    if (!-e $xmlFile) {
        warn "   WARNING: dataset xml not found: $xmlFile - skipping xml update\n";
        next;
    }

    my $block = qq{  <dataset class="productNames">
    <prop name="projectName">\$\$projectName\$\$</prop>
    <prop name="organismAbbrev">\$\$organismAbbrev\$\$</prop>
    <prop name="version">$version</prop>
    <prop name="name">$name</prop>
  </dataset>
};

    open(my $xmlFh, "<", $xmlFile) or die "   ERROR: cannot open $xmlFile: $!\n";
    local $/;
    my $xmlContent = <$xmlFh>;
    close $xmlFh;

    if (!$force && index($xmlContent, $block) != -1) {
        print "   productNames block already present in $xmlFile (skipping; use --force to add another)\n";
        next;
    }

    if ($xmlContent !~ m{</datasets>}) {
        warn "   WARNING: $xmlFile has no </datasets> closing tag - skipping xml update\n";
        next;
    }

    # Insert the new block right before the closing </datasets> tag
    (my $newXmlContent = $xmlContent) =~ s{(</datasets>)}{\n$block\n$1};

    if ($dryRun) {
        print "   [dryRun] would insert productNames block into $xmlFile\n";
    } else {
        open(my $outFh, ">", $xmlFile) or die "   ERROR: cannot write $xmlFile: $!\n";
        print $outFh $newXmlContent;
        close $outFh;
        print "   updated -> $xmlFile\n";
    }
    $countXmlEdit++;
}

print "\nDone. copied: $countCopied, xml updated: $countXmlEdit, skipped (no project mapping): $countSkipped\n";
print "(dry run - no files were actually changed)\n" if $dryRun;

# ---------------------------------------------------------------------------
sub usage {
    my ($msg) = @_;
    print STDERR "$msg\n\n" if $msg;
    print STDERR <<"USAGE";
Usage: perl $0 \\
    --zip organisms_build70_v4.zip \\
    --org2project org2project.txt \\
    --manualDeliveryDirBase /path/to/manualDelivery \\
    --veupathDatasetsBase   /path/to/veupathDatasetsBase \\
    --version 2026-09-11 \\
    --name productNames \\
    [--dryRun] [--force]
USAGE
    exit($msg ? 1 : 0);
}
