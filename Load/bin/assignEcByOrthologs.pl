#!/usr/bin/perl

use strict;
use warnings;

use lib "$ENV{GUS_HOME}/lib/perl";

use Getopt::Long;
use DBI;
use GUS::Supported::GusConfig;

my ($gusConfigFile, $output, $threshold, $group_id, $source_id, $verbose);
$threshold = 0.60;

&GetOptions(
    "gusConfigFile=s" => \$gusConfigFile,
    "output=s"        => \$output,
    "threshold=f"     => \$threshold,
    "group_id=s"      => \$group_id,
    "source_id=s"     => \$source_id,
    "verbose"         => \$verbose,
);

die "Usage: assignEcByOrthologs.pl --output <file> [--gusConfigFile <path>] [--threshold 0.60] [--group_id <id>] [--source_id <source_id>] [--verbose]\n"
    unless $output;

$gusConfigFile ||= "$ENV{GUS_HOME}/config/gus.config";

# --- DB connection ---
my $gusconfig = GUS::Supported::GusConfig->new($gusConfigFile);
my $dbh = DBI->connect(
    $gusconfig->getDbiDsn(),
    $gusconfig->getDatabaseLogin(),
    $gusconfig->getDatabasePassword(),
    { RaiseError => 1, AutoCommit => 0 }
) or die DBI::errstr;

# --- Load group members ---
print STDERR "Loading group members...\n" if $verbose;

my %group_members;   # group_id => [ aa_sequence_id, ... ]
my %protein_info;    # aa_sequence_id => { source_id, protein_length }

