#' @title Calculate cropland footprints for all crop commodities and years
#' 
#' @description This function allocates the non-food commodities that where previously assigned to EXIOBASE sectors 
#' to final demand, thus calculating the footprint of countries.
#' 
#' @param years An integer vector specifying the years to be parsed. Default is 1995:2010.
#' 
#' @param nrreg An integer specifying the number of regions in the MRIO table. Default is 21.
#' 
#' @param nrsec An integer specifying the number of sectors or products in the MRIO table. Default is 200.
#' 
#' @param nrfd An integer specifying the number of final demand categories. Default is 7.
#' 
#' @param nrinput An integer specifying the number of input commodities allocated the MRIO model. Default is 17.
#' 
#' @param start An integer specifying at which position in the commodity list the livestock commodities start. Default is 18.
#' 
#' @param end An integer specifying at which position in the commodity list the livestock commodities end Default is 25.
#' 
#' @param land_type An integer specifying the land type considered. Choices: 3 = 1000 ha cropland; 4 = 1000 ha pasture land;
#' 5 = 1000 ha equiv. pasture land. Default is 3.
#' 
#' @param land_type_names A character vector giving the names of the 5 land types. Default is 
#' c("","","livestock_cropland","livestock_pastures","livestock_equ.pastures").
#' 
#' @return The function returns a data.frame with all footprint results in long format.
#' 
#' @author Martin Bruckner, \email{martin.bruckner@@wu.ac.at}
#' 
#' 

calculate_footprints_crop <- function(years = 1995:2010, nrreg = 21, nrsec = 200, nrfd = 7, nrinput = 25, start = 18, end = 25, land_type = 3, land_type_names = c("","","livestock_cropland","livestock_pastures","livestock_equ.pastures"), ...){

  library(openxlsx)
  library(reshape2)
  library(OpenMx)
  library(XLConnect)
  
  ID <- vector(mode="integer")
  for(regions in 1:nrreg)  ID <- c(ID,rep(regions,nrsec))
  
  
  ##########################################################################
  # Calculate Footprint
  ##########################################################################
  lvst <- land_type_names[land_type]
  if(land_type>3) end <- 21
  FP_all <- list()
  FP_year <- list()
  
  # year = 2010
  for(year in years){
    print(paste0("year ",year))
    # for the years 1990-1995 use the IO model for the year 1995
    yearIO <- year
    if(year<1995) yearIO <- 1995
    # load L and Y
    load(paste0("./output/exiobase/",year,"_extensions_",lvst,".RData"))
    load(paste0("./output/exiobase/",yearIO,"_L.RData"))
    load(paste0("./output/exiobase/",yearIO,"_Y.RData"))
    
    FP_final <- matrix(0, nrow=nrreg,ncol=nrinput+1)
    
    # region = 4
    for(region in 1:nrreg){
      Yreg <- rowSums(Y[,(nrfd*region-nrfd+1):(nrfd*region)])
      print(paste0("region ",region))
      
      # input = 18  # (18=Ruminant meat and offals)
      for(input in start:end){
        # Calculate Multiplier Matrix (Ext * LINV)
        # MP <- as.matrix(vec2diag(extensions[,input])) %*% as.matrix(L)
        # this one is faster and gives exactly the same results:
        MP <- extensions[,input] * as.matrix(L)
        # Calculate Footprint (MP * FD)
        FP <- as.data.frame(rowSums(t(t(MP) * Yreg)))
        # Aggregate FP
        FP$ID <- ID
        FP = aggregate(. ~ ID, data = FP, sum)
        FP_final[,input] <- as.matrix(FP[2])
      }
      # sum up all cropland footprints in additional column
      FP_final[,nrinput+1] <- .rowSums(X=FP_final,m=nrreg,n=nrinput)
      FP_year[[region]] <- FP_final
    }
    FP_all[[year]] <- FP_year
  }
  
  
  ##########################################################################
  # Rearrange and write results
  ##########################################################################
  all <- data.frame()
  
  for(year in years){
    #FP_all[[year]] 
    #FP_exp_all[[year]][[4]]
    print(paste0("year ",year))
    
    f <- melt(FP_all[[year]])
    c <- cast(f, X1 ~ L1 ~ X2)
    
    f$year <- year
    f$type <- 1
    
    load(file=paste0("./output/exiobase/",year,"_extensions_",lvst,".RData"))
    FD <- as.data.frame(FDextensions)
    colnames(FD) <- 1:nrinput
    FD <- melt(as.matrix(FD))
    FD$L1 <- FD$X1
    FD$year <- year
    FD$type <- 2
    FD_sum <- aggregate(. ~ X1, data = FD, sum)
    FD_sum$L1 <- FD_sum$X1
    FD_sum$X2 <- 18
    FD_sum$year <- year
    FD_sum$type <- 2
    FD <- rbind(FD,FD_sum)
    
    all <- rbind(all,f)
    all <- rbind(all,FD)
    
  }
  
  colnames(all) <- c("from","com","value","to","year","type")
  return(all)
}

