#!/usr/bin/Rscript
# Command line arguments for R are not fun... so to make this easy create the args
# by prepending them to this script directly before the R call:
# [bash]$ echo 'arg1 = "value";arg2="someValue"' |cat - script.r | R --no-save
# Variables dataFrame, inputDir, outputDir,  are required
args <- commandArgs(TRUE)

if (length(args) != 3) {
    print("Usage: DESeq.r <refFile> <compFile> <outputDir> <refName> <compName>")
}

refFile <- args[1]
compFile <- args[2]
outputDir <-args[3]
refName <- args[4]
compName <- args[5]

#biocLite("DESeq2");
library(DEGseq);


geneExpMatrix1 <- readGeneExp(file=refFile, geneCol=1, valCol=2);
geneExpMatrix2 <- readGeneExp(file=compFile, geneCol=1, valCol=2);
layout(matrix(c(1,2,3,4,5,6), 3, 2, byrow=TRUE));
par(mar=c(2, 2, 2, 2));
DEGexp(geneExpMatrix1=geneExpMatrix1, geneCol1=1, expCol1=2, groupLabel1=refName,
geneExpMatrix2=geneExpMatrix2, geneCol2=1, expCol2=2, groupLabel2=compName,
method="MARS", outputDir= outputDir);




