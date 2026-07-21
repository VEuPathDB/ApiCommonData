# Design: InsertGeneCoexpression plugin

Date: 2026-07-20

## Purpose

Load a per-organism/per-dataset gene coexpression table into
`ApiDB.GeneCoexpression` using `psql \copy` inside a single transaction. Each
input row pairs a gene with an associated gene and a correlation coefficient;
the load stamps every row with the `external_database_release_id` resolved from
a command-line `extDbRlsSpec`.

This mirrors the load core proven and security-reviewed on the
`variation-dat-loader` branch (`InsertVariationFeatures` /`VariationLoader`),
but is a much thinner loader: one input file, one target table, one derived
column. The organism/transcript/sequence-validation machinery from that branch
is deliberately **not** carried over.

## Target table

`ApiDB.GeneCoexpression`
(from `ApidbSchema/Main/lib/sql/apidbschema/Postgres/createGeneCoexpression.sql`):

| column                         | type          | notes                                         |
|--------------------------------|---------------|-----------------------------------------------|
| `gene_coexpression_id`         | NUMERIC(10)   | PK, `DEFAULT nextval('apidb.GeneCoexpression_sq')` — not in the copy list |
| `gene_id`                      | VARCHAR(50)   | NOT NULL, bare VARCHAR (no FK)                 |
| `associated_gene_id`           | VARCHAR(50)   | NOT NULL, bare VARCHAR (no FK)                 |
| `coefficient`                  | FLOAT8        | nullable in schema, but treated as required by this loader |
| `external_database_release_id` | NUMERIC(10)   | NOT NULL, FK → `sres.ExternalDatabaseRelease`, derived from `extDbRlsSpec` |

Indexes exist on `gene_id`, `associated_gene_id`, and
`external_database_release_id` (the last supports the reload delete).

## Input

A single tab-delimited file with a **header row**:

```
gene_id<TAB>associated_gene_id<TAB>coefficient
```

- The header is validated (3 columns, expected names) and skipped.
- Each data line has exactly 3 fields.
- `coefficient` is **always present**; a blank coefficient is a data error and
  the transform dies on it (schema permits NULL, but this dataset does not).

## Decisions (resolved during brainstorming)

1. **Header row:** present; validate and skip it.
2. **ID validation:** none. `gene_id`/`associated_gene_id` are trusted (the
   schema enforces nothing on them). No organism scoping, no `dots.GeneFeature`
   lookup.
3. **Code structure:** transform + column definitions live in a separate,
   DB-free, unit-testable library module (`GeneCoexpressionLoader.pm`), mirroring
   `VariationLoader.pm`.
4. **Reload/undo:** mirror the reference — the load deletes existing rows for
   this `external_database_release_id` first (restartable); undo via
   `undoPreprocess` recovering `extDbRlsSpec` from `core.AlgorithmParam`.
5. **Input shape:** a single `inputFile` argument (not a directory).
6. **Blank coefficient:** invalid input; transform dies.

## Components

### `Load/lib/perl/GeneCoexpressionLoader.pm` (pure, no DB)

Exports:

- `geneCoexpressionColumns()` — returns the canonical copy column order:
  `[ gene_id, associated_gene_id, coefficient, external_database_release_id ]`.
  `gene_coexpression_id` is intentionally omitted so the sequence default fills
  it.
- `transformGeneCoexpression($inFh, $outFh, $extDbRlsId)` — reads `$inFh`,
  validates + skips the header, and for each data line writes a tab-delimited
  output line with `$extDbRlsId` appended. Returns the row count.

Validation performed by the transform (all `die` on failure, with line numbers):
- empty file (missing header)
- header column count != 3, or unexpected header names
- data line field count != 3
- blank `coefficient`

The column list and the transform's output order are kept in lockstep; a unit
test asserts the count matches.

### `Load/plugin/perl/InsertGeneCoexpression.pm`

`package ApiCommonData::Load::Plugin::InsertGeneCoexpression`, ISA
`GUS::PluginMgr::Plugin`.

**Arguments:**
- `inputFile` — fileArg, `reqd`, `mustExist`, `format => 'file'`.
- `extDbRlsSpec` — stringArg, `reqd`, `name|version`.
- `targetSchema` — stringArg, optional, default `apidb`.

(`gusConfigFile` is provided by the plugin framework and is consumed by
`getPsqlConnection`, matching the reference.)

