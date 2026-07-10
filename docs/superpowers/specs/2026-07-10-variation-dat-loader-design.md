# Loading mergeExperiments variation `.dat` files into ApiDB relational tables

**Date:** 2026-07-10
**Status:** design approved, not yet implemented
**Repos touched:** `ApiCommonData` (loader), `ApidbSchema` branch `dnaseq-tables` (DDL)

## Problem

The `dnaseq-nextflow` `mergeExperiments` workflow emits tab-delimited `.dat` files
describing sequence variation across strains. Nothing loads them. There are no
loading notes anywhere in `dnaseq-nextflow` — only the README's "Outputs are
intended for loading into a GUS/VEuPathDB database." The column contracts live in
`dnaseq-nextflow/docs/superpowers/specs/2026-07-06-variationfeature-per-class-schema-design.md`
and `2026-05-13-hsss-and-product-dat-gene-level.md`.

Three new tables exist in `ApidbSchema` branch `dnaseq-tables`
(`Main/lib/sql/apidbschema/Postgres/createVariationTables.sql`). We need a Perl
loader consistent with this repo's conventions.

## Input files

From `mergeExperiments` output dir. Sample run: `/home/jbrestel/dnaseq_test/merge/output`
(*L. major* Friedlin, 5 strains).

| File | Rows (sample) | Target table |
|---|---|---|
| `variationFeature.dat` | 1,504 | `ApiDB.VariationFeature` |
| `transcript_product.dat` | 781 | `ApiDB.VariationTranscriptProduct` |
| `snpeff.dat` | 1,978 | `ApiDB.VariationEffect` |

Not loaded: `allele.dat`, `sample.dat`, `merged.ann.vcf.gz`, the `hsss_readFreq*/` trees.

**Conventions confirmed against the sample data:**

- Tab-delimited, one header line. Only `transcript_product.dat` prefixes its header with `#`.
- **Empty string means absent.** `FORMAT CSV` maps an unquoted empty field to NULL,
  which is why `ApiCommonData::Load::Psql` deliberately omits its `NULL` clause.
- No backticks, double quotes, or carriage returns in any field, so `Psql.pm`'s
  backtick `QUOTE` character is safe.
- `snpeff.dat` compound effects are already split on `&` into separate rows, so
  `VariationEffect.effect VARCHAR(60)` is sufficient (longest observed: 30).
- Verified: zero duplicate `(seq_id, location)` pairs; zero FK orphans between the
  child files and `variationFeature.dat`; all values fit their declared column widths.

## Schema changes (`ApidbSchema`, branch `dnaseq-tables`)

1. **Add `ApiDB.VariationFeature.source_id VARCHAR(100) NOT NULL UNIQUE.`**
   Format: `Variant_<sequence_source_id>_<location>` — e.g. `Variant_LmjF.01_233`.

   The prefix is a **constant**, not `variant_type`. `variant_type` is derived from
   the strain set: adding a strain can flip a locus `SNV` → `MIXED` (41 of 1,504 loci
   in the sample are already `MIXED`). Embedding it would change the identifier of an
   unchanged physical locus on every re-merge, silently breaking bookmarks, saved
   strategies, and external links. The constant prefix namespaces the id against gene
   and transcript source ids without that churn.

   **The id is opaque. Do not parse it.** Sequence source ids may contain underscores
   (`Variant_Chr1_A_fumigatus_Af293_233`), so it cannot be reliably split back into
   `(sequence_source_id, location)` — and there is no need to, since both columns sit
   alongside it. Sizing: `Variant_` (8) + 60 + `_` + 12 = 81; `VARCHAR(100)` for headroom.

2. **Drop `ApiDB.VariationTranscriptProduct.downstream_of_frameshift_strain_ids`.**
   Populated in 1 of 781 sample rows, with a value (`{1,3,4}`) referencing strain ids
   from `sample.dat`, which we do not load. It would be a dangling pointer into a table
   that does not exist. The `.dat` file retains the column for QA; the loader skips it.

`source_id` gets a `UNIQUE` constraint (auto-indexed). The primary key stays
`(sequence_source_id, location)` and the child tables keep their existing composite
foreign key. `source_id` is **not** denormalized onto the children.

### Assumption: one variation dataset per genome

`VariationFeature`'s primary key is `(sequence_source_id, location)` and carries no
`external_database_release_id`. Two variation datasets for the same organism — say,
different strain sets — cannot coexist; the second collides on the primary key. The
same is true of `source_id`. **Accepted:** the tables model "the variation calls for
this genome," not "the variation calls from this experiment." `mergeExperiments`
produces one merged call set per organism, so this matches the pipeline.

