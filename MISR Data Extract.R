##############################################
# MISR 2008-2009 4.4km AOD and fractions 
# AQS Daily http://www.epa.gov/airdata/ad_data_daily.html
# Aeronet data http://aeronet.gsfc.nasa.gov/
# ICV data (CHS study)
# December 2014, February-June 2015
# Meredith Franklin
##############################################

library(ncdf) # for reading netcdf file formats
library(date) # for converting julian dates
library(chron) # for converting julian dates
library(lubridate) # for date interval matching
library(plyr) # for easy merging/subsetting
library(dplyr) #for easy merging/subsetting
library(sas7bdat) # for reading SAS file formats
library(fields) # for spatial functions
library(proj4) # for map projections
library(R.utils) # decompressing NCDC data



#### Geographic projection for California applied to all lat/lon ####
proj.albers<-"+proj=aea +lat_1=34.0 +lat_2=40.5 +lon_0=-120.0 +x_0=0 +y_0=-4000000 +ellps=GRS80 +datum=NAD83 +units=km"

###### MISR NetCDF ######
# Create list of filenames in directory
setwd("/Users/mf/Documents/MISR/Data")
misr.files <- list.files("./",pattern="*_LM_4p4km*",full.names=FALSE)

# Extract data from netcdf: use RegBestEstimate for AOD, use RegLowestResid for fractions and SS albedo
misr.list<-vector('list',length(misr.files))
  for(i in 1:length(misr.files)) { 
    dat<-open.ncdf(misr.files[i])
    lat<-get.var.ncdf(dat, "Latitude")
    lon<-get.var.ncdf(dat, "Longitude")
    julian<-get.var.ncdf(dat, "Julian")
    AOD<-get.var.ncdf(dat,"RegBestEstimateSpectralOptDepth")
    AODsmallfrac<-get.var.ncdf(dat,"RegLowestResidSpectralOptDepthFraction_Small")
    AODmedfrac<-get.var.ncdf(dat,"RegLowestResidSpectralOptDepthFraction_Medium")
    AODlargefrac<-get.var.ncdf(dat,"RegLowestResidSpectralOptDepthFraction_Large")
    AODnonspher<-get.var.ncdf(dat,"RegLowestResidSpectralOptDepthFraction_Nonsphere")
    SSAlbedo<-get.var.ncdf(dat,"RegLowestResidSpectralSSA")
    land.water.mask<-get.var.ncdf(dat,"AlgTypeFlag")#land=3 water=1
    AOD.dat<-data.frame(lat=lat,lon=lon,julian=julian,AOD=AOD,AODsmallfrac=AODsmallfrac,AODmedfrac=AODmedfrac,
                        AODlargefrac=AODlargefrac,AODnonspher=AODnonspher,SSAlbedo=SSAlbedo,land.water.mask=land.water.mask)
    misr.list[[i]]<-AOD.dat
}
misr.08.09<-do.call("rbind", misr.list)

# Convert Julian dates, create month day year variables for matching with surface measures
misr.08.09$date<-dates(misr.08.09$julian, origin=c(month=11, day=24, year= -4713))
misr.08.09$date2<-mdy(misr.08.09$date)
date<-strsplit(as.character(misr.08.09$date),"/")
misr.08.09$month<-as.numeric(sapply(date, "[[", 1) )
misr.08.09$day<-as.numeric(sapply(date,"[[",2))
misr.08.09$year<-as.numeric(sapply(date,"[[",3))+2000

# multiply fraction by AOD to get AODsmall, AODmed, AODlarge
misr.08.09$AODsmall<-misr.08.09$AODsmallfrac*misr.08.09$AOD
misr.08.09$AODmed<-misr.08.09$AODmedfrac*misr.08.09$AOD
misr.08.09$AODlarge<-misr.08.09$AODlargefrac*misr.08.09$AOD