{
    my $sql = q{
        SELECT og.group_id,
               og.aa_sequence_id,
               s.source_id,
               s.length AS protein_length
        FROM   apidb.orthologgroupaasequence og
        JOIN   dots.aasequence s ON s.aa_sequence_id = og.aa_sequence_id
    };
    $sql .= " WHERE og.group_id = ?" if $group_id;

    my $sth = $dbh->prepare($sql);
    $group_id ? $sth->execute($group_id) : $sth->execute();

    while (my ($gid, $aaid, $src, $len) = $sth->fetchrow_array()) {
        push @{ $group_members{$gid} }, $aaid;
        $protein_info{$aaid} = { source_id => $src, protein_length => $len // 0 };
    }
    $sth->finish();
}
print STDERR "Loaded ", scalar(keys %group_members), " groups, ",
             scalar(keys %protein_info), " proteins\n" if $verbose;

# --- Load EC numbers (exclude OrthoMCLDerived) ---
print STDERR "Loading EC annotations...\n" if $verbose;

my %protein_ec;   # aa_sequence_id => [ ec_number, ... ]

{
    my $sql = q{
        SELECT ae.aa_sequence_id,
               ec.ec_number
        FROM   dots.aasequenceenzymeclass ae
        JOIN   sres.enzymeclass ec ON ec.enzyme_class_id = ae.enzyme_class_id
        WHERE  (ae.evidence_code IS NULL OR ae.evidence_code != 'OrthoMCLDerived')
    };

    if ($group_id) {
        $sql = q{
            SELECT ae.aa_sequence_id,
                   ec.ec_number
            FROM   dots.aasequenceenzymeclass ae
            JOIN   sres.enzymeclass ec ON ec.enzyme_class_id = ae.enzyme_class_id
            JOIN   apidb.orthologgroupaasequence og ON og.aa_sequence_id = ae.aa_sequence_id
            WHERE  (ae.evidence_code IS NULL OR ae.evidence_code != 'OrthoMCLDerived')
              AND  og.group_id = ?
        };
    }

    my $sth = $dbh->prepare($sql);
    $group_id ? $sth->execute($group_id) : $sth->execute();

    while (my ($aaid, $ec) = $sth->fetchrow_array()) {
        push @{ $protein_ec{$aaid} }, $ec if exists $protein_info{$aaid};
    }
    $sth->finish();
}
my $ec_count = scalar grep { @{ $protein_ec{$_} } } keys %protein_ec;
print STDERR "Loaded EC annotations for $ec_count proteins\n" if $verbose;

# --- Load InterPro family IDs ---
print STDERR "Loading InterPro family profiles...\n" if $verbose;

my %protein_profile;   # aa_sequence_id => "IPR...|IPR..." (sorted, pipe-joined)

{
    my %ipr_sets;   # aa_sequence_id => { ipr_id => 1 }

    my $sql = q{
        SELECT ir.protein_source_id,
               ir.interpro_family_id
        FROM   apidb.interproresults ir
        WHERE  ir.interpro_family_id IS NOT NULL
          AND  ir.interpro_family_id != '-'
    };

    if ($group_id) {
        $sql = q{
            SELECT ir.protein_source_id,
                   ir.interpro_family_id
            FROM   apidb.interproresults ir
            JOIN   dots.aasequence s ON s.source_id = ir.protein_source_id
            JOIN   apidb.orthologgroupaasequence og ON og.aa_sequence_id = s.aa_sequence_id
            WHERE  ir.interpro_family_id IS NOT NULL
              AND  ir.interpro_family_id != '-'
              AND  og.group_id = ?
        };
    }

    my $sth = $dbh->prepare($sql);
    $group_id ? $sth->execute($group_id) : $sth->execute();

    my %src_to_aaid;
    for my $aaid (keys %protein_info) {
        $src_to_aaid{ $protein_info{$aaid}{source_id} } = $aaid;
    }

    while (my ($src, $ipr) = $sth->fetchrow_array()) {
        my $aaid = $src_to_aaid{$src};
        next unless defined $aaid;
        $ipr_sets{$aaid}{$ipr} = 1;
    }
    $sth->finish();

    for my $aaid (keys %ipr_sets) {
        $protein_profile{$aaid} = join('|', sort keys %{ $ipr_sets{$aaid} });
    }
}
print STDERR "Loaded InterPro profiles for ", scalar(keys %protein_profile), " proteins\n"
    if $verbose;

$dbh->disconnect();

if ($source_id) {
    my ($focus_aaid) = grep { $protein_info{$_}{source_id} eq $source_id } keys %protein_info;
    die "ERROR: source_id '$source_id' not found in loaded data. Check the ID or --group_id filter.\n"
        unless defined $focus_aaid;
    print STDERR "Focusing on source_id=$source_id  (aa_sequence_id=$focus_aaid)\n" if $verbose;
}

# --- Open output ---
open(my $OUT, '>', $output) or die "Cannot open output '$output': $!\n";

print $OUT join("\t", qw(
    group_id
    aa_sequence_id
    source_id
    protein_length
    assigned_ec_number
    is_novel
    confidence_score
    n_supporting
    n_annotated_in_cluster
    cluster_size
    cluster_profile
)), "\n";

# --- Process each group ---
my $groups_processed = 0;
my $rows_written = 0;

for my $gid (sort keys %group_members) {
    my @members = @{ $group_members{$gid} };

    # Cluster by profile key
    my %clusters;   # profile_key => [ aa_sequence_id, ... ]
    for my $aaid (@members) {
        my $key = $protein_profile{$aaid} // '';
        push @{ $clusters{$key} }, $aaid;
    }

    # Report which cluster the focus protein landed in
    if ($verbose && $source_id) {
        my ($focus_aaid) = grep { $protein_info{$_}{source_id} eq $source_id } @members;
        if (defined $focus_aaid) {
            my $profile = $protein_profile{$focus_aaid} // '';
            my $display = $profile eq '' ? 'none (no InterPro family hits)' : $profile;
            print STDERR "\n  PROTEIN $source_id  (aa_sequence_id=$focus_aaid)\n";
            print STDERR "    group=$gid\n";
            print STDERR "    InterPro profile: $display\n";
            my $own_ecs = @{ $protein_ec{$focus_aaid} // [] }
                ? join(', ', @{ $protein_ec{$focus_aaid} })
                : '(none)';
            print STDERR "    existing ECs on this protein: $own_ecs\n";
            my $cluster_key = $protein_profile{$focus_aaid} // '';
            my $cluster_size = scalar @{ $clusters{$cluster_key} };
            print STDERR "    cluster_size (same profile): $cluster_size\n\n";
        }
    }

    for my $profile_key (sort keys %clusters) {
        my @cluster = @{ $clusters{$profile_key} };

        # Collect all ECs from annotated proteins in this cluster
        my %protein_ecs_in_cluster;   # aaid => [ec, ...]
        my @all_cluster_ecs;

        for my $aaid (@cluster) {
            if ($protein_ec{$aaid} && @{ $protein_ec{$aaid} }) {
                $protein_ecs_in_cluster{$aaid} = $protein_ec{$aaid};
                push @all_cluster_ecs, @{ $protein_ec{$aaid} };
            }
        }

        my $n_annotated = scalar keys %protein_ecs_in_cluster;

        if ($n_annotated == 0 && $verbose && $source_id) {
            my ($focus_aaid) = grep { $protein_info{$_}{source_id} eq $source_id } @cluster;
            if (defined $focus_aaid) {
                my $display = $profile_key eq '' ? 'none' : $profile_key;
                print STDERR "  PROTEIN $source_id: cluster (profile=$display) has no annotated proteins — nothing to propagate\n\n";
            }
        }
        next if $n_annotated == 0;   # nothing to propagate from

        my $cluster_size    = scalar @cluster;
        my $display_profile = $profile_key eq '' ? 'none' : $profile_key;

        # Count support per EC (post-normalization)
        my %ec_support;
        for my $aaid (keys %protein_ecs_in_cluster) {
            my @p_ecs = normalize_ecs(@{ $protein_ecs_in_cluster{$aaid} });
            my %seen;
            for my $ec (@p_ecs) {
                next if $seen{$ec}++;
                $ec_support{$ec}++;
            }
        }

        if ($verbose) {
            # Report any raw ECs that were dropped by hierarchy normalization
            my %raw_unique = map { $_ => 1 } @all_cluster_ecs;
            for my $ec (sort keys %raw_unique) {
                unless (exists $ec_support{$ec}) {
                    print STDERR "  SKIP $gid  profile=$display_profile  EC=$ec: subsumed by more specific EC in cluster\n";
                }
            }
        }

        # Majority vote
        my @passing_ecs;
        for my $ec (sort keys %ec_support) {
            my $support = $ec_support{$ec};
            my $score   = $support / $n_annotated;
            if ($score >= $threshold) {
                push @passing_ecs, { ec => $ec, support => $support, score => $score };
            } elsif ($verbose) {
                printf STDERR "  SKIP $gid  profile=$display_profile  EC=$ec: score too low (%d/%d = %.2f < %.2f)\n",
                    $support, $n_annotated, $score, $threshold;
            }
        }
        # If we are focusing on a specific protein, print its cluster context
        # regardless of whether any ECs pass threshold
        if ($verbose && $source_id) {
            my ($focus_aaid) = grep { $protein_info{$_}{source_id} eq $source_id } @cluster;
            if (defined $focus_aaid) {
                print STDERR "\n  PROTEIN $source_id  (aa_sequence_id=$focus_aaid)\n";
                print STDERR "    group=$gid  cluster_size=$cluster_size  n_annotated=$n_annotated\n";
                print STDERR "    profile=$display_profile\n";
                my $own_ecs = @{ $protein_ec{$focus_aaid} // [] }
                    ? join(', ', @{ $protein_ec{$focus_aaid} })
                    : '(none)';
                print STDERR "    existing ECs on this protein: $own_ecs\n";
                if ($n_annotated > 0) {
                    print STDERR "    cluster members with ECs:\n";
                    for my $other (sort keys %protein_ecs_in_cluster) {
                        my $osrc = $protein_info{$other}{source_id};
                        my @norm = normalize_ecs(@{ $protein_ecs_in_cluster{$other} });
                        printf STDERR "      %s  raw=[%s]  normalized=[%s]\n",
                            $osrc,
                            join(', ', @{ $protein_ecs_in_cluster{$other} }),
                            join(', ', @norm);
                    }
                    print STDERR "    EC vote results:\n";
                    for my $ec (sort keys %ec_support) {
                        my $score = $ec_support{$ec} / $n_annotated;
                        my $verdict = $score >= $threshold ? 'PASS' : 'fail';
                        printf STDERR "      EC=%s  %d/%d = %.2f  %s\n",
                            $ec, $ec_support{$ec}, $n_annotated, $score, $verdict;
                    }
                } else {
                    print STDERR "    no annotated proteins in this cluster — nothing to propagate\n";
                }
                if (@passing_ecs) {
                    print STDERR "    ECs to be assigned:\n";
                    my %existing_ecs = map { $_ => 1 } @{ $protein_ec{$focus_aaid} // [] };
                    for my $pass (@passing_ecs) {
                        my $novel = $existing_ecs{$pass->{ec}} ? 'already annotated' : 'NOVEL';
                        printf STDERR "      EC=%s  score=%.2f (%d/%d)  %s\n",
                            $pass->{ec}, $pass->{score}, $pass->{support}, $n_annotated, $novel;
                    }
                } else {
                    print STDERR "    no ECs passed threshold — nothing assigned\n";
                }
                print STDERR "\n";
            }
        }

        next unless @passing_ecs;

        for my $aaid (@cluster) {
            my $info = $protein_info{$aaid};
            my %existing_ecs = map { $_ => 1 } @{ $protein_ec{$aaid} // [] };

            for my $pass (@passing_ecs) {
                my $ec      = $pass->{ec};
                my $support = $pass->{support};
                my $score   = $pass->{score};
                my $is_novel = $existing_ecs{$ec} ? 0 : 1;

                printf $OUT "%s\t%s\t%s\t%d\t%s\t%d\t%.4f\t%d\t%d\t%d\t%s\n",
                    $gid,
                    $aaid,
                    $info->{source_id},
                    $info->{protein_length},
                    $ec,
                    $is_novel,
                    $score,
                    $support,
                    $n_annotated,
                    $cluster_size,
                    $display_profile;

                $rows_written++;
            }
        }
    }

    $groups_processed++;
    if ($verbose && $groups_processed % 10000 == 0) {
        print STDERR "Processed $groups_processed groups, $rows_written rows written\n";
    }
}

close($OUT);

print STDERR "Done. Processed $groups_processed groups, wrote $rows_written rows to $output\n";

# ===========================================================================
# Helpers
# ===========================================================================

sub normalize_ecs {
    my @ecs = @_;
    my @result;
    for my $ec (@ecs) {
        my $subsumed = 0;
        for my $other (@ecs) {
            next if $other eq $ec;
            if (is_more_specific($other, $ec)) {
                $subsumed = 1;
                last;
            }
        }
        push @result, $ec unless $subsumed;
    }
    return @result;
}

sub is_more_specific {
    my ($specific, $general) = @_;
    my @s = split /\./, $specific;
    my @g = split /\./, $general;
    return 0 unless @g == 4 && @s == 4;
    for my $i (0 .. 3) {
        if ($g[$i] eq '-') {
            # general is a wildcard here; specific is more specific only if it has a defined value
            return ($s[$i] ne '-') ? 1 : 0;
        }
        return 0 if $s[$i] ne $g[$i];   # mismatch at a defined position
    }
    # All 4 positions matched exactly — same specificity, not strictly more specific
    return 0;
}
