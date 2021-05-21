#!/usr/bin/Rscript
# Command line arguments for R are not fun... so to make this easy create the args
# by prepending them to this script directly before the R call:
# [bash]$ echo 'arg1 = "value";arg2="someValue"' |cat - script.r | R --no-save
# Variables dataFrame, inputDir, outputDir,  are required
args <- commandArgs(TRUE)

if (length(args) != 3) {
    print("Usage: DESeq.r <dataFrame> <inputDir> <outputDir> <outputFile>")
}

dataFrame <- args[1]
inputDir <- args[2]
outputDir <-args[3]
outputFile <-args[4]

#biocLite("DESeq2");
library(DESeq2);
df = read.delim(dataFrame, header = TRUE, sep = "\t");
ddsHTSeq <- DESeqDataSetFromHTSeqCount(sampleTable = df, directory =inputDir, design=~ condition);
ddsHTSeq$condition <-relevel(ddsHTSeq$condition, ref="reference");
ddsHTSeq <- estimateSizeFactors(ddsHTSeq);
ddsHTSeq <- tryCatch ({ 
    ddsHTSeq <- estimateDispersions(ddsHTSeq); 
    return (ddsHTSeq);
    },
    error = function(e) {
        ddsHTSeq <- estimateDispersionsGeneEst(ddsHTSeq);
        dispersions(ddsHTSeq) <- mcols(ddsHTSeq)$dispGeneEst;
        return (ddsHTSeq);
    }
)
ddsHTSeq<- nbinomWaldTest(ddsHTSeq);
res<-results(ddsHTSeq);

#can I do something like this for deseq2 so we only need one df for each experiment 
#res = nbinomTest( cds, condition2, condition1); #this bit needs sorting

#need to make this output relate to the display names etc 
fullOutFile = paste(outputDir, outputFile, sep="/");
write.csv( res, file=fullOutFile);



