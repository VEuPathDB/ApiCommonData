#!/usr/bin/Rscript

library("rBiopaxParser")

#suppresses warnings specific to BioCyc spec OWLs (caused by long comment fields) - does not affect output
options(warn=-1)

args <- commandArgs(TRUE)

if (length(args) != 2) {
    print("Usage: biopaxToRdf.R <path to input dir> <path to output dir>\n Input dir contains biopax files for conversion (names in format *.biopax). Tabulated RDF files will be written to output dir.")
}

inputDir <- args[1]
outputDir <- args[2]

biopax2Rdf <- function (file, outputDir) {
    filePrefix <- strsplit(strsplit(file, "/")[[1]][length(strsplit(file, "/")[[1]])], "[.]")[[1]][1]
    fileName <- paste(paste(outputDir, filePrefix, sep="/"), ".rdf", sep="")
    biopax <- readBiopax(file)
    write.table(biopax$dt, fileName, sep="\t")
}


files <- list.files(path=inputDir, pattern="*.biopax$", full.names=T, recursive=FALSE)
invisible(lapply(files, biopax2Rdf, outputDir=outputDir))
