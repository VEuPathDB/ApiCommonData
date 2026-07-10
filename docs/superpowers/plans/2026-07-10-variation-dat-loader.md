# Variation `.dat` Loader Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Load `mergeExperiments` `variationFeature.dat`, `transcript_product.dat`, and `snpeff.dat` into `ApiDB.VariationFeature`, `VariationTranscriptProduct`, and `VariationEffect` via a GUS plugin that transforms each file and loads all three in a single psql transaction.

**Architecture:** Split responsibilities. `ApiCommonData::Load::VariationLoader` is a pure module (no GUS, no DBI) that owns the canonical column orders and the three file transforms — it is unit-testable without a database. `ApiCommonData::Load::Plugin::InsertVariationFeatures` is the GUS plugin that resolves the external database release, builds the organism-scoped transcript map from the database, validates sequence ids, calls the transform, assembles one SQL script (`BEGIN; DELETE; \copy ×3; COMMIT;`), and runs `psql -f` once. Undo is via the undocumented `undoPreprocess` hook (`undoTables` cannot work — no `row_alg_invocation_id`).

**Tech Stack:** Perl 5, GUS PluginMgr, PostgreSQL `\copy` via the `psql` CLI, `Test::More`/`Test::Exception`/`prove`.

**Design spec:** `docs/superpowers/specs/2026-07-10-variation-dat-loader-design.md` — read it first.

---

## Preconditions (verified 2026-07-10, do not re-derive)

- Sample data: `/home/jbrestel/dnaseq_test/merge/output` (*L. major*, 1504 / 781 / 1978 rows).
- Test DB `unidb_shu_a` on **localhost:5432** contains *A. fumigatus* etc., **no *L. major***.
- Stub test env already built in `unidb_shu_a`: schema `jbrestel` holds the three tables
  (with `source_id`, without `downstream_of_frameshift_strain_ids`, external FKs dropped,
  parent→child `ON DELETE CASCADE` kept) plus `jbrestel.StubTranscript` (78 `LmjF`
  transcripts → synthetic `na_feature_id` 9000001+). Recreate with the scratchpad SQL if lost.
- **`psql \copy` must be one line** in a `-f` script; multi-line fails with `parse error at end of line`.
  `Psql.pm`'s `getCommand()` emits multi-line and is therefore NOT reusable here — build the
  `\copy` line directly.
- `ON_ERROR_STOP=1` aborts the whole script (and rolls back the open transaction) when any
  `\copy` fails. Verified.
- Empty field under `FORMAT CSV` → NULL. This is the pipeline's "absent" convention.
- The plugin's own `gus.config` `dbiDsn` uses **port 5433** and DB `genomicsdb_069n`; the test
  DB is a different port/DB. Always pass host/port/dbname explicitly to `psql`.

## Environment setup (run once per shell before building or running)

```bash
export PROJECT_HOME=/home/jbrestel/workspaces/dataLoad/project_home
export GUS_HOME=/home/jbrestel/workspaces/dataLoad/gus_home
export PATH=$GUS_HOME/bin:$PATH
export PERL5LIB=$GUS_HOME/lib/perl:/home/jbrestel/perl5/lib/perl5
```

**Module resolution (important — do not skip):** Source `.pm` files live *flat* under
`Load/lib/perl/` (e.g. `Load/lib/perl/VariationLoader.pm`) but declare the full package
`ApiCommonData::Load::VariationLoader`. Perl can only resolve that from a directory that
has an `ApiCommonData/Load/` subtree — i.e. the **built** copy at
`$GUS_HOME/lib/perl/ApiCommonData/Load/`. Therefore:

- Every `.t` file uses `use lib "$ENV{GUS_HOME}/lib/perl";` (matching all existing repo
  tests), **not** a `$PROJECT_HOME/...` path.
- After editing any `.pm`, sync it into the built tree before running tests or the plugin.
  Dev-loop sync (fast; what to use during this work):

  ```bash
  cp $PROJECT_HOME/ApiCommonData/Load/lib/perl/VariationLoader.pm \
     $GUS_HOME/lib/perl/ApiCommonData/Load/
  # plugin file, when it exists:
  cp $PROJECT_HOME/ApiCommonData/Load/plugin/perl/InsertVariationFeatures.pm \
     $GUS_HOME/lib/perl/ApiCommonData/Load/Plugin/
  ```

  The full deploy build is `build ApiCommonData install ...` (heavyweight: touches config
  and DB schema). Do **not** run it for this dev loop; the `cp` sync is sufficient and is
  standard GUS dev practice. The committed source is the source of truth; the `cp` is a
  local install step, never committed.

- `Test::Exception` is a repo test dependency (used by `ontology_mapping.t`). If missing,
  install once: `cpanm --local-lib=/home/jbrestel/perl5 Test::Exception`. The `PERL5LIB`
  above already includes `/home/jbrestel/perl5/lib/perl5`.

Unit tests (Tasks 2–5) need the `cp` sync but no DB. The integration test (Task 11) needs
both the sync and the live `unidb_shu_a` database.

## File structure

| File | Responsibility |
|---|---|
| `ApidbSchema` repo `.../Postgres/createVariationTables.sql` | Add `VariationFeature.source_id`; drop `VariationTranscriptProduct.downstream_of_frameshift_strain_ids` |
| `ApiCommonData/Load/lib/perl/VariationLoader.pm` | Pure: canonical column orders + 3 transforms. No GUS/DBI. |
| `ApiCommonData/Load/t/variationLoader.t` | Unit tests for the above. No DB. |
| `ApiCommonData/Load/plugin/perl/InsertVariationFeatures.pm` | GUS plugin: DB queries, psql orchestration, undo. |
| `ApiCommonData/Load/t/insertVariationFeatures_integration.t` | Integration test against `jbrestel` stub schema. |

---

## Task 1: Schema changes in ApidbSchema

**Repo:** `/home/jbrestel/workspaces/misc/ApidbSchema`, branch `dnaseq-tables` (already checked out).
**File:** `Main/lib/sql/apidbschema/Postgres/createVariationTables.sql`

- [ ] **Step 1: Add `source_id` as the first column of `ApiDB.VariationFeature`**

Insert as the new first column in the `CREATE TABLE ApiDB.VariationFeature` block:

```sql
  source_id                       VARCHAR(100)  NOT NULL,
```

- [ ] **Step 2: Add a UNIQUE constraint on `source_id`**

After the existing `PRIMARY KEY (sequence_source_id, location)` line, add:

```sql
  , UNIQUE (source_id)
```

- [ ] **Step 3: Drop `downstream_of_frameshift_strain_ids` from `ApiDB.VariationTranscriptProduct`**