# Convert lat and lon into planar x and y (California projection)
newcoords.misr<-project(as.matrix(cbind(misr.08.09$lon, misr.08.09$lat)), proj=proj.albers)
misr.08.09$x<-newcoords.misr[,1]
misr.08.09$y<-newcoords.misr[,2]

# Write (read) csv
#write.csv(misr.08.09,"misr.08.09.csv",row.names=FALSE)
misr.08.09<-read.csv("/Users/mf/Documents/MISR/Data/misr.08.09.csv")


##### Daily AQS PM25 data ######
setwd("/Users/mf/Documents/AQS/PM25")
aqs.files <- list.files("./",pattern="CA_PM25*",full.names=FALSE)

# Extract data for CA then subset
aqs.list<-vector('list',length(aqs.files))
for(i in 1:length(aqs.files)) { 
  dat<-read.csv(aqs.files[i],stringsAsFactors=FALSE)
# separate m/d/y from Date
  date<-strsplit(dat$Date,"/")
  dat$month<-as.numeric(sapply(date, "[[", 1) )
  dat$day<-as.numeric(sapply(date,"[[",2))
  dat$year<-as.numeric(sapply(date,"[[",3))+2000
  dat<-dat[,c(-10:-13)]
# reading national .txt files (no geographic reference)  
  #header<-read.table(aqs.files[i],sep="|",header=TRUE,row.names=NULL,
  #                   check.names=FALSE,nrows=2,skip=1,comment.char="")
  #colnames(dat)<-names(header)
  #dat<-cbind(read.fwf(file = textConnection(as.character(dat$Year)), 
  #               widths = c(4, 2, 3), colClasses = "character", 
  #               col.names = c("year2", "month", "day")),dat)
  aqs.list[[i]]<-dat
}

AQS.08.09 <- do.call("rbind", aqs.list) 

# Convert lat and lon into planar x and y (California projection)
newcoords.aqs<-project(as.matrix(cbind(AQS.08.09$SITE_LONGITUDE, AQS.08.09$SITE_LATITUDE)), proj=proj.albers)
AQS.08.09$x<-newcoords.aqs[,1]
AQS.08.09$y<-newcoords.aqs[,2]

# Subset AQS data around LA area for this study
AQS.08.09.ss<-AQS.08.09[AQS.08.09$SITE_LONGITUDE>=-120 & AQS.08.09$SITE_LONGITUDE<= -117,]
AQS.08.09.ss<-AQS.08.09.ss[AQS.08.09.ss$SITE_LATITUDE>=33.2 & AQS.08.09.ss$SITE_LATITUDE<=35,]
AQS.08.09.ss<-AQS.08.09.ss[AQS.08.09.ss$SITE_LONGITUDE != -119.4869,] #Remove Catalina

# Use only the POC=1 (FRM) monitors
# Retain only FRM daily data (exclude hourly and STN PM25)
AQS.08.09.ss2<-AQS.08.09.ss[AQS.08.09.ss$POC==1,]
AQS.08.09.ss2<-AQS.08.09.ss2[AQS.08.09.ss2$AQS_PARAMETER_CODE==88101,]
AQS.08.09.ss2$date2<- mdy(AQS.08.09.ss2$Date) #use lubridate function for date matching (ICV)

# Write (read) .csv
#write.csv(AQS.08.09.ss2,"/Users/mf/Documents/MISR/Data/AQS.08.09.ss.FRM.csv",row.names=FALSE)
#write.csv(AQS.08.09.ss,"/Users/mf/Documents/MISR/Data/AQS.08.09.ss.csv",row.names=FALSE)
#write.csv(AQS.08.09,"/Users/mf/Documents/MISR/Data/AQS.08.09.csv",row.names=FALSE)
#AQS.08.09.ss<-read.csv("/Users/mf/Documents/MISR/Data/AQS.08.09.ss.csv")


##### Daily AQS PM10 data ######
setwd("/Users/mf/Documents/AQS/PM10")
aqs.files <- list.files("./",pattern="AQS*",full.names=FALSE)

