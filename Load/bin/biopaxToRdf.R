#!/usr/bin/Rscript

msg.trap <- capture.output(suppressMessages(library("rBiopaxParser")))

#suppresses warnings specific to BioCyc spec OWLs (caused by long comment fields) - does not affect output
options(warn=-1)

args <- commandArgs(TRUE)

if (length(args) != 2) {
    print("Usage: biopaxToRdf.R <inputFile> <path to output dir>\n Tabulated RDF file will be written to output dir.")
}

file <- args[1]
outputDir <- args[2]

sink(paste(outputDir, "log", sep="/"))

biopax2Rdf <- function (file, outputDir) {
    filePrefix <- strsplit(strsplit(file, "/")[[1]][length(strsplit(file, "/")[[1]])], "[.]")[[1]][1]
    fileName <- paste(paste(outputDir, filePrefix, sep="/"), ".rdf", sep="")
    biopax <- readBiopax(file)
    write.table(biopax$dt, fileName, sep="\t")
}

msg.trap <- capture.output(suppressMessages(invisible(biopax2Rdf(file, outputDir))))