Delete this line from the `CREATE TABLE ApiDB.VariationTranscriptProduct` block:

```sql
  downstream_of_frameshift_strain_ids VARCHAR(4000),
```

- [ ] **Step 4: Verify the DDL parses against a scratch schema**

```bash
psql -h localhost -p 5432 -d unidb_shu_a -v ON_ERROR_STOP=1 <<'SQL'
BEGIN;
CREATE SCHEMA _ddlcheck;
SET search_path TO _ddlcheck;
-- paste the three CREATE TABLE statements with ApiDB. -> _ddlcheck. and
-- FKs to sres/dots removed, to confirm column syntax only
ROLLBACK;
SQL
```
Expected: no syntax error. (This checks column syntax; the real FKs need the real schemas.)

- [ ] **Step 5: Commit (ApidbSchema repo)**

```bash
cd /home/jbrestel/workspaces/misc/ApidbSchema
git add Main/lib/sql/apidbschema/Postgres/createVariationTables.sql
git commit -m "feat: add VariationFeature.source_id UNIQUE; drop downstream_of_frameshift_strain_ids

source_id = Variant_<sequence_source_id>_<location>, a stable opaque identifier.
downstream_of_frameshift_strain_ids referenced unloaded sample.dat; kept in the
.dat file for QA only.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: VariationLoader — column definitions and header parsing

**Files:**
- Create: `ApiCommonData/Load/lib/perl/VariationLoader.pm`
- Test: `ApiCommonData/Load/t/variationLoader.t`

- [ ] **Step 1: Write the failing test**

Create `ApiCommonData/Load/t/variationLoader.t`:

```perl
use strict;
use warnings;
use lib "$ENV{GUS_HOME}/lib/perl";
use Test::More;
use Test::Exception;
use ApiCommonData::Load::VariationLoader qw/
  variationFeatureColumns transcriptProductColumns variationEffectColumns
  parseHeader buildSourceId
/;

# Canonical column counts match the target tables (incl. added source_id,
# excl. dropped downstream_of_frameshift_strain_ids).
is(scalar @{variationFeatureColumns()},   33, 'VariationFeature has 33 columns');
is(scalar @{transcriptProductColumns()},  12, 'VariationTranscriptProduct has 12 columns');
is(scalar @{variationEffectColumns()},      8, 'VariationEffect has 8 columns');

is(variationFeatureColumns()->[0], 'source_id',          'source_id first');
is(variationFeatureColumns()->[1], 'sequence_source_id', 'sequence_source_id second');

# parseHeader strips a leading # and splits on tab.
is_deeply(parseHeader("#a\tb\tc"), [qw/a b c/], 'parseHeader strips leading #');
is_deeply(parseHeader("a\tb\tc"),  [qw/a b c/], 'parseHeader without #');

is(buildSourceId('LmjF.01', 233), 'Variant_LmjF.01_233', 'buildSourceId format');

done_testing;
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd $PROJECT_HOME && prove -v ApiCommonData/Load/t/variationLoader.t`
Expected: FAIL — `Can't locate ApiCommonData/Load/VariationLoader.pm`.

- [ ] **Step 3: Write the minimal module**

Create `ApiCommonData/Load/lib/perl/VariationLoader.pm`:

```perl
package ApiCommonData::Load::VariationLoader;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw/
  variationFeatureColumns transcriptProductColumns variationEffectColumns
  parseHeader buildSourceId
  transformVariationFeature transformTranscriptProduct transformVariationEffect
/;

# Canonical output column order. The transforms below emit values in exactly
# this order; the plugin uses these same lists to build each \copy field list.
# Keep the two in lockstep — the unit tests assert the counts match.

sub variationFeatureColumns {
  return [ qw/
    source_id sequence_source_id location reference_strain is_coding variant_type
    distinct_strain_count called_strain_count no_call_strain_count call_rate
    total_ploidy_count ref_allele_frequency het_strain_count
    snp_ref_allele snp_major_allele snp_major_allele_frequency snp_major_allele_strain_count
    snp_minor_allele snp_minor_allele_frequency snp_minor_allele_strain_count
    snp_major_genomic_hgvs snp_minor_genomic_hgvs
    indel_ref_allele indel_major_allele indel_major_allele_frequency indel_major_allele_strain_count
    indel_minor_allele indel_minor_allele_frequency indel_minor_allele_strain_count
    indel_major_genomic_hgvs indel_minor_genomic_hgvs indel_frame_effect
    external_database_release_id
  / ];
}

sub transcriptProductColumns {
  return [ qw/
    sequence_source_id location na_feature_id pos_in_cds pos_in_protein codon
    pos_in_codon strain_count product matches_ref_codon matches_ref_product hgvs_p
  / ];
}

sub variationEffectColumns {
  return [ qw/
    sequence_source_id location allele na_feature_id impact effect hgvs_c source
  / ];
}

sub parseHeader {
  my ($line) = @_;
  chomp $line;
  $line =~ s/^#//;
  return [ split /\t/, $line, -1 ];
}

sub buildSourceId {
  my ($seq, $loc) = @_;
  return "Variant_${seq}_${loc}";
}

1;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd $PROJECT_HOME && prove -v ApiCommonData/Load/t/variationLoader.t`
Expected: PASS, 8 subtests.

- [ ] **Step 5: Commit**

```bash
cd $PROJECT_HOME/ApiCommonData
git add Load/lib/perl/VariationLoader.pm Load/t/variationLoader.t
git commit -m "feat: VariationLoader column defs + header/source_id helpers

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: VariationLoader — variationFeature transform

**Files:**
- Modify: `ApiCommonData/Load/lib/perl/VariationLoader.pm`
- Test: `ApiCommonData/Load/t/variationLoader.t`

Input columns (31): `location, seq_id, reference_strain, is_coding, variant_type, distinct_strain_count, called_strain_count, no_call_strain_count, call_rate, total_ploidy_count, ref_allele_frequency, het_strain_count, snp_ref_allele, snp_major_allele, snp_major_allele_frequency, snp_major_allele_strain_count, snp_minor_allele, snp_minor_allele_frequency, snp_minor_allele_strain_count, snp_major_genomic_hgvs, snp_minor_genomic_hgvs, indel_ref_allele, indel_major_allele, indel_major_allele_frequency, indel_major_allele_strain_count, indel_minor_allele, indel_minor_allele_frequency, indel_minor_allele_strain_count, indel_major_genomic_hgvs, indel_minor_genomic_hgvs, indel_frame_effect`.

Transform: prepend `source_id`, emit `seq_id` before `location`, append `external_database_release_id`.

- [ ] **Step 1: Write the failing test** (append to `variationLoader.t`, before `done_testing`)

```perl
use File::Temp qw/tempfile/;
use ApiCommonData::Load::VariationLoader qw/transformVariationFeature/;

