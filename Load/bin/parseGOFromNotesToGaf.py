import re
import sys
import argparse
from datetime import date

parser = argparse.ArgumentParser(
    description="Convert GO annotation note file to GAF 2.2 format.",
    formatter_class=argparse.RawTextHelpFormatter,
    epilog=(
        "Examples:\n"
        "  python3 parse_go_to_gaf.py --input myfile.txt --output out.gaf --assignBy GenBank\n"
        "  python3 parse_go_to_gaf.py --input myfile.txt --output out.gaf "
        "--assignBy GenBank --taxon 665912 --date 20150319"
    )
)
parser.add_argument("--input",    required=True,  help="Input tab-delimited note file")
parser.add_argument("--output",   required=True,  help="Output GAF file path")
parser.add_argument("--assignBy", required=True,  help="Assigned by (col 1 DB and col 15), e.g. GenBank")
parser.add_argument("--taxon",    default="",     help="NCBI Taxon ID, digits only (default: empty)")
parser.add_argument("--date",     default=date.today().strftime("%Y%m%d"),
                                                  help="Annotation date YYYYMMDD (default: today)")

# Print full usage on missing required arguments instead of terse error
try:
    args = parser.parse_args()
except SystemExit:
    parser.print_help()
    sys.exit(1)

INPUT  = args.input
OUTPUT = args.output

# GAF 2.2 aspect mapping
ASPECT = {
    "GO_component": "C",
    "GO_function":  "F",
    "GO_process":   "P",
}

DB             = args.assignBy
DB_OBJECT_TYPE = "protein"
TAXON          = f"taxon:{args.taxon}" if args.taxon else ""
ASSIGNED_BY    = args.assignBy
DATE           = args.date

def zero_pad(go_num):
    """Return zero-padded 7-digit GO ID string."""
    return "GO:" + go_num.zfill(7)

def parse_block(aspect_key, block_body):
    """
    Parse a single GO_xxx block body and return a list of annotation dicts.

    Formats encountered:
      1. GO:XXXX - term name
      2. GO:XXXX; with_term - term name [PMID YYY]
      3. GO:XXXX; with_term - term name [Evidence EEEEE] [PMID YYY]
      4. GO:XXXX; with_term - term name [Evidence EEEEE; extra ] [PMID YYY]
         where Evidence EEEEE is another GO ID used as With/From (col 8)
    """
    results = []

    # ---- Extract PMIDs (col 6) ----
    pmids = re.findall(r'\[PMID\s+(\d+)\]', block_body)

    # ---- Extract Evidence numbers → become With/From (col 8) ----
    with_from_ids = re.findall(r'\[Evidence\s+(\d+)', block_body)
    with_from_col = "|".join(zero_pad(e) for e in with_from_ids) if with_from_ids else ""

    # Evidence code: ISS when PMID present, IEA otherwise
    ev_code = "ISS" if pmids else "IEA"

    # DB:Reference (col 6)
    db_ref = "|".join(f"PMID:{p}" for p in pmids) if pmids else "GO_REF:0000002"

    # ---- Find ALL GO IDs in the block (strip bracketed sections first) ----
    clean = re.sub(r'\[.*?\]', '', block_body)
    go_entries = re.findall(r'GO:(\d+)', clean)

    if not go_entries:
        return results

    # ---- Extract term name ----
    # Format A: "GO:XXXX; with_phrase - term_name"  → keep full "with_phrase - term_name"
    # Format B: "GO:XXXX - term_name"               → keep "term_name" only
    name = ""
    semi_match = re.search(r'GO:\d+\s*;\s*(.+)', clean)
    dash_match  = re.search(r'GO:\d+\s+-\s*(.+)', clean)
    if semi_match:
        raw_name = semi_match.group(1).strip()
        raw_name = re.sub(r'\s*[\[;].*', '', raw_name).strip()
        name = raw_name
    elif dash_match:
        raw_name = dash_match.group(1).strip()
        raw_name = re.sub(r'\s*[\[;].*', '', raw_name).strip()
        name = raw_name

    for go_num in go_entries:
        results.append({
            "aspect":    ASPECT.get(aspect_key, "U"),
            "go_id":     zero_pad(go_num),
            "go_name":   name,
            "db_ref":    db_ref,
            "ev_code":   ev_code,
            "with_from": with_from_col,
        })

    return results


def parse_annotation(annot_str):
    """Split full annotation string into GO blocks and parse each."""
    all_terms = []
    blocks = re.split(r'(?=GO_(?:component|function|process):)', annot_str)
    for block in blocks:
        block = block.strip().rstrip(';').strip()
        m = re.match(r'(GO_component|GO_function|GO_process):\s*(.*)', block, re.DOTALL)
        if not m:
            continue
        all_terms.extend(parse_block(m.group(1), m.group(2).strip()))
    return all_terms


lines_written = 0

with open(INPUT) as fh, open(OUTPUT, "w") as out:
    out.write("!gaf-version: 2.2\n")
    out.write(f"!Generated: {DATE}\n")
#    out.write(f"!Source: {INPUT}\n")
#    out.write("!\n")

    for line in fh:
        line = line.rstrip("\n")
        if not line.strip():
            continue
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        gene_id   = parts[0].strip()
        annot_str = parts[1].strip()

        if annot_str.startswith("Anticodon"):
            continue
        if "GO:" not in annot_str:
            continue

        for t in parse_annotation(annot_str):
            cols = [
                DB,                  # 1  DB
                gene_id,             # 2  DB Object ID
                gene_id,             # 3  DB Object Symbol
                "",                  # 4  Qualifier
                t["go_id"],          # 5  GO ID
                t["db_ref"],         # 6  DB:Reference
                t["ev_code"],        # 7  Evidence Code
                t["with_from"],      # 8  With/From
                t["aspect"],         # 9  Aspect
                t["go_name"],        # 10 DB Object Name
                "",                  # 11 DB Object Synonym
                DB_OBJECT_TYPE,      # 12 DB Object Type
                TAXON,               # 13 Taxon
                DATE,                # 14 Date
                ASSIGNED_BY,         # 15 Assigned By
                "",                  # 16 Annotation Extension
                "",                  # 17 Gene Product Form ID
            ]
            out.write("\t".join(cols) + "\n")
            lines_written += 1

print(f"Done. {lines_written} GAF annotation lines written to {OUTPUT}")
