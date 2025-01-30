#!/bin/bash

# bowtie2 realignment script for unmapped mated reads

# Pregrequisites:
# samtools (v1.16)
# bowtie2  (v2.5.1)
# pigz     (v2.4)

####################################################################################################

# Set -eu to exit on unset variables and errors
set -eu

# Check for required arguments
if [[ $# -ne 4  ]]; then
  echo "Usage: $0 <reference_genome_prefix> <input_bam_prefix> <sample_name> <output_fastq_gz_prefix>" >&2
  exit 1
fi

# Input parameters
R="$1"  # Reference bowtie2 index prefix 
I="$2"  # Input bam file prefix
S="$3"  # Sample name
O="$4"  # Output fq.gz prefix
P=8     # Number of threads

# Test files (more informative error messages)
if [[ ! -s "$R.1.bt2" ]]; then
  echo "Error: Bowtie2 index file $R.1.bt2 not found or empty." >&2
  exit 1
fi

if [[ ! -s "$I.bam" ]]; then
  echo "Error: Input BAM file $I.bam not found or empty." >&2
  exit 1
fi

samtools quickcheck "$I.bam"
if [[ $? -ne 0 ]]; then
  echo "Error: Input BAM file $I.bam failed samtools quickcheck." >&2
  exit 1
fi

# Check if output files already exist (optional - depends on desired behavior)
if [[ -f "$O.1.fq.gz" && -f "$O.2.fq.gz" ]]; then
  echo "Output files $O.1.fq.gz and $O.2.fq.gz already exist. Skipping."
  exit 0 # Or exit 1 to force re-generation
fi

####################################################################################################

# Main processing pipeline (improved and more readable)
samtools view -f 0xC -@ "$P" -bu "$I.bam" | \
  samtools fastq -@ "$P" | \
  bowtie2 --interleaved /dev/stdin -x "$R" -p "$P" --rg "ID:$S" --rg "SM:$S" --rg-id "$S" | \
  samtools view -f 0xC -@ "$P" -bu | \
  samtools fastq -@ "$P" | \
  tee >(perl -ne 'print if(($.-1)%8<4)' | pigz -p "$P" -c > "$O.1.fq.gz") >(perl -ne 'print if(($.-1)%8>=4)' | pigz -p "$P" -c > "$O.2.fq.gz") > /dev/null

echo "Finished processing." # Indicate success
