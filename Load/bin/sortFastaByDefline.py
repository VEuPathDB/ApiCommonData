import argparse
from Bio import SeqIO

# Set up argument parsing
parser = argparse.ArgumentParser(description="Sort a FASTA file by headers.")
parser.add_argument("input_fasta", help="Input FASTA file")
parser.add_argument("output_fasta", help="Output sorted FASTA file")
args = parser.parse_args()

# Read the input FASTA file
sequences = SeqIO.to_dict(SeqIO.parse(args.input_fasta, "fasta"))

# Sort sequences by headers (keys)
sorted_sequences = dict(sorted(sequences.items()))

# Write the sorted sequences to the output FASTA file
with open(args.output_fasta, "w") as output_handle:
    SeqIO.write(sorted_sequences.values(), output_handle, "fasta")

print(f"Sorted FASTA written to {args.output_fasta}")
