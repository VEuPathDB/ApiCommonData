#*******************************************************************************
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | absent
  # GUS4_STATUS | RAD.Analysis                   | auto   | absent
  # GUS4_STATUS | ApiDB.Profile                  | auto   | absent
  # GUS4_STATUS | Study.Study                    | auto   | absent
  # GUS4_STATUS | Dots.Isolate                   | auto   | absent
  # GUS4_STATUS | DeprecatedTables               | auto   | absent
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^
# Filename: PrepDataForPlasmoDB.R
# Author: 	Arlo Randall
# Date: 	2014-02-21
# Purpose:
#	Process raw ICEMR protein array data for upload to PlasmoDB.
# Notes:
#	The script expects specific column names in the input files and will crash
#	or produce unexpected results if these are not present. Also, the script expects
#	the first 12 columns of raw_intensity_data.csv to contain information about the
#	spots, with additional columns containing raw intensity data for samples.
#*******************************************************************************

# Read in sample information
sample.info.df <- read.csv("InputData/sample_information.csv", stringsAsFactors=FALSE, check.names=FALSE)

# Read in spot/protein informatino and intensity data
combined.data.df <- read.csv("InputData/raw_intensity_data.csv", stringsAsFactors=FALSE, check.names=FALSE)


# exclude reference samples
sample.info.df <- sample.info.df[sample.info.df$"Sample type" != "Reference",]

# extract intensity data for all samples
raw.intensity.data.df <- combined.data.df[, sample.info.df$Sample.ID]
spot.info.df <- combined.data.df[, 1:12]

# add unique spot id. ADI_ID is unique for protein spots, both noDNA
spot.info.df$Spot.ID <- paste(spot.info.df$ADI_ID, spot.info.df$Index, sep=".")
rownames(spot.info.df) <- spot.info.df$Spot.ID
rownames(raw.intensity.data.df) <- spot.info.df$Spot.ID

# identify usable IVTT protein ids. Leave out purified protein data
usable.spot.ids <- with(spot.info.df, Spot.ID[ADI_ID != "noDNA" & Protein.Type == "IVTT"])

# calculate median No DNA for each sample for normalization
# normalize by taking log2 and subtracting the median noDNA for each sample. This sets 0 point to the samples background reactivity
nodna.medians.by.sample <- apply(raw.intensity.data.df[spot.info.df$ADI_ID == "noDNA", ], 2, median, na.rm=TRUE)
raw.intensity.data.df[raw.intensity.data.df < 1] <- 1
norm.data.df <- as.data.frame(t(t(log2(raw.intensity.data.df[usable.spot.ids, ])) - log2(nodna.medians.by.sample)))
norm.data.df[norm.data.df < -2] <- -2

# account for multiple spots (exons & segments) mapping to the same PladmoDB ID by taking maximum value
id.freq.tab <- table(spot.info.df[usable.spot.ids, "PlasmoDB_ID"])
single.ids 	<- names(id.freq.tab)[id.freq.tab == 1]
all.single.spot.ids <- spot.info.df$Spot.ID[spot.info.df$PlasmoDB_ID %in% single.ids]
usable.single.spot.ids <- all.single.spot.ids[all.single.spot.ids %in% usable.spot.ids]
multi.ids 	<- names(id.freq.tab)[id.freq.tab > 1]


plasmodb.df <- norm.data.df[usable.single.spot.ids, ]
plasmodb.by.spot <- spot.info.df$PlasmoDB_ID
names(plasmodb.by.spot) <- spot.info.df$Spot.ID
rownames(plasmodb.df) <- plasmodb.by.spot[rownames(plasmodb.df)]

for(plasmodb.id in multi.ids) {
	pdb.spot.ids <- spot.info.df$Spot.ID[spot.info.df$PlasmoDB_ID == plasmodb.id]
	usable.pdb.spot.ids <- pdb.spot.ids[pdb.spot.ids %in% usable.spot.ids]
	multi.df <- norm.data.df[usable.pdb.spot.ids, ]
	max.df <- as.data.frame(t(apply(multi.df, 2, max, na.rm=TRUE)))	
	rownames(max.df) <- plasmodb.id
	plasmodb.df <- rbind(plasmodb.df, max.df)
}

# save the data as matrix with sample ids as columns and PlasmoDB ids as row names
write.csv(round(plasmodb.df, digits=3), "PlasmoDB_IntensityData.csv")