### Uniqueness of `source_id`

`Variant_<seq>_<loc>` is unique iff genomic sequence source ids are unique across
organisms. Verified in `unidb_shu_a`: `dots.ExternalNaSequence` (a view over
`dots.NaSequence`, restricted to genomic sequences) has zero duplicate `source_id`s
across all 8 loaded organisms.

Note this is a *data property*, not an enforced constraint — `dots.NaSequence` in a
UniDB build carries zero indexes and zero constraints, not even a primary key. The
guarantee we actually rely on is our own `UNIQUE (source_id)` on `VariationFeature`,
which turns any hypothetical cross-organism collision into a loud load failure rather
than a silent merge of two organisms' variants. (The one duplicate in the base table
is 79 `SplicedNASequence` rows sharing an empty `source_id` — transcript sequences
with no id, outside the genomic view.)

### Consequence: undo goes through `undoPreprocess`, not `undoTables`

The schema commit deliberately omits housekeeping columns and a `core.TableInfo` entry
(legacy SNP-table precedent). `GUS::Community::Plugin::Undo` (`Undo.pm`) implements
`undoTables` by issuing `DELETE FROM <table> WHERE row_alg_invocation_id IN (...)`.
These tables have no such column, so **`undoTables` must return `()`**.

`Undo.pm` provides a second, undocumented hook. Its `run()` does, in order:

1. `$plugin = $pluginName->new()` — a **fresh, uninitialized** plugin instance.
2. `$plugin->undoPreprocess($dbh, $algInvocationIds)`, inside a transaction with
   `AutoCommit=0`, committed if `--commit`. A missing method is caught and skipped.
3. Deletes each `undoTables()` entry by `row_alg_invocation_id`.
4. Deletes `Core.AlgorithmParam`, then `Core.AlgorithmInvocation`.

Because step 2 precedes step 4, `undoPreprocess` can still read the plugin's original
arguments out of `core.AlgorithmParam`. Because the instance in step 1 is fresh,
`getArg()` and the initialized GUS handle are **not** available — arguments must be
recovered by querying the passed `$dbh`. `InsertEdaStudyFromArtifacts` is the
reference implementation, via its `getAlgorithmParam($dbh, $rowAlgInvocationList, $key)`
helper, which joins `core.AlgorithmParamKey`, `core.AlgorithmImplementation`, and
`core.AlgorithmParam` on the plugin name and invocation id.

So this loader implements:

```perl
sub undoTables { return (); }

sub undoPreprocess {
  my ($self, $dbh, $rowAlgInvocationList) = @_;
  my $spec = $self->getAlgorithmParam($dbh, $rowAlgInvocationList, 'extDbRlsSpec')->[0];
  # resolve $spec -> external_database_release_id against $dbh, then:
  #   DELETE FROM apidb.VariationFeature WHERE external_database_release_id = ?
}
```

`ON DELETE CASCADE` on both children clears them. Resolve the spec with plain SQL
against `sres.ExternalDatabaseRelease`/`sres.ExternalDatabase` rather than
`$self->getExtDbRlsId`, which needs an initialized plugin.

The arg must be named exactly `extDbRlsSpec`, since that string is the
`core.AlgorithmParamKey` lookup key.

Note this deletes **all** rows for that external database release, not merely those
from the given algorithm invocation. Given no per-invocation tracking exists in these
tables, that is the only available granularity, and it is consistent with the
one-dataset-per-genome constraint above.

The absence of `core.TableInfo` also means no `GUS::Model::ApiDB::*` classes exist, so
object-based inserts are unavailable: `COPY` is not merely the fast path, it is the
only path.

## Loader design

`ApiCommonData::Load::Plugin::InsertVariationFeatures`

**Arguments:** `--inputDir`, `--extDbRlsSpec`, `--organismAbbrev`,
`--targetSchema` (default `apidb`; exists so integration tests can target `jbrestel`).

### Step 1 — resolve the external database release

Standard `$self->getExtDbRlsId($self->getArg('extDbRlsSpec'))`.

### Step 2 — build the transcript map, scoped by organism

```sql
SELECT t.source_id, t.na_feature_id
FROM   dots.Transcript t, dots.NaSequence ns, apidb.Organism o
WHERE  t.na_sequence_id = ns.na_sequence_id
  AND  ns.taxon_id      = o.taxon_id
  AND  o.abbrev         = ?
```

Note the column is `apidb.organism.abbrev`, not `organism_abbrev`. Verified against
`unidb_shu_a`: returns 10,130 transcripts for `afumAf293` out of 69,397 total.