{
  my $header = join("\t", qw/location seq_id reference_strain is_coding variant_type
    distinct_strain_count called_strain_count no_call_strain_count call_rate
    total_ploidy_count ref_allele_frequency het_strain_count
    snp_ref_allele snp_major_allele snp_major_allele_frequency snp_major_allele_strain_count
    snp_minor_allele snp_minor_allele_frequency snp_minor_allele_strain_count
    snp_major_genomic_hgvs snp_minor_genomic_hgvs
    indel_ref_allele indel_major_allele indel_major_allele_frequency indel_major_allele_strain_count
    indel_minor_allele indel_minor_allele_frequency indel_minor_allele_strain_count
    indel_major_genomic_hgvs indel_minor_genomic_hgvs indel_frame_effect/);
  # 233 SNV row with empty indel_* fields
  my @vals = (233, 'LmjF.01', 'lmajFriedlin', 0, 'SNV',
    5,4,0,'1.0000',9,'0.7778',0, 'C','G','0.2222',1,'','','', 'LmjF.01:g.233C>G','',
    '','','',  '','','',  '','','', '');   # 31 values, matching the 31-col header
  my $row = join("\t", @vals);

  my ($inFh, $inFile)   = tempfile(UNLINK => 1);
  my ($outFh, $outFile) = tempfile(UNLINK => 1);
  print $inFh "$header\n$row\n"; close $inFh;
  open(my $rh, '<', $inFile) or die $!;

  my $n = transformVariationFeature($rh, $outFh, 42);
  close $outFh; close $rh;
  is($n, 1, 'one data row transformed');

  open(my $oh, '<', $outFile) or die $!;
  my $out = <$oh>; chomp $out; close $oh;
  my @f = split /\t/, $out, -1;
  is(scalar @f, 33, 'output has 33 fields');
  is($f[0], 'Variant_LmjF.01_233', 'source_id prepended');
  is($f[1], 'LmjF.01', 'sequence_source_id = seq_id');
  is($f[2], 233, 'location third');
  is($f[-1], 42, 'external_database_release_id appended');
}

