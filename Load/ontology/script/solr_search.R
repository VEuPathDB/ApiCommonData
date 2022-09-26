##################################################
# Created date:	Aug 11, 2018
# Last modified:	Sept 25, 2022
# Author: 	Jie Zheng
##################################################

# Solr need to start as cloud mode

library(solrium)

##################################################
# Solr client connection and collection generation
##################################################

# change the path to where ApiCommonData/Load/ontology/script/ located in your machine
path <- "/Users/jiezheng/Documents/VEuPathDB-git/ApiCommonData/Load/ontology/script/"

# location of ontology term list csv file
csvFile <- paste0(path,"test/solr_search/solr_collection.csv") 

# read collection csv file
x <- read.csv(file=csvFile, head=TRUE, sep=",")

# connect: by default we connect to localhost, port 8983
cli <- SolrClient$new()

# create collection
if (!cli$collection_exists("clinEpiOntology")) {
	cli$collection_create(name = "clinEpiOntology")
}

# add document from file to solr collection
add(x, cli, "clinEpiOntology")

##################################################
# Loading file for searching
##################################################

# read data dictionary for search
# dataDictionaryFilename<-"/Users/swever/Desktop/clinEpi/solrSandbook/data/SHINE_conversion.csv"

dataDictionaryFilename <- paste0(path,"test/solr_search/dataDictionary_HUAS.csv")

dataDic <- read.csv(file = dataDictionaryFilename, head=TRUE, sep=",")

##################################################
# Solr searching against specific collection
##################################################

# go through the list, search in clinEpiOntology, and get top 10 found terms
rank <- 10

results <- cbind("variable","codebookDescription","suggested_IRI","suggested_label", "parent_in_ontology", "parent_IRI", "score")

for(i in 1:nrow(dataDic)) {
	var<-toString(dataDic$variable[i])
	desc<-toString(dataDic$codebookDescription[i])	
	var_str<-gsub("_", " ", trimws(var))
	term<-paste(trimws(var), trimws(desc))
	term<-gsub("_", " ", term)
	term<-gsub(":", " ", term)
	term<-gsub("/", " or ", term)
	term<-gsub("\\\"","", term)

	# search label, definition and variable fields
    	# searchStr <- (paste("label:(", term,") OR variable:", var_str, " OR definition:(", term,")", varsep=""))
 
 	# search label, and variable fields 
    	searchStr <- (paste0("label:(", trimws(term),") OR variable:", var_str))      
    	# print (searchStr)
	
	b <- cli$search(name = "clinEpiOntology", params = list(q = searchStr, fl=c('entity','label','score','parent_label','parent_IRI'), sort='score desc'), parsetype = "df", rows=rank)	
	a<- as.data.frame(b)
	
	if (nrow(a) != 0) {
		for (j in 1:nrow(a)) {
			if (!is.na(a[j,1])) results <- rbind(results, cbind(var, desc, a[j,1], a[j,2], a[j,3], a[j,4], a[j,5]))
		}
	} else {
		results <- rbind(results, cbind(var, desc, "", "","","",""))
	}	
}

results<-as.data.frame(results)

# write results in a file
outputFilename <- paste0(path,"test/solr_search/searchResults.csv") 

write.table(results, file = outputFilename, sep=",", col.names = FALSE, row.names=FALSE)