Transcript source ids happen to be globally unique in that database today, so the
scoping is not strictly required for correctness. It is still right: it shrinks the
hash roughly sevenfold, guards against future cross-organism collisions, and fails
loudly if `--organismAbbrev` names an organism that isn't loaded. The sample data has
78 distinct transcripts; production genomes have tens of thousands. A hash is fine.

### Step 3 — validate the sequences belong to the organism

`VariationFeature.sequence_source_id` is a bare `VARCHAR(60)` with no foreign key to
`dots.NaSequence`. Nothing in the schema prevents loading *Leishmania* `.dat` files
into an *Aspergillus* build; the rows would land happily and be wrong forever.

Before loading, assert every distinct `seq_id` in `variationFeature.dat` appears in:

```sql
SELECT ens.source_id
FROM   dots.ExternalNaSequence ens, apidb.Organism o
WHERE  ens.taxon_id = o.taxon_id AND o.abbrev = ?
```

`dots.NaSequence` also holds transcript sequences, so the genomic-only
`dots.ExternalNaSequence` is the correct relation (9 rows for `afumAf293`). Any
unmatched `seq_id` is fatal. This converts a silent, permanent data-corruption bug
into a load-time failure.

### Step 4 — stream-transform each file to a temp file

Each `.dat` is read line by line and written to a temp file whose columns match the
`\COPY` field list. Memory stays constant apart from the transcript hash.

Because `\COPY` takes an explicit field list, the physical column order of the tables
is irrelevant; only agreement between the field list and the temp file matters.

**`variationFeature.dat` → `VariationFeature`** (31 columns in, 33 out)
- Prepend `source_id`, computed as `Variant_<seq_id>_<location>`.
- Emit `seq_id` as `sequence_source_id`; reorder so it precedes `location`.
- Append the constant `external_database_release_id`.

**`transcript_product.dat` → `VariationTranscriptProduct`** (13 columns in, 12 out)
- Strip the leading `#` from the header.
- Drop column 12, `downstream_of_frameshift_strain_ids`.
- Rename `count` → `strain_count`.
- Resolve `transcript_id` → `na_feature_id`. **A miss is fatal** — the column is
  `NOT NULL`. All 781 sample rows carry a transcript id.

**`snpeff.dat` → `VariationEffect`** (8 columns in, 8 out)
- Reorder to `sequence_source_id, location, allele, na_feature_id, impact, effect, hgvs_c, source`.
- Resolve `transcript_id` → `na_feature_id`; an **empty** `transcript_id` yields NULL.

  This is the common case, not an edge case: 1,181 of 1,978 sample rows are intergenic
  and have no transcript. The code must never conflate "empty, therefore intergenic"
  (normal) with "looked up and not found" (data corruption). The latter is fatal.

### Step 5 — one psql invocation, one transaction

Generate a single SQL script and run `psql -v ON_ERROR_STOP=1 -f <script>` **once**:

```sql
BEGIN;
DELETE FROM <schema>.VariationFeature WHERE external_database_release_id = <id>;
\COPY <schema>.VariationFeature (<fields>) FROM '<tmp1>' WITH (FORMAT CSV, ...)
\COPY <schema>.VariationTranscriptProduct (<fields>) FROM '<tmp2>' WITH (FORMAT CSV, ...)
\COPY <schema>.VariationEffect (<fields>) FROM '<tmp3>' WITH (FORMAT CSV, ...)
COMMIT;
```

Reuse `ApiCommonData::Load::Psql`'s `getCommand()` to build each `\COPY` clause, but
**not** its `getCommandLine()`. `getCommandLine()` wraps a single `\COPY` in its own
`psql --command` invocation, which is what `InstallEdaStudyFromArtifacts` does per
table. For a parent and two FK children that means three independent transactions: a
failure loading `VariationEffect` leaves committed `VariationFeature` rows behind, and
the only cleanup path is the cascade delete off a parent that may no longer be there.
One script, one transaction.

`InsertAlphaFold` streams into a named FIFO instead of a temp file, avoiding disk
entirely. That works because it loads one table. Temp files are the right call here:
they permit a single transaction across three ordered `\COPY`s, and they survive a
failure so the offending row can be inspected.

Load order is parent then children, or the foreign key checks fail.

The leading `DELETE` makes re-running the loader idempotent, and mirrors exactly what
`undoPreprocess` does.

**Verified against `unidb_shu_a` (2026-07-10), loading the sample data into `jbrestel`:**

