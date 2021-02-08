rm(list=ls())
setwd("~/Documents/GitHub/ApiCommonData/Load/ontology/Gates/GEMS/doc")
list.files()

gems <- read.csv("./GEMS_conversion.csv", as.is=T)

head(gems)
gems$label[grep("[)]$", gems$label)]

gems$units <- ""
gems$units[grep("[)]$", gems$label)] <- gems$label[grep("[)]$", gems$label)]
gems$label[grep("[)]$", gems$label)] <- gsub(" [(].+[)]$", "", gems$label[grep("[)]$", gems$label)])
gems$label[gems$units %in% c("Not applicable (none observed)", "Pour (spigot or spout)", "Bought (tank, bottle, etc)", "Telephone (mobile or non-mobile)")] <- 
  c("Not applicable (none observed)", "Pour (spigot or spout)", "Bought (tank, bottle, etc)", "Telephone (mobile or non-mobile)")
gems$units[gems$units %in% c("Not applicable (none observed)", "Pour (spigot or spout)", "Bought (tank, bottle, etc)", "Telephone (mobile or non-mobile)")] <- ""
gems[gems$units!="",c("label", "units")]  
gems$units <- gsub("[)]$", "", gsub("^.+[(]", "", gems$units))

table(gems$termType)
gems[gems$category %in% c("category", "multifilter")==F, c("label", "units")]
gems$units[gems$label==" BMI, using median length or height"] <- "kg/m2"

gems$units[grep("height [(]", tolower(gems$label))] <- "cm"
gems$label[grep("height [(]", tolower(gems$label))] <- gsub(" [(]cm[)]", "", gems$label[grep("height [(]", tolower(gems$label))])

gems$units[grep("muac [(]", tolower(gems$label))] <- "cm"
gems$label[grep("muac [(]", tolower(gems$label))] <- gsub(" [(]cm[)]", "", gems$label[grep("muac [(]", tolower(gems$label))])

gems$units[grep("amount.+earnings", tolower(gems$label))] <- "amount" 
gems$label[grep("amount.+earnings", tolower(gems$label))] <- c("Earnings lost due to care", "Other lost earnings") 

gems$units[grep("amount paid", tolower(gems$label))] <- "amount"
gems$label[grep("amount paid", tolower(gems$label))] <- gsub("Amount paid", "Payment", gems$label[grep("amount paid", tolower(gems$label))])

gems$units[grep("days lost", tolower(gems$label))] <- "days"
gems$label[grep("days lost", tolower(gems$label))] <- gsub("days ", "", gems$units[grep("days lost", tolower(gems$label))])

gems$units[grep("max ", tolower(gems$label))] <- "count"

gems$units[grep("breaths/min", tolower(gems$label))] <- "breaths/min"
gems$label[grep("breaths/min", tolower(gems$label))] <- gsub(" [(]breaths/min[)]", "", gems$label[grep("breaths/min", tolower(gems$label))])

gems[grep("expenses", tolower(gems$label)), c("label", "parentLabel")]
gems$units[gems$parentLabel=="Previously sought care expenses"] <- "amount"
gems$units[gems$parentLabel=="Hospitalization or clinical visit expenses"] <- "amount"
gems$units[gems$parentLabel=="Hospitalization or clinical visit expenses"] <- "amount"

gems$units[gems$label=="Lost earnings due to care"]<- "amount"
gems$units[gems$label=="Age group"]<- "months"

write.csv(gems, file="./GEMS_conversion_uits.csv", row.names=F)

gems2<- read.csv("./GEMS_conversion_uits.csv", as.is=T)

for(i in unique(gems2$IRI)){
  gems2$old_label[gems2$IRI==i] <- gems$label[gems$IRI==i]
  print(i)
}

gems2[gems2$label!=gems2$old_label,c("label", "old_label", "IRI")]
write.csv(gems2, file="./GEMS_conversion_uits.csv", row.names=F)