# Extract data
aqs.list<-vector('list',length(aqs.files))
for(i in 1:length(aqs.files)) { 
  dat<-read.csv(aqs.files[i],stringsAsFactors=FALSE)
  # separate m/d/y from Date
  dat$date2<-parse_date_time(dat$Date,"mdy")
  date<-strsplit(dat$Date,"/")
  dat$month<-as.numeric(sapply(date, "[[", 1) )
  dat$day<-as.numeric(sapply(date,"[[",2))
  dat$year<-as.numeric(sapply(date,"[[",3))
  #dat<-dat[,c(-10:-14)]
  # reading national .txt files (no geographic reference)  
  #header<-read.table(aqs.files[i],sep="|",header=TRUE,row.names=NULL,
  #                   check.names=FALSE,nrows=2,skip=1,comment.char="")
  #colnames(dat)<-names(header)
  #dat<-cbind(read.fwf(file = textConnection(as.character(dat$Year)), 
  #               widths = c(4, 2, 3), colClasses = "character", 
  #               col.names = c("year2", "month", "day")),dat)
  aqs.list[[i]]<-dat
}

AQS.PM10.08.09 <- do.call("rbind", aqs.list) 

# Convert lat and lon into planar x and y (California projection)
newcoords.aqs<-project(as.matrix(cbind(AQS.PM10.08.09$SITE_LONGITUDE, AQS.PM10.08.09$SITE_LATITUDE)), proj=proj.albers)
AQS.PM10.08.09$x<-newcoords.aqs[,1]
AQS.PM10.08.09$y<-newcoords.aqs[,2]

AQS.PM10.08.09.ss<-AQS.PM10.08.09[AQS.PM10.08.09$POC==1,]
AQS.PM10.08.09.ss<-AQS.PM10.08.09.ss[AQS.PM10.08.09.ss$SITE_LONGITUDE>=-120 & AQS.PM10.08.09.ss$SITE_LONGITUDE<= -117,]
AQS.PM10.08.09.ss<-AQS.PM10.08.09.ss[AQS.PM10.08.09.ss$SITE_LATITUDE>=33.2 & AQS.PM10.08.09.ss$SITE_LATITUDE<=35,]
AQS.PM10.08.09.ss<-AQS.PM10.08.09.ss[AQS.PM10.08.09.ss$SITE_LONGITUDE != -119.4869,] #Remove Catalina
AQS.PM10.08.09.ss<-AQS.PM10.08.09.ss[,c(-3,-5:-14)]
write.csv(AQS.PM10.08.09.ss,"/Users/mf/Documents/MISR/Data/AQS.PM10.FRM.08.09.ss",row.names=FALSE)

