# Command line arguments for R are not fun... so to make this easy create the args
# by prepending them to this script directly before the R call:  
# [bash]$ echo 'arg1 = "value";arg2="someValue"' |cat - script.r | R --no-save

# Variables inputFile and outputFile are required

# Simple Script to calculate the mean, standard deviation, standard error, rank, and percentile from a file

# The input file should be a tab del file with the first column being an identifier and NO HEADER !!!
# All columns after the first are considered to be data
# NA values are ignored

library(samr);

input=read.table(file=inputFile, header=TRUE, sep="\t", check.names=FALSE);

dat = as.matrix(input[,2:ncol(input)]);
header = as.integer(colnames(dat));

samIn = list(x=dat, y=header, geneid=as.character(input$id), genenames=as.character(input$id));

samr.obj = samr(samIn,  resp.type="Multiclass",  testStatistic=statistic, knn.neighbors=knnNeighbors, nperms=numPermutations);

deltaTable=samr.compute.delta.table(samr.obj, min.foldchange=0);

samOut = samr.compute.siggenes.table(samr.obj, 0, samIn, deltaTable);

write.table(samOut$genes.up, file=outputFile, quote=FALSE, sep="\t", row.names=F)

saveFile = paste(inputFile, ".RData", sep="");

save.image(saveFile);