- One transaction loads 1504 / 781 / 1978 rows. Empty fields become NULL:
  `VariationEffect.na_feature_id` is non-null in exactly 797 rows (1978 − 1181
  intergenic); `indel_frame_effect` in exactly 273 (207 + 42 + 24).
- Re-running is idempotent: `DELETE 1504`, reload, identical counts.
- **Atomicity holds.** Appending one FK-violating row to the third `\COPY` aborts the
  transaction and the pre-existing 1504 / 781 / 1978 survive — the leading `DELETE`
  does *not* commit. Under three separate `psql --command` invocations the same
  failure would have committed the `DELETE` and both parent COPYs, leaving a reloaded
  parent and an empty `VariationEffect`. This is the concrete reason for the single
  script.
- Cascade delete by `external_database_release_id` clears all three tables (0 / 0 / 0).
- `Psql.pm`'s exact `\COPY` configuration (`FORMAT CSV, DELIMITER E'\t', QUOTE '` + "`" + `'`)
  round-trips the data unchanged.

### Step 6 — report

Log rows read per file and rows loaded per table; verify they agree.

## Testing

`unidb_shu_a` contains *A. fumigatus*, *P. falciparum*, *T. gondii*, and others — but
**no *L. major***. Zero `LmjF%` transcripts. The sample `.dat` files therefore cannot
have their `na_feature_id` lookups satisfied against real `dots.Transcript` rows.

Testing splits accordingly:

**Unit (no database).** The per-file transforms are pure functions of
`(input handle, transcript map, extDbRlsId)` → output lines. Test column reordering,
the `#` header strip, the dropped column, `count` → `strain_count`, `source_id`
construction, empty-to-NULL passthrough, intergenic NULL `na_feature_id`, and fatal
handling of an unresolvable transcript id. No database required, which is the point of
factoring the transform out of the plugin.

**Integration (`jbrestel` schema).** *Created 2026-07-10.* The `jbrestel` schema holds
copies of the three tables *without* the `dots`/`sres` foreign keys but *with* the
parent→child `ON DELETE CASCADE`, plus `jbrestel.StubTranscript` carrying the 78 `LmjF`
source ids mapped to synthetic `na_feature_id`s (9000001+, chosen not to collide with
real values). Run the loader with `--targetSchema jbrestel`. This exercises the
generated SQL script end to end: column order, null handling, load ordering, cascade
delete, transaction atomicity, and idempotent re-run — all four already confirmed by
hand with a throwaway prototype of the transform.

**Lookup query (real data).** The organism-scoped transcript query and the sequence
validation query are tested directly against `afumAf293`, which is really loaded.
Both are single SQL statements and have been verified by hand.

Dropping the `dots`/`sres` foreign keys in the `jbrestel` copies costs little
confidence: those constraints are Postgres's job, not the loader's, and the loader
never constructs the values they guard except through the lookup, which is tested
separately against real data.

## Risks and open items

- **`unidb_shu_a` crashed once** during ordinary read-only catalog queries
  (`server terminated abnormally`, then connection-refused until manually restarted).
  Cause unknown. Worth watching; unrelated to this design as far as anyone can tell.
- **`snpeff.dat` `&`-splitting** is asserted by the pipeline author and consistent with
  the sample (zero `&` in 1,978 rows). If a future SnpEff config stops splitting,
  `VariationEffect.effect VARCHAR(60)` will start truncating. Worth a full-size run
  before production.
- **`--targetSchema`** is a test affordance in production code (accepted 2026-07-10).
  Default it to `apidb` and do not document it as a user-facing knob.

## Decisions log

| Decision | Rationale |
|---|---|
| Perl GUS plugin, not standalone script | Consistency; `getExtDbRlsId`, `--commit` semantics |
| Temp files + `\COPY`, not `DBD::Pg` `pg_putcopydata` | Repo precedent; `Psql.pm` reuse |
| One psql script, not three `system()` calls | Atomicity across a parent and two FK children (verified) |
| Empty `undoTables()` + `undoPreprocess()` | No `row_alg_invocation_id`; recover `extDbRlsSpec` from `core.AlgorithmParam` |
| `source_id` = `Variant_<seq>_<loc>` | Stable across re-merges; `variant_type` is derived |
| `source_id` on parent only | Avoids denormalizing an identifier into three tables |
| Drop `downstream_of_frameshift_strain_ids` | Dangling reference to unloaded `sample.dat` |
| Scope transcript lookup by `--organismAbbrev` | Smaller hash, future collision safety, fail-fast |
| Validate `seq_id`s against `ExternalNaSequence` | No FK protects `sequence_source_id` |