dies_ok {
  my ($rh, $f) = tempfile(UNLINK => 1);
  print $rh "location\tseq_id\n1\t2\t3\n"; close $rh;
  open(my $r, '<', $f); my $junk;
  open(my $w, '>', \$junk);
  ApiCommonData::Load::VariationLoader::transformVariationFeature($r, $w, 1);
} 'dies on wrong field count';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd $PROJECT_HOME && prove -v ApiCommonData/Load/t/variationLoader.t`
Expected: FAIL — `transformVariationFeature` undefined.

- [ ] **Step 3: Implement** (add to `VariationLoader.pm` before the final `1;`)

```perl
sub transformVariationFeature {
  my ($inFh, $outFh, $extDbRlsId) = @_;
  my $header = <$inFh>;
  die "variationFeature.dat: empty file\n" unless defined $header;
  my $cols = parseHeader($header);
  die "variationFeature.dat: expected 31 columns, got " . scalar(@$cols) . "\n"
    unless @$cols == 31;
  die "variationFeature.dat: unexpected header (want location, seq_id first)\n"
    unless $cols->[0] eq 'location' && $cols->[1] eq 'seq_id';

  my $n = 0;
  while (my $line = <$inFh>) {
    chomp $line;
    my @f = split /\t/, $line, -1;
    die "variationFeature.dat line $.: expected 31 fields, got " . scalar(@f) . "\n"
      unless @f == 31;
    my ($loc, $seq) = @f[0, 1];
    print $outFh join("\t", buildSourceId($seq, $loc), $seq, $loc, @f[2..30], $extDbRlsId), "\n";
    $n++;
  }
  return $n;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd $PROJECT_HOME && prove -v ApiCommonData/Load/t/variationLoader.t`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd $PROJECT_HOME/ApiCommonData
git add Load/lib/perl/VariationLoader.pm Load/t/variationLoader.t
git commit -m "feat: transformVariationFeature

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: VariationLoader — transcriptProduct transform

**Files:**
- Modify: `ApiCommonData/Load/lib/perl/VariationLoader.pm`
- Test: `ApiCommonData/Load/t/variationLoader.t`

Input columns (13): `seq_id, location, transcript_id, pos_in_cds, pos_in_protein, codon, pos_in_codon, count, product, matches_ref_codon, matches_ref_product, downstream_of_frameshift_strain_ids, hgvs_p` (header prefixed with `#`).
Transform: resolve `transcript_id` → `na_feature_id` (fatal on empty or miss), rename `count` → `strain_count` positionally, DROP column 12 (`downstream_of_frameshift_strain_ids`).

- [ ] **Step 1: Write the failing test** (append before `done_testing`)

```perl
use ApiCommonData::Load::VariationLoader qw/transformTranscriptProduct/;

{
  my %map = ('LmjF.01.0010:mRNA' => 9000001);
  my $header = "#" . join("\t", qw/seq_id location transcript_id pos_in_cds
    pos_in_protein codon pos_in_codon count product matches_ref_codon
    matches_ref_product downstream_of_frameshift_strain_ids hgvs_p/);
  my $row = join("\t", 'LmjF.01', 3745, 'LmjF.01.0010:mRNA', 958, 320, 'GAC',
    1, 3, 'D', 1, 1, '{1,3,4}', 'p.Asp320=');

  my ($inFh, $inFile)   = tempfile(UNLINK => 1);
  my ($outFh, $outFile) = tempfile(UNLINK => 1);
  print $inFh "$header\n$row\n"; close $inFh;
  open(my $rh, '<', $inFile) or die $!;

  my $n = transformTranscriptProduct($rh, $outFh, \%map);
  close $outFh; close $rh;
  is($n, 1, 'one row');

  open(my $oh, '<', $outFile); my $out = <$oh>; chomp $out; close $oh;
  my @f = split /\t/, $out, -1;
  is(scalar @f, 12, 'output has 12 fields (dropped column)');
  is($f[2], 9000001, 'transcript_id resolved to na_feature_id');
  is($f[7], 3, 'count value now in strain_count position');
  is($f[-1], 'p.Asp320=', 'hgvs_p last; frameshift ids column dropped');
}

dies_ok {
  my %map = ('LmjF.01.0010:mRNA' => 9000001);
  my $header = "#seq_id\tlocation\ttranscript_id\tpos_in_cds\tpos_in_protein\tcodon\tpos_in_codon\tcount\tproduct\tmatches_ref_codon\tmatches_ref_product\tdownstream_of_frameshift_strain_ids\thgvs_p";
  my ($rh,$f)=tempfile(UNLINK=>1);
  print $rh "$header\nLmjF.01\t3745\tUNKNOWN:mRNA\t1\t1\tGAC\t1\t1\tD\t1\t1\t\tp.x\n"; close $rh;
  open(my $r,'<',$f); my $j; open(my $w,'>',\$j);
  transformTranscriptProduct($r,$w,\%map);
} 'dies on unresolvable transcript_id';

dies_ok {
  my %map;
  my $header = "#seq_id\tlocation\ttranscript_id\tpos_in_cds\tpos_in_protein\tcodon\tpos_in_codon\tcount\tproduct\tmatches_ref_codon\tmatches_ref_product\tdownstream_of_frameshift_strain_ids\thgvs_p";
  my ($rh,$f)=tempfile(UNLINK=>1);
  print $rh "$header\nLmjF.01\t3745\t\t1\t1\tGAC\t1\t1\tD\t1\t1\t\tp.x\n"; close $rh;
  open(my $r,'<',$f); my $j; open(my $w,'>',\$j);
  transformTranscriptProduct($r,$w,\%map);
} 'dies on empty transcript_id (NOT NULL column)';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd $PROJECT_HOME && prove -v ApiCommonData/Load/t/variationLoader.t`
Expected: FAIL — `transformTranscriptProduct` undefined.

- [ ] **Step 3: Implement** (add before final `1;`)

```perl
sub transformTranscriptProduct {
  my ($inFh, $outFh, $map) = @_;
  my $header = <$inFh>;
  die "transcript_product.dat: empty file\n" unless defined $header;
  my $cols = parseHeader($header);
  die "transcript_product.dat: expected 13 columns, got " . scalar(@$cols) . "\n"
    unless @$cols == 13;
  die "transcript_product.dat: unexpected header (want seq_id first)\n"
    unless $cols->[0] eq 'seq_id';

  my $n = 0;
  while (my $line = <$inFh>) {
    chomp $line;
    my @f = split /\t/, $line, -1;
    die "transcript_product.dat line $.: expected 13 fields, got " . scalar(@f) . "\n"
      unless @f == 13;
    my $tid = $f[2];
    die "transcript_product.dat line $.: empty transcript_id (na_feature_id is NOT NULL)\n"
      if $tid eq '';
    my $nfid = $map->{$tid};
    die "transcript_product.dat line $.: transcript_id '$tid' not found for this organism\n"
      unless defined $nfid;
    # out: seq_id, location, na_feature_id, cols 4..11 (pos_in_cds..matches_ref_product), hgvs_p
    # drop col index 11 (downstream_of_frameshift_strain_ids); hgvs_p is index 12
    print $outFh join("\t", @f[0,1], $nfid, @f[3..10], $f[12]), "\n";
    $n++;
  }
  return $n;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd $PROJECT_HOME && prove -v ApiCommonData/Load/t/variationLoader.t`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd $PROJECT_HOME/ApiCommonData
git add Load/lib/perl/VariationLoader.pm Load/t/variationLoader.t
git commit -m "feat: transformTranscriptProduct (resolve na_feature_id, drop col, rename count)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: VariationLoader — variationEffect transform

**Files:**
- Modify: `ApiCommonData/Load/lib/perl/VariationLoader.pm`
- Test: `ApiCommonData/Load/t/variationLoader.t`

Input columns (8): `location, seq_id, allele, transcript_id, impact, effect, hgvs_c, source`.
Transform: reorder to `sequence_source_id, location, allele, na_feature_id, impact, effect, hgvs_c, source`. Resolve `transcript_id` → `na_feature_id`; **empty transcript_id → empty output (NULL)**; **non-empty but not found → fatal**.

- [ ] **Step 1: Write the failing test** (append before `done_testing`)

```perl
use ApiCommonData::Load::VariationLoader qw/transformVariationEffect/;

{
  my %map = ('LmjF.01.0010:mRNA' => 9000001);
  my $header = join("\t", qw/location seq_id allele transcript_id impact effect hgvs_c source/);
  my $coding     = join("\t", 3745, 'LmjF.01', 'A', 'LmjF.01.0010:mRNA', 'MODERATE', 'missense_variant', 'c.958G>A', 'snpeff');
  my $intergenic = join("\t", 233,  'LmjF.01', 'G', '',                  'MODIFIER', 'intergenic_region', 'n.233C>G', 'snpeff');

  my ($inFh, $inFile)   = tempfile(UNLINK => 1);
  my ($outFh, $outFile) = tempfile(UNLINK => 1);
  print $inFh "$header\n$coding\n$intergenic\n"; close $inFh;
  open(my $rh, '<', $inFile) or die $!;

  my $n = transformVariationEffect($rh, $outFh, \%map);
  close $outFh; close $rh;
  is($n, 2, 'two rows');

  open(my $oh, '<', $outFile); my @lines = <$oh>; close $oh;
  my @c = split /\t/, $lines[0], -1;
  is(scalar @c, 8, 'output has 8 fields');
  is($c[0], 'LmjF.01', 'sequence_source_id first');
  is($c[1], 3745, 'location second');
  is($c[3], 9000001, 'coding row resolved na_feature_id');
  my @i = split /\t/, $lines[1], -1;
  is($i[3], '', 'intergenic row has empty na_feature_id (-> NULL)');
}

dies_ok {
  my %map;
  my $header = "location\tseq_id\tallele\ttranscript_id\timpact\teffect\thgvs_c\tsource";
  my ($rh,$f)=tempfile(UNLINK=>1);
  print $rh "$header\n1\tLmjF.01\tA\tUNKNOWN:mRNA\tHIGH\tx\tc.1A>T\tsnpeff\n"; close $rh;
  open(my $r,'<',$f); my $j; open(my $w,'>',\$j);
  transformVariationEffect($r,$w,\%map);
} 'dies on non-empty unresolvable transcript_id';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd $PROJECT_HOME && prove -v ApiCommonData/Load/t/variationLoader.t`
Expected: FAIL — `transformVariationEffect` undefined.

- [ ] **Step 3: Implement** (add before final `1;`)

```perl
sub transformVariationEffect {
  my ($inFh, $outFh, $map) = @_;
  my $header = <$inFh>;
  die "snpeff.dat: empty file\n" unless defined $header;
  my $cols = parseHeader($header);
  die "snpeff.dat: expected 8 columns, got " . scalar(@$cols) . "\n"
    unless @$cols == 8;
  die "snpeff.dat: unexpected header (want location first)\n"
    unless $cols->[0] eq 'location';

  my $n = 0;
  while (my $line = <$inFh>) {
    chomp $line;
    my @f = split /\t/, $line, -1;
    die "snpeff.dat line $.: expected 8 fields, got " . scalar(@f) . "\n"
      unless @f == 8;
    my ($loc, $seq, $allele, $tid, $impact, $effect, $hgvsc, $source) = @f;
    my $nfid = '';                       # empty -> NULL for intergenic
    if ($tid ne '') {
      $nfid = $map->{$tid};
      die "snpeff.dat line $.: transcript_id '$tid' not found for this organism\n"
        unless defined $nfid;
    }
    print $outFh join("\t", $seq, $loc, $allele, $nfid, $impact, $effect, $hgvsc, $source), "\n";
    $n++;
  }
  return $n;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd $PROJECT_HOME && prove -v ApiCommonData/Load/t/variationLoader.t`
Expected: PASS, all subtests.

- [ ] **Step 5: Commit**

```bash
cd $PROJECT_HOME/ApiCommonData
git add Load/lib/perl/VariationLoader.pm Load/t/variationLoader.t
git commit -m "feat: transformVariationEffect (reorder, empty transcript_id -> NULL)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Plugin skeleton — args, documentation, new()

**File:** Create `ApiCommonData/Load/plugin/perl/InsertVariationFeatures.pm`

- [ ] **Step 1: Write the skeleton**

```perl
package ApiCommonData::Load::Plugin::InsertVariationFeatures;
use lib "$ENV{GUS_HOME}/lib/perl";
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use GUS::PluginMgr::Plugin;
use GUS::Supported::GusConfig;
use ApiCommonData::Load::VariationLoader qw/
  variationFeatureColumns transcriptProductColumns variationEffectColumns
  transformVariationFeature transformTranscriptProduct transformVariationEffect
/;
use File::Temp qw/tempdir/;

sub getArgsDeclaration {
  return [
    fileArg({ name => 'inputDir', descr => 'mergeExperiments output dir with the .dat files',
              constraintFunc => undef, reqd => 1, isList => 0, mustExist => 1, format => 'directory' }),
    stringArg({ name => 'extDbRlsSpec', descr => 'ExternalDatabaseRelease spec, name|version',
                constraintFunc => undef, reqd => 1, isList => 0 }),
    stringArg({ name => 'organismAbbrev', descr => 'apidb.organism.abbrev to scope the transcript lookup',
                constraintFunc => undef, reqd => 1, isList => 0 }),
    stringArg({ name => 'targetSchema', descr => 'schema to load into (default apidb; tests use jbrestel)',
                constraintFunc => undef, reqd => 0, isList => 0, default => 'apidb' }),
  ];
}

sub getDocumentation {
  my $purpose = "Load mergeExperiments variationFeature.dat, transcript_product.dat, and snpeff.dat into ApiDB variation tables in a single transaction.";
  return {
    purpose          => $purpose,
    purposeBrief     => $purpose,
    notes            => "Undo via undoPreprocess (no row_alg_invocation_id on these tables).",
    tablesAffected   => "ApiDB.VariationFeature, ApiDB.VariationTranscriptProduct, ApiDB.VariationEffect",
    tablesDependedOn => "dots.Transcript, dots.ExternalNaSequence, apidb.Organism, sres.ExternalDatabaseRelease",
    howToRestart     => "Re-run; the load deletes existing rows for this external_database_release_id first.",
    failureCases     => "Unknown organismAbbrev; sequence id not in genome; transcript id unresolved for a coding effect.",
  };
}

sub new {
  my $class = shift;
  my $self = {};
  bless($self, $class);
  $self->initialize({
    requiredDbVersion => 4.0,
    cvsRevision       => '$Revision$',
    name              => ref($self),
    argsDeclaration   => getArgsDeclaration(),
    documentation     => getDocumentation(),
  });
  return $self;
}

sub run { die "not yet implemented\n"; }

1;
```

- [ ] **Step 2: Build and verify the plugin loads**

```bash
cp $PROJECT_HOME/ApiCommonData/Load/plugin/perl/InsertVariationFeatures.pm $GUS_HOME/lib/perl/ApiCommonData/Load/Plugin/
perl -c $GUS_HOME/lib/perl/ApiCommonData/Load/Plugin/InsertVariationFeatures.pm
```
Expected: `... syntax OK`.

- [ ] **Step 3: Commit**

```bash
cd $PROJECT_HOME/ApiCommonData
git add Load/plugin/perl/InsertVariationFeatures.pm
git commit -m "feat: InsertVariationFeatures plugin skeleton (args, docs)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: Plugin — DB queries (transcript map + sequence validation)

**File:** Modify `ApiCommonData/Load/plugin/perl/InsertVariationFeatures.pm`

These use the plugin's `getQueryHandle()` (a live DBI handle) and are verified SQL from the spec.

- [ ] **Step 1: Add `getTranscriptMap` and `getGenomicSequenceIds`** (before `1;`)

```perl
sub getTranscriptMap {
  my ($self, $organismAbbrev) = @_;
  my $dbh = $self->getQueryHandle();
  my $sql = "
    SELECT t.source_id, t.na_feature_id
    FROM   dots.Transcript t, dots.NaSequence ns, apidb.Organism o
    WHERE  t.na_sequence_id = ns.na_sequence_id
      AND  ns.taxon_id      = o.taxon_id
      AND  o.abbrev         = ?";
  my $sth = $dbh->prepare($sql);
  $sth->execute($organismAbbrev);
  my %map;
  while (my ($sid, $nfid) = $sth->fetchrow_array) { $map{$sid} = $nfid; }
  $self->error("No transcripts found for organismAbbrev '$organismAbbrev' - is it loaded?")
    unless %map;
  $self->log("Loaded " . scalar(keys %map) . " transcript ids for $organismAbbrev");
  return \%map;
}

sub getGenomicSequenceIds {
  my ($self, $organismAbbrev) = @_;
  my $dbh = $self->getQueryHandle();
  my $sql = "
    SELECT ens.source_id
    FROM   dots.ExternalNaSequence ens, apidb.Organism o
    WHERE  ens.taxon_id = o.taxon_id
      AND  o.abbrev     = ?";
  my $sth = $dbh->prepare($sql);
  $sth->execute($organismAbbrev);
  my %seqIds;
  while (my ($sid) = $sth->fetchrow_array) { $seqIds{$sid} = 1; }
  return \%seqIds;
}

# Reads distinct seq_id (column 2) from variationFeature.dat and dies if any is
# not a genomic sequence for this organism. Nothing else protects
# VariationFeature.sequence_source_id (it is a bare VARCHAR with no FK).
sub validateSequenceIds {
  my ($self, $inputDir, $validSeqIds) = @_;
  open(my $fh, '<', "$inputDir/variationFeature.dat")
    or $self->error("Cannot open $inputDir/variationFeature.dat: $!");
  <$fh>; # header
  my %seen;
  while (my $line = <$fh>) {
    chomp $line;
    my @f = split /\t/, $line, -1;
    $seen{$f[1]} = 1;
  }
  close $fh;
  my @bad = grep { !$validSeqIds->{$_} } sort keys %seen;
  $self->error("variationFeature.dat references sequence ids not in this organism's genome: "
    . join(", ", @bad)) if @bad;
  $self->log("Validated " . scalar(keys %seen) . " distinct sequence ids");
}
```

- [ ] **Step 2: Build and syntax-check**

```bash
cp $PROJECT_HOME/ApiCommonData/Load/plugin/perl/InsertVariationFeatures.pm $GUS_HOME/lib/perl/ApiCommonData/Load/Plugin/
perl -c $GUS_HOME/lib/perl/ApiCommonData/Load/Plugin/InsertVariationFeatures.pm
```
Expected: `syntax OK`.

- [ ] **Step 3: Commit**

```bash
cd $PROJECT_HOME/ApiCommonData
git add Load/plugin/perl/InsertVariationFeatures.pm
git commit -m "feat: InsertVariationFeatures organism-scoped transcript map + seq validation

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: Plugin — psql orchestration (transform + single-transaction load)

**File:** Modify `ApiCommonData/Load/plugin/perl/InsertVariationFeatures.pm`

- [ ] **Step 1: Add connection parsing and the loader** (before `1;`)

```perl
# Parse host/port/dbname out of the gus.config dbiDsn. NOTE: the port matters —
# the default config runs on 5433, and psql defaults to 5432, so an omitted port
# silently hits the wrong database.
sub getPsqlConnection {
  my ($self) = @_;
  my $cfg = GUS::Supported::GusConfig->new();
  my $dsn = $cfg->getDbiDsn();     # dbi:Pg:dbname=...;host=...;port=...
  my ($dbname) = $dsn =~ /dbname=([^;]+)/;
  my ($host)   = $dsn =~ /host=([^;]+)/;
  my ($port)   = $dsn =~ /port=([^;]+)/;
  return {
    login    => $cfg->getDatabaseLogin(),
    password => $cfg->getDatabasePassword(),
    dbname   => $dbname,
    host     => $host || 'localhost',
    port     => $port || 5432,
  };
}

# Build a single-line \copy command. Psql.pm's getCommand() emits multi-line,
# which fails in a psql -f script, so we assemble it here.
sub copyCommand {
  my ($self, $table, $columns, $file) = @_;
  my $cols = join(", ", @$columns);
  # QUOTE '`' matches Psql.pm and is verified against this data (no backticks,
  # double quotes, or CRs occur in any field). The data is unquoted, so QUOTE
  # only needs to be a byte that never appears.
  return "\\copy $table ($cols) FROM '$file' "
       . "WITH (FORMAT CSV, DELIMITER E'\\t', QUOTE '\`', ENCODING 'UTF8')";
}

sub loadAll {
  my ($self, $schema, $extDbRlsId, $vfFile, $tpFile, $veFile) = @_;
  my $conn = $self->getPsqlConnection();
  my $dir  = tempdir(CLEANUP => 1);
  my $sqlFile = "$dir/load.sql";

  open(my $sql, '>', $sqlFile) or $self->error("Cannot write $sqlFile: $!");
  print $sql "BEGIN;\n";
  print $sql "DELETE FROM $schema.VariationFeature WHERE external_database_release_id = $extDbRlsId;\n";
  print $sql $self->copyCommand("$schema.VariationFeature",           variationFeatureColumns(),  $vfFile) . "\n";
  print $sql $self->copyCommand("$schema.VariationTranscriptProduct", transcriptProductColumns(), $tpFile) . "\n";
  print $sql $self->copyCommand("$schema.VariationEffect",            variationEffectColumns(),   $veFile) . "\n";
  print $sql "COMMIT;\n";
  close $sql;

  my $connStr = "postgresql://$conn->{login}:$conn->{password}\@$conn->{host}:$conn->{port}/$conn->{dbname}";
  my $logFile = "$dir/psql.log";
  my $cmd = "psql -v ON_ERROR_STOP=1 --log-file='$logFile' -f '$sqlFile' '$connStr'";

  $self->log("Running single-transaction load via psql");
  my $rc = system($cmd);
  if ($rc != 0) {
    $self->printFile($logFile);
    $self->error("psql load failed (rc=$rc); transaction rolled back, prior data intact");
  }
}

sub printFile {
  my ($self, $file) = @_;
  return unless -e $file;
  open(my $fh, '<', $file) or return;
  while (<$fh>) { $self->log("psql: $_") }
  close $fh;
}
```

- [ ] **Step 2: Build and syntax-check**

```bash
cp $PROJECT_HOME/ApiCommonData/Load/plugin/perl/InsertVariationFeatures.pm $GUS_HOME/lib/perl/ApiCommonData/Load/Plugin/
perl -c $GUS_HOME/lib/perl/ApiCommonData/Load/Plugin/InsertVariationFeatures.pm
```
Expected: `syntax OK`.

- [ ] **Step 3: Commit**

```bash
cd $PROJECT_HOME/ApiCommonData
git add Load/plugin/perl/InsertVariationFeatures.pm
git commit -m "feat: InsertVariationFeatures single-transaction psql loader

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: Plugin — wire run() together

**File:** Modify `ApiCommonData/Load/plugin/perl/InsertVariationFeatures.pm`

- [ ] **Step 1: Replace the stub `run`**

```perl
sub run {
  my ($self) = @_;

  my $inputDir       = $self->getArg('inputDir');
  my $organismAbbrev = $self->getArg('organismAbbrev');
  my $schema         = $self->getArg('targetSchema');
  my $extDbRlsId     = $self->getExtDbRlsId($self->getArg('extDbRlsSpec'))
    or $self->error("Cannot resolve extDbRlsSpec: " . $self->getArg('extDbRlsSpec'));

  my $map      = $self->getTranscriptMap($organismAbbrev);
  my $validSeq = $self->getGenomicSequenceIds($organismAbbrev);
  $self->validateSequenceIds($inputDir, $validSeq);

  my $dir = tempdir(CLEANUP => 1);
  my ($vf, $tp, $ve) = ("$dir/vf.tmp", "$dir/tp.tmp", "$dir/ve.tmp");

  my $nvf = $self->transformFile($inputDir, 'variationFeature.dat', $vf,
    sub { transformVariationFeature($_[0], $_[1], $extDbRlsId) });
  my $ntp = $self->transformFile($inputDir, 'transcript_product.dat', $tp,
    sub { transformTranscriptProduct($_[0], $_[1], $map) });
  my $nve = $self->transformFile($inputDir, 'snpeff.dat', $ve,
    sub { transformVariationEffect($_[0], $_[1], $map) });

  $self->loadAll($schema, $extDbRlsId, $vf, $tp, $ve);

  return "Loaded VariationFeature=$nvf VariationTranscriptProduct=$ntp VariationEffect=$nve";
}

sub transformFile {
  my ($self, $inputDir, $name, $outFile, $transform) = @_;
  open(my $in,  '<', "$inputDir/$name") or $self->error("Cannot open $inputDir/$name: $!");
  open(my $out, '>', $outFile)          or $self->error("Cannot write $outFile: $!");
  my $n = eval { $transform->($in, $out) };
  $self->error("Transform of $name failed: $@") if $@;
  close $in; close $out;
  $self->log("Transformed $name: $n rows");
  return $n;
}
```

- [ ] **Step 2: Build and syntax-check**

```bash
cp $PROJECT_HOME/ApiCommonData/Load/plugin/perl/InsertVariationFeatures.pm $GUS_HOME/lib/perl/ApiCommonData/Load/Plugin/
perl -c $GUS_HOME/lib/perl/ApiCommonData/Load/Plugin/InsertVariationFeatures.pm
```
Expected: `syntax OK`.

- [ ] **Step 3: Commit**

```bash
cd $PROJECT_HOME/ApiCommonData
git add Load/plugin/perl/InsertVariationFeatures.pm
git commit -m "feat: InsertVariationFeatures run() orchestration

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: Plugin — undo via undoPreprocess

**File:** Modify `ApiCommonData/Load/plugin/perl/InsertVariationFeatures.pm`

The `Undo.pm` framework constructs the plugin with a bare `new()` — no `getArg`, no
initialized handle. Recover `extDbRlsSpec` from `core.AlgorithmParam` and resolve it to
an id with plain SQL, then delete (children cascade).

- [ ] **Step 1: Add undo methods** (before `1;`)

```perl
sub undoTables { return (); }   # no row_alg_invocation_id on these tables

sub undoPreprocess {
  my ($self, $dbh, $rowAlgInvocationList) = @_;

  my $specs = $self->getAlgorithmParam($dbh, $rowAlgInvocationList, 'extDbRlsSpec');
  $self->error("undo: could not recover extDbRlsSpec from core.AlgorithmParam")
    unless $specs && @$specs;

  # targetSchema is optional; default to apidb if it was not recorded.
  my $schemas = $self->getAlgorithmParam($dbh, $rowAlgInvocationList, 'targetSchema');
  my $schema  = ($schemas && @$schemas && $schemas->[0]) ? $schemas->[0] : 'apidb';

  foreach my $spec (@$specs) {
    my ($name, $version) = split /\|/, $spec;
    my $sql = "
      SELECT r.external_database_release_id
      FROM   sres.ExternalDatabaseRelease r, sres.ExternalDatabase d
      WHERE  d.external_database_id = r.external_database_id
        AND  d.name = ? AND r.version = ?";
    my $sth = $dbh->prepare($sql);
    $sth->execute($name, $version);
    my ($id) = $sth->fetchrow_array;
    $self->error("undo: no external_database_release_id for '$spec'") unless $id;

    my $del = $dbh->prepare("DELETE FROM $schema.VariationFeature WHERE external_database_release_id = ?");
    my $n = $del->execute($id);
    $self->log("undo: deleted $n VariationFeature rows (children cascade) for $spec");
  }
}

# Recover a plugin argument's recorded value(s) from core.AlgorithmParam, keyed by
# plugin name and invocation id. Pattern from InsertEdaStudyFromArtifacts.
sub getAlgorithmParam {
  my ($self, $dbh, $rowAlgInvocationList, $paramKey) = @_;
  my $pluginName = ref($self);
  my @values;
  foreach my $rowAlgInvId (@$rowAlgInvocationList) {
    my $sql = "SELECT p.STRING_VALUE
      FROM core.ALGORITHMPARAMKEY k
      LEFT JOIN core.ALGORITHMIMPLEMENTATION a ON k.ALGORITHM_IMPLEMENTATION_ID = a.ALGORITHM_IMPLEMENTATION_ID
      LEFT JOIN core.ALGORITHMPARAM p ON k.ALGORITHM_PARAM_KEY_ID = p.ALGORITHM_PARAM_KEY_ID
      WHERE a.EXECUTABLE = ? AND p.ROW_ALG_INVOCATION_ID = ? AND k.ALGORITHM_PARAM_KEY = ?";
    my $sth = $dbh->prepare($sql);
    $sth->execute($pluginName, $rowAlgInvId, $paramKey);
    while (my ($v) = $sth->fetchrow_array) { push @values, $v if defined $v; }
  }
  return \@values;
}
```

- [ ] **Step 2: Build and syntax-check**

```bash
cp $PROJECT_HOME/ApiCommonData/Load/plugin/perl/InsertVariationFeatures.pm $GUS_HOME/lib/perl/ApiCommonData/Load/Plugin/
perl -c $GUS_HOME/lib/perl/ApiCommonData/Load/Plugin/InsertVariationFeatures.pm
```
Expected: `syntax OK`.

- [ ] **Step 3: Commit**

```bash
cd $PROJECT_HOME/ApiCommonData
git add Load/plugin/perl/InsertVariationFeatures.pm
git commit -m "feat: InsertVariationFeatures undo via undoPreprocess

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 11: Integration test against the jbrestel stub schema

**File:** Create `ApiCommonData/Load/t/insertVariationFeatures_integration.t`

This does not run the plugin through GUS (which needs a full workflow context). It exercises
the transform + single-transaction load path — the parts unique to this loader — against the
real `jbrestel` stub schema, using the transform functions directly.

- [ ] **Step 1: Ensure the stub schema exists**

```bash
psql -h localhost -p 5432 -d unidb_shu_a -tAc \
  "SELECT count(*) FROM jbrestel.stubtranscript;"
```
Expected: `78`. If the schema is gone, recreate it with the scratchpad SQL
(`create_jbrestel_stub.sql`) and re-seed `stub_transcript.dat`.

- [ ] **Step 2: Write the integration test**

```perl
use strict;
use warnings;
use lib "$ENV{GUS_HOME}/lib/perl";
use Test::More;
use File::Temp qw/tempdir/;
use ApiCommonData::Load::VariationLoader qw/
  variationFeatureColumns transcriptProductColumns variationEffectColumns
  transformVariationFeature transformTranscriptProduct transformVariationEffect
/;

my $INPUT = '/home/jbrestel/dnaseq_test/merge/output';
my $DB    = 'unidb_shu_a';
plan skip_all => "sample data $INPUT not present" unless -d $INPUT;

# Build the transcript map from jbrestel.StubTranscript via psql.
my %map;
open(my $m, "-|", "psql -h localhost -p 5432 -d $DB -tAF'\t' -c "
  . "'SELECT source_id, na_feature_id FROM jbrestel.stubtranscript'") or die $!;
while (<$m>) { chomp; my ($s,$n) = split /\t/; $map{$s} = $n if $s; }
close $m;
is(scalar keys %map, 78, 'stub transcript map has 78 entries');

my $dir = tempdir(CLEANUP => 1);
my %n;
for ([qw/variationFeature.dat vf/], [qw/transcript_product.dat tp/], [qw/snpeff.dat ve/]) {
  my ($file, $tag) = @$_;
  open(my $in, '<', "$INPUT/$file") or die $!;
  open(my $out, '>', "$dir/$tag.tmp") or die $!;
  $n{$tag} =
      $tag eq 'vf' ? transformVariationFeature($in, $out, 1)
    : $tag eq 'tp' ? transformTranscriptProduct($in, $out, \%map)
    :                transformVariationEffect($in, $out, \%map);
  close $in; close $out;
}
is($n{vf}, 1504, 'vf rows'); is($n{tp}, 781, 'tp rows'); is($n{ve}, 1978, 've rows');

# Assemble and run the single-transaction load into jbrestel.
my $vfCols = join(", ", @{variationFeatureColumns()});
my $tpCols = join(", ", @{transcriptProductColumns()});
my $veCols = join(", ", @{variationEffectColumns()});
my $sqlFile = "$dir/load.sql";
open(my $s, '>', $sqlFile) or die $!;
print $s "BEGIN;\n";
print $s "DELETE FROM jbrestel.VariationFeature WHERE external_database_release_id = 1;\n";
print $s "\\copy jbrestel.VariationFeature ($vfCols) FROM '$dir/vf.tmp' WITH (FORMAT CSV, DELIMITER E'\\t', QUOTE '\`', ENCODING 'UTF8')\n";
print $s "\\copy jbrestel.VariationTranscriptProduct ($tpCols) FROM '$dir/tp.tmp' WITH (FORMAT CSV, DELIMITER E'\\t', QUOTE '\`', ENCODING 'UTF8')\n";
print $s "\\copy jbrestel.VariationEffect ($veCols) FROM '$dir/ve.tmp' WITH (FORMAT CSV, DELIMITER E'\\t', QUOTE '\`', ENCODING 'UTF8')\n";
print $s "COMMIT;\n";
close $s;

my $rc = system("psql -h localhost -p 5432 -d $DB -v ON_ERROR_STOP=1 -f '$sqlFile' >/dev/null 2>&1");
is($rc, 0, 'single-transaction load succeeded');

sub count1 {
  my ($tbl) = @_;
  my $c = `psql -h localhost -p 5432 -d $DB -tAc "SELECT count(*) FROM jbrestel.$tbl"`;
  chomp $c; return $c;
}
is(count1('VariationFeature'), 1504, 'VariationFeature loaded');
is(count1('VariationTranscriptProduct'), 781, 'VariationTranscriptProduct loaded');
is(count1('VariationEffect'), 1978, 'VariationEffect loaded');

# Intergenic rows -> NULL na_feature_id: 1978 - 1181 = 797 non-null.
my $nn = `psql -h localhost -p 5432 -d $DB -tAc "SELECT count(na_feature_id) FROM jbrestel.VariationEffect"`;
chomp $nn;
is($nn, 797, 'VariationEffect na_feature_id non-null count (empty -> NULL)');

# Cascade delete clears all three (the undo path).
system("psql -h localhost -p 5432 -d $DB -c 'DELETE FROM jbrestel.VariationFeature WHERE external_database_release_id = 1' >/dev/null 2>&1");
is(count1('VariationTranscriptProduct'), 0, 'children cascade-deleted');

done_testing;
```

- [ ] **Step 3: Run it**

Run: `cd $PROJECT_HOME && prove -v ApiCommonData/Load/t/insertVariationFeatures_integration.t`
Expected: PASS — all counts as asserted.

- [ ] **Step 4: Commit**

```bash
cd $PROJECT_HOME/ApiCommonData
git add Load/t/insertVariationFeatures_integration.t
git commit -m "test: integration load into jbrestel stub schema

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 12: End-to-end smoke via the real plugin (manual, optional)

Requires a `gus.config` pointing at a database where the target tables and a real organism
both exist. Not runnable against `unidb_shu_a` as-is (no *L. major*). Document the command
for whoever has such an instance:

```bash
ga ApiCommonData::Load::Plugin::InsertVariationFeatures \
  --inputDir /path/to/merge/output \
  --extDbRlsSpec 'someVariation_RSRC|2026-07-10' \
  --organismAbbrev lmajFriedlin \
  --commit
```

Undo:

```bash
ga GUS::Community::Plugin::Undo \
  --plugin ApiCommonData::Load::Plugin::InsertVariationFeatures \
  --algInvocationId <id> --commit
```

---

## Self-review notes

- **Spec coverage:** schema changes (T1), transforms incl. all three files and null/fatal
  rules (T3–5), organism-scoped map + sequence validation (T7), single-transaction load with
  correct port handling (T8), run() wiring (T9), undoPreprocess (T10), integration incl.
  atomicity-relevant counts and cascade (T11). All spec sections map to a task.
- **QUOTE character:** the plan uses backtick `` '`' `` — matching Psql.pm and verified
  against the sample loads (no backticks, double quotes, or CRs occur in any field). The
  data is unquoted, so QUOTE only needs a byte that never appears.
- **Not covered by automated tests:** the full `ga` plugin invocation (needs workflow
  context + a real organism), hence the manual T12. The DB-query methods (T7) and psql
  orchestration (T8) are exercised by T11 via the same SQL, but not through the plugin's
  own `getQueryHandle`. Acceptable given the environment; flagged honestly.
