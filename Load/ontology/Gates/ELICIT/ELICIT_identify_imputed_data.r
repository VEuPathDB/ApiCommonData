rm(list=ls())
setwd("~/Documents/Filezilla downloads")

d <- read.csv("ELICIT_data_for_PLOS_reshaped_v2.csv", as.is=T)

head(d)
temp <- d[,c("pid", "obs_number", "impute_mthr_height", "mthr_height")]
unique(temp$obs_number[!is.na(temp$impute_mthr_height)])
#[1] 0
unique(temp$obs_number[!is.na(temp$mthr_height)])
#[1] 0

temp <- d[d$obs_number==0,c("pid", "obs_number", "impute_mthr_height", "mthr_height")]
temp[temp$impute_mthr_height!=temp$mthr_height & !is.na(temp$impute_mthr_height) & !is.na(temp$mthr_height),]

length(temp$pid[is.na(temp$impute_mthr_height)])
#[1] 0

length(temp$pid[is.na(temp$mthr_height)])
#[1] 79

d$is_mthr_height_imputed <- NA
d$is_mthr_height_imputed[d$obs_number==0 & is.na(d$mthr_height)] <- "yes"
d$is_mthr_height_imputed[d$obs_number==0 & !is.na(d$mthr_height)] <- "no"

table(d[d$obs_number==0, "impute_mthr_height"], d[d$obs_number==0, "is_mthr_height_imputed"], useNA="ifany")
unique(d$impute_mthr_height[d$is_mthr_height_imputed=="yes" & !is.na(d$is_mthr_height_imputed)])
unique(d$is_mthr_height_imputed[d$impute_mthr_height==157.3236 & !is.na(d$impute_mthr_height)])


####

d$is_mthr_weight_imputed <- NA
d$is_mthr_weight_imputed[d$obs_number==0 & is.na(d$mthr_weight)] <- "yes"
d$is_mthr_weight_imputed[d$obs_number==0 & !is.na(d$mthr_weight)] <- "no"

table(d[d$obs_number==0, "impute_mthr_weight"], d[d$obs_number==0, "is_mthr_weight_imputed"], useNA="ifany")
unique(d$impute_mthr_weight[d$is_mthr_weight_imputed=="yes" & !is.na(d$is_mthr_weight_imputed)])
unique(d$is_mthr_weight_imputed[d$impute_mthr_weight==54.93949 & !is.na(d$impute_mthr_weight)])


####

write.csv(d, "ELICIT_data_for_PLOS_reshaped_v3.csv", row.names=F)