#### EPA STN data (1 in 3 or 1 in 6 days) #####
# Parameter codes for species EC=88307 OC=88305, sulfate=88403, nitrate=88306, PM25=88502
setwd("/Users/mf/Documents/AQS/STN")
stn.files <- list.files("./",pattern="RD_501_SPEC_.*.csv",full.names=FALSE)
# Extract data
stn.list<-vector('list',length(stn.files))
for(i in 1:length(stn.files)) { 
  dat<-read.csv(stn.files[i],stringsAsFactors=FALSE)
  dat$StateCode<-as.numeric(dat$StateCode)
  #dat$CountyCode<-as.numeric(dat$CountyCode)
  #dat$SiteID<-as.numeric(dat$SiteID)
  dat$POC<-as.numeric(dat$POC)
  dat$Concentration<-as.numeric(dat$Concentration)
  dat<-dat[dat$StateCode==6 & dat$POC==5 & dat$Parameter>88000,] #Subset to CA and STN sites (remove POC 6)

  # separate m/d/y from Date
  dat$date2<-parse_date_time(dat$Date,"ymd")
  #dat$year<-as.numeric(substr(dat$Date,1,4))
  #dat$month<-as.numeric(substr(dat$Date,5,6))
  #dat$day<-as.numeric(substr(dat$Date,7,8))
  
  PM25stn<-dat[dat$Parameter==88502,c(3:4,12,28)]
  PM25stn<-rename(PM25stn, PM25=Concentration)
  #PM25stn<-PM25stn[with(PM25stn,order(CountyCode, SiteID, month, day, year)),]
  PM25stn<-PM25stn[!duplicated(PM25stn),]
  
  EC<-dat[dat$Parameter==88307,c(3:4,12,28)]
  EC<-rename(EC, EC=Concentration)
  EC<-EC[!duplicated(EC),]
  
  OC<-dat[dat$Parameter==88305,c(3:4,12,28)]
  OC<-rename(OC, OC=Concentration)
  OC<-OC[!duplicated(OC),]
  
  NH4<-dat[dat$Parameter==88306,c(3:4,12,28)]
  NH4<-rename(NH4, NH4=Concentration)
  NH4<-NH4[!duplicated(NH4),]
  
  SO4<-dat[dat$Parameter==88403,c(3:4,12,28)]
  SO4<-rename(SO4, SO4=Concentration)
  SO4<-SO4[!duplicated(SO4),]
  
  join1<-join(EC, OC, by=c("CountyCode","SiteID","date2"))
  join2<-join(join1,NH4, by=c('CountyCode','SiteID','date2'))
  join3<-join(join2,SO4, by=c('CountyCode','SiteID','date2'))
  join4<-join(join3,PM25stn, by=c('CountyCode','SiteID','date2'))
  # reading national .txt files (no geographic reference)  
 
  stn.list[[i]]<-join4
}

STN.08.09 <- do.call("rbind", stn.list) 
STN.08.09<-STN.08.09[with(STN.08.09,order(CountyCode, SiteID, date2)),]
STN.08.09$SiteID<-ifelse(STN.08.09$CountyCode==19 & STN.08.09$SiteID==8, 11, STN.08.09$SiteID)
# STN site info
STN.site.info<-read.csv("STNSiteInfo.csv")
STN.site.CA<-STN.site.info[STN.site.info$StateCode==6,]
# Find out where site 6-19-8 is located. Note used coordinates for Fresno 6-9-11 site (same county)
STN.08.09.all<-join(STN.08.09,STN.site.CA, by=c('CountyCode','SiteID'))

proj.albers<-"+proj=aea +lat_1=34.0 +lat_2=40.5 +lon_0=-120.0 +x_0=0 +y_0=-4000000 +ellps=GRS80 +datum=NAD83 +units=km"
newcoords.stn<-project(as.matrix(cbind(STN.08.09.all$Longitude, STN.08.09.all$Latitude)), proj=proj.albers)
STN.08.09.all$x<-newcoords.stn[,1]
STN.08.09.all$y<-newcoords.stn[,2]

STN.08.09.ss<-STN.08.09.all[STN.08.09.all$Latitude>=33.599,]
STN.08.09.ss<-STN.08.09.ss[STN.08.09.ss$Latitude<=35,]


#write.csv(STN.08.09.ss,"STN.08.09.ss.csv",row.names=FALSE)
STN.08.09.ss<-read.csv("/Users/mf/Documents/AQS/STN/STN.08.09.ss.csv")

##### Daily NCDC data #####
# Station Information
#file <- "ftp://ftp.ncdc.noaa.gov/pub/data/noaa/isd-history.csv"
#download.file(file, "isd-history.csv")
setwd("/Users/mf/Documents/NCDC/")
stations <- read.csv("isd-history.csv") 
st.ca<-stations[stations$CTRY=="US" & stations$STATE=="CA",]
st.ca$BEGIN <- as.numeric(substr(st.ca$BEGIN, 1, 4))
st.ca$END <- as.numeric(substr(st.ca$END, 1, 4))