**`run()`:**
1. Resolve `extDbRlsId = getExtDbRlsId(extDbRlsSpec)`; error if unresolved.
2. `schema = validSchema(targetSchema)`.
3. Transform `inputFile` → temp file via `transformGeneCoexpression`.
4. `loadAll(schema, extDbRlsId, tmpFile)`.
5. Return a summary string with the loaded row count.

**Reused verbatim from `InsertVariationFeatures`** (proven / security-reviewed):
- `validSchema` — rejects any `targetSchema` that isn't a bare `\w+` identifier
  before it is interpolated into SQL.
- `getPsqlConnection` — parses host/port/dbname from the gus.config `dbiDsn`
  and honors an explicit `gusConfigFile`. NOTE: the port matters — the default
  config runs on 5433 while psql defaults to 5432, so an omitted port silently
  hits the wrong database. Carried over as-is from the reference.
- `copyCommand` — single-line `\copy <table> (<cols>) FROM '<file>' WITH
  (FORMAT CSV, DELIMITER E'\t', QUOTE '`', ENCODING 'UTF8')`.
- `loadAll` — writes a `load.sql`: `BEGIN;` →
  `DELETE FROM <schema>.GeneCoexpression WHERE external_database_release_id =
  <id>;` → the `\copy` → `COMMIT;`. Runs `psql -v ON_ERROR_STOP=1 -f load.sql`
  via list-form `system()` with `PGPASSWORD` in the child env; on non-zero exit
  it prints the psql log and errors (transaction rolled back, prior data
  intact).
- `printFile`.

**Undo:**
- `undoTables()` returns `()` (no `row_alg_invocation_id` on this table).
- `undoPreprocess($dbh, $rowAlgInvocationList)` — recovers `extDbRlsSpec` (and
  optional `targetSchema`, default `apidb`) from `core.AlgorithmParam` via
  `getAlgorithmParam`, resolves each spec to an
  `external_database_release_id`, and deletes matching
  `<schema>.GeneCoexpression` rows.

### Documentation block

`getDocumentation` fields:
- purpose: load gene coexpression pairs into `ApiDB.GeneCoexpression` in a single
  transaction.
- tablesAffected: `ApiDB.GeneCoexpression`.
- tablesDependedOn: `sres.ExternalDatabaseRelease`.
- howToRestart: re-run; the load deletes existing rows for this
  `external_database_release_id` first.
- failureCases: unresolvable `extDbRlsSpec`; malformed header; wrong field
  count; blank coefficient.

## Data flow

```
inputFile (gene_id, associated_gene_id, coefficient + header)
   │  transformGeneCoexpression(extDbRlsId)   [validate + skip header, append FK]
   ▼
tmpFile (gene_id, associated_gene_id, coefficient, external_database_release_id)
   │  loadAll → psql -f load.sql (single txn)
   ▼
DELETE existing rows for extDbRlsId → \copy tmpFile → COMMIT
```

## Error handling

- Unresolvable `extDbRlsSpec` → `$self->error` before any write.
- Malformed input (header/field-count/blank coefficient) → transform `die`,
  surfaced by the plugin before the load runs.
- Any psql failure → whole transaction rolls back; prior data for that
  `external_database_release_id` is untouched; the psql log is printed and the
  plugin errors.
- Failed flush/close of the temp file is detected (mirrors the reference's
  `transformFile` close-check) so a truncated temp file can't be silently
  loaded.

## Testing

- `Load/t/geneCoexpressionLoader.t` — unit tests against
  `GeneCoexpressionLoader` using in-memory filehandles:
  - column count matches `geneCoexpressionColumns`
  - header validated and skipped; extDbRlsId appended
  - dies on empty file, bad header, wrong field count, blank coefficient
- `Load/t/insertGeneCoexpression_integration.t` — env-gated (same pattern as
  `insertVariationFeatures_integration.t`) load into the `jbrestel` stub schema,
  asserting row counts and that reload replaces (not duplicates) rows for the
  same `external_database_release_id`.

## Deliberately out of scope (avoiding copy-paste debt)

From the reference, **not** carried over: `getTranscriptMap`,
`getGenomicSequenceIds`, `validateSequenceIds`, multi-file orchestration
(`transformFile` per-file loop), and the `organismAbbrev` argument.
