m<-function(c1,c2,n1,n2) {
   matrix(c(c1,c2,n1-c1,n2-c2),nrow=2,byrow=F)
}

data <- as.matrix(read.table(inputFile, header=F))
p<-numeric()
for (i in 1:nrow(data)) {
   if ((data[i,1]/n1)>=(data[i,2]/n2)){
      p[i]<-fisher.test(m(data[i,1],data[i,2],n1,n2),alternative="greater")$p
   }
   else {
      p[i]<-fisher.test(m(data[i,1],data[i,2],n1,n2),alternative="less")$p
   }	
}
write.table(p, file=outputFile, col.names=F, row.names=F, sep="\t", eol="\n", quote=F)