st.so.ca<-st.ca[st.ca$LAT>=33.2 & st.ca$LAT<=35,]
st.so.ca<-st.so.ca[st.so.ca$LON>= -120 & st.so.ca$LON<= -117,]
# Remove Catalina and buoys
st.so.ca<-st.so.ca[-(grep(c("BUOY|CATALINA|ISLAND"),st.so.ca$STATION.NAME)),]
st.so.ca<-st.so.ca[complete.cases(st.so.ca),]
# write.csv(st.so.ca,"/Users/mf/Documents/NCDC/SoCalNCDCsites.csv",row.names = FALSE)
# st.so.ca<-read.csv("/Users/mf/Documents/NCDC/SoCalNCDCsites.csv")

for (y in 2008:2009){
  y.la.list<-st.so.ca[st.so.ca$BEGIN<=y & st.so.ca$END>=y,]
  for (s in 1:dim(y.la.list)[1]){
    filename<-paste(sprintf("%06d",y.la.list[s,1]),"-",sprintf("%05d",y.la.list[s,2]),"-",y,".gz",sep="")
    download.file(paste("ftp://ftp.ncdc.noaa.gov/pub/data/noaa/", y,"/",filename,sep=""), paste("/Users/mf/Documents/NCDC/SoCal Met/",filename,sep=""), method='wget') 
    }

  files.gz <- list.files("./SoCal Met",full.names=TRUE,pattern=".gz")
      for(i in 1:length(files.gz)){
       gunzip(files.gz[[i]],overwrite=TRUE)
    }
# Extract data from downloaded files
  # Need to define column widths, see ftp://ftp.ncdc.noaa.gov/pub/data/noaa/ish-format-document.pdf
  column.widths <- c(4, 6, 5, 4, 2, 2, 2, 2, 1, 6, 7, 5, 5, 5, 4, 3, 1, 1, 4, 1, 5, 1, 1, 1, 6, 1, 1, 1, 5, 1, 5, 1, 5, 1)
#stations <- as.data.frame(matrix(NA, length(files.gz),))
#names(stations) <- c("USAFID", "WBAN", "YR", "LAT","LONG", "ELEV")

  met.files <- list.files("./SoCal Met",full.names=TRUE,include.dirs = FALSE, recursive=FALSE)
  met.list<-vector('list',length(met.files))
    for (i in 1:length(met.files)) {
      if (file.info(met.files[i])$size>0){
      met.data <- read.fwf(met.files[i], column.widths)
  #data <- data[, c(2:8, 10:11, 13, 16, 19, 29,31, 33)]
      names(met.data) <- c("ID","USAFID", "WBAN", "year", "month","day", "hour", "min","srcflag", "lat", "lon",
                    "typecode","elev","callid","qcname","wind.dir", "wind.dir.qc","wind.type.code","wind.sp","wind.sp.qc",
                        "ceiling.ht","ceiling.ht.qc","ceiling.ht.method","sky.cond","vis.dist","vis.dist.qc","vis.var","vis.var.qc",
                            "temp","temp.qc", "dew.point","dew.point.qc","atm.press","atm.press.qc")
  # change 9999 to missing
      met.data$wind.dir<-ifelse(met.data$wind.dir==999,NA,met.data$wind.dir)
      met.data$wind.sp<-ifelse(met.data$wind.sp==9999,NA,met.data$wind.sp)
      met.data$ceiling.ht<-ifelse(met.data$ceiling.ht==99999,NA,met.data$ceiling.ht)
      met.data$vis.dist<-ifelse(met.data$vis.dist==999999,NA,met.data$vis.dist)
      met.data$temp<-ifelse(met.data$temp==9999,NA,met.data$temp)
      met.data$dew.point<-ifelse(met.data$dew.point==9999,NA,met.data$dew.point)
      met.data$atm.press<-ifelse(met.data$atm.press==99999,NA,met.data$atm.press)
  
  # conversions and scaling factors
      met.data$lat <- met.data$lat/1000
      met.data$lon <- met.data$lon/1000
      met.data$wind.sp <- met.data$wind.sp/10
      met.data$temp <- met.data$temp/10
      met.data$dew.point <- met.data$dew.point/10
      met.data$atm.press<- met.data$atm.press/10
  #drop some variables
      met.data<-subset(met.data, select=-c(ID,srcflag,typecode,callid,qcname))
  # take average of hours matching MISR overpass time
      met.data.misr.hrs<-met.data[met.data$hour %in% c(10,11,12),]
      met.data.misr.avg<- ddply(met.data.misr.hrs, .(month, day, year,lat,lon,USAFID,elev), summarise, temp=mean(temp,na.rm=TRUE),
                            dew.point=mean(dew.point,rm=TRUE), ceiling.ht=mean(ceiling.ht,na.rm=TRUE), wind.dir=mean(wind.dir,na.rm=TRUE),
                              wind.sp=mean(wind.sp,na.rm=TRUE), atm.press=mean(atm.press,na.rm=TRUE))

      met.list[[i]]<-met.data.misr.avg
    }
  else{ print("Zero file")
    }
}
}
met.08.09 <- do.call("rbind", met.list) 
# add projected coordinates
proj.albers<-"+proj=aea +lat_1=34.0 +lat_2=40.5 +lon_0=-120.0 +x_0=0 +y_0=-4000000 +ellps=GRS80 +datum=NAD83 +units=km"
newcoords.met<-project(as.matrix(cbind(met.08.09$lon, met.08.09$lat)), proj=proj.albers)
met.08.09$x<-newcoords.met[,1]
met.08.09$y<-newcoords.met[,2]

#write.csv(met.08.09,"/Users/mf/Documents/MISR/Data/met.08.09.csv",row.names=FALSE)
met.08.09<-read.csv("/Users/mf/Documents/MISR/Data/met.08.09.csv")
met.08.09<-met.08.09[,-1]

# match MISR, AQS and STN by date and distance
# Take unique dates from MISR file
#misr.days<-misr.08.09 %>% distinct(round(julian,digits=0))
misr.days<-misr.08.09 %>% distinct(date2)
MISR.AQS.match.all<-vector('list',length(misr.days$date))
MISR.AQSPM10.match.all<-vector('list',length(misr.days$date))
MISR.STN.match.all<-vector('list',length(misr.days$date))
met.AQS.match.all<-vector('list',length(misr.days$date))
met.AQSPM10.match.all<-vector('list',length(misr.days$date))   

for (i in 1:length(misr.days$date)){
  aqs.daily<-AQS.08.09.ss2[AQS.08.09.ss2$date2 %in% misr.days[i,]$date2,] 
  
  aqsPM10.daily<-AQS.PM10.08.09.ss[AQS.PM10.08.09.ss$date2 %in% misr.days[i,]$date2,] 
  
  stn.daily<-STN.08.09.ss[STN.08.09.ss$date2 %in% misr.days[i,]$date2,] 
  
  misr.daily<-misr.08.09[misr.08.09$date2 %in% misr.days[i,]$date2,] 
                       
  met.daily<-met.08.09[met.08.09$day %in% misr.days[i,]$day &
                         met.08.09$month %in% misr.days[i,]$month & 
                         met.08.09$year %in% misr.days[i,]$year,]
  
  #distance matrices for each dataset
  dist<-rdist(cbind(misr.daily$x,misr.daily$y),cbind(aqs.daily$x,aqs.daily$y))
  dist.PM10<-rdist(cbind(misr.daily$x,misr.daily$y),cbind(aqsPM10.daily$x,aqsPM10.daily$y))
  dist.stn<-rdist(cbind(misr.daily$x,misr.daily$y),cbind(stn.daily$x,stn.daily$y))
  dist.met<-rdist(cbind(met.daily$x,met.daily$y),cbind(aqs.daily$x,aqs.daily$y))
  dist.PM10met<-rdist(cbind(met.daily$x,met.daily$y),cbind(aqsPM10.daily$x,aqsPM10.daily$y))
  
  # take pixel which is smallest distance from AQS site (but within 5km)
  # identify row of distance matrix (misr pixel id), with smallest column is aqs site
  
  MISR.AQS.match.list<-vector('list',length(dist[1,]))
  MISR.AQSPM10.match.list<-vector('list',length(dist[1,]))
  met.AQS.match.list<-vector('list',length(dist[1,]))
  met.AQSPM10.match.list<-vector('list',length(dist[1,]))
  
  for (j in 1:length(dist[1,])){ 
    if (min(dist[,j])<=5){
      MISR.AQS.match.list[[j]]<-data.frame(misr.daily[which.min(dist[,j]),],aqs.daily[j,]) # identifies misr pixel close to AQS PM25 site
    } 
  }
  
  for (j in 1:length(dist[1,])){ 
    if (min(dist.PM10[,j])<=5){
      MISR.AQSPM10.match.list[[j]]<-data.frame(misr.daily[which.min(dist.PM10[,j]),],aqsPM10.daily[j,]) # identifies misr pixel close to AQS PM10 site
    } 
  }
  
  MISR.AQS.match.all[[i]] <- do.call("rbind", MISR.AQS.match.list) 
  MISR.AQSPM10.match.all[[i]] <- do.call("rbind", MISR.AQSPM10.match.list) 
  
  # match now with closest met sites
  for (j in 1:length(dist[1,])){ 
    if (min(dist[,j])<=10){
      met.AQS.match.list[[j]]<-data.frame(met.daily[which.min(dist.met[,j]),],aqs.daily[j,]) # match AQS PM25 with met
    }
  }
  
  for (j in 1:length(dist[1,])){ 
    if (min(dist.PM10[,j])<=10){
      met.AQSPM10.match.list[[j]]<-data.frame(met.daily[which.min(distPM10.met[,j]),],aqsPM10.daily[j,]) # match AQS PM10 with met
    }
  }
  
  met.AQS.match.all[[i]] <- do.call("rbind", met.AQS.match.list)
  met.AQSPM10.match.all[[i]] <- do.call("rbind", met.AQSPM10.match.list)
  
  MISR.STN.match.list<-vector('list',length(dist[1,]))
  for (j in 1:length(dist[1,])){ 
    if (min(dist[,j])<=5){
      MISR.STN.match.list[[j]]<-data.frame(misr.daily[which.min(dist[,j]),],stn.daily[j,]) # identifies misr pixel close to STN site
    } 
  }
  MISR.STN.match.all[[i]] <- do.call("rbind", MISR.STN.match.list) 
  
}

MISR.AQS <- do.call("rbind", MISR.AQS.match.all)
write.csv(MISR.AQS,"/Users/mf/Documents/MISR/Data/MISR.AQS.csv",row.names=FALSE)

AQS.met <- do.call("rbind", met.AQS.match.all)
write.csv(AQS.met, "/Users/mf/Documents/MISR/Data/AQS.met.csv",row.names=FALSE)

MISR.STN <- do.call("rbind", MISR.STN.match.all)
write.csv(MISR.STN,"/Users/mf/Documents/MISR/Data/MISR.STN.csv",row.names=FALSE)

#merge
MISR.AQS.met<-join(MISR.AQS, AQS.met, by=c('AQS_SITE_ID','month','day','year'))
write.csv(MISR.AQS.met, "/Users/mf/Documents/MISR/Data/MISR.AQS.met.csv")


# ICV data (monthly with odd start dates)
ICV<-read.sas7bdat("/Volumes/Projects/CHSICV/Temp/TempRima/ICV2 Spatial Modeling/icv2spatial_01jun15.sas7bdat")
ICV<-ICV[,c(1:2,4:13,110:118)]
ICV.long<-read.sas7bdat("/Volumes/Projects/CHSICV/Temp/TempRima/ICV2 Spatial Modeling/icv2temporal_09jun15.sas7bdat")
ICV.long<-ICV.long[,c(1,6:12)]
ICV.new<-merge(ICV,ICV.long,by=c("Space_ID","startdate"))
ICV.new<-ICV.new[,c(1:13,18:21,26:27)]
ICV.new$datestart<-dates(ICV.new$startdate,origin=c(month=1,day=1,year=1960))
ICV.new$datestart2<-mdy(ICV.new$datestart)
ICV.new$dateend<-dates(ICV.new$enddate,origin=c(month=1,day=1,year=1960))
ICV.new$dateend2<-mdy(ICV.new$dateend)

proj.albers<-"+proj=aea +lat_1=34.0 +lat_2=40.5 +lon_0=-120.0 +x_0=0 +y_0=-4000000 +ellps=GRS80 +datum=NAD83 +units=km"
newcoords.icv<-project(as.matrix(cbind(ICV.new$avg_lon, ICV.new$avg_lat)), proj=proj.albers)
ICV.new$x<-newcoords.icv[,1]
ICV.new$y<-newcoords.icv[,2]

write.csv(ICV.new,"/Users/mf/Documents/MISR/Data/ICV_new.csv")

# find unique startdates and create interval to match MISR
ICV.startdays<-ICV.new %>% distinct(datestart2)
ICV.startdays$sampling.interval <- as.interval(ICV.startdays$datestart2, ICV.startdays$dateend2)

# MISR grid x,y to make 1km grid
misr.08.09<-misr.08.09[misr.08.09$land.water.mask==3,]
MISR.grid<-unique(misr.08.09[,19:20])

MISR.ICV.match.all<-vector('list',length(ICV.new$startdate))

for (i in 1:length(ICV.startdays$startdate)){
  # take MISR averages between each ICV start and end date (sampling.interval)
  misr.icv.date.match<-misr.08.09[misr.08.09$date2 %within% ICV.startdays$sampling.interval[i],]
  misr.monthly <- ddply(misr.icv.date.match, .(x,y), summarise, AOD.month=mean(AOD),
                            AODsmall.month=mean(AODsmall), AODmed.month=mean(AODmed), 
                            AODlarge.month=mean(AODlarge), AODnonsph.month=mean(AODnonspher))
  knots=dim(misr.icv.monthly)[1]/3
  misr.monthly.gam<-gam(AOD.month~s(x,y,k=knots),data=misr.monthly,na.action='na.exclude')
  misr.monthly.pred.smooth<-predict.gam(misr.monthly.gam,newdata = MISR.grid)
  
  # select icv observations for ith startdate  
 icv.monthly<-ICV.new[ICV.new$datestart2 %in% ICV.startdays$datestart2[i],]
 # remove missing locations
 icv.monthly<-icv.monthly[!is.na(icv.monthly$x),]
 # calculate distance between misr pixels and ICV sites
 dist<-rdist(cbind(misr.monthly$x,misr.monthly$y),cbind(icv.monthly$x,icv.monthly$y))

  MISR.ICV.match.list<-vector('list',length(dist[1,]))
 
 for (j in 1:length(dist[1,])){ 
   if (min(dist[,j])<=3){
     MISR.ICV.match.list[[j]]<-data.frame(misr.monthly[which.min(dist[,j]),],icv.monthly[j,]) # identifies misr pixel close to ICV site
   } 
 }
  MISR.ICV.match.all[[i]] <- do.call("rbind", MISR.ICV.match.list) 
}

MISR.ICV2 <- do.call("rbind", MISR.ICV.match.all)

write.csv(MISR.ICV,"/Users/mf/Documents/MISR/Data/MISR.ICV.csv",row.names=FALSE)  

#check
MISR.ICV.ss <- na.omit(subset(MISR.ICV,select=c(AOD.month,PM25)))
plot(PM25~AOD.month,data=MISR.ICV.ss)



