# Install packages ------------------------------------------------------------------------------------------------

lib <- c("RPostgres", "DBI", "bit64", "data.table", "tidyverse", "stringr", "openxlsx","lubridate", "scales")

new.lib <- lib[!c(lib %in% installed.packages()[, "Package"])]

if (length(new.lib)>0){
  install.packages(newlib)
}

# ----------------------------------------------------------------------------------------------------------------


# Establish connection ---------------------------------------------------------------------------------------------

library(RPostgres)
library(openxlsx)
library(data.table)
library(stringr)
library(lubridate)
library(tidyverse)
options(scipen = 999)


con <- dbConnect(RPostgres::Postgres(),
                 host = "localhost",
                 port = 5432,
                 dbname = "Vyndaqel_Japan_2022",
                 user = "postgres",
                 password = "****")

dbListTables(con)     # main, test, public schemes
dbListObjects(con)

# --------------------------------------------------------------------------------------------------------------------

# Terminate queries if needed ------------------------------------------------------------------------------------------
# When needed, start a new section and run this

query <- "SELECT pid, now() - pg_stat_activity.query_start AS duration, query, state
          FROM pg_stat_activity;"

test <- dbGetQuery(con, query)

query <- "SELECT pg_terminate_backend(9332)" # substitute for the active "pid" to stop
dbGetQuery(con, query)


# --------------------------------------------------------------------------------------------------------------------




# Create sample files V2 below ---------------------------------------------------------------------------------

# fileSys <- read.xlsx("./JMDC_Table_Field_List.xlsx", sheet = "Table list")
# files <- fileSys$Table.name
# directory <- list.files("./Extract/")
# sdirectory <- list.files("./Samples/")
# cTables <- read.xlsx("./JMDC_Table_Field_List.xlsx", sheet = "Field list")
# 
# for(f in files){
#   sfiles <- directory[directory %in% fileSys$file.name[fileSys$Table.name == f]]
#   sExists <- sum(paste0(sfiles,".csv") %in% sdirectory) > 0
#   if(length(sfiles) > 0 & !sExists){
#     print(f)
#     for(i in sfiles){
#       t <- read.csv(paste0("./Extract/",i), sep=",", nrows=10000, header=T)
#       fwrite(t, paste0("./Samples/",i), sep=",")
#     }
#   }
# }



# --------------------------------------------------------------------------------------------------------------------


# Create sample tables (cols, types) onto test schema ------------------------------------------------------------


# for (t in files){
#   sfiles <- directory[directory %in% fileSys$file.name[fileSys$Table.name == f]]
#   if(length(sfiles)>0){
#     print(t)
#     query <- paste0("DROP TABLE IF EXISTS test.",t,";")
#     dbGetQuery(con, query)
# 
#     query <- paste0("CREATE TABLE test.",t, " (",
#                     paste0(cTables$Field.name[cTables$Table.name==t], " ",
#                            cTables$Type[cTables$Table.name==t], collapse = ","),
#                     ")
#                     TABLESPACE pg_default;")
#     dbGetQuery(con, query)
#   }
# }



# --------------------------------------------------------------------------------------------------------------------


# Upload sample data onto test schema tables  ---------------------------------------------------------------------
# 
# # I could not read in the files from their original location, somehow postgres would denie me access
# # So I've temporarily moved the files to the C:/public (...)
# #query <- paste0("COPY test.","Enrollment"," FROM 'C:/Users/paulo/Desktop/Vanguard Strategy/Rimegepant Japan/Samples/","Enrollment.csv","' DELIMITER ',' CSV HEADER;")
# #dbSendQuery(con, query)
# 
# 
# directory <- list.files("./Samples/")
# 
# for(f in files){
#   sfiles <- directory[directory %in% paste0(fileSys$file.name[fileSys$Table.name==f] )]
#   if(length(sfiles)>0){
#     print(f)
#     for(i in sfiles){
#       query <- paste0("COPY test.",f," FROM 'C:/Users/paulo/Desktop/Vanguard Strategy/Rimegepant Japan/Samples/",i,"' DELIMITER ',' CSV HEADER;")
#       dbSendQuery(con, query)
#       cat(i)
# 
#     }
#   }
# }


# --------------------------------------------------------------------------------------------------------------------





# DeSC environment ---------------------------------------------------------------------------------------------------

DeSC <- new.env()

# DeSC tables

DeSC$tables <- data.table(read.xlsx("D:/Documentation/Vyndaqel_Table_Field_List.xlsx", sheet="Table list"))
names(DeSC$tables) <- c("table", "file", "records")
DeSC$tables <- DeSC$tables[, upload := (!str_detect(table, "!!"))*1] # if you want to leave any tables out (with "!!" in this case)

# DeSC table fields (columns infos)

DeSC$tabfields <- data.table(read.xlsx("D:/Documentation/Vyndaqel_Table_Field_List.xlsx", sheet="Field list"))
names(DeSC$tabfields) <- c("table", "field", "type")
DeSC$tabfields <- DeSC$tabfields[, DropField := str_detect(field, "_j$")*1] # I won't be dropping any fields for now, double check later


# --------------------------------------------------------------------------------------------------------------------




# Create sample files ---------------------------------------------------------------------------------------------

# Testing upload of the extracts into the the DB
# Create sample files with 10000 rows, from the Extract files for further upload into the postgreSQL DB Test schema

files <- DeSC$tables[upload == 1, .(table)]

extrD <- list.files("D:/Extracts/202211/utf8/all/") # files in the JMDC_Extracts directory 
smplD <- list.files("D:/Samples/")  # files in the JMDC_Samples directory

for(f in files$table){
  smplExist <- sum(paste0(f,".csv") %in% smplD)
  if(length(files) > 0 & smplExist == 0){
    print(f)
    t <- read.csv(paste0("D:/Extracts/202211/utf8/all/",f,".csv"), sep = ",", nrows = 10000, header = T)
    fwrite(t, paste0("D:/Samples/",f,".csv"))
  }
}


# --------------------------------------------------------------------------------------------------------------------



# Create Test schema ------------------------------------------------------------------------------------------------

query <- paste0("DROP SCHEMA IF EXISTS test CASCADE;")
dbSendQuery(con, query)
query <- paste0("CREATE SCHEMA test;")
dbSendQuery(con, query)


# --------------------------------------------------------------------------------------------------------------------



# Create empty tables in schema test with right fields ----------------------------------------------------------

tables <- DeSC$tables[upload == 1, .(table)]

for(t in tables$table){
  print(t)
  query <- paste0("DROP TABLE IF EXISTS test.",t,";")
  dbSendQuery(con, query)
  
  query <- paste0("CREATE TABLE test.",t," (",
                  paste0(DeSC$tabfields$field[DeSC$tabfields$table==t], " ",
                         DeSC$tabfields$type[DeSC$tabfields$table==t], collapse = ","),
                         ") TABLESPACE pg_default;")
  dbSendQuery(con, query)
}


# --------------------------------------------------------------------------------------------------------------------


# Upload samples ------------------------------------------------------------------------------------------------

tables <- DeSC$tables[upload==1, .(table)]
wd <- getwd()

for(t in tables$table){
  print(t)
  query <- paste0("COPY test.", tolower(t)," FROM '", wd, "Samples/",t,".csv' DELIMITER ',' CSV HEADER;" )
  dbSendQuery(con, query)
}



# --------------------------------------------------------------------------------------------------------------------


# Drop fields/cols in japanese ------------------------------------------------------------------------------

#   ! NOT PERFORMED ! #

# for(t in tables$table){
#   print(t)
#   drpfields <- DeSC$tabfields$field[DeSC$tabfields$table==t & DeSC$tabfields$DropField==1]
#   for(f in drpfields){
#     cat(f)
#     query <- paste0("ALTER TABLE test.", tolower(t), " DROP COLUMN ",f,";")
#     dbSendQuery(con, query)
#   }
# }

# --------------------------------------------------------------------------------------------------------------------



# Index test data on kojin_id ---------------------------------------------------------------------------------

query <- "SELECT * FROM information_schema.tables WHERE table_schema = 'test'"
t <- dbGetQuery(con, query)

query <- "SELECT * FROM pg_indexes WHERE schemaname = 'test'"
ind <- dbGetQuery(con, query)


toindex <- t$table_name[t$table_name == "exam_interview" | t$table_name == "receipt" | t$table_name == "receipt_dental_practice" |
                          t$table_name == "receipt_dental_practice_addition" | t$table_name == "receipt_dental_practice_santei_ymd" |
                          t$table_name == "receipt_diseases" | t$table_name == "receipt_dispensing" |
                          t$table_name == "receipt_drug" | t$table_name == "receipt_drug_santei_ymd" |
                          t$table_name == "receipt_ika_medical_practice_detail" | t$table_name == "receipt_ika_medical_practice_detail_santei_ymd" |
                          t$table_name == "receipt_insurance_pharmacy" | t$table_name == "receipt_medical_institution" |
                          t$table_name == "receipt_medical_practice" | t$table_name == "receipt_medical_practice_santei_ymd" |
                          t$table_name == "receipt_tooth_type_comment" | t$table_name == "receipt_tooth_type_diseases" |
                          t$table_name == "tekiyo" | t$table_name == "tekiyo_all" ]


indexed <- ind$tablename

for(i in toindex){
  if(!(i %in% indexed)){
    print(i)
    start <- Sys.time()
    query <- paste0("CREATE INDEX ",i,"_kojin_id ON test.",i," (kojin_id);")
    dbSendQuery(con, query)
    end <- Sys.time()
    print(end-start)
  }
}




# --------------------------------------------------------------------------------------------------------------------



# Create schema for tables with all data ------------------------------------------------------------------------

query <- paste0("DROP SCHEMA IF EXISTS vyndaqel CASCADE;")
dbSendQuery(con, query)

query <- paste0("CREATE SCHEMA vyndaqel;")
dbSendQuery(con, query)


# --------------------------------------------------------------------------------------------------------------------



# Create empty table with right fields within the DeSC schema -----------------------------------------------------

tables <- DeSC$tables[upload==1 & (table=="receipt_medical_practice"|table=="receipt_medical_practice_santei_ymd"|
                                     table=="receipt_drug_santei_ymd"|table=="receipt_diseases"|
                                     table=="receipt_tooth_type_diseases"|
                                     table=="receipt_dispensing"|
                                     table=="receipt"), .(table)]

for(t in tables$table){
  query <- paste0("SELECT table_name FROM information_schema.tables WHERE table_schema = 'vyndaqel';")
  vyndaqelT <- dbGetQuery(con, query)
  if(length(tables$table)>0 & !(tolower(t) %in% vyndaqelT$table_name)){
    print(t)
    query <- paste0("CREATE TABLE vyndaqel.",t," (", paste0(DeSC$tabfields$field[DeSC$tabfields$table==t]," ",
                                                            DeSC$tabfields$type[DeSC$tabfields$table==t], collapse = ","),
                                                        ") TABLESPACE pg_default;")
    dbSendQuery(con, query)
  }
}

# --------------------------------------------------------------------------------------------------------------------


# Upload entire data onto tables ------------------------------------------------------------------------------------

tables <- DeSC$tables[upload==1 & (table=="receipt_medical_practice"|table=="receipt_medical_practice_santei_ymd"|
                                     table=="receipt_drug_santei_ymd"|table=="receipt_diseases"|
                                     table=="receipt_tooth_type_diseases"|
                                     table=="receipt_dispensing"|
                                     table=="receipt"), .(table)]
wd <- getwd()




for(t in tables$table){
  query <- paste0("SELECT table_name FROM information_schema.tables WHERE table_schema='vyndaqel';")
  vyndaqelT <- dbGetQuery(con, query)
  if(tolower(t) %in% vyndaqelT$table_name){
    query <- paste0("SELECT EXISTS(SELECT 1 FROM vyndaqel.", tolower(t), ");")
    hasrows <- dbGetQuery(con, query)
    if(hasrows==FALSE){
      print(t)
      start <- Sys.time()
      query <- paste0("COPY vyndaqel.",tolower(t), " FROM '",wd,"Extracts/202211/utf8/all/",t,".csv' DELIMITER ',' CSV HEADER;")
      dbSendQuery(con, query)
      end <- Sys.time()
      print(end-start)
    }
  }
}




# --------------------------------------------------------------------------------------------------------------------



# Index entire data on kojin_id ------------------------------------------------------------------------------------

# Select existing tables in vyndaqel schema

query <- "SELECT * FROM information_schema.tables WHERE table_schema = 'vyndaqel'"
t <- dbGetQuery(con , query)

# Check existing indexes

query <- "SELECT * FROM pg_indexes WHERE schemaname = 'vyndaqel'"
ind <- dbGetQuery(con, query)

# Add new indexes

toindex <- t$table_name[t$table_name == "exam_interview" | t$table_name == "receipt" | t$table_name == "receipt_dental_practice" |
                          t$table_name == "receipt_dental_practice_addition" | t$table_name == "receipt_dental_practice_santei_ymd" |
                          t$table_name == "receipt_diseases" | t$table_name == "receipt_dispensing" |
                          t$table_name == "receipt_drug" | t$table_name == "receipt_drug_santei_ymd" |
                          t$table_name == "receipt_ika_medical_practice_detail" | t$table_name == "receipt_ika_medical_practice_detail_santei_ymd" |
                          t$table_name == "receipt_insurance_pharmacy" | t$table_name == "receipt_medical_institution" |
                          t$table_name == "receipt_medical_practice" | t$table_name == "receipt_medical_practice_santei_ymd" |
                          t$table_name == "receipt_tooth_type_comment" | t$table_name == "receipt_tooth_type_diseases" |
                          t$table_name == "tekiyo" | t$table_name == "tekiyo_all"]

indexed <- ind$tablename


# as before, but on the entire vyndaqel schema 

for(i in toindex){
  if(!(i %in% indexed)){
    print(i)
    start <- Sys.time()
    query <- paste0("CREATE INDEX ",i,"_kojin_id ON vyndaqel.",i," (kojin_id);")
    dbSendQuery(con, query)
    end <- Sys.time()
    print(end-start)
  }
}

# --------------------------------------------------------------------------------------------------------------------


# Pagify function ------------------------------------------------------------------------------------------

# Pagify function to get things in chunks from the database
# Arguments: 'data' -> a vector of values respecting ideally to an indexed data field in the DB table; 
# 'by' -> batch length

pagify <- function(data = NULL, by = 1000){
  pagemin <- seq(1,length(data), by = by)
  pagemax <- pagemin - 1 + by
  pagemax[length(pagemax)] <- length(data)
  pages   <- list(min = pagemin, max = pagemax)
}



# --------------------------------------------------------------------------------------------------------------------






# Create database reference tables lookups -----------------------------------------------

db <- new.env()
db$schema    <- "vyndaqel"               
db$pat       <- "patient"       
db$enroll    <- "enrollment" 
pop <- fread("Documentation/JMDC Japan Insurances.txt") 
defs$pop <- pop[,3:5]

# --------------------------------------------------------------------------------------------------------------------


# Check Min & Max   Start | End dates --------------------------------------------

# Data availability window   |  01 April 2014 to 30 August 2021

query <- paste0("SELECT MAX(observable_start_ym), 
                MIN(observable_start_ym) FROM vyndaqel.tekiyo;")

dbGetQuery(con, query) # Starts
# max     min
# 1 2021/08 2014/04


query <- paste0("SELECT MAX(observable_end_ym), 
                MIN(observable_end_ym) FROM vyndaqel.tekiyo;")

dbGetQuery(con, query) # Ends
# max     min
# 1 2021/08 2014/04




# --------------------------------------------------------------------------------------------------------------------



# Create definitions lookup --------------------------------------------------------------------------------------

defs <- new.env()
defs$disease <- "JPVyndaqel"
defs$minEnrdd <- ymd("2014-04-01") # First record
defs$maxEnrdd <- ymd("2021-08-30") # Last record


# --------------------------------------------------------------------------------------------------------------------


# Entire enrollment table - How many patients ? -------------------------------------------------------------------

query <- paste0("SELECT COUNT(*) FROM vyndaqel.tekiyo;")
dbGetQuery(con, query)  # 
query <- paste0("SELECT DISTINCT kojin_id FROM vyndaqel.tekiyo;")
dbGetQuery(con, query)  # 

# --------------------------------------------------------------------------------------------------------------------


# Vyndaqel pats vector -----------------------------------------------------------------------------------------

query <- paste0("SELECT * FROM vyndaqel.m_drug_main
                 WHERE drug_name LIKE '%ビンダケルカプセル２０ｍｇ%';")
dbGetQuery(con, query)  # 


# Ever tried vindaqel  
query <- paste0("SELECT DISTINCT(kojin_id) FROM vyndaqel.receipt_drug
                 WHERE drug_code LIKE '622278901';")
Ever_Vyndaqel_pats <- dbGetQuery(con, query)   #  
fwrite(Ever_Vyndaqel_pats, "Ever_Vyndaqel_pats.txt", sep = "\t")

# --------------------------------------------------------------------------------------------------------------------


# How many patients finished on each month ----------------------------------------------------------------------

query <- paste0("SELECT TO_DATE(observable_end_ym,'YYYY/MM'), COUNT(*)
                 FROM vyndaqel.tekiyo
                 GROUP BY TO_DATE(observable_end_ym,'YYYY/MM')
                 ORDER BY TO_DATE(observable_end_ym,'YYYY/MM') DESC;")
temp <- dbGetQuery(con, query)

temp$count <- as.numeric(temp$count)

temp %>% ggplot(aes(x = to_date, y = count)) + 
  geom_col(alpha=0.6, fill="firebrick") +
  theme_classic() + 
  theme(legend.title = element_blank(), legend.position = "top", legend.justification = "right") +
  ggtitle("Last observable dates")+
  xlab("\n Last Observable Date")+
  ylab("No. patient samples \n")

sum(temp$count)

# --------------------------------------------------------------------------------------------------------------------


# Check how many were enrolled last year,2 years, 3 years, etc +/- Vyndaqel --------------------------------------

query <- paste0("SELECT TO_DATE(observable_start_ym,'YYYY/MM') AS observable_start_ym, 
                        TO_DATE(observable_end_ym,'YYYY/MM') AS observable_end_ym
                FROM vyndaqel.tekiyo
                WHERE TO_DATE(observable_start_ym,'YYYY/MM')<='2020-04-01' AND 
                      TO_DATE(observable_end_ym,'YYYY/MM') >= '2021-03-01'; ")

dbGetQuery(con, query)  #   


# How many of these ALSO had vyndaqel? 

query <- paste0("SELECT table1.kojin_id FROM
                        (SELECT DISTINCT(kojin_id)
                          FROM vyndaqel.receipt_drug
                          WHERE drug_code LIKE '622278901' AND 
                          TO_DATE(receipt_ym,'YYYY/MM') >= '2020-04-01' AND 
                          TO_DATE(receipt_ym,'YYYY/MM') <= '2021-03-01') AS table1  -- 138
                JOIN 
                        (SELECT DISTINCT(kojin_id)
                          FROM vyndaqel.tekiyo
                          WHERE TO_DATE(observable_start_ym,'YYYY/MM') <= '2020-04-01' AND 
                          TO_DATE(observable_end_ym,'YYYY/MM') >= '2021-03-01') table2   -- 2549564
                ON table1.kojin_id = table2.kojin_id;")

Vyndaqel_Pats_ce_Y1 <- dbGetQuery(con, query)   # 




# Check how many were enrolled last 2 years

query <- paste0("SELECT TO_DATE(observable_start_ym,'YYYY/MM') AS observable_start_ym, 
                        TO_DATE(observable_end_ym,'YYYY/MM') AS observable_end_ym,
                        kojin_id
                FROM vyndaqel.tekiyo
                WHERE TO_DATE(observable_start_ym,'YYYY/MM')<='2019-04-01' AND 
                      TO_DATE(observable_end_ym,'YYYY/MM') >= '2021-03-01'; ")

dbGetQuery(con, query)  #   


# How many of these ALSO had vyndaqel?

query <- paste0("SELECT table1.kojin_id FROM
                        (SELECT DISTINCT(kojin_id)
                          FROM vyndaqel.receipt_drug
                          WHERE drug_code LIKE '622278901' AND 
                          TO_DATE(receipt_ym,'YYYY/MM') >= '2019-04-01' AND 
                          TO_DATE(receipt_ym,'YYYY/MM') <= '2021-03-01') AS table1  -- 121
                JOIN 
                        (SELECT DISTINCT(kojin_id)
                          FROM vyndaqel.tekiyo
                          WHERE TO_DATE(observable_start_ym,'YYYY/MM') <= '2019-04-01' AND 
                          TO_DATE(observable_end_ym,'YYYY/MM') >= '2021-03-01') table2   -- 2224045
                ON table1.kojin_id = table2.kojin_id;")

Vyndaqel_Pats_ce_Y2 <- dbGetQuery(con, query) 






# Check how many were enrolled last 3 years

query <- paste0("SELECT TO_DATE(observable_start_ym,'YYYY/MM') AS observable_start_ym, 
                        TO_DATE(observable_end_ym,'YYYY/MM') AS observable_end_ym,
                        kojin_id
                FROM vyndaqel.tekiyo
                WHERE TO_DATE(observable_start_ym,'YYYY/MM')<='2018-04-01' AND 
                      TO_DATE(observable_end_ym,'YYYY/MM') >= '2021-03-01'; ")

dbGetQuery(con, query)  #   


query <- paste0("SELECT table1.kojin_id FROM
                        (SELECT DISTINCT(kojin_id)
                          FROM vyndaqel.receipt_drug
                          WHERE drug_code LIKE '622278901' AND 
                          TO_DATE(receipt_ym,'YYYY/MM') >= '2018-04-01' AND 
                          TO_DATE(receipt_ym,'YYYY/MM') <= '2021-03-01') AS table1  -- 74
                JOIN 
                        (SELECT DISTINCT(kojin_id)
                          FROM vyndaqel.tekiyo
                          WHERE TO_DATE(observable_start_ym,'YYYY/MM') <= '2018-04-01' AND 
                          TO_DATE(observable_end_ym,'YYYY/MM') >= '2021-03-01') table2   -- 1864247
                ON table1.kojin_id = table2.kojin_id;")

Vyndaqel_Pats_ce_Y3 <- dbGetQuery(con, query) 



# Check how many were enrolled last 4 years

query <- paste0("SELECT TO_DATE(observable_start_ym,'YYYY/MM') AS observable_start_ym, 
                        TO_DATE(observable_end_ym,'YYYY/MM') AS observable_end_ym,
                        kojin_id
                FROM vyndaqel.tekiyo
                WHERE TO_DATE(observable_start_ym,'YYYY/MM')<='2017-04-01' AND 
                      TO_DATE(observable_end_ym,'YYYY/MM') >= '2021-03-01'; ")

dbGetQuery(con, query)  #   


query <- paste0("SELECT table1.kojin_id FROM
                        (SELECT DISTINCT(kojin_id)
                          FROM vyndaqel.receipt_drug
                          WHERE drug_code LIKE '622278901' AND 
                          TO_DATE(receipt_ym,'YYYY/MM') >= '2017-04-01' AND 
                          TO_DATE(receipt_ym,'YYYY/MM') <= '2021-03-01') AS table1  -- 31
                JOIN 
                        (SELECT DISTINCT(kojin_id)
                          FROM vyndaqel.tekiyo
                          WHERE TO_DATE(observable_start_ym,'YYYY/MM') <= '2017-04-01' AND 
                          TO_DATE(observable_end_ym,'YYYY/MM') >= '2021-03-01') table2   -- 1174882
                ON table1.kojin_id = table2.kojin_id;")

Vyndaqel_Pats_ce_Y4 <- dbGetQuery(con, query) 



# Check how many were enrolled last 5 years

query <- paste0("SELECT TO_DATE(observable_start_ym,'YYYY/MM') AS observable_start_ym, 
                        TO_DATE(observable_end_ym,'YYYY/MM') AS observable_end_ym,
                        kojin_id
                FROM vyndaqel.tekiyo
                WHERE TO_DATE(observable_start_ym,'YYYY/MM')<='2016-04-01' AND 
                      TO_DATE(observable_end_ym,'YYYY/MM') >= '2021-03-01'; ")

dbGetQuery(con, query)  #   



query <- paste0("SELECT table1.kojin_id FROM
                        (SELECT DISTINCT(kojin_id)
                          FROM vyndaqel.receipt_drug
                          WHERE drug_code LIKE '622278901' AND 
                          TO_DATE(receipt_ym,'YYYY/MM') >= '2016-04-01' AND 
                          TO_DATE(receipt_ym,'YYYY/MM') <= '2021-03-01') AS table1  -- 26
                JOIN 
                        (SELECT DISTINCT(kojin_id)
                          FROM vyndaqel.tekiyo
                          WHERE TO_DATE(observable_start_ym,'YYYY/MM') <= '2016-04-01' AND 
                          TO_DATE(observable_end_ym,'YYYY/MM') >= '2021-03-01') table2   -- 1007145
                ON table1.kojin_id = table2.kojin_id;")

Vyndaqel_Pats_ce_Y5 <- dbGetQuery(con, query) 


# --------------------------------------------------------------------------------------------------------------------


# How many with ATTR ever ? code -- '8850066' ----------------------------------------------------------

query <- paste0("SELECT COUNT(*)
                 FROM vyndaqel.receipt_diseases
                 WHERE diseases_code = '8850066'; ")

dbGetQuery(con, query) # 

query <- paste0("SELECT table1.kojin_id FROM
                        (SELECT DISTINCT(kojin_id)
                          FROM vyndaqel.receipt_diseases
                          WHERE diseases_code = '8850066' AND 
                          TO_DATE(receipt_ym,'YYYY/MM') >= '2018-04-01' AND 
                          TO_DATE(receipt_ym,'YYYY/MM') <= '2021-03-01') AS table1 
                JOIN 
                        (SELECT DISTINCT(kojin_id)
                          FROM vyndaqel.tekiyo
                          WHERE TO_DATE(observable_start_ym,'YYYY/MM') <= '2018-04-01' AND 
                          TO_DATE(observable_end_ym,'YYYY/MM') >= '2021-03-01') table2   
                ON table1.kojin_id = table2.kojin_id;")

dbGetQuery(con, query)  # 


# --------------------------------------------------------------------------------------------------------------------


# How many with amyloidosis ever ? code -- 'E85' ----------------------------------------------------------------

query <- paste0("SELECT DISTINCT(table2.kojin_id) FROM
                        (SELECT DISTINCT(diseases_code)
                         FROM vyndaqel.m_icd10
                         WHERE icd10_code LIKE '%E85%') AS table1 
                JOIN 
                        (SELECT kojin_id, diseases_code
                         FROM vyndaqel.receipt_diseases) table2   
                ON table1.diseases_code = table2.diseases_code;")

dbGetQuery(con, query) # 

# -- Year 1
query <- paste0("SELECT DISTINCT(table3.kojin_id) FROM
            (SELECT DISTINCT(diseases_code)
              FROM vyndaqel.m_icd10
              WHERE icd10_code LIKE '%E85%') AS table1
      JOIN
            (SELECT kojin_id, diseases_code
              FROM vyndaqel.receipt_diseases) AS table2
            ON table1.diseases_code = table2.diseases_code
      JOIN
            (SELECT DISTINCT(kojin_id)
              FROM vyndaqel.tekiyo
              WHERE TO_DATE(observable_start_ym,'YYYY/MM') <= '2020-04-01' AND
              TO_DATE(observable_end_ym,'YYYY/MM') >= '2021-03-01') AS table3
      ON table2.kojin_id = table3.kojin_id;")

E55_Year1 <- dbGetQuery(con, query)  # 


# -- Year 2
query <- paste0("SELECT DISTINCT(table3.kojin_id) FROM
            (SELECT DISTINCT(diseases_code)
              FROM vyndaqel.m_icd10
              WHERE icd10_code LIKE '%E85%') AS table1
      JOIN
            (SELECT kojin_id, diseases_code
              FROM vyndaqel.receipt_diseases) AS table2
            ON table1.diseases_code = table2.diseases_code
      JOIN
            (SELECT DISTINCT(kojin_id)
              FROM vyndaqel.tekiyo
              WHERE TO_DATE(observable_start_ym,'YYYY/MM') <= '2019-04-01' AND
              TO_DATE(observable_end_ym,'YYYY/MM') >= '2021-03-01') AS table3
      ON table2.kojin_id = table3.kojin_id;")

E55_Year2 <- dbGetQuery(con, query)


# -- Year 3
query <- paste0("SELECT DISTINCT(table3.kojin_id) FROM
            (SELECT DISTINCT(diseases_code)
              FROM vyndaqel.m_icd10
              WHERE icd10_code LIKE '%E85%') AS table1
      JOIN
            (SELECT kojin_id, diseases_code
              FROM vyndaqel.receipt_diseases) AS table2
            ON table1.diseases_code = table2.diseases_code
      JOIN
            (SELECT DISTINCT(kojin_id)
              FROM vyndaqel.tekiyo
              WHERE TO_DATE(observable_start_ym,'YYYY/MM') <= '2018-04-01' AND
              TO_DATE(observable_end_ym,'YYYY/MM') >= '2021-03-01') AS table3
      ON table2.kojin_id = table3.kojin_id;")

E55_Year3 <- dbGetQuery(con, query)  # 



# -- Year 4
query <- paste0("SELECT DISTINCT(table3.kojin_id) FROM
            (SELECT DISTINCT(diseases_code)
              FROM vyndaqel.m_icd10
              WHERE icd10_code LIKE '%E85%') AS table1
      JOIN
            (SELECT kojin_id, diseases_code
              FROM vyndaqel.receipt_diseases) AS table2
            ON table1.diseases_code = table2.diseases_code
      JOIN
      (SELECT DISTINCT(kojin_id)
              FROM vyndaqel.tekiyo
              WHERE TO_DATE(observable_start_ym,'YYYY/MM') <= '2017-04-01' AND
              TO_DATE(observable_end_ym,'YYYY/MM') >= '2021-03-01') AS table3
      ON table2.kojin_id = table3.kojin_id;")

E55_Year4 <- dbGetQuery(con, query)


# -- Year 5
query <- paste0("SELECT DISTINCT(table3.kojin_id) FROM
          (SELECT DISTINCT(diseases_code)
            FROM vyndaqel.m_icd10
            WHERE icd10_code LIKE '%E85%') AS table1
      JOIN
            (SELECT kojin_id, diseases_code
              FROM vyndaqel.receipt_diseases) AS table2
            ON table1.diseases_code = table2.diseases_code
      JOIN
      (SELECT DISTINCT(kojin_id)
              FROM vyndaqel.tekiyo
              WHERE TO_DATE(observable_start_ym,'YYYY/MM') <= '2016-04-01' AND
              TO_DATE(observable_end_ym,'YYYY/MM') >= '2021-03-01') AS table3
      ON table2.kojin_id = table3.kojin_id;")

E55_Year5 <- dbGetQuery(con, query)



# --------------------------------------------------------------------------------------------------------------------


# Create projection weights ------------------------------------------------------------------------------------

# Target patients continuously enrolled 3 years

query <- paste0("SELECT kojin_id, birth_ym, sex_code
                FROM vyndaqel.tekiyo
                WHERE TO_DATE(observable_start_ym,'YYYY/MM') <='2018-04-01' AND 
                      TO_DATE(observable_end_ym,'YYYY/MM') >= '2021-03-01'; ")

ContinuouslyEnrolled_Y3_tekiyo <- dbGetQuery(con, query)  #   


# All databsed patients continuously enrolled 3 years
query <- paste0("SELECT kojin_id, birth_ym, sex_code
                FROM vyndaqel.tekiyo_all
                WHERE TO_DATE(observable_start_ym,'YYYY/MM')<='2018-04-01' AND 
                      TO_DATE(observable_end_ym,'YYYY/MM') >= '2021-03-01'; ")

ContinuouslyEnrolled_Y3_tekiyoAll <- dbGetQuery(con, query)  #   
# temp <- ContinuouslyEnrolled_Y3_tekiyoAll

ContinuouslyEnrolled_Y3_tekiyoAll <- temp 

ContinuouslyEnrolled_Y3_tekiyoAll$birth_ym <- ym(ContinuouslyEnrolled_Y3_tekiyoAll$birth_ym)

ContinuouslyEnrolled_Y3_tekiyoAll$age <- round(time_length(interval(ContinuouslyEnrolled_Y3_tekiyoAll$birth_ym, ymd("2021-08-01")), "year"))

ContinuouslyEnrolled_Y3_tekiyoAll <- 
  ContinuouslyEnrolled_Y3_tekiyoAll[ContinuouslyEnrolled_Y3_tekiyoAll$age<=100 &
                                      ContinuouslyEnrolled_Y3_tekiyoAll$age>=18 ,]

typeof(as.data.table(ContinuouslyEnrolled_Y3_tekiyoAll))

ContinuouslyEnrolled_Y3_tekiyoAll <- data.table(ContinuouslyEnrolled_Y3_tekiyoAll)

ContinuouslyEnrolled_Y3_tekiyoAll <- ContinuouslyEnrolled_Y3_tekiyoAll[, .(samples_count = .N), keyby = .(sex_code,age)]

ContinuouslyEnrolled_Y3_tekiyoAll[, gender:= ifelse(sex_code == 1, "M","F")]

ContinuouslyEnrolled_Y3_tekiyoAll <- ContinuouslyEnrolled_Y3_tekiyoAll[,.(age,gender, samples_count)]

ContinuouslyEnrolled_Y3_tekiyoAll[, age := ifelse(age <= 94, age, 95)] # anyone above 94 stays 95

ContinuouslyEnrolled_Y3_tekiyoAll <- ContinuouslyEnrolled_Y3_tekiyoAll[, .(samples_count = sum(samples_count)), by = .(age, gender)] 

ContinuouslyEnrolled_Y3_tekiyoAll <- 
  merge(ContinuouslyEnrolled_Y3_tekiyoAll, defs$pop, by.x=c("age","gender"), 
        by.y=c("age","gender"), all.x = TRUE)


ContinuouslyEnrolled_Y3_tekiyoAll[age==74,]
ContinuouslyEnrolled_Y3_tekiyoAll[age==73,]
ContinuouslyEnrolled_Y3_tekiyoAll[age==72,]

ContinuouslyEnrolled_Y3_tekiyoAll[, samples_count  := ifelse(age == 74,0.9*samples_count ,samples_count )]
ContinuouslyEnrolled_Y3_tekiyoAll[, samples_count  := ifelse(age == 73,0.9*samples_count ,samples_count )]
ContinuouslyEnrolled_Y3_tekiyoAll[, samples_count  := ifelse(age == 72,0.9*samples_count ,samples_count )]
ContinuouslyEnrolled_Y3_tekiyoAll[, samples_count  := ifelse(age == 76 & gender=="F",samples_count+27781.7,samples_count )]
ContinuouslyEnrolled_Y3_tekiyoAll[, samples_count  := ifelse(age == 76 & gender=="M",samples_count+24656.5,samples_count )]


ContinuouslyEnrolled_Y3_tekiyoAll[age==81,]
ContinuouslyEnrolled_Y3_tekiyoAll[age==80,]
ContinuouslyEnrolled_Y3_tekiyoAll[age==79,]

ContinuouslyEnrolled_Y3_tekiyoAll[, samples_count  := ifelse(age == 81,0.9*samples_count ,samples_count )]
ContinuouslyEnrolled_Y3_tekiyoAll[, samples_count  := ifelse(age == 80,0.9*samples_count ,samples_count )]
ContinuouslyEnrolled_Y3_tekiyoAll[, samples_count  := ifelse(age == 79,0.9*samples_count ,samples_count )]
ContinuouslyEnrolled_Y3_tekiyoAll[, samples_count  := ifelse(age == 77 & gender=="F",samples_count+30196.7,samples_count )]
ContinuouslyEnrolled_Y3_tekiyoAll[, samples_count  := ifelse(age == 77 & gender=="M",samples_count+23618.9,samples_count )]

ContinuouslyEnrolled_Y3_tekiyoAll[,weight:=total_population/samples_count]

ggplot(ContinuouslyEnrolled_Y3_tekiyoAll, aes(x = age, y = weight, fill = gender)) + 
  geom_col(alpha=0.6) +
  scale_fill_manual(values = c("deeppink4","darkslategray")) +
  scale_x_continuous(breaks = seq(18,95,3)) +
  scale_y_continuous(expand = c(0,0)) +
  theme_classic() + 
  theme(legend.title = element_blank(), legend.position = "top", legend.justification = "right") +
  ggtitle("Projections Weights: Age & Gender")+
  xlab("\n Age (years)")+
  ylab("Projection weight \n")



ggplot(ContinuouslyEnrolled_Y3_tekiyoAll, aes(x = age, y = samples_count, fill = gender)) + 
  geom_col(alpha=0.6) +
  scale_fill_manual(values = c("deeppink4","darkslategray")) +
  scale_x_continuous(breaks = seq(18,95,3)) +
  scale_y_continuous(expand = c(0,0)) +
  theme_classic() + 
  theme(legend.title = element_blank(), legend.position = "top", legend.justification = "right") +
  ggtitle("Total No. of Samples: Age & Gender")+
  xlab("\n Age (years)")+
  ylab("No. patient samples \n")


fwrite(ContinuouslyEnrolled_Y3_tekiyoAll, "Documentation/Projection Weights Japan.txt", sep="\t")





# --------------------------------------------------------------------------------------------------------------------




# Apply projection weights to the tekiyo cohort (continuously enrolled last3 years) --------------------------------

Pop_weights <- ContinuouslyEnrolled_Y3_tekiyoAll
Pop_weights <- Pop_weights[,.(age, gender, weight)]

ContinuouslyEnrolled_Y3_tekiyo$birth_ym <- ym(ContinuouslyEnrolled_Y3_tekiyo$birth_ym)

ContinuouslyEnrolled_Y3_tekiyo$age <- round(time_length(interval(ContinuouslyEnrolled_Y3_tekiyo$birth_ym, ymd("2021-08-01")), "year"))

ContinuouslyEnrolled_Y3_tekiyo <- 
  ContinuouslyEnrolled_Y3_tekiyo[ContinuouslyEnrolled_Y3_tekiyo$age<=100 &
                                   ContinuouslyEnrolled_Y3_tekiyo$age>=18 ,]

typeof(as.data.table(ContinuouslyEnrolled_Y3_tekiyo))

ContinuouslyEnrolled_Y3_tekiyo <- data.table(ContinuouslyEnrolled_Y3_tekiyo)

ContinuouslyEnrolled_Y3_tekiyo[, gender:= ifelse(sex_code == 1, "M","F")]

ContinuouslyEnrolled_Y3_tekiyo[, age := ifelse(age <= 94, age, 95)] # anyone above 94 stays 95

ContinuouslyEnrolled_Y3_tekiyo <- ContinuouslyEnrolled_Y3_tekiyo[, .(kojin_id, age, gender)] 

ContinuouslyEnrolled_Y3_tekiyo <- ContinuouslyEnrolled_Y3_tekiyo %>% arrange(gender, age)

ContinuouslyEnrolled_Y3_tekiyo <- ContinuouslyEnrolled_Y3_tekiyo %>% group_by(gender, age) %>% mutate(total=n())
ContinuouslyEnrolled_Y3_tekiyo <- ContinuouslyEnrolled_Y3_tekiyo %>% group_by(gender, age) %>% mutate(ID=row_number())

ContinuouslyEnrolled_Y3_tekiyo <- ContinuouslyEnrolled_Y3_tekiyo %>% group_by(gender, age) %>%
  mutate(To_change=ifelse(ID>0.9*total,"YES","NO"))

ContinuouslyEnrolled_Y3_tekiyo <- ContinuouslyEnrolled_Y3_tekiyo %>% 
  mutate(age=ifelse(age==74&To_change=="YES",76,age)) %>%
  mutate(age=ifelse(age==73&To_change=="YES",76,age)) %>%
  mutate(age=ifelse(age==72&To_change=="YES",76,age)) %>%
  mutate(age=ifelse(age==81&To_change=="YES",77,age)) %>%
  mutate(age=ifelse(age==80&To_change=="YES",77,age)) %>%
  mutate(age=ifelse(age==79&To_change=="YES",77,age)) 

ContinuouslyEnrolled_Y3_tekiyo <- ContinuouslyEnrolled_Y3_tekiyo %>% ungroup() %>% select(kojin_id, age, gender)
ContinuouslyEnrolled_Y3_tekiyo <- ContinuouslyEnrolled_Y3_tekiyo %>% left_join(Pop_weights)

fwrite(ContinuouslyEnrolled_Y3_tekiyo, "ContinuouslyEnrolled_Y3_tekiyo_weights.txt", sep="\t") 

sum(ContinuouslyEnrolled_Y3_tekiyo$weight) # 26009563




# --------------------------------------------------------------------------------------------------------------------











# Subset tables for 195 vyndaqel patients   ---------------------------------------------------------------

# Pagify function to get things in chunks from the database
# Arguments: 'data' -> a vector of values respecting ideally to an indexed data field in the DB table; 
# 'by' -> batch length

pagify <- function(data = NULL, by = 1000){
  pagemin <- seq(1,length(data), by = by)
  pagemax <- pagemin - 1 + by
  pagemax[length(pagemax)] <- length(data)
  pages   <- list(min = pagemin, max = pagemax)
}



Ever_Vyndaqel_pats <- fread("Processed Data/Ever_Vyndaqel_pats.txt", sep="\t")

pages <- pagify(Ever_Vyndaqel_pats$kojin_id, 195)


# vyndaqel.tekiyo
for(i in 1:length(pages$max)) {
  pts <- paste0(Ever_Vyndaqel_pats$kojin_id[pages$min[i]:pages$max[i]], collapse = "','")
  query <- paste0("SELECT * FROM vyndaqel.tekiyo  WHERE kojin_id IN ('",pts,"');")
  data  <- setDT(dbGetQuery(con, query))
  fwrite(data, "Processed Data/tekiyo_Vyndaqel195pts.txt", sep="\t")
}


# vyndaqel.exam_interview
for(i in 1:length(pages$max)) {
  pts <- paste0(Ever_Vyndaqel_pats$kojin_id[pages$min[i]:pages$max[i]], collapse = "','")
  query <- paste0("SELECT * FROM vyndaqel.exam_interview  WHERE kojin_id IN ('",pts,"');")
  data  <- setDT(dbGetQuery(con, query))
  fwrite(data, "Processed Data/exam_interview_Vyndaqel195pts.txt", sep="\t")
}



# vyndaqel.receipt_diseases
for(i in 1:length(pages$max)) {
  pts <- paste0(Ever_Vyndaqel_pats$kojin_id[pages$min[i]:pages$max[i]], collapse = "','")
  query <- paste0("SELECT * FROM vyndaqel.receipt_diseases  WHERE kojin_id IN ('",pts,"');")
  data  <- setDT(dbGetQuery(con, query))
  fwrite(data, "Processed Data/receipt_diseases_Vyndaqel195pts.txt", sep="\t")
}


# vyndaqel.receipt_drug
for(i in 1:length(pages$max)) {
  pts <- paste0(Ever_Vyndaqel_pats$kojin_id[pages$min[i]:pages$max[i]], collapse = "','")
  query <- paste0("SELECT * FROM vyndaqel.receipt_drug  WHERE kojin_id IN ('",pts,"');")
  data  <- setDT(dbGetQuery(con, query))
  fwrite(data, "Processed Data/receipt_drug_Vyndaqel195pts.txt", sep="\t")
}



# vyndaqel.receipt_dispensing
for(i in 1:length(pages$max)) {
  pts <- paste0(Ever_Vyndaqel_pats$kojin_id[pages$min[i]:pages$max[i]], collapse = "','")
  query <- paste0("SELECT * FROM vyndaqel.receipt_dispensing  WHERE kojin_id IN ('",pts,"');")
  data  <- setDT(dbGetQuery(con, query))
  fwrite(data, "Processed Data/receipt_dispensing_Vyndaqel195pts.txt", sep="\t")
}


# vyndaqel.receipt_medical_institution
for(i in 1:length(pages$max)) {
  pts <- paste0(Ever_Vyndaqel_pats$kojin_id[pages$min[i]:pages$max[i]], collapse = "','")
  query <- paste0("SELECT * FROM vyndaqel.receipt_medical_institution  WHERE kojin_id IN ('",pts,"');")
  data  <- setDT(dbGetQuery(con, query))
  fwrite(data, "Processed Data/receipt_medical_institution_Vyndaqel195pts.txt", sep="\t")
}



# vyndaqel.receipt_medical_practice
for(i in 1:length(pages$max)) {
  pts <- paste0(Ever_Vyndaqel_pats$kojin_id[pages$min[i]:pages$max[i]], collapse = "','")
  query <- paste0("SELECT * FROM vyndaqel.receipt_medical_practice  WHERE kojin_id IN ('",pts,"');")
  data  <- setDT(dbGetQuery(con, query))
  fwrite(data, "Processed Data/receipt_medical_practice_Vyndaqel195pts.txt", sep="\t")
}


# -------------------------------------------------------------------------------------------------


#  195 vyndaqel patients -> Age & gender vyndaqel patients 195 -------------------------------------------------------------

tekiyo_Vyndaqel195pts <- fread("VyndaqelPts195/tekiyo_Vyndaqel195pts.txt")

tekiyo_Vyndaqel195pts <- tekiyo_Vyndaqel195pts %>% select(kojin_id, birth_ym, sex_code)

tekiyo_Vyndaqel195pts$birth_ym <- ym(tekiyo_Vyndaqel195pts$birth_ym)

tekiyo_Vyndaqel195pts$age <- round(time_length(interval(tekiyo_Vyndaqel195pts$birth_ym, ymd("2021-08-01")), "year"))

tekiyo_Vyndaqel195pts[, gender:= ifelse(sex_code == 1, "M","F")]

tekiyo_Vyndaqel195pts[, age := ifelse(age <= 94, age, 95)] 

tekiyo_Vyndaqel195pts <- tekiyo_Vyndaqel195pts[,.(kojin_id, age, gender)]

# ContinuouslyEnrolled_Y3_tekiyo_weights <- fread("All_Pts_Continuousenrolled/ContinuouslyEnrolled_Y3_tekiyo_weights.txt")
# 
# temp <- tekiyo_Vyndaqel195pts %>% left_join(ContinuouslyEnrolled_Y3_tekiyo_weights %>% 
#                                       select(kojin_id, weight))


Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", sep="\t")
Vyndaqel_pats_CM_vs_PN <- Vyndaqel_pats_CM_vs_PN %>% filter(CM==1|PN==1) %>% select(kojin_id)


tekiyo_Vyndaqel195pts %>% inner_join(Vyndaqel_pats_CM_vs_PN) %>% group_by(gender) %>% count()


length(unique(tekiyo_Vyndaqel195pts$age)) # 36
min(tekiyo_Vyndaqel195pts$age) #
max(tekiyo_Vyndaqel195pts$age) #

tekiyo_Vyndaqel195pts %>% inner_join(Vyndaqel_pats_CM_vs_PN) %>% group_by(gender) %>% summarise(n = mean(age))


tekiyo_Vyndaqel195pts %>% inner_join(Vyndaqel_pats_CM_vs_PN) %>% 
ggplot( aes(x = age, fill = gender)) + 
  geom_density(alpha = 0.8) +
  scale_fill_manual(values = c("darkgoldenrod1","darkblue")) +
  scale_x_continuous(breaks = seq(36,95,2)) +
  scale_y_continuous(expand = c(0,0)) +
  theme_classic() + 
  theme(legend.title = element_blank(), legend.position = "top", legend.justification = "right") +
  ggtitle("Proportion of Vyndaqel ATTR-CM patients within each gender") +
  xlab("\n Age (years)") +
  ylab("Proportion\n")


# --------------------------------------------------------------------------------------------------




# 195 vyndaqel patients -> No. Pts ON Vyndaqel each month  -----------------------------------------------------------------------

receipt_drug_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_drug_Vyndaqel195pts.txt", 
                                     colClasses = "character")

data.frame(receipt_drug_Vyndaqel195pts %>% filter(drug_code == "622278901") %>%
  select(kojin_id, receipt_ym) %>% distinct() %>%
  group_by(receipt_ym) %>% count()) %>%
  ggplot(aes(receipt_ym, n)) +
  geom_col(fill = "darkblue") +
  scale_y_continuous(expand = c(0,0)) +
  theme_classic() + 
  theme(legend.title = element_blank(), legend.position = "top", 
        legend.justification = "right", axis.text.x  = element_text(angle = 45, vjust = 0.5, size = 6)) +
  ggtitle("Total No. of patients with vyndaqel prescriptions month-over-month") +
  xlab("\n Prescription date (YYYY/MM)") +
  ylab("No. patients presrcribed\n")


receipt_medical_institution_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_medical_institution_Vyndaqel195pts.txt", 
                                                    colClasses = "character")

unique(receipt_medical_institution_Vyndaqel195pts$shinryouka_name_code)

receipt_drug_Vyndaqel195pts %>% 
  filter(drug_code == "622278901") %>%
  select(kojin_id, receipt_ym, receipt_id) %>%
  left_join(receipt_medical_institution_Vyndaqel195pts %>% 
              select(receipt_id, shinryouka_name_code)) %>%
  group_by(shinryouka_name_code) %>% count()


# --------------------------------------------------------------------------------------------------




# 195 vyndaqel patients -> Time ON Vyndaqel & Percent coverage  -----------------------------------------------------------------------

receipt_drug_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_drug_Vyndaqel195pts.txt", 
                                     colClasses = "character")


receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% filter(drug_code == "622278901") %>% select(kojin_id, receipt_ym) 

receipt_drug_Vyndaqel195pts$receipt_ym <- ym(receipt_drug_Vyndaqel195pts$receipt_ym)

receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% group_by(kojin_id) %>% mutate(mindate = min(receipt_ym)) %>% mutate(maxdate = max(receipt_ym))

  
receipt_drug_Vyndaqel195pts$period <- round(time_length(interval(receipt_drug_Vyndaqel195pts$mindate, receipt_drug_Vyndaqel195pts$maxdate), "month") + 1)

receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% group_by(kojin_id) %>% mutate(NoScripts = n())

receipt_drug_Vyndaqel195pts %>%
  select(kojin_id, period) %>% distinct() %>%
  ggplot(aes(x = period)) + 
  geom_density(alpha = 0.8, fill = "darkblue", colour = "firebrick", size = 1) +
  theme_classic() + 
  theme(legend.title = element_blank(), legend.position = "top", legend.justification = "right") +
  ggtitle("") +
  xlab("\n No. Months ON Vyndaqel (First-to-Last date)") +
  ylab("Proportion\n")



receipt_drug_Vyndaqel195pts %>%
  select(kojin_id, period, NoScripts) %>% distinct() %>%
  ggplot(aes(period, NoScripts)) +
  geom_jitter(size=2, alpha=0.6, colour = "darkblue") +
  theme_classic() + 
  theme(legend.title = element_blank(), legend.position = "top", legend.justification = "right") +
  ggtitle("") +
  xlim(0,70) + ylim(0,70) +
  xlab("\n No. Months ON Vyndaqel (First-to-Last date)") +
  ylab("No. of Scripts (i.e. coverage)\n") + 
  geom_abline(slope = 1, intercept = 0, size = 2, alpha = 0.6, colour = "firebrick")
  


receipt_drug_Vyndaqel195pts %>%
  select(kojin_id, period, NoScripts) %>% distinct() %>%
  mutate(coverage = 100*NoScripts/period) %>%
  ggplot(aes(coverage)) +
  geom_density(alpha = 0.8, fill = "darkblue", colour = "firebrick", size = 1) +
  theme_classic() + 
  theme(legend.title = element_blank(), legend.position = "top", legend.justification = "right") +
  ggtitle("") +
  xlab("\n % Coverage (No. Scripts / No. Months ON Vyndaqel") +
  ylab("Proportion\n")



receipt_drug_Vyndaqel195pts %>%
  select(kojin_id, period, NoScripts) %>% distinct() %>%
  mutate(coverage = 100*NoScripts/period) %>% 
  ungroup() %>%
  summarise(n = mean(NoScripts  ))


# ---------------------------------------------------------------------------------------------
# 195 vyndaqel patients -> Vyndaqel persistency - DEAD vs ALIVE ------------------------------------------------------------------------

# Vyndaqel dates
receipt_drug_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_drug_Vyndaqel195pts.txt", 
                                     colClasses = "character")

receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% filter(drug_code == "622278901") %>% select(kojin_id, receipt_ym) 

receipt_drug_Vyndaqel195pts$receipt_ym <- ym(receipt_drug_Vyndaqel195pts$receipt_ym)

receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% group_by(kojin_id) %>% mutate(mindate = min(receipt_ym)) %>% mutate(maxdate = max(receipt_ym))

receipt_drug_Vyndaqel195pts$period <- round(time_length(interval(receipt_drug_Vyndaqel195pts$mindate, receipt_drug_Vyndaqel195pts$maxdate), "month") + 1)

receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% group_by(kojin_id) %>% mutate(NoScripts = n())


# Start / End dates
tekiyo_Vyndaqel195pts <- fread("VyndaqelPts195/tekiyo_Vyndaqel195pts.txt", colClasses = "character")
tekiyo_Vyndaqel195pts <- tekiyo_Vyndaqel195pts %>% select(kojin_id, observable_start_ym, observable_end_ym, shibou_flg)
tekiyo_Vyndaqel195pts$observable_start_ym <- ym(tekiyo_Vyndaqel195pts$observable_start_ym)
tekiyo_Vyndaqel195pts$observable_end_ym <- ym(tekiyo_Vyndaqel195pts$observable_end_ym)

unique(tekiyo_Vyndaqel195pts$shibou_flg)

# Vyndaqel Duration  --   Dead patients

tekiyo_Vyndaqel195pts %>% filter(shibou_flg == "1") %>% select(kojin_id) %>% 
  inner_join(receipt_drug_Vyndaqel195pts) %>% 
  select(kojin_id, period) %>% distinct() %>% 
  summarise(n = mean(period))   # 


tekiyo_Vyndaqel195pts %>% filter(shibou_flg == "1") %>% select(kojin_id) %>% 
  inner_join(receipt_drug_Vyndaqel195pts) %>% 
  select(kojin_id, period) %>% distinct() %>% group_by(period) %>% count()

# Vyndaqel Duration  --   Alive patients

tekiyo_Vyndaqel195pts %>% filter(shibou_flg == "") %>% select(kojin_id) %>% 
  inner_join(receipt_drug_Vyndaqel195pts) %>%
  select(kojin_id, period) %>% distinct() %>% summarise(n = mean(period))  # 


data.frame(tekiyo_Vyndaqel195pts %>% filter(shibou_flg == "") %>% select(kojin_id) %>% 
  inner_join(receipt_drug_Vyndaqel195pts) %>% 
  select(kojin_id, period) %>% distinct() %>% group_by(period) %>% count())



# Vyndaqel Duration  --   Alive patients -- ON Vyndaqel until the end

tekiyo_Vyndaqel195pts %>% filter(shibou_flg == "") %>% inner_join(receipt_drug_Vyndaqel195pts) %>%
  mutate(Last_Vyndaqel_toEnd = as.numeric(observable_end_ym - maxdate)) %>% 
  filter(Last_Vyndaqel_toEnd<=61) %>% select(kojin_id, period) %>% distinct() %>% 
  summarise(n = mean(period)) # 


# Vyndaqel Duration  --   Alive patients -- ON Vyndaqel not until the end

tekiyo_Vyndaqel195pts %>% filter(shibou_flg == "") %>% inner_join(receipt_drug_Vyndaqel195pts) %>%
  mutate(Last_Vyndaqel_toEnd = as.numeric(observable_end_ym - maxdate)) %>% 
  filter(Last_Vyndaqel_toEnd>61) %>% select(kojin_id, period) %>% distinct() %>% 
  summarise(n = mean(period)) # 



tekiyo_Vyndaqel195pts %>% filter(shibou_flg == "") %>% inner_join(receipt_drug_Vyndaqel195pts) %>%
   mutate(Last_Vyndaqel_toEnd = as.numeric(observable_end_ym - maxdate)) %>% 
  filter(Last_Vyndaqel_toEnd <= 61) %>% 
  filter(mindate > "2017-06-01" & mindate < "2018-06-01") %>%
  mutate(persistency = as.numeric(observable_end_ym-mindate)) %>%
  select(kojin_id, persistency) %>% distinct() %>% 
  summarise(n = mean(persistency/30.5))



tekiyo_Vyndaqel195pts %>% filter(shibou_flg == "") %>% inner_join(receipt_drug_Vyndaqel195pts) %>%
   mutate(Last_Vyndaqel_toEnd = as.numeric(observable_end_ym - maxdate)) %>% 
  filter(Last_Vyndaqel_toEnd > 61) %>% 
  filter(mindate < "2018-06-01") %>%
  mutate(persistency = as.numeric(observable_end_ym-mindate)) %>%
  select(kojin_id, persistency) %>% distinct() %>% 
  summarise(n = mean(persistency/30.5))



# receipt_drug_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_drug_Vyndaqel195pts.txt", 
#                                      colClasses = "character")
# 
# receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% filter(drug_code == "622278901") %>% select(kojin_id, receipt_ym) 
# receipt_drug_Vyndaqel195pts$receipt_ym <- ym(receipt_drug_Vyndaqel195pts$receipt_ym)
# receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% group_by(kojin_id) %>% mutate(mindate = min(receipt_ym)) %>% mutate(maxdate = max(receipt_ym))
# receipt_drug_Vyndaqel195pts$period <- round(time_length(interval(receipt_drug_Vyndaqel195pts$mindate, receipt_drug_Vyndaqel195pts$maxdate), "month") + 1)
# receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% group_by(kojin_id) %>% mutate(NoScripts = n())
# 
# 
# tekiyo_Vyndaqel195pts <- fread("VyndaqelPts195/tekiyo_Vyndaqel195pts.txt", colClasses = "character")
# tekiyo_Vyndaqel195pts <- tekiyo_Vyndaqel195pts %>% select(kojin_id, observable_start_ym, observable_end_ym, shibou_flg)
# tekiyo_Vyndaqel195pts$observable_start_ym <- ym(tekiyo_Vyndaqel195pts$observable_start_ym)
# tekiyo_Vyndaqel195pts$observable_end_ym <- ym(tekiyo_Vyndaqel195pts$observable_end_ym)
# 
# tekiyo_Vyndaqel195pts  %>% select(kojin_id) %>% 
#   inner_join(receipt_drug_Vyndaqel195pts) %>% 
#   select(kojin_id, period) %>% distinct() %>% group_by(period) %>% count()



# ----------------------------------------------------------------------------------------------------------------
# 195 vyndaqel patients -> ICD10 disease comorbidity penetrance -------------------------------------------------

receipt_diseases_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_diseases_Vyndaqel195pts.txt", 
                                         colClasses = "character")

receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>% select(receipt_ym, kojin_id, diseases_code)

m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")

m_icd10 <- m_icd10 %>% select(diseases_code, icd10_subdiv_code, icd10_subdiv_name_en)


temp <- receipt_diseases_Vyndaqel195pts %>% left_join(m_icd10) %>%
  select(kojin_id, icd10_subdiv_code, icd10_subdiv_name_en) %>% distinct() %>%
  group_by(icd10_subdiv_code, icd10_subdiv_name_en) %>% count()

data.frame(temp %>% mutate(penetrance = 100*n/195) %>% filter(penetrance > 25) %>% arrange(-penetrance) %>%
             filter(icd10_subdiv_code != "")) %>%
  select(-icd10_subdiv_name_en) 

# Codes that appear 6m before vyndaqel start

receipt_diseases_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_diseases_Vyndaqel195pts.txt", 
                                         colClasses = "character")

receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>% select(receipt_ym, kojin_id, diseases_code)

m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")

m_icd10 <- m_icd10 %>% select(diseases_code, icd10_subdiv_code)

receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>% left_join(m_icd10)

receipt_diseases_Vyndaqel195pts$receipt_ym <- ym(receipt_diseases_Vyndaqel195pts$receipt_ym)

# get vyndaqel start date

receipt_drug_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_drug_Vyndaqel195pts.txt", 
                                     colClasses = "character")

receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% filter(drug_code == "622278901") %>% select(kojin_id, receipt_ym) 

receipt_drug_Vyndaqel195pts$receipt_ym <- ym(receipt_drug_Vyndaqel195pts$receipt_ym)

receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% group_by(kojin_id) %>% mutate(mindate = min(receipt_ym)) %>% mutate(maxdate = max(receipt_ym))

receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% select(kojin_id, mindate)

names(receipt_drug_Vyndaqel195pts)[2] <- "VyndaqelStartDate"

receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>% left_join(receipt_drug_Vyndaqel195pts)

receipt_diseases_Vyndaqel195pts$ElapsedTime <- round(time_length(interval(receipt_diseases_Vyndaqel195pts$receipt_ym, receipt_diseases_Vyndaqel195pts$VyndaqelStartDate), "month"))

receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts[receipt_diseases_Vyndaqel195pts$ElapsedTime<0,]

receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts[, .(kojin_id, icd10_subdiv_code, ElapsedTime)]

receipt_diseases_Vyndaqel195pts <- unique(receipt_diseases_Vyndaqel195pts)

temp <- receipt_diseases_Vyndaqel195pts %>% filter(ElapsedTime>(-13)) %>% 
  select(kojin_id, icd10_subdiv_code) %>% distinct() %>%
  anti_join(receipt_diseases_Vyndaqel195pts %>% filter(ElapsedTime<(-13)) %>%
              select(kojin_id, icd10_subdiv_code) %>% distinct()) %>%
  select(kojin_id, icd10_subdiv_code) %>%
  filter(icd10_subdiv_code != "") %>%
  distinct() %>%
  group_by(icd10_subdiv_code) %>% count() %>% arrange(-n)

data.frame(temp)


# --------------------------------------------------------------------------------------------------

# 195 vyndaqel patients -> ICD10 disease comorbidity penetrance CONFIRMED -------------------------------------------------

receipt_diseases_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_diseases_Vyndaqel195pts.txt", 
                                         colClasses = "character")

receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>% filter(utagai_flg==0)

receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>% select(receipt_ym, kojin_id, diseases_code)

m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")

m_icd10 <- m_icd10 %>% select(diseases_code, icd10_subdiv_code, icd10_subdiv_name_en)


temp <- receipt_diseases_Vyndaqel195pts %>% left_join(m_icd10) %>%
  select(kojin_id, icd10_subdiv_code, icd10_subdiv_name_en) %>% distinct() %>%
  group_by(icd10_subdiv_code, icd10_subdiv_name_en) %>% count()

data.frame(temp %>% mutate(penetrance = 100*n/195) %>% filter(penetrance > 25) %>% arrange(-penetrance) %>%
             filter(icd10_subdiv_code != "")) %>%
  select(-icd10_subdiv_name_en) 



Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")
Vyndaqel_pats_CM_vs_PN <- Vyndaqel_pats_CM_vs_PN %>% select(kojin_id, PN, CM, Combo) 
Vyndaqel_pats_CM_vs_PN %>% group_by(PN, CM, Combo) %>% count()

receipt_diseases_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_diseases_Vyndaqel195pts.txt", 
                                         colClasses = "character")
receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>% filter(utagai_flg==0)
receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>% select(receipt_ym, kojin_id, diseases_code)
m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_subdiv_code, icd10_subdiv_name_en)

tempPN <- receipt_diseases_Vyndaqel195pts %>% left_join(m_icd10) %>%
  select(kojin_id, icd10_subdiv_code, icd10_subdiv_name_en) %>% distinct() %>%
  inner_join(Vyndaqel_pats_CM_vs_PN %>% filter(PN==1) %>% select(kojin_id)) %>%
  group_by(icd10_subdiv_code, icd10_subdiv_name_en) %>% count()

data.frame(tempPN %>% mutate(penetrance = 100*n/27) %>% filter(penetrance > 25) %>% arrange(-penetrance) %>%
             filter(icd10_subdiv_code != "")) %>%
  select(-icd10_subdiv_name_en) 



tempCM <- receipt_diseases_Vyndaqel195pts %>% left_join(m_icd10) %>%
  select(kojin_id, icd10_subdiv_code, icd10_subdiv_name_en) %>% distinct() %>%
  inner_join(Vyndaqel_pats_CM_vs_PN %>% filter(PN!=1) %>% select(kojin_id)) %>%
  group_by(icd10_subdiv_code, icd10_subdiv_name_en) %>% count()

data.frame(tempCM %>% mutate(penetrance = 100*n/168) %>% filter(penetrance > 25) %>% arrange(-penetrance) %>%
             filter(icd10_subdiv_code != "")) %>%
  select(-icd10_subdiv_name_en) 


# ------------------------------------------------------------------------------------
# 195 vyndaqel patients -> ICD10 disease comorbidity penetrance DETAILED deep dive -------------------------------------------------


receipt_diseases_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_diseases_Vyndaqel195pts.txt", 
                                         colClasses = "character")

receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>% select(receipt_ym, kojin_id, diseases_code)

receipt_diseases_Vyndaqel195pts <- unique(receipt_diseases_Vyndaqel195pts[,.(kojin_id, diseases_code)])

m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")

m_icd10 <- m_icd10 %>% select(diseases_code, icd10_subdiv_code, icd10_subdiv_name_en)


Diagnosis_master <- fread("Masters/Diagnosis_master.csv", colClasses = "character")
Diagnosis_master <- Diagnosis_master %>% filter(icd10_level3_code=="E85"|icd10_level3_code=="I50"|icd10_level3_code=="I42"|icd10_level3_code=="I43")
Diagnosis_master <- Diagnosis_master[,.(standard_disease_code, standard_disease_name, icd10_level3_code, icd10_level3_name, icd10_level4_code, icd10_level4_name)]
names(Diagnosis_master)[1] <- "diseases_code"

receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>% inner_join(Diagnosis_master)

receipt_diseases_Vyndaqel195pts %>% select(kojin_id, icd10_level4_code, icd10_level4_name) %>%
  distinct() %>% group_by(icd10_level4_code, icd10_level4_name) %>% count() %>%
  arrange(icd10_level4_code, -n)

# repeat with standard disease code


receipt_diseases_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_diseases_Vyndaqel195pts.txt", 
                                         colClasses = "character")

receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>% select(receipt_ym, kojin_id, diseases_code)

receipt_diseases_Vyndaqel195pts <- unique(receipt_diseases_Vyndaqel195pts[,.(kojin_id, diseases_code)])

Diagnosis_master <- fread("Masters/Diagnosis_master.csv", colClasses = "character")
# Diagnosis_master <- Diagnosis_master %>% filter(grepl("cardiomyopathy",standard_disease_name))
Diagnosis_master <- Diagnosis_master[,.(standard_disease_code, standard_disease_name)]
names(Diagnosis_master)[1] <- "diseases_code"

receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>% inner_join(Diagnosis_master)

data.frame(receipt_diseases_Vyndaqel195pts %>% select(kojin_id, standard_disease_name) %>%
  distinct() %>% group_by(standard_disease_name) %>% count() %>%
  arrange(-n))
# 
# -------------------------------------------------------------------------------------------------------------------------------
  
  # 195 vyndaqel patients -> standard disease comorbidity penetrance CM vs PN vs Combo -------------------------------------------------

Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")
Vyndaqel_pats_CM_vs_PN <- Vyndaqel_pats_CM_vs_PN %>% select(kojin_id, PN, CM, Combo) 
Vyndaqel_pats_CM_vs_PN %>% group_by(PN, CM, Combo) %>% count()

receipt_diseases_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_diseases_Vyndaqel195pts.txt", 
                                         colClasses = "character")

receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>% filter(utagai_flg==0)

receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>% select(receipt_ym, kojin_id, diseases_code)

receipt_diseases_Vyndaqel195pts <- unique(receipt_diseases_Vyndaqel195pts[,.(kojin_id, diseases_code)])

# m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
# m_icd10 <- m_icd10 %>% select(diseases_code, icd10_subdiv_code, icd10_subdiv_name_en)

Diagnosis_master <- fread("Masters/Diagnosis_master.csv", colClasses = "character")
Diagnosis_master <- Diagnosis_master %>% filter(grepl("E",icd10_level3_code)|grepl("I",icd10_level3_code)|grepl("G",icd10_level3_code))
Diagnosis_master <- Diagnosis_master[,.(standard_disease_code, standard_disease_name)]
names(Diagnosis_master)[1] <- "diseases_code"

receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>% inner_join(Diagnosis_master)

data.frame(receipt_diseases_Vyndaqel195pts %>% select(kojin_id, standard_disease_name) %>%
             inner_join(Vyndaqel_pats_CM_vs_PN %>% filter(CM==1|Combo==1) %>% select(kojin_id)) %>%
  distinct() %>% group_by(standard_disease_name) %>% count() %>%
    mutate(standard_disease_name=str_replace_all(standard_disease_name," ", "_")) %>%
  arrange(-n))


# ----------------------------------------------------------------
# 195 vyndaqel patients -> Split Vyndaqel pats in Amyloidosis CM vs Amyloidosis PN ------------------------


# Drug usage (when, how much)

receipt_drug_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_drug_Vyndaqel195pts.txt", colClasses = "character")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts[,.(receipt_ym, kojin_id, drug_code, shiyouryou)]
receipt_drug_Vyndaqel195pts$receipt_ym <- as.Date(paste0(as.character(receipt_drug_Vyndaqel195pts$receipt_ym), '/01'))
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% filter(drug_code=="622278901")

Vyndaqel_pats <- receipt_drug_Vyndaqel195pts %>% select(kojin_id) %>% distinct()
Before2919_03_pats <- receipt_drug_Vyndaqel195pts %>% filter(receipt_ym<"2019-03-01") %>% 
  select(kojin_id) %>% distinct() %>% mutate(Before2019_03=1)
Eighthymg_pats <- receipt_drug_Vyndaqel195pts %>% filter(shiyouryou!="1") %>% 
  select(kojin_id) %>% distinct() %>% mutate(Eighthymg=1)
Twentymg_pats <- receipt_drug_Vyndaqel195pts %>% filter(shiyouryou=="1") %>% 
  select(kojin_id) %>% distinct() %>% mutate(Twentymg=1)

Vyndaqel_pats <- Vyndaqel_pats %>% left_join(Before2919_03_pats) %>% left_join(Eighthymg_pats) %>% left_join(Twentymg_pats) %>%
  mutate(Before2019_03 =ifelse(is.na(Before2019_03),0,Before2019_03)) %>%
 mutate(Eighthymg =ifelse(is.na(Eighthymg),0,Eighthymg))  %>%
  mutate(Twentymg =ifelse(is.na(Twentymg),0,Twentymg)) 




#   Disease codes
receipt_diseases_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_diseases_Vyndaqel195pts.txt", 
                                         colClasses = "character")
receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>% select(receipt_ym, kojin_id, diseases_code)
receipt_diseases_Vyndaqel195pts <- unique(receipt_diseases_Vyndaqel195pts[,.(kojin_id, diseases_code)])
m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")

m_icd10 <- m_icd10 %>% select(diseases_code, icd10_subdiv_code, icd10_subdiv_name_en)
m_icd10 <- m_icd10 %>% filter(grepl("E85", icd10_subdiv_code)|
                                grepl("I50", icd10_subdiv_code)|
                                grepl("I42", icd10_subdiv_code)|
                                grepl("I43", icd10_subdiv_code))

receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>% inner_join(m_icd10) %>% 
  select(kojin_id, icd10_subdiv_code, icd10_subdiv_name_en) %>% distinct()

receipt_diseases_Vyndaqel195pts %>% select(icd10_subdiv_code, icd10_subdiv_name_en) %>% distinct()


receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>% select(kojin_id , icd10_subdiv_code) %>% distinct() %>%
  mutate(value=1) %>%
  spread(key=icd10_subdiv_code, value=value)

receipt_diseases_Vyndaqel195pts <- mutate_if(receipt_diseases_Vyndaqel195pts, is.numeric, ~replace(., is.na(.), 0))

receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>% mutate(AmyloidosisType = ifelse(I422==1|I431==1|I429==1|E850==1,"CM",
                                                                    ifelse(E851==1,"PN",NA)))

receipt_diseases_Vyndaqel195pts %>% group_by(AmyloidosisType) %>% count()

Vyndaqel_pats <- Vyndaqel_pats %>% left_join(receipt_diseases_Vyndaqel195pts)

Vyndaqel_pats %>% group_by(AmyloidosisType) %>% count()
Vyndaqel_pats <- Vyndaqel_pats %>% select(-AmyloidosisType)



Vyndaqel_pats <- Vyndaqel_pats %>% mutate(PN=ifelse(E851==1,1,0)) %>%
  mutate(CM=ifelse((I422==1|I431==1|I429==1|E850==1),1,0)) 

Vyndaqel_pats %>% group_by(CM, PN) %>% count()

Vyndaqel_pats <- Vyndaqel_pats %>% mutate(Combo=ifelse(CM==1&(Twentymg==1|Before2019_03==1),1,0))
Vyndaqel_pats <- Vyndaqel_pats %>% mutate(PN=ifelse(CM==1&PN==1&Twentymg==0&Before2019_03==0,0,PN))


Vyndaqel_pats <- Vyndaqel_pats %>% mutate(PN=ifelse(Combo==1,0,PN))
Vyndaqel_pats <- Vyndaqel_pats %>% mutate(CM=ifelse(Combo==1,0,CM))

Vyndaqel_pats %>% group_by(CM, PN, Combo) %>% count()

fwrite(Vyndaqel_pats, "VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", sep="\t")

# ------------------------------------------------------------------------------
# 195 vyndaqel patients ->  Gap fill Vyndaqel scripts to track inflows/outflows ------------------------------------------------

receipt_drug_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_drug_Vyndaqel195pts.txt", colClasses = "character")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts[,.(kojin_id, receipt_ym, drug_code)]
# receipt_drug_Vyndaqel195pts$receipt_ym <- as.Date(paste0(as.character(receipt_drug_Vyndaqel195pts$receipt_ym), '/01'))
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% filter(drug_code=="622278901")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% select(-c(drug_code))

Exact_Month_Lookup <- receipt_drug_Vyndaqel195pts %>% select(receipt_ym) %>% distinct() %>% arrange(receipt_ym) %>%
  mutate(Exact_Month=row_number())
names(Exact_Month_Lookup)[2] <- "Month"

receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% select(receipt_ym) %>% distinct() %>% arrange(receipt_ym) %>%
  mutate(Exact_Month=row_number()) %>% left_join(receipt_drug_Vyndaqel195pts)


receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% select(kojin_id, Exact_Month) %>% distinct()
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% mutate(value=1) %>% spread(key=Exact_Month, value=value)
receipt_drug_Vyndaqel195pts <- mutate_if(receipt_drug_Vyndaqel195pts, is.numeric, ~replace(., is.na(.), 0))

fwrite(receipt_drug_Vyndaqel195pts, "VyndaqelPts195/GapFill_Vyndaqel.csv", sep=",")


GapFillVyndael <- fread("VyndaqelPts195/GapFill_Vyndaqel.csv", sep=",")

GapFillVyndael <- gather(GapFillVyndael, Month, Treat, 2:88, factor_key=TRUE)
GapFillVyndael$Month <- as.numeric(GapFillVyndael$Month)

GapFillVyndael <- GapFillVyndael %>% left_join(Exact_Month_Lookup)
GapFillVyndael$receipt_ym <- as.Date(paste0(as.character(GapFillVyndael$receipt_ym), '/01'))


# Cut from date of drop out/death 
tekiyo_Vyndaqel195pts <- fread("VyndaqelPts195/tekiyo_Vyndaqel195pts.txt")
tekiyo_Vyndaqel195pts <- tekiyo_Vyndaqel195pts %>% select(kojin_id, observable_end_ym)
tekiyo_Vyndaqel195pts$observable_end_ym <- as.Date(paste0(as.character(tekiyo_Vyndaqel195pts$observable_end_ym), '/01'))

GapFillVyndael <- GapFillVyndael %>% left_join(tekiyo_Vyndaqel195pts)
GapFillVyndael <- GapFillVyndael %>% group_by(kojin_id) %>% filter(receipt_ym<=observable_end_ym)

GapFillVyndael <- GapFillVyndael %>% ungroup() %>% select(kojin_id, Month, Treat) %>% spread(key=Month, value=Treat)
temp <- GapFillVyndael

temp <- gather(temp, Month, Treat, 2:88, factor_key=TRUE)

temp <- temp %>% group_by(kojin_id) %>% mutate(flow=ifelse(lag(Treat)!=Treat,1,0))
temp <- temp %>% group_by(kojin_id) %>% mutate(Inflow=ifelse(lag(Treat)!=Treat&Treat==1,1,0))
temp <- temp %>% group_by(kojin_id) %>% mutate(Outflow=ifelse(lag(Treat)!=Treat&Treat==0,1,0))




# Weights 
VyndaqelPts195 <- fread("VyndaqelPts195/tekiyo_Vyndaqel195pts.txt", colClasses = "character")
VyndaqelPts195 <- VyndaqelPts195 %>% select(kojin_id, birth_ym, sex_code)
VyndaqelPts195[, gender:= ifelse(sex_code == 1, "M","F")]
VyndaqelPts195 <- VyndaqelPts195 %>% select(-sex_code)
VyndaqelPts195$birth_ym <- as.Date(paste0(as.character(VyndaqelPts195$birth_ym), '/01'))
VyndaqelPts195$age <- round(time_length(interval(VyndaqelPts195$birth_ym, ymd("2021-08-01")), "year"))
VyndaqelPts195 <- VyndaqelPts195 %>% select(-birth_ym)
VyndaqelPts195 <- VyndaqelPts195 %>% mutate(age=ifelse(age>=95,95,age))
VyndaqelPts195$age <- as.character(VyndaqelPts195$age)
ContinuouslyEnrolled_Y3_tekiyo_weights <- fread("All_Pts_ContinuousEnrolled/ContinuouslyEnrolled_Y3_tekiyo_weights.txt", colClasses = "character")
VyndaqelPts195 <- VyndaqelPts195  %>% left_join(ContinuouslyEnrolled_Y3_tekiyo_weights %>% select(age, gender, weight) %>% distinct())
VyndaqelPts195 <- VyndaqelPts195 %>% select(kojin_id, weight)
sum(as.numeric(VyndaqelPts195$weight))
VyndaqelPts195$kojin_id <- as.numeric(VyndaqelPts195$kojin_id)

Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", sep="\t")
Vyndaqel_pats_CM_vs_PN <- Vyndaqel_pats_CM_vs_PN %>% filter(CM==1|PN==1) %>% select(kojin_id)

data.frame(temp  %>% ungroup() %>% select(Month) %>% distinct()  %>% 
  left_join(temp %>% inner_join(VyndaqelPts195) %>% inner_join(Vyndaqel_pats_CM_vs_PN) %>% ungroup() %>% filter(Inflow==1) %>% group_by(Month) %>% summarise(n=sum(as.numeric(weight))) %>% ungroup()) %>% 
  mutate(n=ifelse(is.na(n),0,n)))


data.frame(temp %>% ungroup() %>% select(Month) %>% distinct()  %>% 
  left_join(temp %>% inner_join(VyndaqelPts195) %>% inner_join(Vyndaqel_pats_CM_vs_PN) %>% ungroup() %>% filter(Outflow==1) %>% group_by(Month) %>%summarise(n=sum(as.numeric(weight))) %>% ungroup()) %>% 
  mutate(n=ifelse(is.na(n),0,n)))


data.frame(temp %>% ungroup() %>% select(Month) %>% distinct()  %>% 
  left_join(temp %>% inner_join(VyndaqelPts195) %>% inner_join(Vyndaqel_pats_CM_vs_PN) %>% ungroup() %>% filter(Treat==1) %>% group_by(Month) %>% summarise(n=sum(as.numeric(weight)))  %>% ungroup()) %>% 
  mutate(n=ifelse(is.na(n),0,n)))


data.frame(temp %>% ungroup() %>% select(Month) %>% distinct() %>%
  left_join(temp %>% inner_join(VyndaqelPts195) %>% inner_join(Vyndaqel_pats_CM_vs_PN) %>%  ungroup() %>% 
              select(kojin_id, Month, Treat, weight)) %>% mutate(Treat=ifelse(is.na(Treat),0,Treat)) %>%
  group_by(kojin_id) %>% mutate(cum=cumsum(Treat)) %>%
  filter(cum!=0) %>%
  ungroup() %>% group_by(Month) %>% summarise(n=sum(as.numeric(weight))))
  

# Repeat spliting CM vs PN

Vyndaqel_pats <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", sep="\t")
Vyndaqel_pats <- Vyndaqel_pats %>% select(kojin_id, PN, CM,Combo)
Vyndaqel_pats %>% group_by(CM,PN, Combo) %>% count()

length(unique(temp$kojin_id)) 
length(unique(Vyndaqel_pats$kojin_id)) 
length(unique(VyndaqelPts195$kojin_id)) 



data.frame(temp %>% ungroup() %>% select(Month) %>% distinct()  %>% 
  left_join(Vyndaqel_pats %>% filter(PN==1) %>% select(kojin_id) %>% 
              inner_join(tekiyo_All_ContEnr_pts) %>%
              left_join(VyndaqelPts195) %>% 
              left_join(temp) %>% ungroup() %>% filter(Treat==1) %>% group_by(Month) %>% summarise(PN=sum(as.numeric(weight))) %>% ungroup()) %>% 
  mutate(PN=ifelse(is.na(PN),0,PN))) %>%
  left_join(
    data.frame(temp %>% ungroup() %>% select(Month) %>% distinct()  %>% 
  left_join(Vyndaqel_pats %>% filter(Combo==1) %>% select(kojin_id) %>% 
              inner_join(tekiyo_All_ContEnr_pts) %>%
              left_join(VyndaqelPts195) %>% 
              left_join(temp) %>% ungroup() %>% filter(Treat==1) %>% group_by(Month) %>% summarise(Combo=sum(as.numeric(weight))) %>% ungroup()) %>% 
  mutate(Combo=ifelse(is.na(Combo),0,Combo)))) %>%
  left_join(
    data.frame(temp %>% ungroup() %>% select(Month) %>% distinct()  %>% 
  left_join(Vyndaqel_pats %>% filter(CM==1) %>% select(kojin_id) %>% 
              inner_join(tekiyo_All_ContEnr_pts) %>%
              left_join(VyndaqelPts195) %>% 
              left_join(temp) %>% ungroup() %>% filter(Treat==1) %>% group_by(Month) %>% summarise(CM=sum(as.numeric(weight))) %>% ungroup()) %>% 
  mutate(CM=ifelse(is.na(CM),0,CM)))) %>%
  mutate(Month=as.numeric(Month)) %>% filter(Month<=82) %>%
  gather(Group, Pop, PN:CM, factor_key=TRUE) %>%
  mutate(Pop=1.756904*Pop) %>%
  left_join(Exact_Month_Lookup) %>%
  mutate(receipt_ym=as.Date(receipt_ym)) %>%
  ggplot(aes(receipt_ym, Pop, colour=Group, fill=Group)) +
  geom_smooth(se = FALSE, size=3) +
  theme_minimal() +
  scale_color_manual(values=c("#000077", "#f3af01", "#970000")) +
    scale_fill_manual(values=c("#000077", "#f3af01", "#970000")) 
  




tekiyo_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/tekiyo_All_ContEnr_pts.txt")
tekiyo_All_ContEnr_pts <- tekiyo_All_ContEnr_pts %>% select(kojin_id) %>% distinct()


data.frame(temp %>% ungroup() %>% select(Month) %>% distinct() %>%
  left_join(Vyndaqel_pats %>% filter(PN==1) %>% select(kojin_id) %>% left_join(temp) %>% ungroup() %>% select(kojin_id, Month, Treat)) %>% mutate(Treat=ifelse(is.na(Treat),0,Treat)) %>%
  group_by(kojin_id) %>% mutate(cum=cumsum(Treat)) %>%
  filter(cum!=0) %>%
  ungroup() %>% group_by(Month) %>% count())
  



# -----------------------------------------------------------------------------------------------------------------------------------------------
# 195 vyndaqel patients ->  Reasons for stopping vyndaqel ---------------------------------------------------------
receipt_drug_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_drug_Vyndaqel195pts.txt", colClasses = "character")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts[,.(kojin_id, receipt_ym, drug_code)]
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% filter(drug_code=="622278901")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% select(-c(drug_code))

Exact_Month_Lookup <- receipt_drug_Vyndaqel195pts %>% select(receipt_ym) %>% distinct() %>% arrange(receipt_ym) %>%
  mutate(Exact_Month=row_number())
names(Exact_Month_Lookup)[2] <- "Month"

GapFillVyndael <- fread("VyndaqelPts195/GapFill_Vyndaqel.csv", sep=",")
GapFillVyndael <- gather(GapFillVyndael, Month, Treat, 2:88, factor_key=TRUE)
GapFillVyndael$Month <- as.numeric(GapFillVyndael$Month)
GapFillVyndael <- GapFillVyndael %>% left_join(Exact_Month_Lookup)
GapFillVyndael$receipt_ym <- as.Date(paste0(as.character(GapFillVyndael$receipt_ym), '/01'))


# LAST Obeservale and Death dates
tekiyo_Vyndaqel195pts <- fread("VyndaqelPts195/tekiyo_Vyndaqel195pts.txt")
tekiyo_Vyndaqel195pts <- tekiyo_Vyndaqel195pts %>% select(kojin_id, observable_end_ym, shibou_flg)
tekiyo_Vyndaqel195pts$observable_end_ym <- as.Date(paste0(as.character(tekiyo_Vyndaqel195pts$observable_end_ym), '/01'))

Death_date <- tekiyo_Vyndaqel195pts %>% filter(shibou_flg==1) %>% select(kojin_id, observable_end_ym)
names(Death_date)[2] <- "Death_Date"


GapFillVyndael <- GapFillVyndael %>% left_join(Death_date) %>% left_join(tekiyo_Vyndaqel195pts %>% filter(is.na(shibou_flg)) %>% select(kojin_id, observable_end_ym))


GapFillVyndael <- GapFillVyndael %>% filter(receipt_ym<="2021-03-01") # MAX is month 82

# 183 had Vyndqel before month 82  or "2021-03-01"
GapFillVyndael %>% group_by(kojin_id) %>% filter(Treat==1) %>% filter(Month==max(Month))

GapFillVyndael %>% group_by(kojin_id) %>% filter(Treat==1) %>% filter(Month==max(Month)) %>%
  filter(Month==82) # 
GapFillVyndael <- GapFillVyndael %>% group_by(kojin_id) %>% filter(Treat==1) %>% filter(Month==max(Month)) %>%
  filter(Month<82) # 

GapFillVyndael %>% filter((Death_Date<=receipt_ym)|(Death_Date==receipt_ym)) # 5 died stopped upon death
GapFillVyndael <- GapFillVyndael %>% anti_join(GapFillVyndael %>% filter((Death_Date<=receipt_ym)|(Death_Date==receipt_ym)) %>% select(kojin_id)) 

GapFillVyndael %>% filter( (observable_end_ym<receipt_ym)|(observable_end_ym==receipt_ym)|(as.numeric(observable_end_ym-receipt_ym)<92)) #

GapFillVyndael <- GapFillVyndael %>% anti_join(GapFillVyndael %>% filter( (observable_end_ym<receipt_ym)|(observable_end_ym==receipt_ym)|(as.numeric(observable_end_ym-receipt_ym)<92))) 

GapFillVyndael %>% left_join(Onpattro_Start) %>% filter( (Onpattro_Start>receipt_ym)|(Onpattro_Start==receipt_ym)|(as.numeric(Onpattro_Start-receipt_ym)<92) ) %>%
  select(kojin_id) %>% distinct() # 



# Move to Onpatro
receipt_drug_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_drug_Vyndaqel195pts.txt", colClasses = "character")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts[,.(kojin_id, receipt_ym, drug_code)]
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% filter(drug_code=="622687701")
receipt_drug_Vyndaqel195pts$receipt_ym <- as.Date(paste0(as.character(receipt_drug_Vyndaqel195pts$receipt_ym), '/01'))
names(receipt_drug_Vyndaqel195pts)[2] <- "Onpattro_Start"
Onpattro_Start <- receipt_drug_Vyndaqel195pts
Onpattro_Start$kojin_id <- as.numeric(Onpattro_Start$kojin_id)
Onpattro_Start <- Onpattro_Start %>% select(kojin_id, Onpattro_Start)

# ------------------------------------------------------------------------------------------------
# 195 vyndaqel patients ->  Reasons for stopping vyndaqelCM only  ---------------------------------------------------------
receipt_drug_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_drug_Vyndaqel195pts.txt", colClasses = "character")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts[,.(kojin_id, receipt_ym, drug_code)]
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% filter(drug_code=="622278901")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% select(-c(drug_code))

Exact_Month_Lookup <- receipt_drug_Vyndaqel195pts %>% select(receipt_ym) %>% distinct() %>% arrange(receipt_ym) %>%
  mutate(Exact_Month=row_number())
names(Exact_Month_Lookup)[2] <- "Month"

GapFillVyndael <- fread("VyndaqelPts195/GapFill_Vyndaqel.csv", sep=",")
GapFillVyndael <- gather(GapFillVyndael, Month, Treat, 2:88, factor_key=TRUE)
GapFillVyndael$Month <- as.numeric(GapFillVyndael$Month)
GapFillVyndael <- GapFillVyndael %>% left_join(Exact_Month_Lookup)
GapFillVyndael$receipt_ym <- as.Date(paste0(as.character(GapFillVyndael$receipt_ym), '/01'))


# LAST Obeservale and Death dates
tekiyo_Vyndaqel195pts <- fread("VyndaqelPts195/tekiyo_Vyndaqel195pts.txt")
tekiyo_Vyndaqel195pts <- tekiyo_Vyndaqel195pts %>% select(kojin_id, observable_end_ym, shibou_flg)
tekiyo_Vyndaqel195pts$observable_end_ym <- as.Date(paste0(as.character(tekiyo_Vyndaqel195pts$observable_end_ym), '/01'))

Death_date <- tekiyo_Vyndaqel195pts %>% filter(shibou_flg==1) %>% select(kojin_id, observable_end_ym)
names(Death_date)[2] <- "Death_Date"


GapFillVyndael <- GapFillVyndael %>% left_join(Death_date) %>% left_join(tekiyo_Vyndaqel195pts %>% filter(is.na(shibou_flg)) %>% select(kojin_id, observable_end_ym))


GapFillVyndael <- GapFillVyndael %>% filter(receipt_ym<="2021-03-01") # MAX is month 82

Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", sep="\t")
Vyndaqel_pats_CM_vs_PN <- Vyndaqel_pats_CM_vs_PN %>% filter(CM==1|PN==1) %>% select(kojin_id)


# 147 had Vyndqel before month 82  or "2021-03-01"
GapFillVyndael %>% group_by(kojin_id) %>% filter(Treat==1) %>% filter(Month==max(Month)) %>% inner_join(Vyndaqel_pats_CM_vs_PN)

GapFillVyndael  %>% inner_join(Vyndaqel_pats_CM_vs_PN) %>% group_by(kojin_id) %>% filter(Treat==1) %>% filter(Month==max(Month)) %>%
  filter(Month==82) # 

GapFillVyndael <- GapFillVyndael %>% inner_join(Vyndaqel_pats_CM_vs_PN)  %>% group_by(kojin_id) %>% filter(Treat==1) %>% filter(Month==max(Month)) %>%
  filter(Month<82) #

GapFillVyndael %>% filter((Death_Date<=receipt_ym)|(Death_Date==receipt_ym)) # 
GapFillVyndael <- GapFillVyndael %>% anti_join(GapFillVyndael %>% filter((Death_Date<=receipt_ym)|(Death_Date==receipt_ym)) %>% select(kojin_id)) 

GapFillVyndael %>% filter( (observable_end_ym<receipt_ym)|(observable_end_ym==receipt_ym)|(as.numeric(observable_end_ym-receipt_ym)<92)) # 

GapFillVyndael <- GapFillVyndael %>% anti_join(GapFillVyndael %>% filter( (observable_end_ym<receipt_ym)|(observable_end_ym==receipt_ym)|(as.numeric(observable_end_ym-receipt_ym)<92))) 

GapFillVyndael %>% left_join(Onpattro_Start) %>% filter( (Onpattro_Start>receipt_ym)|(Onpattro_Start==receipt_ym)|(as.numeric(Onpattro_Start-receipt_ym)<92) ) %>%
  select(kojin_id) %>% distinct() # 



# Move to Onpatro
receipt_drug_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_drug_Vyndaqel195pts.txt", colClasses = "character")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts[,.(kojin_id, receipt_ym, drug_code)]
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% filter(drug_code=="622687701")
receipt_drug_Vyndaqel195pts$receipt_ym <- as.Date(paste0(as.character(receipt_drug_Vyndaqel195pts$receipt_ym), '/01'))
names(receipt_drug_Vyndaqel195pts)[2] <- "Onpattro_Start"
Onpattro_Start <- receipt_drug_Vyndaqel195pts
Onpattro_Start$kojin_id <- as.numeric(Onpattro_Start$kojin_id)
Onpattro_Start <- Onpattro_Start %>% select(kojin_id, Onpattro_Start)


# ---------------------------------
# 195 vyndaqel patients -> Health checkups ------------------------------------------------------------------------------------


exam_interview_Vyndaqel195pts <- fread("exam_interview_Vyndaqel195pts.txt", colClasses = "character")
length(unique(exam_interview_Vyndaqel195pts$kojin_id)) # 34

# BMI
exam_interview_Vyndaqel195pts$bmi <- as.numeric(exam_interview_Vyndaqel195pts$bmi)

exam_interview_Vyndaqel195pts %>% mutate(weight=as.numeric(bmi)) %>% select(kojin_id, bmi) %>% 
  group_by(kojin_id) %>% summarise(bmi=mean(bmi)) %>% ungroup() %>% summarise(n=mean(bmi)) # 
  
exam_interview_Vyndaqel195pts %>% mutate(weight=as.numeric(bmi)) %>% select(kojin_id, bmi) %>% 
  group_by(kojin_id) %>% summarise(bmi=mean(bmi)) %>% ungroup() %>%
  ggplot(aes(bmi)) +
  geom_density(alpha = 0.8, fill="darkblue") +
  theme_classic() + 
  theme(legend.title = element_blank(), legend.position = "top", legend.justification = "right") +
  ggtitle("Proportion of Vyndaqel patients") +
  xlab("\n BMI (kg/m2") +
  ylab("Proportion\n")



# fukui
exam_interview_Vyndaqel195pts$fukui <- as.numeric(exam_interview_Vyndaqel195pts$fukui)

exam_interview_Vyndaqel195pts %>% mutate(fukui=as.numeric(fukui)) %>% select(kojin_id, fukui) %>% 
  group_by(kojin_id) %>% summarise(fukui=mean(fukui, na.rm=T)) %>% ungroup() %>% summarise(n=mean(fukui, na.rm=T)) #
  
exam_interview_Vyndaqel195pts %>% mutate(fukui=as.numeric(fukui)) %>% select(kojin_id, fukui) %>% 
  group_by(kojin_id) %>% summarise(fukui=mean(fukui, na.rm=T)) %>% ungroup() %>%
  ggplot(aes(fukui)) +
  geom_density(alpha = 0.8, fill="darkblue") +
  theme_classic() + 
  theme(legend.title = element_blank(), legend.position = "top", legend.justification = "right") +
  ggtitle("Proportion of Vyndaqel patients") +
  xlab("\n Waist circumference (cm)") +
  ylab("Proportion\n")


# Systolic blood pressure
exam_interview_Vyndaqel195pts <- exam_interview_Vyndaqel195pts %>% select(kojin_id, systolic_blood_pressure_other, systolic_blood_pressure2, systolic_blood_pressure1)

exam_interview_Vyndaqel195pts <- gather(exam_interview_Vyndaqel195pts, source, SBP, systolic_blood_pressure_other:systolic_blood_pressure1, factor_key=TRUE)
exam_interview_Vyndaqel195pts <- exam_interview_Vyndaqel195pts %>% select(-source)

exam_interview_Vyndaqel195pts$SBP <- as.numeric(exam_interview_Vyndaqel195pts$SBP)

exam_interview_Vyndaqel195pts %>% drop_na() %>% group_by(kojin_id) %>% 
  summarise(SBP = mean(SBP, na.rm=T)) %>% 
  ungroup()  %>% summarise(n=mean(SBP))  # 


exam_interview_Vyndaqel195pts %>% drop_na() %>% group_by(kojin_id) %>% 
  summarise(SBP = mean(SBP, na.rm=T)) %>% 
  ungroup()  %>%
  ggplot(aes(SBP)) +
  geom_density(alpha = 0.8, fill="darkblue") +
  theme_classic() + 
  theme(legend.title = element_blank(), legend.position = "top", legend.justification = "right") +
  ggtitle("Proportion of Vyndaqel patients") +
  xlab("\n Systolic Blood Pressure (mmHg)") +
  ylab("Proportion\n")



# Dyastolic blood pressure
exam_interview_Vyndaqel195pts <- fread("exam_interview_Vyndaqel195pts.txt", colClasses = "character")

exam_interview_Vyndaqel195pts <- exam_interview_Vyndaqel195pts %>% select(kojin_id, diastolic_blood_pressure_other, diastolic_blood_pressure2, diastolic_blood_pressure1)

exam_interview_Vyndaqel195pts <- gather(exam_interview_Vyndaqel195pts, source, DBP, diastolic_blood_pressure_other:diastolic_blood_pressure1, factor_key=TRUE)
exam_interview_Vyndaqel195pts <- exam_interview_Vyndaqel195pts %>% select(-source)

exam_interview_Vyndaqel195pts$DBP <- as.numeric(exam_interview_Vyndaqel195pts$DBP)

exam_interview_Vyndaqel195pts %>% drop_na() %>% group_by(kojin_id) %>% 
  summarise(DBP = mean(DBP, na.rm=T)) %>% 
  ungroup()  %>% summarise(n=mean(DBP))  # 


exam_interview_Vyndaqel195pts %>% drop_na() %>% group_by(kojin_id) %>% 
  summarise(DBP = mean(DBP, na.rm=T)) %>% 
  ungroup()  %>%
  ggplot(aes(DBP)) +
  geom_density(alpha = 0.8, fill="darkblue") +
  theme_classic() + 
  theme(legend.title = element_blank(), legend.position = "top", legend.justification = "right") +
  ggtitle("Proportion of Vyndaqel patients") +
  xlab("\n Diastolic Blood Pressure (mmHg)") +
  ylab("Proportion\n")



# Triglycerides
exam_interview_Vyndaqel195pts <- fread("exam_interview_Vyndaqel195pts.txt", colClasses = "character")

exam_interview_Vyndaqel195pts <- exam_interview_Vyndaqel195pts %>% select(kojin_id, chusei_shibou_kashi, chusei_shibou_other, chusei_shibou_shigai)

exam_interview_Vyndaqel195pts <- gather(exam_interview_Vyndaqel195pts, source, Triglycerides, chusei_shibou_kashi:chusei_shibou_shigai, factor_key=TRUE)
exam_interview_Vyndaqel195pts <- exam_interview_Vyndaqel195pts %>% select(-source)

exam_interview_Vyndaqel195pts$Triglycerides <- as.numeric(exam_interview_Vyndaqel195pts$Triglycerides)

exam_interview_Vyndaqel195pts %>% drop_na() %>% group_by(kojin_id) %>% 
  summarise(Triglycerides = mean(Triglycerides, na.rm=T)) %>% 
  ungroup()  %>% summarise(n=mean(Triglycerides))  # 

exam_interview_Vyndaqel195pts %>% drop_na() %>% group_by(kojin_id) %>% 
  summarise(Triglycerides = mean(Triglycerides, na.rm=T)) %>% 
  ungroup()  %>%
  ggplot(aes(Triglycerides)) +
  geom_density(alpha = 0.8, fill="darkblue") +
  theme_classic() + 
  theme(legend.title = element_blank(), legend.position = "top", legend.justification = "right") +
  ggtitle("Proportion of Vyndaqel patients") +
  xlab("\n Triglycerides (mg/dL)") +
  ylab("Proportion\n")


# HDL
exam_interview_Vyndaqel195pts <- fread("exam_interview_Vyndaqel195pts.txt", colClasses = "character")

exam_interview_Vyndaqel195pts <- exam_interview_Vyndaqel195pts %>% select(kojin_id, hdl_kashi, hdl_shigai, hdl_other)

exam_interview_Vyndaqel195pts <- gather(exam_interview_Vyndaqel195pts, source, HDL, hdl_kashi:hdl_other, factor_key=TRUE)
exam_interview_Vyndaqel195pts <- exam_interview_Vyndaqel195pts %>% select(-source)

exam_interview_Vyndaqel195pts$HDL <- as.numeric(exam_interview_Vyndaqel195pts$HDL)

exam_interview_Vyndaqel195pts %>% drop_na() %>% group_by(kojin_id) %>% 
  summarise(HDL = mean(HDL, na.rm=T)) %>% 
  ungroup()  %>% summarise(n=mean(HDL))  # 

exam_interview_Vyndaqel195pts %>% drop_na() %>% group_by(kojin_id) %>% 
  summarise(HDL = mean(HDL, na.rm=T)) %>% 
  ungroup()  %>%
  ggplot(aes(HDL)) +
  geom_density(alpha = 0.8, fill="darkblue") +
  theme_classic() + 
  theme(legend.title = element_blank(), legend.position = "top", legend.justification = "right") +
  ggtitle("Proportion of Vyndaqel patients") +
  xlab("\n HDL (mg/dL)") +
  ylab("Proportion\n")



# LDL
exam_interview_Vyndaqel195pts <- fread("exam_interview_Vyndaqel195pts.txt", colClasses = "character")

exam_interview_Vyndaqel195pts <- exam_interview_Vyndaqel195pts %>% select(kojin_id, ldl_kashi, ldl_shigai, ldl_other)

exam_interview_Vyndaqel195pts <- gather(exam_interview_Vyndaqel195pts, source, LDL, ldl_kashi:ldl_other, factor_key=TRUE)
exam_interview_Vyndaqel195pts <- exam_interview_Vyndaqel195pts %>% select(-source)

exam_interview_Vyndaqel195pts$LDL <- as.numeric(exam_interview_Vyndaqel195pts$LDL)

exam_interview_Vyndaqel195pts %>% drop_na() %>% group_by(kojin_id) %>% 
  summarise(LDL = mean(LDL, na.rm=T)) %>% 
  ungroup()  %>% summarise(n=mean(LDL))  # 

exam_interview_Vyndaqel195pts %>% drop_na() %>% group_by(kojin_id) %>% 
  summarise(LDL = mean(LDL, na.rm=T)) %>% 
  ungroup()  %>%
  ggplot(aes(LDL)) +
  geom_density(alpha = 0.8, fill="darkblue") +
  theme_classic() + 
  theme(legend.title = element_blank(), legend.position = "top", legend.justification = "right") +
  ggtitle("Proportion of Vyndaqel patients") +
  xlab("\n LDL (mg/dL)") +
  ylab("Proportion\n")






# GOT
exam_interview_Vyndaqel195pts <- fread("exam_interview_Vyndaqel195pts.txt", colClasses = "character")

exam_interview_Vyndaqel195pts <- exam_interview_Vyndaqel195pts %>% select(kojin_id, got_shigai, got_other)

exam_interview_Vyndaqel195pts <- gather(exam_interview_Vyndaqel195pts, source, GOT, got_shigai:got_other, factor_key=TRUE)
exam_interview_Vyndaqel195pts <- exam_interview_Vyndaqel195pts %>% select(-source)

exam_interview_Vyndaqel195pts$GOT <- as.numeric(exam_interview_Vyndaqel195pts$GOT)

exam_interview_Vyndaqel195pts %>% drop_na() %>% group_by(kojin_id) %>% 
  summarise(GOT) %>% 
  ungroup()  %>% summarise(n=mean(GOT))  # 

exam_interview_Vyndaqel195pts %>% drop_na() %>% group_by(kojin_id) %>% 
  summarise(GOT = mean(GOT, na.rm=T)) %>% 
  ungroup()  %>%
  ggplot(aes(GOT)) +
  geom_density(alpha = 0.8, fill="darkblue") +
  theme_classic() + 
  theme(legend.title = element_blank(), legend.position = "top", legend.justification = "right") +
  ggtitle("Proportion of Vyndaqel patients") +
  xlab("\n AST (IU/L)") +
  ylab("Proportion\n")



# GPT
exam_interview_Vyndaqel195pts <- fread("exam_interview_Vyndaqel195pts.txt", colClasses = "character")

exam_interview_Vyndaqel195pts <- exam_interview_Vyndaqel195pts %>% select(kojin_id, gpt_shigai, gpt_other)

exam_interview_Vyndaqel195pts <- gather(exam_interview_Vyndaqel195pts, source, GPT, gpt_shigai:gpt_other, factor_key=TRUE)
exam_interview_Vyndaqel195pts <- exam_interview_Vyndaqel195pts %>% select(-source)

exam_interview_Vyndaqel195pts$GPT <- as.numeric(exam_interview_Vyndaqel195pts$GPT)

exam_interview_Vyndaqel195pts %>% drop_na() %>% group_by(kojin_id) %>% 
  summarise(GPT) %>% 
  ungroup()  %>% summarise(n=mean(GPT))  # 

exam_interview_Vyndaqel195pts %>% drop_na() %>% group_by(kojin_id) %>% 
  summarise(GPT = mean(GPT, na.rm=T)) %>% 
  ungroup()  %>%
  ggplot(aes(GPT)) +
  geom_density(alpha = 0.8, fill="darkblue") +
  theme_classic() + 
  theme(legend.title = element_blank(), legend.position = "top", legend.justification = "right") +
  ggtitle("Proportion of Vyndaqel patients") +
  xlab("\n ALT (IU/L)") +
  ylab("Proportion\n")




# GGT
exam_interview_Vyndaqel195pts <- fread("exam_interview_Vyndaqel195pts.txt", colClasses = "character")

exam_interview_Vyndaqel195pts <- exam_interview_Vyndaqel195pts %>% select(kojin_id, gamma_gt_kashi, gamma_gt_other)

exam_interview_Vyndaqel195pts <- gather(exam_interview_Vyndaqel195pts, source, GGT, gamma_gt_kashi:gamma_gt_other, factor_key=TRUE)
exam_interview_Vyndaqel195pts <- exam_interview_Vyndaqel195pts %>% select(-source)

exam_interview_Vyndaqel195pts$GGT <- as.numeric(exam_interview_Vyndaqel195pts$GGT)

exam_interview_Vyndaqel195pts %>% drop_na() %>% group_by(kojin_id) %>% 
  summarise(GGT) %>% 
  ungroup()  %>% summarise(n=mean(GGT))  # 

exam_interview_Vyndaqel195pts %>% drop_na() %>% group_by(kojin_id) %>% 
  summarise(GGT = mean(GGT, na.rm=T)) %>% 
  ungroup()  %>%
  ggplot(aes(GGT)) +
  geom_density(alpha = 0.8, fill="darkblue") +
  theme_classic() + 
  theme(legend.title = element_blank(), legend.position = "top", legend.justification = "right") +
  ggtitle("Proportion of Vyndaqel patients") +
  xlab("\n GGT (IU/L)") +
  ylab("Proportion\n")




# Fasting glucose
exam_interview_Vyndaqel195pts <- fread("exam_interview_Vyndaqel195pts.txt", colClasses = "character")

exam_interview_Vyndaqel195pts <- exam_interview_Vyndaqel195pts %>% select(kojin_id, kuufukuji_ketto_denisahou, kuufukuji_ketto_kashi, kuufukuji_ketto_shigai, kuufukuji_ketto_other)

exam_interview_Vyndaqel195pts <- gather(exam_interview_Vyndaqel195pts, source, FastingGlucose, kuufukuji_ketto_denisahou:kuufukuji_ketto_other, factor_key=TRUE)
exam_interview_Vyndaqel195pts <- exam_interview_Vyndaqel195pts %>% select(-source)

exam_interview_Vyndaqel195pts$FastingGlucose <- as.numeric(exam_interview_Vyndaqel195pts$FastingGlucose)

exam_interview_Vyndaqel195pts %>% drop_na() %>% group_by(kojin_id) %>% 
  summarise(FastingGlucose) %>% 
  ungroup()  %>% summarise(n=mean(FastingGlucose))  # 

exam_interview_Vyndaqel195pts %>% drop_na() %>% group_by(kojin_id) %>% 
  summarise(FastingGlucose = mean(FastingGlucose, na.rm=T)) %>% 
  ungroup()  %>%
  ggplot(aes(FastingGlucose)) +
  geom_density(alpha = 0.8, fill="darkblue") +
  theme_classic() + 
  theme(legend.title = element_blank(), legend.position = "top", legend.justification = "right") +
  ggtitle("Proportion of Vyndaqel patients") +
  xlab("\n Fasting Glucose (mg/dL)") +
  ylab("Proportion\n")







# HbA1c
exam_interview_Vyndaqel195pts <- fread("exam_interview_Vyndaqel195pts.txt", colClasses = "character")

exam_interview_Vyndaqel195pts <- exam_interview_Vyndaqel195pts %>% select(kojin_id, hba1c_ngsp_meneki:hba1c_jdsh_other)

exam_interview_Vyndaqel195pts <- gather(exam_interview_Vyndaqel195pts, source, HbA1c, hba1c_ngsp_meneki:hba1c_jdsh_other, factor_key=TRUE)
exam_interview_Vyndaqel195pts <- exam_interview_Vyndaqel195pts %>% select(-source)

exam_interview_Vyndaqel195pts$HbA1c <- as.numeric(exam_interview_Vyndaqel195pts$HbA1c)

exam_interview_Vyndaqel195pts %>% drop_na() %>% group_by(kojin_id) %>% 
  summarise(HbA1c) %>% 
  ungroup()  %>% summarise(n=mean(HbA1c))  # 

exam_interview_Vyndaqel195pts %>% drop_na() %>% group_by(kojin_id) %>% 
  summarise(HbA1c = mean(HbA1c, na.rm=T)) %>% 
  ungroup()  %>%
  ggplot(aes(HbA1c)) +
  geom_density(alpha = 0.8, fill="darkblue") +
  theme_classic() + 
  theme(legend.title = element_blank(), legend.position = "top", legend.justification = "right") +
  ggtitle("Proportion of Vyndaqel patients") +
  xlab("\n HbA1c (%)") +
  ylab("Proportion\n")




# Hematocrit
exam_interview_Vyndaqel195pts <- fread("exam_interview_Vyndaqel195pts.txt", colClasses = "character")

exam_interview_Vyndaqel195pts <- exam_interview_Vyndaqel195pts %>% select(kojin_id, hematocrit_value)

exam_interview_Vyndaqel195pts <- gather(exam_interview_Vyndaqel195pts, source, Hematocrit, hematocrit_value, factor_key=TRUE)
exam_interview_Vyndaqel195pts <- exam_interview_Vyndaqel195pts %>% select(-source)

exam_interview_Vyndaqel195pts$Hematocrit <- as.numeric(exam_interview_Vyndaqel195pts$Hematocrit)

exam_interview_Vyndaqel195pts %>% drop_na() %>% group_by(kojin_id) %>% 
  summarise(Hematocrit) %>% 
  ungroup()  %>% summarise(n=mean(Hematocrit))  # 

exam_interview_Vyndaqel195pts %>% drop_na() %>% group_by(kojin_id) %>% 
  summarise(Hematocrit = mean(Hematocrit, na.rm=T)) %>% 
  ungroup()  %>%
  ggplot(aes(Hematocrit)) +
  geom_density(alpha = 0.8, fill="darkblue") +
  theme_classic() + 
  theme(legend.title = element_blank(), legend.position = "top", legend.justification = "right") +
  ggtitle("Proportion of Vyndaqel patients") +
  xlab("\n Hematocrit (%)") +
  ylab("Proportion\n")





# Hemoglobin
exam_interview_Vyndaqel195pts <- fread("exam_interview_Vyndaqel195pts.txt", colClasses = "character")

exam_interview_Vyndaqel195pts <- exam_interview_Vyndaqel195pts %>% select(kojin_id, kesshikisoryou_hb)

exam_interview_Vyndaqel195pts <- gather(exam_interview_Vyndaqel195pts, source, Hemoglobin, kesshikisoryou_hb, factor_key=TRUE)
exam_interview_Vyndaqel195pts <- exam_interview_Vyndaqel195pts %>% select(-source)

exam_interview_Vyndaqel195pts$Hemoglobin <- as.numeric(exam_interview_Vyndaqel195pts$Hemoglobin)

exam_interview_Vyndaqel195pts %>% drop_na() %>% group_by(kojin_id) %>% 
  summarise(Hemoglobin) %>% 
  ungroup()  %>% summarise(n=mean(Hemoglobin))  # 

exam_interview_Vyndaqel195pts %>% drop_na() %>% group_by(kojin_id) %>% 
  summarise(Hemoglobin = mean(Hemoglobin, na.rm=T)) %>% 
  ungroup()  %>%
  ggplot(aes(Hemoglobin)) +
  geom_density(alpha = 0.8, fill="darkblue") +
  theme_classic() + 
  theme(legend.title = element_blank(), legend.position = "top", legend.justification = "right") +
  ggtitle("Proportion of Vyndaqel patients") +
  xlab("\n Hemoglobin (g/dL)") +
  ylab("Proportion\n")




# Serum creatinine
exam_interview_Vyndaqel195pts <- fread("exam_interview_Vyndaqel195pts.txt", colClasses = "character")

exam_interview_Vyndaqel195pts <- exam_interview_Vyndaqel195pts %>% select(kojin_id, kessei_cr_kashi, kessei_cr_other)

exam_interview_Vyndaqel195pts <- gather(exam_interview_Vyndaqel195pts, source, Creatinine, kessei_cr_kashi:kessei_cr_other, factor_key=TRUE)
exam_interview_Vyndaqel195pts <- exam_interview_Vyndaqel195pts %>% select(-source)

exam_interview_Vyndaqel195pts$Creatinine <- as.numeric(exam_interview_Vyndaqel195pts$Creatinine)

exam_interview_Vyndaqel195pts %>% drop_na() %>% group_by(kojin_id) %>% 
  summarise(Creatinine) %>% 
  ungroup()  %>% summarise(n=mean(Creatinine))  # 

exam_interview_Vyndaqel195pts %>% drop_na() %>% group_by(kojin_id) %>% 
  summarise(Creatinine = mean(Creatinine, na.rm=T)) %>% 
  ungroup()  %>%
  ggplot(aes(Creatinine)) +
  geom_density(alpha = 0.8, fill="darkblue") +
  theme_classic() + 
  theme(legend.title = element_blank(), legend.position = "top", legend.justification = "right") +
  ggtitle("Proportion of Vyndaqel patients") +
  xlab("\n Serum Creatinine (mg/dL)") +
  ylab("Proportion\n")





# Serum uric acid
exam_interview_Vyndaqel195pts <- fread("exam_interview_Vyndaqel195pts.txt", colClasses = "character")

exam_interview_Vyndaqel195pts <- exam_interview_Vyndaqel195pts %>% select(kojin_id, kessei_nyousan_kashi, kessei_nyousan_other)

exam_interview_Vyndaqel195pts <- gather(exam_interview_Vyndaqel195pts, source, UricAcid, kessei_nyousan_kashi:kessei_nyousan_other, factor_key=TRUE)
exam_interview_Vyndaqel195pts <- exam_interview_Vyndaqel195pts %>% select(-source)

exam_interview_Vyndaqel195pts$UricAcid <- as.numeric(exam_interview_Vyndaqel195pts$UricAcid)

exam_interview_Vyndaqel195pts %>% drop_na() %>% group_by(kojin_id) %>% 
  summarise(UricAcid) %>% 
  ungroup()  %>% summarise(n=mean(UricAcid))  # 

exam_interview_Vyndaqel195pts %>% drop_na() %>% group_by(kojin_id) %>% 
  summarise(UricAcid = mean(UricAcid, na.rm=T)) %>% 
  ungroup()  %>%
  ggplot(aes(UricAcid)) +
  geom_density(alpha = 0.8, fill="darkblue") +
  theme_classic() + 
  theme(legend.title = element_blank(), legend.position = "top", legend.justification = "right") +
  ggtitle("Proportion of Vyndaqel patients") +
  xlab("\n Serum Uric Acid (mg/dL)") +
  ylab("Proportion\n")





# eGFR
exam_interview_Vyndaqel195pts <- fread("exam_interview_Vyndaqel195pts.txt", colClasses = "character")

exam_interview_Vyndaqel195pts <- exam_interview_Vyndaqel195pts %>% select(kojin_id, e_gfr)

exam_interview_Vyndaqel195pts <- gather(exam_interview_Vyndaqel195pts, source, GFR, e_gfr:e_gfr, factor_key=TRUE)
exam_interview_Vyndaqel195pts <- exam_interview_Vyndaqel195pts %>% select(-source)

exam_interview_Vyndaqel195pts$GFR <- as.numeric(exam_interview_Vyndaqel195pts$GFR)

exam_interview_Vyndaqel195pts %>% drop_na() %>% group_by(kojin_id) %>% 
  summarise(GFR) %>% 
  ungroup()  %>% summarise(n=mean(GFR))  # 

exam_interview_Vyndaqel195pts %>% drop_na() %>% group_by(kojin_id) %>% 
  summarise(GFR = mean(GFR, na.rm=T)) %>% 
  ungroup()  %>%
  ggplot(aes(GFR)) +
  geom_density(alpha = 0.8, fill="darkblue") +
  theme_classic() + 
  theme(legend.title = element_blank(), legend.position = "top", legend.justification = "right") +
  ggtitle("Proportion of Vyndaqel patients") +
  xlab("\n eGFR (ml/min)") +
  ylab("Proportion\n")





# ECG findings
exam_interview_Vyndaqel195pts <- fread("exam_interview_Vyndaqel195pts.txt", colClasses = "character")

exam_interview_Vyndaqel195pts <- exam_interview_Vyndaqel195pts %>% select(kojin_id, shindenzu_code)

exam_interview_Vyndaqel195pts <- gather(exam_interview_Vyndaqel195pts, source, ECG, shindenzu_code:shindenzu_code, factor_key=TRUE)
exam_interview_Vyndaqel195pts <- exam_interview_Vyndaqel195pts %>% select(-source)

exam_interview_Vyndaqel195pts$ECG <- as.numeric(exam_interview_Vyndaqel195pts$ECG)

exam_interview_Vyndaqel195pts %>% group_by(ECG) %>% count()




Summary_Biochemistry <- fread("Summary_Biochemistry.csv")
Summary_Biochemistry$Variable = factor(Summary_Biochemistry$Variable)

# Summary_Biochemistry$Value <- scale(Summary_Biochemistry$Value)
# Summary_Biochemistry$Lower <- scale(Summary_Biochemistry$Lower)
# Summary_Biochemistry$Upper <- scale(Summary_Biochemistry$Upper)

Summary_Biochemistry <- Summary_Biochemistry %>% arrange(Value)

ggplot(Summary_Biochemistry, aes(x=reorder(Variable, Value), y=Value, ymin=Lower, ymax=Upper)) + 
  geom_linerange(size=5, colour="coral", alpha=0.5, position=position_dodge(width = 0.5)) +
  geom_point(size=4, shape=21, colour="white", fill="deepskyblue4", stroke = 0.5,position=position_dodge(width = 0.5)) +
  coord_flip() +
  theme_minimal()+
  ylab(" \n Value (Lower-Upper ref bound), respective units")+xlab("")











# -------------------------------------------------------------------------------------------------------------------------------
# 195 vyndaqel patients -> First "Cardiac Amyloidosis" to 1st Vyndaqel  ------------------------------------------------------------------------------------

# Data of first cardiac amyloidosis Dx

receipt_diseases_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_diseases_Vyndaqel195pts.txt", 
                                         colClasses = "character")

receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>% filter(diseases_code=="8834886"|
                                             diseases_code=="8836892"|
                                             diseases_code=="8846224"|
                                             diseases_code=="8850066") %>% select(kojin_id, receipt_ym, sinryo_start_ymd) %>% distinct()

Earliest_Cardiac_Amyloidosis <- receipt_diseases_Vyndaqel195pts %>% group_by(kojin_id) %>% 
  filter(receipt_ym==min(receipt_ym))  %>% select(kojin_id, receipt_ym) %>% distinct() %>%
  full_join(receipt_diseases_Vyndaqel195pts %>% group_by(kojin_id) %>% 
  filter(sinryo_start_ymd==min(sinryo_start_ymd))  %>% select(kojin_id, sinryo_start_ymd) %>% distinct())

Earliest_Cardiac_Amyloidosis$receipt_ym <- as.Date(paste0(as.character(Earliest_Cardiac_Amyloidosis$receipt_ym), '/01'))
names(Earliest_Cardiac_Amyloidosis)[2] <- "First_CardiacAmyloidosis"




# drugs 

receipt_drug_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_drug_Vyndaqel195pts.txt", colClasses = "character")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts[,.(receipt_ym, kojin_id, drug_code)]
receipt_drug_Vyndaqel195pts$receipt_ym <- as.Date(paste0(as.character(receipt_drug_Vyndaqel195pts$receipt_ym), '/01'))

unique(receipt_drug_Vyndaqel195pts$drug_code) # 
temp <- receipt_drug_Vyndaqel195pts %>% filter(drug_code=="622278901") %>% 
  group_by(kojin_id) %>% filter(receipt_ym==min(receipt_ym)) %>% distinct() %>% 
  select(-drug_code) %>%
  left_join(Earliest_Cardiac_Amyloidosis) 
  
temp %>% mutate(ElapsedTime=as.numeric(receipt_ym-First_CardiacAmyloidosis)/30.5) %>% 
    ungroup() %>% summarise(n=mean(ElapsedTime, na.rm=T)) # 

temp <-  temp %>% mutate(ElapsedTime=as.numeric(receipt_ym-First_CardiacAmyloidosis)/30.5)

temp %>% mutate(ElapsedTime=as.numeric(receipt_ym-First_CardiacAmyloidosis)/30.5) %>% 
  ungroup() %>% ggplot(aes(ElapsedTime)) +
  geom_density(alpha = 0.8, fill="firebrick") +
  theme_classic() + 
  xlim(0,40) +
  theme(legend.title = element_blank(), legend.position = "top", legend.justification = "right") +
  ggtitle("Proportion of Vyndaqel patients") +
  xlab("\n No. Months 1st Cardiac Amyloidosis Dx to 1st Vyndaqel Script") +
  ylab("Proportion\n")


temp %>% mutate(sinryo_start_ymd=as.Date(sinryo_start_ymd)) %>%
  mutate(ElapsedTime=as.numeric(receipt_ym-sinryo_start_ymd)/30.5) %>% 
    ungroup() %>% summarise(n=mean(ElapsedTime, na.rm=T)) # 


temp %>% mutate(sinryo_start_ymd=as.Date(sinryo_start_ymd)) %>% 
  mutate(ElapsedTime=as.numeric(receipt_ym-sinryo_start_ymd)/30.5) %>% 
  ungroup() %>% ggplot(aes(ElapsedTime)) +
  geom_density(alpha = 0.8, fill="firebrick") +
  theme_classic() + 
  theme(legend.title = element_blank(), legend.position = "top", legend.justification = "right") +
  ggtitle("Proportion of Vyndaqel patients") +
  xlab("\n No. Months 1st Cardiac Amyloidosis Dx to 1st Vyndaqel Script") +
  ylab("Proportion\n")

# ---------------------------------------------------------------------------------------------
# 195 vyndaqel patients -> First "Amyloidosis" to 1st Vyndaqel  ------------------------------------------------------------------------------------

# Data of first  amyloidosis Dx

receipt_diseases_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_diseases_Vyndaqel195pts.txt", 
                                         colClasses = "character")

m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% filter(icd10_sub_code=="E85") %>% select(diseases_code)


receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>% inner_join(m_icd10) %>%
  select(kojin_id, receipt_ym, sinryo_start_ymd) %>% distinct()

Earliest_Amyloidosis <- receipt_diseases_Vyndaqel195pts %>% group_by(kojin_id) %>% 
  filter(receipt_ym==min(receipt_ym))  %>% select(kojin_id, receipt_ym) %>% distinct() %>%
  full_join(receipt_diseases_Vyndaqel195pts %>% group_by(kojin_id) %>% 
  filter(sinryo_start_ymd==min(sinryo_start_ymd))  %>% select(kojin_id, sinryo_start_ymd) %>% distinct())

Earliest_Amyloidosis$receipt_ym <- as.Date(paste0(as.character(Earliest_Amyloidosis$receipt_ym), '/01'))
names(Earliest_Amyloidosis)[2] <- "Earliest_Amyloidosis"



# drugs 

receipt_drug_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_drug_Vyndaqel195pts.txt", colClasses = "character")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts[,.(receipt_ym, kojin_id, drug_code)]
receipt_drug_Vyndaqel195pts$receipt_ym <- as.Date(paste0(as.character(receipt_drug_Vyndaqel195pts$receipt_ym), '/01'))

unique(receipt_drug_Vyndaqel195pts$drug_code) # 

temp <- receipt_drug_Vyndaqel195pts %>% filter(drug_code=="622278901") %>% 
  group_by(kojin_id) %>% filter(receipt_ym==min(receipt_ym)) %>% distinct() %>% 
  select(-drug_code) %>%
  left_join(Earliest_Amyloidosis) 
  
temp %>% mutate(ElapsedTime=as.numeric(receipt_ym-Earliest_Amyloidosis)/30.5) %>% 
    ungroup() %>% summarise(n=mean(ElapsedTime, na.rm=T)) # 

temp <-  temp %>% mutate(ElapsedTime=as.numeric(receipt_ym-Earliest_Amyloidosis)/30.5)

temp %>% mutate(ElapsedTime=as.numeric(receipt_ym-Earliest_Amyloidosis)/30.5) %>% 
  ungroup() %>% ggplot(aes(ElapsedTime)) +
  geom_density(alpha = 0.8, fill="firebrick") +
  theme_classic() + 
  xlim(0,40) +
  theme(legend.title = element_blank(), legend.position = "top", legend.justification = "right") +
  ggtitle("Proportion of Vyndaqel patients") +
  xlab("\n No. Months 1st Amyloidosis Dx to 1st Vyndaqel Script") +
  ylab("Proportion\n")


temp %>% mutate(sinryo_start_ymd=as.Date(sinryo_start_ymd)) %>%
  mutate(ElapsedTime=as.numeric(receipt_ym-sinryo_start_ymd)/30.5) %>% 
    ungroup() %>% summarise(n=mean(ElapsedTime, na.rm=T)) # 


temp %>% mutate(sinryo_start_ymd=as.Date(sinryo_start_ymd)) %>% 
  mutate(ElapsedTime=as.numeric(receipt_ym-sinryo_start_ymd)/30.5) %>% 
  ungroup() %>% ggplot(aes(ElapsedTime)) +
  geom_density(alpha = 0.8, fill="firebrick") +
  theme_classic() + 
  theme(legend.title = element_blank(), legend.position = "top", legend.justification = "right") +
  ggtitle("Proportion of Vyndaqel patients") +
  xlab("\n No. Months 1st Amyloidosis Dx to 1st Vyndaqel Script") +
  ylab("Proportion\n")

# ------------------------------------------------------------------------------------------------------------------
# 195 vyndaqel patients -> First "Heart Failure" to 1st Vyndaqel  ------------------------------------------------------------------------------------

# Data of first  amyloidosis Dx

receipt_diseases_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_diseases_Vyndaqel195pts.txt", 
                                         colClasses = "character")

m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% filter(icd10_sub_code=="I50") %>% select(diseases_code)


receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>% inner_join(m_icd10) %>%
  select(kojin_id, receipt_ym, sinryo_start_ymd) %>% distinct()

Earliest_HF <- receipt_diseases_Vyndaqel195pts %>% group_by(kojin_id) %>% 
  filter(receipt_ym==min(receipt_ym))  %>% select(kojin_id, receipt_ym) %>% distinct() %>%
  full_join(receipt_diseases_Vyndaqel195pts %>% group_by(kojin_id) %>% 
  filter(sinryo_start_ymd==min(sinryo_start_ymd))  %>% select(kojin_id, sinryo_start_ymd) %>% distinct())

Earliest_HF$receipt_ym <- as.Date(paste0(as.character(Earliest_HF$receipt_ym), '/01'))
names(Earliest_HF)[2] <- "Earliest_HF"



# drugs 

receipt_drug_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_drug_Vyndaqel195pts.txt", colClasses = "character")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts[,.(receipt_ym, kojin_id, drug_code)]
receipt_drug_Vyndaqel195pts$receipt_ym <- as.Date(paste0(as.character(receipt_drug_Vyndaqel195pts$receipt_ym), '/01'))

unique(receipt_drug_Vyndaqel195pts$drug_code) # 

temp <- receipt_drug_Vyndaqel195pts %>% filter(drug_code=="622278901") %>% 
  group_by(kojin_id) %>% filter(receipt_ym==min(receipt_ym)) %>% distinct() %>% 
  select(-drug_code) %>%
  left_join(Earliest_HF) 
  
temp %>% mutate(ElapsedTime=as.numeric(receipt_ym-Earliest_HF)/30.5) %>% 
    ungroup() %>% summarise(n=mean(ElapsedTime, na.rm=T)) # 

temp <-  temp %>% mutate(ElapsedTime=as.numeric(receipt_ym-Earliest_HF)/30.5)

temp %>% mutate(ElapsedTime=as.numeric(receipt_ym-Earliest_HF)/30.5) %>% 
  ungroup() %>% ggplot(aes(ElapsedTime)) +
  geom_density(alpha = 0.8, fill="firebrick") +
  theme_classic() + 
  xlim(0,40) +
  theme(legend.title = element_blank(), legend.position = "top", legend.justification = "right") +
  ggtitle("Proportion of Vyndaqel patients") +
  xlab("\n No. Months 1st Heart Failure Dx to 1st Vyndaqel Script") +
  ylab("Proportion\n")


# --------------------------------------------------------------------------------------------------------------------------------

# 195 vyndaqel patients -> First Scintigraphy/Biopsy to 1st Vyndaqel -------------------------------------

receipt_medical_practice_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_medical_practice_Vyndaqel195pts.txt", colClasses = "character")
receipt_medical_practice_Vyndaqel195pts <- receipt_medical_practice_Vyndaqel195pts[,.(receipt_ym, kojin_id, medical_practice_code)]
receipt_medical_practice_Vyndaqel195pts$receipt_ym <- as.Date(paste0(as.character(receipt_medical_practice_Vyndaqel195pts$receipt_ym), '/01'))

Procedure_master <- fread("Masters/Procedure_master.csv", colClasses = "character")

receipt_medical_practice_Vyndaqel195pts <- 
  receipt_medical_practice_Vyndaqel195pts %>% 
  left_join(Procedure_master, 
            by=c("medical_practice_code"="standardized_procedure_code")) %>%
  select(kojin_id, receipt_ym, medical_practice_code, standardized_procedure_name) 
 

receipt_medical_practice_Vyndaqel195pts <- receipt_medical_practice_Vyndaqel195pts %>%
                                              filter(grepl("computerized tomog", standardized_procedure_name)|
                                                     grepl("CT imaging", standardized_procedure_name)|
                                                     grepl("nuclear medicine diagnosis", standardized_procedure_name)|
                                                     grepl("scintigraphy", standardized_procedure_name)|
                                                     grepl("MRI", standardized_procedure_name)|
                                                     grepl("electrocardiog", standardized_procedure_name)|
                                                     grepl("ECG", standardized_procedure_name)|
                                                     grepl("ultrasonography", standardized_procedure_name)|
                                                     grepl("SPECT", standardized_procedure_name)|
                                                     grepl("PET ", standardized_procedure_name)|
                                                     grepl("percutaneous needle biopsy", standardized_procedure_name)|
                                                     grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name)|
                                                     grepl("endoscopic biopsy", standardized_procedure_name)|
                                                     grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name)|
                                                     grepl("brain natriuretic peptide", standardized_procedure_name)|
                                                     grepl("BNP", standardized_procedure_name)|
                                                     grepl("troponin", standardized_procedure_name)|
                                                     grepl("genetic test", standardized_procedure_name)|
                                                     grepl("cardiac catheterization", standardized_procedure_name)|
                                                     grepl("Holter", standardized_procedure_name)|
                                                     grepl("pacemaker", standardized_procedure_name)|
                                                     grepl("gene-related", standardized_procedure_name)|
                                                     grepl("exercise test", standardized_procedure_name)|
                                                     grepl("hospitalization", standardized_procedure_name)|
                                                     grepl("serum amyloid A protein", standardized_procedure_name)|
                                                     grepl("prealbumin", standardized_procedure_name)|
                                                     grepl("transthyretin", standardized_procedure_name)|
                                                     grepl("amylase", standardized_procedure_name))

unique(receipt_medical_practice_Vyndaqel195pts$medical_practice_code)


receipt_medical_practice_Vyndaqel195pts <-
  receipt_medical_practice_Vyndaqel195pts %>% mutate(standardized_procedure_name=
                                                     ifelse(grepl("computerized tomog",standardized_procedure_name), "CT",
                                                            ifelse(grepl("CT imaging,", standardized_procedure_name), "CT",
                                                                   ifelse(grepl("nuclear medicine diagnosis", standardized_procedure_name), "other nuclear medicine",
                                                                          ifelse(grepl("scintigraphy", standardized_procedure_name), "scintigraphy",
                                                                                 ifelse(grepl("MRI", standardized_procedure_name), "MRI",
                                                                                        ifelse(grepl("electrocardiog", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ECG", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ultrasonography", standardized_procedure_name), "ultrasonography",
                                                                                                      ifelse(grepl("SPECT", standardized_procedure_name), "scintigraphy",
                                                                                                             ifelse(grepl("PET ", standardized_procedure_name), "scintigraphy",
                                                                                                      ifelse(grepl("percutaneous needle biopsy", standardized_procedure_name), "biopsy",
                                                                                                             ifelse(grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("endoscopic biopsy", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name), "heart biopsy",
                                                                                                                           ifelse(grepl("brain natriuretic peptide", standardized_procedure_name), "BNP",
                                                                                                                                  ifelse(grepl("BNP", standardized_procedure_name), "BNP",
                                                                                                                                         ifelse(grepl("troponin", standardized_procedure_name), "troponin",
                                                                                                                                                ifelse(grepl("genetic test", standardized_procedure_name), "genetic test",
                                                                                                                                                       ifelse(grepl("cardiac catheterization", standardized_procedure_name), "cardiac catheterization",
                                                                                                                                                              ifelse(grepl("Holter", standardized_procedure_name), "Holter",
                                                                                                                                                                     ifelse(grepl("pacemaker", standardized_procedure_name), "pacemaker",
                                                                                                                                                                            ifelse(grepl("gene-related", standardized_procedure_name), "genetic test",
                                                                                                                                                                                          ifelse(grepl("exercise test", standardized_procedure_name), "exercise test",
                                                                                                                                                                                                 ifelse(grepl("hospitalization", standardized_procedure_name), "hospitalization",
                                                                                                                                                                                                        ifelse(grepl("serum amyloid A protein", standardized_procedure_name), "AmyloidA",
                                                                                                                                                                                                               ifelse(grepl("prealbumin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("transthyretin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("amylase", standardized_procedure_name), "amylase",NA)))))))))))))))))))))))))))))
                                                                   

receipt_medical_practice_Vyndaqel195pts <- receipt_medical_practice_Vyndaqel195pts %>% mutate(standardized_procedure_name=ifelse(is.na(standardized_procedure_name),"CT", standardized_procedure_name))

receipt_medical_practice_Vyndaqel195pts %>% 
  select(kojin_id, standardized_procedure_name) %>% distinct() %>%
  group_by(standardized_procedure_name) %>% count() %>% arrange(-n)

Fisrt_scintigraphy <- receipt_medical_practice_Vyndaqel195pts %>% filter(standardized_procedure_name=="scintigraphy") %>%
  group_by(kojin_id) %>% filter(receipt_ym==min(receipt_ym)) %>% slice(1) %>% select(kojin_id, receipt_ym)
names(Fisrt_scintigraphy)[2] <- "First_scintigraphy"

Fisrt_biopsy <- receipt_medical_practice_Vyndaqel195pts %>% filter(standardized_procedure_name=="biopsy") %>%
  group_by(kojin_id) %>% filter(receipt_ym==min(receipt_ym)) %>% slice(1) %>% select(kojin_id, receipt_ym)
names(Fisrt_biopsy)[2] <- "First_biopsy"

receipt_drug_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_drug_Vyndaqel195pts.txt", colClasses = "character")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts[,.(receipt_ym, kojin_id, drug_code)]
receipt_drug_Vyndaqel195pts$receipt_ym <- as.Date(paste0(as.character(receipt_drug_Vyndaqel195pts$receipt_ym), '/01'))

Fisrt_Vyndaqel <- receipt_drug_Vyndaqel195pts %>% filter(drug_code=="622278901") %>% 
  group_by(kojin_id) %>% filter(receipt_ym==min(receipt_ym)) %>% distinct() %>% 
  select(-drug_code)

Fisrt_scintigraphy %>% left_join(Fisrt_Vyndaqel) %>% mutate(ElapsedTime=as.numeric(receipt_ym-First_scintigraphy)/30.5) %>%
  ungroup() %>% summarise(n=mean(ElapsedTime)) #



Fisrt_scintigraphy %>% left_join(Fisrt_Vyndaqel) %>% mutate(ElapsedTime=as.numeric(receipt_ym-First_scintigraphy)/30.5) %>%
  ungroup() %>% ggplot(aes(ElapsedTime)) +
  geom_density(alpha = 0.8, fill="midnightblue") +
  theme_classic() + 
  xlim(0,18) +
  theme(legend.title = element_blank(), legend.position = "top", legend.justification = "right") +
  ggtitle("Proportion of Scintigraphy/Vyndaqel patients") +
  xlab("\n No. Months 1st Scintigraphy to 1st Vyndaqel Script") +
  ylab("Proportion\n")


Fisrt_biopsy %>% left_join(Fisrt_Vyndaqel) %>% mutate(ElapsedTime=as.numeric(receipt_ym-First_biopsy)/30.5) %>%
  ungroup() %>% summarise(n=mean(ElapsedTime)) # 


Fisrt_biopsy %>% left_join(Fisrt_Vyndaqel) %>% mutate(ElapsedTime=as.numeric(receipt_ym-First_biopsy)/30.5) %>%
  ungroup() %>% ggplot(aes(ElapsedTime)) +
  geom_density(alpha = 0.8, fill="midnightblue") +
  theme_classic() + 
  xlim(0,20) +
  theme(legend.title = element_blank(), legend.position = "top", legend.justification = "right") +
  ggtitle("Proportion of Biopsy/Vyndaqel patients") +
  xlab("\n No. Months 1st Biopsy to 1st Vyndaqel Script") +
  ylab("Proportion\n")


# ------------------------------------------------------------------------------------------





# 195 vyndaqel patients -> Drugs ------------------------------------------------------------------------------------

receipt_drug_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_drug_Vyndaqel195pts.txt", colClasses = "character")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts[,.(receipt_ym, kojin_id, drug_code)]
receipt_drug_Vyndaqel195pts$receipt_ym <- as.Date(paste0(as.character(receipt_drug_Vyndaqel195pts$receipt_ym), '/01'))

Drug_Classes_lookup <- fread("Masters/Drug_Classes_lookup.csv", colClasses = "character")
m_drug_who_atc <- fread("Masters/m_drug_who_atc.csv", colClasses = "character")
m_drug_who_atc <- m_drug_who_atc %>% select(drug_code, atc_major_name_en)


receipt_drug_Vyndaqel195pts %>%
  left_join(Drug_Classes_lookup) %>% select(kojin_id, drug_code, drug_class) %>% 
  group_by(drug_class) %>% count() %>% arrange(-n)

receipt_drug_Vyndaqel195pts %>%
  left_join(Drug_Classes_lookup) %>% select(kojin_id, drug_code, drug_class) %>%
  filter(drug_class=="ATTR") %>% select(drug_code) %>% group_by(drug_code) %>% count()


receipt_drug_Vyndaqel195pts %>% select(kojin_id, drug_code) %>% distinct() %>%
  filter(drug_code!="622278901") %>%
  left_join(Drug_Classes_lookup) %>% select(kojin_id, drug_class) %>% distinct() %>%
  group_by(drug_class) %>% count() %>% arrange(-n)



Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")
Vyndaqel_pats_CM_vs_PN <- Vyndaqel_pats_CM_vs_PN %>% select(kojin_id, PN, CM, Combo) 



receipt_drug_Vyndaqel195pts %>% select(kojin_id, drug_code) %>% distinct() %>%
  left_join(Drug_Classes_lookup) %>% select(kojin_id, drug_class) %>% distinct() %>%
  inner_join(Vyndaqel_pats_CM_vs_PN %>% filter(PN!=1) %>% select(kojin_id)) %>%
  group_by(drug_class) %>% count() %>% arrange(-n)


receipt_drug_Vyndaqel195pts %>% select(kojin_id, drug_code) %>% distinct() %>%
  left_join(Drug_Classes_lookup) %>% select(kojin_id, drug_class) %>% distinct() %>%
  inner_join(Vyndaqel_pats_CM_vs_PN %>% filter(PN==1) %>% select(kojin_id)) %>%
  group_by(drug_class) %>% count() %>% arrange(-n)






# -------------------------------------------------------------------------------------------------------

# 195 vyndaqel patients -> Procedures ------------------------------------------------------------------------------------

receipt_medical_practice_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_medical_practice_Vyndaqel195pts.txt", colClasses = "character")
receipt_medical_practice_Vyndaqel195pts <- receipt_medical_practice_Vyndaqel195pts[,.(receipt_ym, kojin_id, medical_practice_code)]
receipt_medical_practice_Vyndaqel195pts$receipt_ym <- as.Date(paste0(as.character(receipt_medical_practice_Vyndaqel195pts$receipt_ym), '/01'))

Procedure_master <- fread("Masters/Procedure_master.csv", colClasses = "character")


receipt_medical_practice_Vyndaqel195pts <- 
  receipt_medical_practice_Vyndaqel195pts %>% 
  left_join(Procedure_master, 
            by=c("medical_practice_code"="standardized_procedure_code")) %>%
  select(kojin_id, receipt_ym, medical_practice_code, standardized_procedure_name) 
 

receipt_medical_practice_Vyndaqel195pts <- receipt_medical_practice_Vyndaqel195pts %>%
                                              filter(grepl("computerized tomog", standardized_procedure_name)|
                                                     grepl("CT imaging", standardized_procedure_name)|
                                                     grepl("nuclear medicine diagnosis", standardized_procedure_name)|
                                                     grepl("scintigraphy", standardized_procedure_name)|
                                                     grepl("MRI", standardized_procedure_name)|
                                                     grepl("electrocardiog", standardized_procedure_name)|
                                                     grepl("ECG", standardized_procedure_name)|
                                                     grepl("ultrasonography", standardized_procedure_name)|
                                                     grepl("SPECT", standardized_procedure_name)|
                                                     grepl("PET ", standardized_procedure_name)|
                                                     grepl("percutaneous needle biopsy", standardized_procedure_name)|
                                                     grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name)|
                                                     grepl("endoscopic biopsy", standardized_procedure_name)|
                                                     grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name)|
                                                     grepl("brain natriuretic peptide", standardized_procedure_name)|
                                                     grepl("BNP", standardized_procedure_name)|
                                                     grepl("troponin", standardized_procedure_name)|
                                                     grepl("genetic test", standardized_procedure_name)|
                                                     grepl("cardiac catheterization", standardized_procedure_name)|
                                                     grepl("Holter", standardized_procedure_name)|
                                                     grepl("pacemaker", standardized_procedure_name)|
                                                     grepl("gene-related", standardized_procedure_name)|
                                                     grepl("exercise test", standardized_procedure_name)|
                                                     grepl("hospitalization", standardized_procedure_name)|
                                                     grepl("serum amyloid A protein", standardized_procedure_name)|
                                                     grepl("prealbumin", standardized_procedure_name)|
                                                     grepl("transthyretin", standardized_procedure_name)|
                                                     grepl("amylase", standardized_procedure_name))

unique(receipt_medical_practice_Vyndaqel195pts$medical_practice_code)

unique(Procedure_master$standardized_procedure_name[grepl("biopsy", Procedure_master$standardized_procedure_name)])

receipt_medical_practice_Vyndaqel195pts <-
  receipt_medical_practice_Vyndaqel195pts %>% mutate(standardized_procedure_name=
                                                     ifelse(grepl("computerized tomog",standardized_procedure_name), "CT",
                                                            ifelse(grepl("CT imaging,", standardized_procedure_name), "CT",
                                                                   ifelse(grepl("nuclear medicine diagnosis", standardized_procedure_name), "other nuclear medicine",
                                                                          ifelse(grepl("scintigraphy", standardized_procedure_name), "scintigraphy",
                                                                                 ifelse(grepl("MRI", standardized_procedure_name), "MRI",
                                                                                        ifelse(grepl("electrocardiog", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ECG", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ultrasonography", standardized_procedure_name), "ultrasonography",
                                                                                                      ifelse(grepl("SPECT", standardized_procedure_name), "scintigraphy",
                                                                                                             ifelse(grepl("PET ", standardized_procedure_name), "scintigraphy",
                                                                                                      ifelse(grepl("percutaneous needle biopsy", standardized_procedure_name), "biopsy",
                                                                                                             ifelse(grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("endoscopic biopsy", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name), "heart biopsy",
                                                                                                                           ifelse(grepl("brain natriuretic peptide", standardized_procedure_name), "BNP",
                                                                                                                                  ifelse(grepl("BNP", standardized_procedure_name), "BNP",
                                                                                                                                         ifelse(grepl("troponin", standardized_procedure_name), "troponin",
                                                                                                                                                ifelse(grepl("genetic test", standardized_procedure_name), "genetic test",
                                                                                                                                                       ifelse(grepl("cardiac catheterization", standardized_procedure_name), "cardiac catheterization",
                                                                                                                                                              ifelse(grepl("Holter", standardized_procedure_name), "Holter",
                                                                                                                                                                     ifelse(grepl("pacemaker", standardized_procedure_name), "pacemaker",
                                                                                                                                                                            ifelse(grepl("gene-related", standardized_procedure_name), "genetic test",
                                                                                                                                                                                          ifelse(grepl("exercise test", standardized_procedure_name), "exercise test",
                                                                                                                                                                                                 ifelse(grepl("hospitalization", standardized_procedure_name), "hospitalization",
                                                                                                                                                                                                        ifelse(grepl("serum amyloid A protein", standardized_procedure_name), "AmyloidA",
                                                                                                                                                                                                               ifelse(grepl("prealbumin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("transthyretin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("amylase", standardized_procedure_name), "amylase",NA)))))))))))))))))))))))))))))
                                                                   

receipt_medical_practice_Vyndaqel195pts <- receipt_medical_practice_Vyndaqel195pts %>% mutate(standardized_procedure_name=ifelse(is.na(standardized_procedure_name),"CT", standardized_procedure_name))

receipt_medical_practice_Vyndaqel195pts %>% 
  select(kojin_id, standardized_procedure_name) %>% distinct() %>%
  group_by(standardized_procedure_name) %>% count() %>% arrange(-n)


Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")
Vyndaqel_pats_CM_vs_PN <- Vyndaqel_pats_CM_vs_PN %>% select(kojin_id, PN, CM, Combo) 


receipt_medical_practice_Vyndaqel195pts %>% 
  select(kojin_id, standardized_procedure_name) %>% distinct() %>%
    inner_join(Vyndaqel_pats_CM_vs_PN %>% filter(PN==1) %>% select(kojin_id)) %>%
  group_by(standardized_procedure_name) %>% count() %>% arrange(-n)


receipt_medical_practice_Vyndaqel195pts %>% 
  select(kojin_id, standardized_procedure_name) %>% distinct() %>%
    inner_join(Vyndaqel_pats_CM_vs_PN %>% filter(PN!=1) %>% select(kojin_id)) %>%
  group_by(standardized_procedure_name) %>% count() %>% arrange(-n)


# ------------------------------------------------------------------------------------------------------------------------------------
# 195 vyndaqel patients -> Facilities  ------------------------------------------------------------------------

receipt_medical_institution_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_medical_institution_Vyndaqel195pts.txt", 
                                     colClasses = "character")


receipt_medical_institution_Vyndaqel195pts

m_hco_med <- fread("Masters/m_hco_med.csv")
m_hco_xref <- fread("Masters/m_hco_xref_specialty.csv")


data.frame(receipt_medical_institution_Vyndaqel195pts %>% select(kojin_id, shinryouka_name_code) %>% distinct() %>% group_by(shinryouka_name_code) %>% count()) %>% arrange(n)



unique(m_hco_med$iryokikan_no)

# There are   1047 different faiclities seeing the Vyndaqel pats
data.frame(receipt_medical_institution_Vyndaqel195pts %>% select(kojin_id, iryokikan_no) %>%
  distinct() %>% group_by(iryokikan_no) %>% count() %>% arrange(-n))

data.frame(receipt_medical_institution_Vyndaqel195pts %>% select(kojin_id, iryokikan_no) %>%
  distinct() %>% group_by(iryokikan_no) %>% count() %>% arrange(-n) %>% ungroup() %>% summarise(n2=mean(n))) 

receipt_medical_institution_Vyndaqel195pts %>% select(kojin_id, iryokikan_no) %>%
  distinct() %>% group_by(iryokikan_no) %>% count() %>% arrange(-n) %>% ungroup() %>%
  ggplot(aes(n)) +
  geom_density(alpha = 0.8, fill="firebrick") +
  theme_classic() + 
  theme(legend.title = element_blank(), legend.position = "top", legend.justification = "right") +
  xlab("\nNo. of Different Vyndaqel Patients") +
  ylab("Proportion of Facilities\n")

data.frame(receipt_medical_institution_Vyndaqel195pts %>% select(kojin_id, iryokikan_no) %>%
  distinct() %>% group_by(kojin_id) %>% count() %>% arrange(-n) %>% ungroup() %>% summarise(n2=mean(n)))

receipt_medical_institution_Vyndaqel195pts %>% select(kojin_id, iryokikan_no) %>%
  distinct() %>% group_by(kojin_id) %>% count() %>% arrange(-n) %>% ungroup() %>%
  ggplot(aes(n)) +
  geom_density(alpha = 0.8, fill="darkslategrey") +
  theme_classic() + 
  theme(legend.title = element_blank(), legend.position = "top", legend.justification = "right") +
  xlab("\nNo. of Different Facilities") +
  ylab("Proportion of Vyndaqel patients\n")




receipt_drug_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_drug_Vyndaqel195pts.txt", 
                                     colClasses = "character")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% filter(drug_code == "622278901") %>% select(kojin_id, receipt_ym) 
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% group_by(kojin_id) %>% mutate(mindate = min(receipt_ym))
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% select(kojin_id, mindate) %>% distinct()
receipt_drug_Vyndaqel195pts$VyndaqelStart <- "Start"

temp <- receipt_medical_institution_Vyndaqel195pts %>% select(kojin_id, receipt_ym, iryokikan_no) %>% distinct() %>%
  arrange(kojin_id, receipt_ym) %>% left_join(receipt_drug_Vyndaqel195pts, by=c("kojin_id"="kojin_id", "receipt_ym"="mindate")) %>%
  group_by(kojin_id) %>% 
  slice(if(any(grepl("Start",VyndaqelStart))) 1:which.max(grepl("Start",VyndaqelStart)) else row.number()) 

temp %>% select(kojin_id, iryokikan_no) %>% distinct() %>% group_by(kojin_id) %>% count() %>%
  ungroup() %>% summarise(n2=mean(n)) # 


temp %>% select(kojin_id, iryokikan_no) %>% distinct() %>% group_by(kojin_id) %>% count() %>% ungroup() %>%
    ggplot(aes(n)) +
  geom_density(alpha = 0.8, fill="deepskyblue4") +
  theme_classic() + 
  theme(legend.title = element_blank(), legend.position = "top", legend.justification = "right") +
  xlab("\nNo. of Different Facilities until Vyndaqel Initiation") +
  ylab("Proportion of Vyndaqel patients\n")







receipt_medical_institution_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_medical_institution_Vyndaqel195pts.txt", 
                                     colClasses = "character")


receipt_medical_institution_Vyndaqel195pts

m_hco_med <- fread("Masters/m_hco_med.csv", colClasses = "character")
m_hco_xref <- fread("Masters/m_hco_xref_specialty.csv", colClasses = "character")

length(unique(receipt_medical_institution_Vyndaqel195pts$shinryouka_name_code)) #

receipt_medical_institution_Vyndaqel195pts %>% select(kojin_id, shinryouka_name_code) %>%
  distinct() %>% group_by(shinryouka_name_code) %>% count() %>% arrange(-n)

temp <- data.frame(unique(m_hco_xref$specialty_name))

temp2 <- as.data.frame("1 internal medicine
2 Surgery
3 Dentistry
4 Obstetrics
5 Ophthalmology
6 Gynecology
7 Pediatrics
8 Emergency Department
9 Dermatology
10 Neurology
11 Psychiatry
12 Proctology
13 Gastroenterology
14 Anesthesiology
15 Oncology
16 Breast Medicine
17 Breast Surgery
18 Metabolic Medicine
19 Respiratory
20 Colon Medicine
21 Colon Surgery
22 Womens Internal Medicine
23 Pediatrics
24 Pediatric Surgery
25 Pediatric Dentistry
26 Plastic Surgery
27 Cardiology
28 Psychosomatic Medicine
29 Cardiology
30 Radiology
31 Orthopedics
32 Urology
33 Gastroenterology
34 Kampo Internal Medicine
35 Obstetrics and Gynecology
36 Orthodontics
37 Neurology
38 Diabetes
39 General Medicine
40 Cosmetic Surgery
41 Geriatric Medicine
42 Proctology
43 Anal Surgery
44 Hepatology
45 Gastroenterology
46 Gastrointestinal Surgery
47 Nephrology
48 Medical Oncology
49 Hematology
50 Vascular Surgery
51 Dialysis Internal Medicine
52 Dialysis Surgery
53 Cervical Surgery
54 Rheumatology
55 Fertility Department
56 Department of Dialysis
57 Child Psychiatry
58 Endocrinology
59 Endocrine Surgery
60 Endoscopy
61 Respiratory Medicine
62 Respiratory Surgery
63 Pediatric Dermatology
64 Cardiology
65 Cardiovascular Surgery
66 Infectious Diseases
67 Neonatal Medicine
68 Tracheoesophageal
69 Gastroenterology
70 Gastroenterological Surgery
71 Thyroid Medicine
72 Department of Diagnostic Pathology
73 Neuropsychiatry
74 Neuropsychiatry
75 Diabetes Medicine
76 General Medicine
77 Cosmetic Dermatology
78 Geriatric Psychiatry
79 Otolaryngology
80 Otolaryngology
81 Neurology
82 Neurosurgery
83 Oncology Psychiatry
84 Internal Medicine (Cardiology)
85 Internal Medicine (Infectious Diseases)
86 Surgery (Endoscopy)
87 Allergy
88 Dialysis Internal Medicine
89 Dialysis Surgery
90 Colon and Proctology
91 Colon and Anal Surgery
92 Female Urology
93 Pediatric Orthopedics
94 Pediatric Neurology
95 Cardiovascular Medicine
96 Cardiovascular Surgery
97 Department of Sexually Transmitted Diseases
98 Radiation Oncology
99 Diagnostic Radiology
100 Dental Oral Surgery
101 Male Urology
102 Pain Relief Medicine
103 Dermatology and Urology
104 Palliative Care Internal Medicine
105 Geriatric Psychosomatic Medicine
106 Neuropediatrics
107 Nephrology and Urology
108 Hematology and Oncology
109 Hemodialysis Internal Medicine
110 Internal Medicine (Dialysis)
111 Internal medicine (at home)
112 Internal Medicine (Palliative Care)
113 Internal Medicine (Hemodialysis)
114 Surgery (dialysis)
115 Nephrology (Dialysis)
116 Fertility Gynecology
117 Breast and Anal Surgery
118 Endocrinology and Metabolism
119 Colorectal and Anal Surgery
120 Colonoscopy
121 Pediatric Otolaryngology
122 Reproductive Medicine and Gynecology
123 Cosmetic and Plastic Surgery
124 Gastrointestinal Endoscopy
125 Gastroenterology
126 Nephrology and Urology
127 Hematology and Oncology
128 Emergency Department (outside, inside, small)
129 Internal Medicine (with dialysis)
130 Internal Medicine (General Medicine)
131 Surgery (Breast/Anal)
132 Gynecology (fertility treatment)
133 Gynecology (Reproductive Medicine)
134 Obstetrics and Gynecology (Endoscopy)
135 Proctology (Proctology)
136 Fertility and Gynecology
137 Breast and Endocrine Surgery
138 Endocrinology and Metabolism
139 Cardiology and Cardiology
140 Gastroenterology and Hepatology
141 Gastroenterological and Abdominal Surgery
142 Gastroenterological Endoscopy
143 Diabetes and Metabolism
144 Diabetes and Endocrinology
145 Liver and Gastroenterology
146 Internal Medicine (Pancreatic/Diabetes)
147 Urology (Dialysis)
148 Gastroenterology (Endoscopy)
149 Obstetrics and Gynecology (fertility treatment)
150 Obstetrics and Gynecology (Reproductive Medicine)
151 Nephrology (Dialysis)
152 Fertility Treatment and Obstetrics and Gynecology
153 Breast and Radiology
154 Endocrinology and Diabetes
155 Infectious Diseases and Respiratory Medicine
156 Diabetes and Endocrinology
157 Kidney Transplantation/Urology
158 Internal Medicine (Cardiovascular and Respiratory)
159 Dermatology (including sexually transmitted diseases)
160 Otolaryngology (Tracheoesophageal)
161 Pain Clinic Internal Medicine
162 Pain Clinic Surgery
163 Department of Rehabilitation
164 Tracheoesophageal and Otolaryngology
165 Obstetrics and Gynecology (Obstetrics, Gynecology)
166 Department of Diabetes and Lipid Metabolism
167 Diabetes and Metabolism
168 Gastrointestinal, Colon and Anal Surgery
169 Internal Medicine (Pain Clinic)
170 Internal Medicine (Cardiology/Dialysis)
171 Obstetrics and Gynecology (Gynecology and Obstetrics)
172 Liver, Gallbladder and Pancreatic Medicine
173 Surgery
174 Gastroenterology and Gastroenterology (Endoscopy)
175 Cosmetic Dermatology (Private practice only)
176 Nephrology and Urology (Dialysis)
177 Pain Clinic Orthopedic Surgery
178 Cardiac Rehabilitation
179 Diabetes, Metabolism, Endocrinology
180 Gynecology (Infertility Treatment/Reproductive Medicine)
181 Internal Medicine (Dialysis Internal Medicine, Nephrology Internal Medicine)
182 Internal Medicine (Gastroenterology, Cardiology)
183 Internal Medicine (Cardiovascular, Digestive, Respiratory)
184 Internal Medicine (Digestive, Circulatory, Respiratory)
185 Internal Medicine (Gastroenterology, Diabetes, Cardiovascular)
186 Obstetrics and Gynecology (Obstetrics, Gynecology, Infertility Treatment)
187 Internal Medicine (outpatient care abolished, inpatient only)
188 Internal Medicine (Diabetes, Cardiovascular, Respiratory, Digestive)
189 Gynecology (Reproductive Medicine/Puberty/Endocrinology)
190 Internal Medicine (Gastroenterology, Endoscopy, Liver, Diabetes)
191 Internal medicine
192 Pain Clinic Rehabilitation
193 Internal Medicine (Cardiovascular, Diabetes, Endocrinology, Lipid Metabolism)
194 Internal Medicine (Gastrointestinal, Cardiovascular, Respiratory, Diabetes/Endocrinology)
195 Internal medicine
196 Internal Medicine
197 Internal Medicine
198 Internal Medicine (Cardiovascular, Respiratory, Digestive, Diabetes/Metabolism, Dialysis)
199 Venereal Diseases
200 Hepatology
201 Neurology
202 Brain Surgery
203 Endocrinology
204 Oral Surgery
205 Respiratory Medicine
206 Gynecology
206 Gynecology
207 Pediatric Ophthalmology
208 Plastic Ophthalmology
209 Infectious Diseases
210 Kampo Ophthalmology
211 Dermatology
212 Neurosurgery
213 Cosmetic Medicine
214 Geriatric Medicine
215 Geriatric Medicine
216 Thoracic Surgery
217 Spine Surgery
218 Kidney Surgery
219 Oncology
220 Vascular Medicine
221 Internal Medicine (Nephrology)
222 Surgery (Cancer)
223 Endoscopic Surgery
224 Pediatric Neurology
225 Pediatric Psychiatry
226 Pediatric Otolaryngology
227 Psychosomatic Dermatology
228 Cardiac Pediatrics
229 Kampo Pediatrics
230 Kampo Dermatology
231 Kampo Psychiatry
232 Physical Medicine
233 Thyroid Surgery
234 Male Dermatology
235 Neuropediatrics
236 Department of Psycho-Oncology
237 Gastroenterology
238 Gallbladder Surgery
239 Cerebrovascular Medicine
240 Dermatology Oncology
241 Clinical Laboratory
242 Head Dermatology
243 Head and Neck Surgery
244 Head and Neck Surgery
245 Geriatric Medicine
246 Rheumatology
247 Fertility Medicine
248 Respiratory Pediatrics
249 Colon and Proctology
250 Womens Kampo Medicine
251 Female Anal Surgery
252 Pediatric Plastic Surgery
253 Pediatric Psychiatry
254 Pediatric Urology
255 Pediatric Orthodontics
256 Adolescent Psychiatry
257 Sexually Transmitted Disease Surgery
258 Neonatal Pediatrics
259 Tracheoesophageal Medicine
260 Tracheoesophageal Surgery
261 Gastroenterology/Surgery
262 Kampo Psychosomatic Medicine
263 Reproductive Surgery
264 Department of Neurology and Psychiatry
265 Palliative Care Surgery
266 Palliative Medicine
267 Geriatric Neurology
268 Department of Lipid Metabolism
269 ​​Neurology and Vascular Medicine
270 Kidney Transplant Surgery
271 Department of Radiation Oncology
272 Medical Surgery
273 Surgery(Breast Surgery)
274 Surgery (Anal Surgery)
275 Pediatric Surgery (Kampo)
276 Pediatrics (Endocrinology)
277 Obstetrics and Gynecology (Cancer)
278 Colon and Proctology
279 Pediatric Endocrinology
280 Pediatric Respiratory Medicine
281 Pediatric Cardiology
282 Pediatric Otolaryngology
283 Pediatric Neurosurgery
284 Plastic and Cosmetic Surgery
285 Infectious Disease Urology
286 Gastroenterology and Hepatology
287 Kampo Otolaryngology
288 Anal and Colon Surgery
289 Gastroenterology and Hepatology
290 Nephrology and Hypertension
291 Esophageal and Gastroenterology
292 Breast Surgery
293 Internal Medicine (Endocrine Metabolism)
294 Surgery (Gastroenterology/Orthopedics)
295 Gastroenterology (Endoscopy)
296 Otolaryngology (Pediatrics)
297 Pain Clinic
298 Fertility Urology
299 Breast and Thyroid Surgery
300 Metabolism and Endocrinology
301 Internal Medicine for Children and Adolescents
302 Pediatric Allergy
303 Pediatric Radiation Oncology
304 Pediatric Otolaryngologist
305 Cardiology and Women's Internal Medicine
306 Gastroenterology and Nephrology
307 Gastroenterology and Hematology
308 Kampo Allergy
309 Male Infertility Surgery
310 Diabetes and Endocrinology
311 Gastroenterology and Gastroenterology
312 Pancreas and Gastroenterology
313 Gastroenterology/Endoscopy
314 Urology (Fertility Treatment)
315 Urology (Reproductive Medicine)
316 Gastroenterological Surgery (Endoscopy)
317 Medical Oncology (Chemotherapy)
318 Medical Oncology (Pain Relief)
319 Allergic Medicine
320 Immunology and Rheumatology
321 Child and Adolescent Psychiatry
322 Colon and Gastroscopy
323 Gastroenterology and Endoscopy
324 Gastroenterology and Cardiology
325 Gastroenterology and Diabetes
326 Pain and Palliative Care Internal Medicine
327 Palliative Care/Geriatrics
328 Hematology and Chemotherapy
329 Cardiology (Dialysis)
330 Gastroenterology (Gastroenterology)
331 Diabetes Internal Medicine (Metabolic Internal Medicine)
332 Rheumatology and Collagen Disease Internal Medicine
333 Respiratory and Allergy
334 Department of Pathological Diagnosis and Clinical Laboratory
335 Otolaryngology and Tracheoesophageal Medicine
336 Department of Lipid Metabolism and Diabetes
337 Surgery (Pain Clinic)
338 Urology (Male Fertility Treatment)
339 Gastroenterology (Endoscopy)
340 Respiratory and Allergology
341 Gastroenterology and Endoscopy
342 Kampo Pediatrics and Psychosomatic Pediatrics
343 Diabetes, Metabolism, Endocrinology
344 Internal Medicine (Gastroenterology, Gastroenterology, Endoscopy)
345 Endocrinology and Metabolism (Diabetes)
346 Gastroenterology (Hepatology/Endoscopy)
347 Gastroenterology and Gastroenterology (Endoscopy)
348 Orthopedic Rehabilitation
349 Tracheoesophageal Surgery, Otolaryngology
350 Gastroenterology, Hematology, Collagen Disease Internal Medicine
351 Diabetes, Endocrinology and Metabolism
352 Liver, Endoscopy, Gastroenterology
353 Urology (Dialysis/Kidney Transplantation)
354 Psychiatry (Women/Children/Adolescents)
355 Internal Medicine (Cardiovascular, Digestive, Liver, Kampo)
356 Internal Medicine (Gastrointestinal/Cardiovascular/Diabetes)
357 Internal Medicine (Hematology, Liver, Diabetes Metabolism, Kidney)
358 Respiratory Medicine/Nephrology (Dialysis)
359 Surgery (Gastrointestinal, Breast, Anal, Respiratory)
360 Gastroenterology (Gastrointestinal, Anal, Endoscopy)
361 Surgery (Gastrointestinal, Breast, Anal, Endoscopy, Cranial Nerve)
362 Gastroenterology (Hepatology, Respiratory, Cardiovascular, etc.)
363 Breast
364 Hand Surgery
365 Otolaryngology
366 Clinical Department
367 Endoscopy
368 Department of Infectious Diseases
369 Kampo Surgery
370 Pain Internal Medicine
371 Psychiatry
372 Liver Surgery
373 Stroke Department
374 Pancreatic Medicine
375 Outside (Endoscope)
376 Preventive Medicine
377 Home Clinic
378 Women's Dermatology
379 Plastic Dermatology
380 Kampo Gynecology
381 Department of Palliative Care
382 Geriatric Dermatology
383 Collagen Disease Internal Medicine
384 Hemodialysis
385 Head and Neck Internal Medicine
386 Internal Medicine (Respiratory)
387 Internal Medicine (Neonatal)
388 Surgery (Gastrointestinal)
389 Fertility Surgery
390 Pediatric Psychosomatic Medicine
391 Endocrinology and Metabolism
392 Respiratory Internal Medicine
393 Pediatric Nephrology
394 Kampo Womens Internal Medicine
395 Pain Relief Surgery
396 Neurology and Psychiatry
397 Neuroradiology
398 Kidney Dialysis Surgery
399 Internal Medicine (Medical Examination)
400 Pediatrics (Neonatal)
401 Gastroenterology (Gastroenterology)
402 Allergy Medicine
403 Breast Pathology
404 Surgery (Anal, Breast)
405 Womens Laboratory
406 Cardiac Rehabilitation
407 Cardiology and Vascular Medicine
408 Sexually Transmitted Diseases Gynecology
409 Department of Lifestyle Medicine
410 Neuro-Otolaryngology
411 Hepatology and Gastroenterology
412 Gastroenterology and Proctology
413 Gastrointestinal and Anal Surgery
414 Renal Rheumatology
415 Nephrology and Metabolism
416 Esophageal and Gastrointestinal Surgery
417 Gastroenterology (Gastroenterology)
418 Child and Adolescent Psychiatry
419 Perinatal Cardiology
420 Pediatric Dentistry Oral Surgery
421 Pediatric Neuropsychiatric Medicine
422 Cardiology and Nephrology
423 Infectious Diseases and Oncology
424 Gastrointestinal rheumatology
425 Gastroenterology and Endoscopy
426 Digestive and Anal Surgery
427 Pain Palliative Care Internal Medicine
428 Skin Allergy
429 Anal and Gastroenterology
430 Internal Medicine (Fever Outpatient Specialty)
431 Surgery(Gastrointestinal Endoscopy)
432 Womens Internal Medicine (Sexually Transmitted Diseases)
433 Pediatrics (Children and Adolescents)
434 Diabetes (Metabolic Medicine)
435 Pain Clinic
436 Thyroid and Endocrinology
437 Parotid and Thyroid Surgery
438 Nephrology and Dialysis Internal Medicine
439 Nephrology, Breast Surgery
440 Surgery (Stomach/Colon/Anal)
441 Cancer and Breast Radiology
442 Allergic Dermatology
443 Endoscopy/Hepatology
444 Department of Respiratory Allergy
445 Respiratory Medicine/Oncology
446 Collagen Disease and Rheumatology
447 Blood Purification and Diabetes Internal Medicine
448 Internal Medicine (Nephrology, Dialysis, Diabetes)
449 Surgery(Liver/Pancreas/Transplantation)
450 Endocrinology, Metabolism and Diabetes
451 Gastrointestinal, Colon and Endoscopy
452 Hepatology and Gastroenterology (Endoscopy)
453 Womens Pain Clinic Internal Medicine
454 Pediatric Rehabilitation
455 Cardiology, Respiratory and Nephrology
456 Pain Clinic/Orthopedics
457 Neurological Rehabilitation
458 Cardiology, Nephrology, Metabolism and Endocrinology
459 Gastrointestinal, Colon, Gallbladder and Anal Surgery
460 Calls
461 Throat
462 Immunology
463 Pain Clinic
464 Smoking Cessation Clinic
465 Palliative medicine
466 Visiting Dentistry
467 Internal Medicine (Home)
468 Internal Medicine (Vascular)
469 Vaccination Department
470 Medical Examination Department
471 Adolescent Internal Medicine
472 Department of Oriental Medicine
473 Beauty and Gynecology
474 Gastroenterology Surgery
475 Gall bladder Internal Medicine
476 Kidney Pediatrics
477 Hypertension
478 Internal Medicine (Gastroenterology)
479 Breast Oncology
480 Chemotherapy Internal Medicine
481 Surgery/Gastroenterology
482 Female Breast Surgery
483 Womens Psychosomatic Medicine
484 Pediatric Cardiology
485 Neonatal Dermatology
486 Peripheral Blood Surgery
487 Kampo Gastroenterology
488 Gastroenterology and Proctology
489 Psychosomatic Medicine (Kampo)
490 Obstetrics and Gynecology (Kampo)
491 Pediatric Rheumatology
492 Adolescent Psychosomatic Medicine
493 Kampo rheumatology
494 Kampo Gastroenterology
495 Pain Relief Dermatology
496 Nephrology and Dialysis
497 Nephrology and Diabetes
498 Gastroenterology (Endoscopy)
499 Pediatric Psychiatry
500 Pediatric Neurodevelopment Clinic
501 Diabetes and Hematology
502 Gallbladder and Pancreatic Medicine
503 Nephrology and Endocrinology
504 Tumor Pain Relief Medicine
505 Hypertension and Endocrinology
506 Endocrinology (Thyroid)
507 Surgery (Breast/Thyroid)
508 Rheumatism and Collagen Disease Internal Medicine
509 Pediatric Hematology and Oncology
510 Cardiology and Respiratory Medicine
511 Cervical, Thyroid and Breast Surgery
512 Gastrointestinal Surgery
513 Pediatric Endocrinology and Metabolism
514 Orthopedics and Rheumatology
515 Airway, Esophageal, Otolaryngology
516 Gastroenterology, Colonoscopy and Endoscopy
517 Kampo Medical Oncology (Gan Kampo)
518 Liver/Gall Bladder/Pancreatic Surgery
519 Nephrology, Endocrinology and Metabolism
520 Anesthesiology (Pain Clinic)
521 Allergy and Rheumatology
522 Endocrinology, Diabetes and Metabolism
523 Kampo Medicine and Allergic Internal Medicine
524 Orthopedics (Pain Clinic)
525 Urology (Nephrology, Dialysis, Sexually Transmitted Diseases)
526 Internal medicine (lipid metabolism, endocrinology, pancreas, pain clinic)
527 Abdominal Surgery
528 Cancer Psychiatry
529 Pediatric Psychiatry
530 Dental Anesthesiology
531 Diabetes Surgery
532 Stroke Internal Medicine
533 Brain Tumor Surgery
534 Geriatric Dentistry
535 Cancer Psychosomatic Medicine
536 Female Proctology
537 Spine and Spinal Surgery
538 Geriatric Dermatology
539 Colon Endoscopic Surgery
540 Kampo Respiratory Medicine
541 Kampo Cardiology
542 Department of Diabetes and Endocrinology
543 Gastroenterology/Surgery
544 Spine/Spinal Surgery
545 Hematology and Nephrology
546 Cardiology (Dialysis)
547 Sports Orthopedics
548 Respiratory and Oncology
549 Pediatric Hematology and Oncology
550 Kampo Medicine and Psychiatry
551 Inflammatory Bowel Medicine
552 Male Sexually Transmitted Disease Surgery
553 Nephrology and Rheumatology
554 Pancreas and Gallbladder Internal Medicine
555 Endoscopic Surgery (Gastrointestinal)
556 Obstetrics and Gynecology (Sexually Transmitted Diseases)
557 Respiratory Medicine (Chemotherapy)
558 Rheumatoid and Collagen Disease Internal Medicine
559 Department of Endocrinology and Lipid Metabolism
560 Allergy and Collagen Disease Internal Medicine
561 Orthopedics (Sports Medicine)
562 Gastroenterology (Endoscopy, Liver)
563 Department of Lipid Metabolism and Thyroid Medicine
564 Reproductive Medicine/Fertility Obstetrics and Gynecology
565 Geriatrics
566 Neuro-Ophthalmology
567 Perinatal Medicine
568 Psychosomatic Psychiatry
569 Urology
570 Cervical Surgery
571 Geriatric Psychiatry
572 Radiological diagnosis fee
573 Kampo Obstetrics and Gynecology
574 Pharmacotherapeutic Internal Medicine
575 Hematology and Oncology
576 Breast Surgery/Internal Medicine
577 Respiratory Oncology
578 Cardiovascular Surgery
579 Urology and Infectious Diseases
580 Surgery(Mammary Gland/Gastrointestinal)
581 Anal Surgery (Endoscopy)
582 Cancer Chemotherapy
583 Endoscopy (Internal Medicine, Surgery)
584 Gastroenterological and Breast Surgery
585 Dialysis Internal Medicine (Artificial Dialysis)
586 Rheumatology and Connective Diseases
587 Nephrology and Rheumatology
588 Urology/Pediatric Urology
589 Otolaryngology, Head and Neck Surgery
590 Hepatology, Diabetes and Endocrinology
591 Pain Clinic/Psychosomatic Medicine
592 Pain Clinic (Orthopedics)
593 Anesthesiology (Pain Clinic Orthopedic Surgery)
594 Female Surgery
595 Transplant surgery
596 Esophageal Surgery
597 Gastrointestinal Surgery
598 Forgetful Outpatient
599 Physical Therapy
600 Department of Physical Diagnosis
601 Medical drug therapy
602 Pediatric Kampo Medicine
603 Kampo Urology
604 Nephrology and Hypertension
605 Gastroenterological Endoscopy
606 Kampo Neurology
607 Thoracic and Breast Surgery
608 Oncology and Hematology
609 Hematologic rheumatology
610 Dialysis and vascular surgery
611 Rheumatology and Internal Medicine
612 Breast and Endocrinology
613 Dialysis Vascular Surgery
614 Gastroenterology and Endoscopy
615 Hypertension and Diabetes Medicine
616 Internal Medicine (General Medicine)
617 Pediatrics (Cardiology)
618 Department of Respiratory and Infectious Diseases
619 Gastroenterological and Endoscopic Surgery
620 Head and Neck, Otolaryngology
621 Department of Respiratory Medicine and Chemotherapy
622 Cardiovascular Surgery
623 Pancreatic Surgery
624 Coloproctology
625 Neonatal Surgery
626 Developmental Pediatrics
627 Breast Oncology
628 Chemotherapy Surgery
629 Plastic and cosmetic surgery
630 Stroke Clinic
631 Surgery and orthopedics
632 Pediatric Infectious Diseases
633 Kampo Neurosurgery
634 Rheumatism and Collagen Disease
635 Breast and Digestive Surgery
636 Pediatric Cardiovascular Surgery
637 Gastroenterology and general internal medicine
638 Plastic and cosmetic surgery
639 Collagen disease, rheumatology
640 Allergy (Respiratory)
641 Rehabilitation Internal Medicine
642 Cardiovascular Surgery/Vascular Surgery
643 Medical Oncology and Palliative Care Medicine
644 Sports Surgery, Rheumatology
645 Pain Relief Internal Medicine (Nervous System, Cancer, Diabetes, Allergic Diseases)
646 Cosmetology
647 Neonatology
648 Esophageal Medicine
649 Geriatric Medicine
650 Liver Medicine
651 Clinical Pathology
652 Endoscopic Gynecology
653 Pediatric Hematology
654 Kampo Gastroenterology
655 Pediatric Neurology
656 Pulmonary Radiology
657 Breast and Endocrine Surgery
658 Pediatrics (Pediatric Cardiology)
659 Respiratory, Mammary and Endocrine Surgery
660 Department of Rehabilitation (Orthopedics, Cranial Nerves)
661 Developmental Pediatrics
662 Pediatrics (Brain)
663 Pediatric Neurosurgery
664 Airway and Esophageal Surgery
665 Neurourology
666 Cosmetic surgery
667 Radiation Oncology
668 Cardiology (Arrhythmia)
669 Allergy (Pediatrics)
670 Allergic diseases Rheumatology
671 Cardiac Surgery
672 Department of Regenerative Medicine
673 Kampo medicine
674 Palliative Medicine
675 Brain and Neurology
676 Oncology and Hematology
677 Surgery (Cancer Chemotherapy)
678 Surgery (Gastrointestinal/Breast)
679 Department of Skin Oncology/Dermatology
680 Gastrointestinal Surgery (Gastrointestinal/Anal)
681 Gallbladder, Liver and Pancreas Surgery
682 Surgery (Cancer)
683 Psychiatry (Neurology)
684 Cerebrovascular Surgery
685 Respiratory and cardiology
686 Oncology and Pain Relief Surgery
687 Laboratory/Emergency Department
688 Otolaryngology, Head and Neck Surgery
689 Diabetes Metabolism and Endocrinology
690 Rheumatology and Allergy Medicine
691 Dermatology
692 Radiation Oncology
693 Renal Dialysis Internal Medicine
694 Spine/Spine Surgery
695 Gastroenterology (Stomach/Colon)
696 Breast Surgery/Endocrine Surgery
697 Allergy and Rheumatology
698 Collagen Disease and Allergy Internal Medicine
699 Otolaryngology, Head and Neck Surgery
700 Transplant Medicine
701 Obstetrics and Gynecology
702 Diabetic Ophthalmology
703 Stomach transplant surgery
704 Stomach and Esophageal Surgery
705 Female Endoscopic Surgery
706 Neural Regenerative Medicine
707 Surgery and Neurology
708 Respiratory and Collagen Disease Internal Medicine
709 Head and Neck, Otolaryngology
710 Liver, Gallbladder and Spleen Surgery
711 Nephrology (Dialysis, Kidney Transplantation)
712 Vascular Surgery
713 Psychiatry (Pediatrics)
714 Thoracic and Vascular Surgery
715 Endocrinology (Diabetes)
716 Pain Click Surgery
717 Rehabilitation (Pediatrics)
718 Pain Clinic/Palliative Care Surgery
719 General Examination Department
720 Hematology and Oncology
721 Radiology
722 Oncoplastic Surgery
723 Rehabilitation (Orthopedics)
724 Anesthesiology (Pain Clinic)
725 Gastrointestinal, Liver, Gallbladder, Pancreatic Internal Medicine
726 Family medicine
727 Urological Surgery
728 Department of Obstetrics and Perinatal Medicine
729 Oculoplastic Orbital Surgery
730 Gastroenterological Surgery (Endoscopy)
731 Emergency and General Medicine
732 Nephrology and Urology Surgery
733 Kampo Medicine and Pain Relief Medicine
734 Thoracic and Cardiovascular Surgery
735 Cancer Chemotherapy Surgery (Hemp)
736 Liver, Gallbladder and Spleen Internal Medicine
737 Pelvic Floor Rehabilitation
738 Womens Clinic
739 Department of Airway and Esophageal Medicine
740 Orthopedics (hand)
741 Organ transplant surgery
742 Internal Medicine (Hematology, Kidney)
743 Endocrinology and Diabetes
744 Sexually Transmitted Disease Urology
745 Nephrology and Hypertension
746 Cardiac/Vascular/Nephrology
747 Pain Clinic Internal Medicine and Surgery
748 Head and neck department
749 Dentistry and oral surgery
750 Endocrinology, Metabolism and Diabetes
751 Respiratory and Cardiovascular Surgery
752 Joint Surgery
753 Endocrinology and Metabolism
754 Hematology and Rheumatology
755 Respiratory and Breast Surgery
756 Infectious Disease Medicine/Infectious Disease Surgery
757 Kidney Transplantation
758 Breast Oncology
759 Hematology and Oncology Surgery
760 Dermatology and Allergy
761 Department of Dermatology and Skin Oncology
762 Allergy and Respiratory Medicine
763 Gynecology (fertility treatment, endoscopy)
764 Diagnostic Radiology and Radiotherapy
765 Diabetes, Endocrinology and Metabolism, Nephrology
766 Liver, gallbladder, pancreatic and transplant surgery
767 Clinical Oncology
768 Access Outpatient
769 Diabetes Metabolism
770 Metabolic Diabetes Internal Medicine
771 Radiology Imaging
772 Gastroenterology and Metabolism
773 Palliative Care Radiology
774 Allergy and Collagen Disease
775 Maternal Medicine
776 Cervical Surgery
777 Emergency General Medicine
778 Endoscopy/Surgery
779 Respiratory/Allergy/Hematology
780 Head and Neck Surgery
781 Psychosomatic Pediatrics
782 Emergency Department
783 Obstetrics and Gynecology
784 Oncology and Cardiology
785 Genetic Medicine
786 Rheumatology and internal medicine
787 Respiratory and Breast Surgery
788 Pediatric Urogenital Surgery
789 Otolaryngology, Head and Neck Surgery
790 Allergy and Respiratory Medicine
791 Infection Control Medicine
792 Small Intestine and Colon Medicine
793 Emergency Department Gastroenterology
794 Diagnostic Imaging and Therapeutics
795 Hematology and Infectious Diseases Internal Medicine
796 Hypertension/Nephrology
797 Kidney Surgery & Urology
798 Nephrology and Endocrinology
799 Diabetes and Nephrology
800 Kidney Surgery (Kidney Transplantation)
801 Diabetes, Endocrinology and Metabolism
802 Otolaryngology, Head and Neck Surgery
803 Oncology
804 Pediatric Cardiac Surgery
805 Spine/extraspinal cord
806 Respiratory and Cardiovascular Surgery
807 Gastrointestinal, Liver, Gallbladder and Pancreatic Surgery
808 Surgery (Digestive Surgery, Anal Surgery, Cancer)
809 Pediatric Cardiology
810 Nephrology and Rheumatology
811 Diagnostic Radiology (Imaging)
812 Department of Diabetes, Endocrinology, Nephrology and Collagen Disease
813 Department of Neuropathology
814 Liver/Biliary/Pancreatic Surgery
815 Diagnostic Radiology (Department of Nuclear Medicine)
816 Pathology (Kidney, Hematology/Tumor, Infection, Diabetes/Metabolism)
817 Pediatric Nephrology
818 Emergency Medicine
819 Stroke Surgery
820 Emergency and Intensive Care Department
821 Emergency Department (Emergency General Medicine Department)
822 Internal Medicine (Endocrinology, Neonatal, Palliative Care)
823 Department of Neuroradiology and Vascular Radiology
824 Rheumatology and Nephrology
825 Dentistry Oral and Maxillofacial Surgery
826 Cardiovascular Medicine/Cardiology
827 Department of Anesthesiology and Pain Clinic
828 Internal Medicine
829 Chemotherapy
830 Department of Pathology
831 Clinical Pharmacology
832 Laboratory Medicine
833 Cancer Chemotherapy
834 Hematology and Collagen Disease Internal Medicine
835 Geriatric Laboratory
836 Urology (Male Infertility)
837 Clinical examination fee
838 Outpatient Clinic for Women
839 Psychiatry and psychosomatic medicine
840 Geriatric Neurology
841 Bone and Soft Tissue Oncology
842 Endocrinology and Breast Surgery
843 Kampo and Rheumatology
844 Chemotherapy and Palliative Care Internal Medicine
845 Pain Clinic / Pain Relief Surgery
846 Pediatrics (Nephrology, Nerves, Cardiology, Endocrine Metabolism)
847 Pediatric Emergency Department
848 Pediatric Radiology
849 Skin tumor surgery
850 Pediatrics (Nephrology)
851 Clinical Oncology
852 Pediatrics (Neurology)
853 Trachea and Esophageal Surgery
854 Gastroenterological Oncology Surgery
855 Neurological and Vascular Surgery
856 Liver/Gall Bladder/Pancreatic Surgery/Liver Transplant Surgery
857 Pediatrics (Heart)
858 Cerebrovascular Medicine/Surgery
859 Lipid Metabolism/Hematology
860 Esophageal/Stomach/Colon Surgery
861 Cerebrovascular Surgery
862 Pediatric Anesthesiology (Kidney, Pediatric Kidney, Neonatal, Infectious Disease)
863 Gynecologic Oncology
864 Immunology and Infectious Diseases
865 Neuropsychiatry
866 Internal Medicine (Hematology/Oncology, Pediatric Hematology/Oncology)
867 Medical Genetics
868 Internal Medicine (Diabetes/Metabolism, Pediatric Endocrinology/Metabolism)
869 Other management
870 Dialysis and transplant surgery
871 Internal Medicine (Tracheoesophageal, Gastrointestinal, Breast)
872 Nephrology and Urology Surgery")


# Translated all those specialty_name in Japanese to english 


typeof(temp2)
temp2 <- data.frame(temp2)
names(temp2)[1] <- "EN"
separate_rows(temp2$EN, sep = "n")

class(temp2)

temp3 <- data.frame(unlist(strsplit(temp2$EN, "\\n")))

temp3 <- temp3[-206,]

# pooled them together
temp3 <- temp3 %>% bind_cols(temp)
names(temp3)[1] <- "EN"
names(temp3)[2] <- "JP"

fwrite(temp3, "Masters/Lookup_Facilities_Name_EN.txt", sep="\t")

Lookup_Facilities_Name_EN <- fread("Masters/Lookup_Facilities_Name_EN.txt", sep="\t", colClasses = "character")

m_hco_xref <- m_hco_xref %>% left_join(Lookup_Facilities_Name_EN, by=c("specialty_name"="JP"))


receipt_medical_institution_Vyndaqel195pts %>% inner_join(m_hco_xref %>% filter(grepl("Cardiology", EN)) %>% select(iryokikan_no)) %>%
  select(kojin_id) %>% distinct()










# ---------------------------------------------------------------------------------------------------------------------------
# 195 vyndaqel patients ->  Facilities First Vyndaqel +/- Dxs --------------------------------------------------

# Receipts IDs of the First Vyndaqel
receipt_drug_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_drug_Vyndaqel195pts.txt", colClasses = "character")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts[,.(receipt_ym, kojin_id, drug_code, receipt_id)]
receipt_drug_Vyndaqel195pts$receipt_ym <- as.Date(paste0(as.character(receipt_drug_Vyndaqel195pts$receipt_ym), '/01'))
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% filter(drug_code=="622278901")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% group_by(kojin_id) %>% filter(receipt_ym==min(receipt_ym)) %>% distinct() %>%  select(-drug_code) 
names(receipt_drug_Vyndaqel195pts)[1] <- "FirstVyndaqel"


# Facilities associated with that Vyndaqel receipt
receipt_medical_institution_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_medical_institution_Vyndaqel195pts.txt", 
                                     colClasses = "character")
receipt_medical_institution_Vyndaqel195pts <- receipt_medical_institution_Vyndaqel195pts %>% select(kojin_id, receipt_ym, iryokikan_no, receipt_id)
names(receipt_medical_institution_Vyndaqel195pts)[2] <- "FacilityDate"
receipt_medical_institution_Vyndaqel195pts$FacilityDate <- as.Date(paste0(as.character(receipt_medical_institution_Vyndaqel195pts$FacilityDate), '/01'))

temp <- receipt_drug_Vyndaqel195pts %>% left_join(receipt_medical_institution_Vyndaqel195pts, 
                                                  by=c("kojin_id"="kojin_id", "receipt_id"="receipt_id")) %>%
  group_by(kojin_id) %>% filter(FacilityDate==FirstVyndaqel)

# ICD10 codes associated with that vyndaqel script/facility
receipt_diseases_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_diseases_Vyndaqel195pts.txt", 
                                         colClasses = "character")
receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>% select(receipt_ym, kojin_id, diseases_code, receipt_id)
m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_subdiv_code, icd10_subdiv_name_en)
receipt_diseases_Vyndaqel195pts$receipt_ym <- as.Date(paste0(as.character(receipt_diseases_Vyndaqel195pts$receipt_ym), '/01'))

temp2 <-  temp %>% left_join(receipt_diseases_Vyndaqel195pts %>% left_join(m_icd10) %>%
  select(kojin_id, receipt_ym , icd10_subdiv_code, receipt_id) %>% distinct() %>%
    filter(grepl("E851",icd10_subdiv_code)|
             grepl("I431",icd10_subdiv_code)))


# Other ICD10 codes on the same date/facility but on a different script

temp2 <- temp2 %>% left_join(
receipt_diseases_Vyndaqel195pts %>% left_join(m_icd10 %>% select(-icd10_subdiv_name_en)) %>% filter(icd10_subdiv_code=="I431"|
                                                                                                      icd10_subdiv_code=="E851") %>%
  inner_join(receipt_medical_institution_Vyndaqel195pts, by=c("kojin_id"="kojin_id","receipt_id"="receipt_id" )) %>%
  select(kojin_id, receipt_ym, iryokikan_no, icd10_subdiv_code ) %>% distinct(),
by=c("kojin_id"="kojin_id", "FirstVyndaqel"="receipt_ym", "iryokikan_no"="iryokikan_no")
)

temp2 <- temp2 %>% mutate(icd10_subdiv_code.x=ifelse(is.na(icd10_subdiv_code.x), icd10_subdiv_code.y,icd10_subdiv_code.x)) %>%
  select(-c(receipt_ym, icd10_subdiv_code.y))


temp2 %>% select(FirstVyndaqel, kojin_id, iryokikan_no, icd10_subdiv_code.x) %>% distinct()


# In how many different facilities did they have any of these before?

names(temp2)[5] <- "VyndaqelFacility"

temp3 <- temp2 %>% select(FirstVyndaqel, kojin_id, VyndaqelFacility, icd10_subdiv_code.x) %>% distinct() %>%
  select(FirstVyndaqel, kojin_id, VyndaqelFacility, icd10_subdiv_code.x) %>%distinct() %>% drop_na() %>%
  left_join(
    
receipt_diseases_Vyndaqel195pts %>% left_join(m_icd10 %>% select(-icd10_subdiv_name_en)) %>% filter(icd10_subdiv_code=="I431"|
                                                                                                      icd10_subdiv_code=="E851") %>%
  inner_join(receipt_medical_institution_Vyndaqel195pts, by=c("kojin_id"="kojin_id","receipt_id"="receipt_id" )) %>%
  select(kojin_id, receipt_ym, iryokikan_no, icd10_subdiv_code ) %>% distinct(),

by=c("kojin_id"="kojin_id", "icd10_subdiv_code.x"="icd10_subdiv_code")
    
  )

temp3 %>% select(kojin_id) %>% distinct() %>% left_join(
temp3 %>% group_by(kojin_id) %>% filter(receipt_ym<FirstVyndaqel) %>%
  filter(iryokikan_no!=VyndaqelFacility) %>% select(kojin_id, iryokikan_no) %>% distinct() %>%
  count())  %>% 
  ungroup() %>%
  group_by(n) %>% count()
  


receipt_drug_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_drug_Vyndaqel195pts.txt", colClasses = "character")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts[,.(receipt_ym, kojin_id, drug_code, receipt_id)]
receipt_drug_Vyndaqel195pts$receipt_ym <- as.Date(paste0(as.character(receipt_drug_Vyndaqel195pts$receipt_ym), '/01'))
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% filter(drug_code=="622278901")
names(receipt_drug_Vyndaqel195pts)[1] <- "VyndaqelDate"

receipt_medical_institution <- fread("VyndaqelPts195/receipt_medical_institution_Vyndaqel195pts.txt", colClasses = "character")
receipt_medical_institution %>% select(kojin_id, receipt_id, receipt_shubetsu_code)


receipt_drug_Vyndaqel195pts %>% left_join(receipt_medical_institution) %>% drop_na() %>%
  group_by(receipt_shubetsu_code) %>% count()

 receipt_medical_institution$receipt_ym <- as.Date(paste0(as.character(receipt_medical_institution$receipt_ym), '/01'))

 

temp3 %>% select(kojin_id) %>% distinct() %>% left_join(
temp3 %>% group_by(kojin_id) %>% filter(receipt_ym<FirstVyndaqel) %>%
  filter(iryokikan_no!=VyndaqelFacility) %>% select(kojin_id, iryokikan_no) %>% distinct() %>%
  count())  %>% 
  ungroup() %>%
  filter(n==1) %>% select(kojin_id) %>% distinct() %>%
  left_join(
    temp3 %>% group_by(kojin_id) %>% filter(receipt_ym<FirstVyndaqel) %>%
  filter(iryokikan_no!=VyndaqelFacility) %>% select(kojin_id, iryokikan_no) %>% distinct()) %>%
  left_join(receipt_medical_institution %>% select(kojin_id , receipt_shubetsu_code, iryokikan_no, receipt_ym ) %>% distinct()) %>%
  group_by(receipt_shubetsu_code) %>% count()




# Time from first I431 or E851 to first Vyndaqel

 temp2 %>% select(FirstVyndaqel, kojin_id, VyndaqelFacility) %>%
   left_join(
  receipt_diseases_Vyndaqel195pts %>% left_join(m_icd10) %>%
  select(kojin_id, receipt_ym , icd10_subdiv_code) %>% distinct() %>%
    filter(grepl("E851",icd10_subdiv_code)|
             grepl("I431",icd10_subdiv_code)) %>%
    group_by(kojin_id) %>% filter(receipt_ym==min(receipt_ym)) %>% slice(1) %>% 
    select(-icd10_subdiv_code)) %>%
   mutate(Elapsed=as.numeric(FirstVyndaqel-receipt_ym)/30.5) %>% ungroup() %>%
   # summarise(mean=mean(Elapsed)) %>%
   ggplot(aes(Elapsed)) +
   geom_density(alpha = 0.8, fill="darkblue") +
   theme_classic() + 
   xlim(0,25) +
   theme(legend.title = element_blank(), legend.position = "top", legend.justification = "right") +
   ggtitle("Proportion of Vyndaqel patients") +
   xlab("\n Elapsed time (months) from Dx (I431|E851) to Vyndaqel") +
   ylab("Proportion\n")

 
 
 
 temp2 %>% select(FirstVyndaqel, kojin_id, VyndaqelFacility) %>%
   inner_join(
   receipt_diseases_Vyndaqel195pts %>% left_join(m_icd10 %>% select(-icd10_subdiv_name_en)) %>% filter(icd10_subdiv_code=="I431"|
                                                                                                      icd10_subdiv_code=="E851") %>%
  inner_join(receipt_medical_institution_Vyndaqel195pts, by=c("kojin_id"="kojin_id","receipt_id"="receipt_id" )) %>%
  select(kojin_id, receipt_ym, iryokikan_no ) %>% distinct(),
  by=c("kojin_id"="kojin_id", "VyndaqelFacility"="iryokikan_no")
  ) %>%
   ungroup() %>%
   group_by(kojin_id) %>% filter(receipt_ym==min(receipt_ym)) %>% slice(1) %>% 
    mutate(Elapsed=as.numeric(FirstVyndaqel-receipt_ym)/30.5) %>% ungroup() %>%
   #summarise(mean=mean(Elapsed)) %>% # 3.41
  ggplot(aes(Elapsed)) +
   geom_density(alpha = 0.8, fill="darkblue") +
   theme_classic() + 
   xlim(0,20) +
   theme(legend.title = element_blank(), legend.position = "top", legend.justification = "right") +
   ggtitle("Proportion of Vyndaqel patients") +
   xlab("\n Elapsed time (months) from Dx (I431|E851) to Vyndaqel") +
   ylab("Proportion\n")
   
   
   receipt_diseases_Vyndaqel195pts %>% left_join(m_icd10 %>% select(-icd10_subdiv_name_en)) %>% filter(icd10_subdiv_code=="I431"|
                                                                                                      icd10_subdiv_code=="E851") %>%
  inner_join(receipt_medical_institution_Vyndaqel195pts, by=c("kojin_id"="kojin_id","receipt_id"="receipt_id" )) %>%
  select(kojin_id, receipt_ym, iryokikan_no ) %>% distinct()
   
# -------------------------------------------------------------------------------------------------
# 195 vyndaqel patients -> # % Subsequent Scripts ON Same Facility vs Different Facility --------------------------------------

# Receipts IDs of the First Vyndaqel
receipt_drug_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_drug_Vyndaqel195pts.txt", colClasses = "character")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts[,.(receipt_ym, kojin_id, drug_code, receipt_id)]
receipt_drug_Vyndaqel195pts$receipt_ym <- as.Date(paste0(as.character(receipt_drug_Vyndaqel195pts$receipt_ym), '/01'))
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% filter(drug_code=="622278901")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>%  select(-drug_code) 

receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% 
  left_join(receipt_drug_Vyndaqel195pts %>% group_by(kojin_id) %>% filter(receipt_ym==min(receipt_ym)) %>% distinct() %>% 
              mutate(FirstVyndaqel="FirstVyndaqel")) %>% arrange(kojin_id, receipt_ym) %>% ungroup()



# Facilities associated with that Vyndaqel receipt
receipt_medical_institution_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_medical_institution_Vyndaqel195pts.txt", 
                                     colClasses = "character")
receipt_medical_institution_Vyndaqel195pts <- receipt_medical_institution_Vyndaqel195pts %>% select(kojin_id, receipt_ym, iryokikan_no, receipt_id)
names(receipt_medical_institution_Vyndaqel195pts)[2] <- "FacilityDate"
receipt_medical_institution_Vyndaqel195pts$FacilityDate <- as.Date(paste0(as.character(receipt_medical_institution_Vyndaqel195pts$FacilityDate), '/01'))

receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% left_join(receipt_medical_institution_Vyndaqel195pts, 
                                                  by=c("kojin_id"="kojin_id", "receipt_id"="receipt_id", "receipt_ym"="FacilityDate")) 

receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% distinct()

temp <-receipt_drug_Vyndaqel195pts %>% filter(FirstVyndaqel=="FirstVyndaqel") %>% select(receipt_ym, kojin_id, iryokikan_no) %>% distinct()
names(temp)[3] <- "First_Facility"
temp <- temp %>% select(kojin_id, First_Facility) %>% distinct()

receipt_drug_Vyndaqel195pts %>% left_join(temp) %>% filter(is.na(FirstVyndaqel)) %>%
  mutate(Same=ifelse(First_Facility==iryokikan_no,"YES","NO")) %>%
  select(kojin_id,Same) %>%
  group_by(kojin_id,Same) %>% count() %>%
  ungroup() %>%
  spread(key=Same, value=n) %>%
  mutate(NO=ifelse(is.na(NO),0,NO)) %>%
  mutate(YES=ifelse(is.na(YES),0,YES)) %>%
  summarise(n=mean(NO))



data.frame(data.frame(receipt_drug_Vyndaqel195pts %>% left_join(temp) %>% filter(is.na(FirstVyndaqel)) %>%
  group_by(kojin_id) %>% count()) %>% filter(n>3) %>% select(kojin_id) %>%
  left_join(receipt_drug_Vyndaqel195pts %>% left_join(temp) %>% filter(is.na(FirstVyndaqel))) %>%
  mutate(Same=ifelse(First_Facility==iryokikan_no,"YES","NO")) %>%
  select(kojin_id,Same) %>%
  group_by(kojin_id,Same) %>% count() %>%
  ungroup() %>%
  spread(key=Same, value=n) %>%
  mutate(NO=ifelse(is.na(NO),0,NO)) %>%
  mutate(YES=ifelse(is.na(YES),0,YES)) %>%
  mutate(TOTAL=NO+YES) %>%
  mutate(PercentYes=YES/TOTAL) %>%
  select(kojin_id, PercentYes) %>%
  arrange(PercentYes)) %>%
  mutate(PercentYes=ifelse(PercentYes==0,"0",
                           ifelse(PercentYes==1,"100",
                                  ifelse(PercentYes>0&PercentYes<=0.20,"<20",
                                         ifelse(PercentYes>0.20&PercentYes<=0.40,"<40",
                                                ifelse(PercentYes>0.40&PercentYes<=0.60,"<60",
                                                       ifelse(PercentYes>0.60&PercentYes<=0.80,"<80",
                                                              ifelse(PercentYes>0.80&PercentYes<1,"<100",NA)))))))) %>%
  group_by(PercentYes) %>% count()



data.frame(data.frame(receipt_drug_Vyndaqel195pts %>% left_join(temp) %>% filter(is.na(FirstVyndaqel)) %>%
  group_by(kojin_id) %>% count()) %>%  select(kojin_id) %>%
  left_join(receipt_drug_Vyndaqel195pts %>% left_join(temp) %>% filter(is.na(FirstVyndaqel))) %>%
  mutate(Same=ifelse(First_Facility==iryokikan_no,"YES","NO")) %>%
  select(kojin_id,Same) %>%
  group_by(kojin_id,Same) %>% count() %>%
  ungroup() %>%
  spread(key=Same, value=n) %>%
  mutate(NO=ifelse(is.na(NO),0,NO)) %>%
  mutate(YES=ifelse(is.na(YES),0,YES)) %>%
  mutate(TOTAL=NO+YES) %>%
  mutate(PercentYes=YES/TOTAL) %>%
  select(kojin_id, PercentYes) %>%
  arrange(PercentYes)) %>%
  mutate(PercentYes=ifelse(PercentYes==0,"0",
                           ifelse(PercentYes==1,"100",
                                  ifelse(PercentYes>0&PercentYes<=0.20,"<20",
                                         ifelse(PercentYes>0.20&PercentYes<=0.40,"<40",
                                                ifelse(PercentYes>0.40&PercentYes<=0.60,"<60",
                                                       ifelse(PercentYes>0.60&PercentYes<=0.80,"<80",
                                                              ifelse(PercentYes>0.80&PercentYes<1,"<100",NA)))))))) %>%
  group_by(PercentYes) %>% count()

# -----------------------------------------------------------------------------------------------copy_receipt_drug
# 195 vyndaqel patients -> Check G6 among PN Vyndaqel patients ---------------------------------
Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")

receipt_diseases_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_diseases_Vyndaqel195pts.txt", 
                                         colClasses = "character")
receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>% select(receipt_ym, kojin_id, diseases_code)
m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_subdiv_code)

Vyndaqel_pats_CM_vs_PN %>% filter(PN==1) %>% select(kojin_id) %>% 
  inner_join(
    receipt_diseases_Vyndaqel195pts %>% left_join(m_icd10) %>%
  select(kojin_id, icd10_subdiv_code) %>% distinct() %>%
  filter(grepl("G6",icd10_subdiv_code)) %>% select(kojin_id) %>% distinct()
)
# -----------------------------------------------------------------------------------------------------------------
# 195 vyndaqel patients -> Suspicion / Confirmation rate ------------------------------
receipt_diseases_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_diseases_Vyndaqel195pts.txt", 
                                         colClasses = "character")

receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>% select(kojin_id, diseases_code, utagai_flg)

m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
Codes_I431 <- m_icd10 %>% filter(icd10_code=="I431") %>% select(diseases_code)


m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
Codes_E851 <- m_icd10 %>% filter(icd10_code=="E851") %>% select(diseases_code)


m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
Codes_I50 <- m_icd10 %>% filter(grepl("I50",icd10_code)) %>% select(diseases_code)


receipt_diseases_Vyndaqel195pts %>% inner_join(Codes_I431) %>% group_by(utagai_flg) %>% count()

receipt_diseases_Vyndaqel195pts %>% inner_join(Codes_E851) %>% group_by(utagai_flg) %>% count()

receipt_diseases_Vyndaqel195pts %>% inner_join(Codes_I50) %>% group_by(utagai_flg) %>% count()


# -------------------------
# Subset tables for continuously enrolled patients   ---------------------------------------------------------------
  
# Pagify function to get things in chunks from the database
# Arguments: 'data' -> a vector of values respecting ideally to an indexed data field in the DB table; 
# 'by' -> batch length
  
pagify <- function(data = NULL, by = 1000){
    pagemin <- seq(1,length(data), by = by)
    pagemax <- pagemin - 1 + by
    pagemax[length(pagemax)] <- length(data)
    pages   <- list(min = pagemin, max = pagemax)
  }
  
  
# vector of continuosly enrolled patients
ContinuouslyEnrolled_Y3_tekio_weights <- fread("All_Pts_ContinuousEnrolled/ContinuouslyEnrolled_Y3_tekiyo_weights.txt", sep="\t")
ContinuouslyEnrolled_Y3_tekio_weights <- ContinuouslyEnrolled_Y3_tekio_weights %>% select(kojin_id) %>% distinct()

pages <- pagify(ContinuouslyEnrolled_Y3_tekio_weights$kojin_id, 1000)
  
  

 
# Tekiyo continuously enrolled ALL pats

tekiyo_All_ContEnr_pts <- data.table()

# vyndaqel.tekiyo

for(i in 1:length(pages$max)) {
    pts <- paste0(ContinuouslyEnrolled_Y3_tekio_weights$kojin_id[pages$min[i]:pages$max[i]], collapse = "','")
    query <- paste0("SELECT kojin_id, observable_start_ym, observable_end_ym FROM vyndaqel.tekiyo  WHERE kojin_id IN ('",pts,"');")
    data  <- setDT(dbGetQuery(con, query))
    tekiyo_All_ContEnr_pts <- rbind(tekiyo_All_ContEnr_pts, data)
}

fwrite(tekiyo_All_ContEnr_pts, "All_Pts_ContinuousEnrolled/tekiyo_All_ContEnr_pts.txt", sep="\t")

  
  




# Exam interview continuously enrolled ALL pats  #

exam_interview_All_ContEnr_pts <- data.table()

# vyndaqel.exam_interview

for(i in 1:length(pages$max)) {
    cat(i)
    pts <- paste0(ContinuouslyEnrolled_Y3_tekio_weights$kojin_id[pages$min[i]:pages$max[i]], collapse = "','")
    query <- paste0("SELECT * FROM vyndaqel.exam_interview  WHERE kojin_id IN ('",pts,"');")
    data  <- setDT(dbGetQuery(con, query))
    exam_interview_All_ContEnr_pts <- rbind(exam_interview_All_ContEnr_pts, data)
}

fwrite(exam_interview_All_ContEnr_pts, "All_Pts_ContinuousEnrolled/exam_interview_All_ContEnr_pts.txt", sep="\t")

  










# Diseases table for Es and Is only  #

# create "copy_receipt_diseases" with only 3 colunms



# filter patients with diseases of interest -- E85, I50, I42

m_icd10 <- fread("Masters/m_icd10.csv")
m_icd10 <- m_icd10[,.(diseases_code, icd10_code)]

diseases_codes_E85I50I42 <- m_icd10 %>% filter(grepl("E85",icd10_code)|
                                                 grepl("I50",icd10_code)|
                                                 grepl("I42",icd10_code)) %>%
  select(diseases_code) %>% distinct()

query <- paste0("SELECT DISTINCT(table2.kojin_id) FROM 
                (SELECT DISTINCT(diseases_code) FROM vyndaqel.m_icd10
                WHERE icd10_code LIKE ('E85%') OR 
                      icd10_code LIKE ('I50%') OR
	                    icd10_code LIKE ('I42%')) AS table1
                JOIN
                (SELECT * FROM vyndaqel.copy_receipt_diseases) AS table2
                ON table1.diseases_code = table2.diseases_code;")

PatsWithE85I50I42  <- setDT(dbGetQuery(con, query))

PatsWithE85I50I42 %>% inner_join(ContinuouslyEnrolled_Y3_tekio_weights) # wouldn't reduce much, only to 1436584 kojin_id 's

fwrite(PatsWithE85I50I42, "All_Pts_ContinuousEnrolled/PatsWithE85I50I42.txt", sep="\t")




query <- paste0("SELECT COUNT(*) FROM 
                (SELECT DISTINCT(diseases_code) FROM vyndaqel.m_icd10
                WHERE icd10_code LIKE ('E85%') OR 
                      icd10_code LIKE ('I50%') OR
	                    icd10_code LIKE ('I42%')) AS table1
                JOIN
                (SELECT * FROM vyndaqel.copy_receipt_diseases) AS table2
                ON table1.diseases_code = table2.diseases_code;")

countDiseasesClaimsE85I50I42  <- setDT(dbGetQuery(con, query)) # 41068842


query <- paste0("SELECT COUNT(*) FROM 
                (SELECT DISTINCT(diseases_code) FROM vyndaqel.m_icd10
                WHERE icd10_code LIKE ('O%') OR 
                      icd10_code LIKE ('P%') OR
	                    icd10_code LIKE ('Q%') OR
                      icd10_code LIKE ('R%') OR
                      icd10_code LIKE ('S%') OR
                      icd10_code LIKE ('U%') OR
                      icd10_code LIKE ('V%') OR
                      icd10_code LIKE ('Z%')) AS table1
                JOIN
                (SELECT * FROM vyndaqel.copy_receipt_diseases) AS table2
                ON table1.diseases_code = table2.diseases_code;")

countDiseasesClaimsremovingOtoZ  <- setDT(dbGetQuery(con, query)) # 119285169




# Create subset of only Es and Is (used this versions in the end)

query <- paste0("CREATE TABLE vyndaqel.short_E_receipt_diseases_facility AS
                 SELECT table2.* FROM 
                 (SELECT DISTINCT(diseases_code) FROM vyndaqel.m_icd10
                 WHERE icd10_code LIKE ('E%')) AS table1
                  JOIN
                 (SELECT receipt_ym, receipt_id, kojin_id, diseases_code, utagai_flg FROM vyndaqel.receipt_diseases) AS table2
                  ON table1.diseases_code = table2.diseases_code;")

dbGetQuery(con, query)

query <- paste0("CREATE TABLE vyndaqel.short_I_receipt_diseases_facility AS
                 SELECT table2.* FROM 
                 (SELECT DISTINCT(diseases_code) FROM vyndaqel.m_icd10
                 WHERE icd10_code LIKE ('I%')) AS table1
                  JOIN
                 (SELECT receipt_ym, receipt_id, kojin_id, diseases_code, utagai_flg FROM vyndaqel.receipt_diseases) AS table2
                  ON table1.diseases_code = table2.diseases_code;")

dbGetQuery(con, query)


query <- paste0("CREATE TABLE vyndaqel.short_G_receipt_diseases_facility AS
                 SELECT table2.* FROM 
                 (SELECT DISTINCT(diseases_code) FROM vyndaqel.m_icd10
                 WHERE icd10_code LIKE ('G%')) AS table1
                  JOIN
                 (SELECT receipt_ym, receipt_id, kojin_id, diseases_code, utagai_flg FROM vyndaqel.receipt_diseases) AS table2
                  ON table1.diseases_code = table2.diseases_code;")

dbGetQuery(con, query)



# Create subset of only Es and Is including confirmation/suspicion flag 

query <- paste0("CREATE TABLE vyndaqel.short_E_receipt_diseases_utagai AS
                 SELECT table2.* FROM 
                 (SELECT DISTINCT(diseases_code) FROM vyndaqel.m_icd10
                 WHERE icd10_code LIKE ('E%')) AS table1
                  JOIN
                 (SELECT * FROM vyndaqel.copy_receipt_diseases_2) AS table2
                  ON table1.diseases_code = table2.diseases_code;")

dbGetQuery(con, query)

query <- paste0("CREATE TABLE vyndaqel.short_I_receipt_diseases_utagai AS
                 SELECT table2.* FROM 
                 (SELECT DISTINCT(diseases_code) FROM vyndaqel.m_icd10
                 WHERE icd10_code LIKE ('I%')) AS table1
                  JOIN
                 (SELECT * FROM vyndaqel.copy_receipt_diseases_2) AS table2
                  ON table1.diseases_code = table2.diseases_code;")

dbGetQuery(con, query)


query <- paste0("CREATE TABLE vyndaqel.short_G_receipt_diseases_utagai AS
                 SELECT table2.* FROM 
                 (SELECT DISTINCT(diseases_code) FROM vyndaqel.m_icd10
                 WHERE icd10_code LIKE ('G%')) AS table1
                  JOIN
                 (SELECT * FROM vyndaqel.copy_receipt_diseases_2) AS table2
                  ON table1.diseases_code = table2.diseases_code;")

dbGetQuery(con, query)



















# vyndaqel.receipt_diseases

# - Only E's

short_e_receipt_diseases_All_ContEnr_pts <- data.table()

length(pages$max) 

for(i in 1:length(pages$max)) {
  cat(i)
  start <- Sys.time()
  pts <- paste0(ContinuouslyEnrolled_Y3_tekio_weights$kojin_id[pages$min[i]:pages$max[i]], collapse = "','")
  query <- paste0("SELECT receipt_ym, kojin_id, diseases_code FROM vyndaqel.short_e_receipt_diseases  WHERE kojin_id IN ('",pts,"');")
  data  <- setDT(dbGetQuery(con, query))
  short_e_receipt_diseases_All_ContEnr_pts <- rbind(short_e_receipt_diseases_All_ContEnr_pts, data)
  end   <- Sys.time()
  print(end - start)
}

fwrite(short_e_receipt_diseases_All_ContEnr_pts, "All_Pts_ContinuousEnrolled/short_e_receipt_diseases_All_ContEnr_pts.txt", sep="\t")

  

# - Only I's 

short_i_receipt_diseases_All_ContEnr_pts <- data.table()

length(pages$max) # 

for(i in 928:length(pages$max)) {
  cat(i)
  start <- Sys.time()
  pts <- paste0(ContinuouslyEnrolled_Y3_tekio_weights$kojin_id[pages$min[i]:pages$max[i]], collapse = "','")
  query <- paste0("SELECT receipt_ym, kojin_id, diseases_code FROM vyndaqel.short_i_receipt_diseases  WHERE kojin_id IN ('",pts,"');")
  data  <- setDT(dbGetQuery(con, query))
  short_i_receipt_diseases_All_ContEnr_pts <- rbind(short_i_receipt_diseases_All_ContEnr_pts, data)
  end   <- Sys.time()
  print(end - start)
}

fwrite(short_i_receipt_diseases_All_ContEnr_pts, "All_Pts_ContinuousEnrolled/short_i_receipt_diseases_All_ContEnr_pts.txt", sep="\t")



# - Only G's 

short_g_receipt_diseases_All_ContEnr_pts <- data.table()

length(pages$max) # 

for(i in 1:length(pages$max)) {
  cat(i)
  start <- Sys.time()
  pts <- paste0(ContinuouslyEnrolled_Y3_tekio_weights$kojin_id[pages$min[i]:pages$max[i]], collapse = "','")
  query <- paste0("SELECT receipt_ym, kojin_id, diseases_code FROM vyndaqel.short_g_receipt_diseases  WHERE kojin_id IN ('",pts,"');")
  data  <- setDT(dbGetQuery(con, query))
  short_g_receipt_diseases_All_ContEnr_pts <- rbind(short_g_receipt_diseases_All_ContEnr_pts, data)
  end   <- Sys.time()
  print(end - start)
}

fwrite(short_g_receipt_diseases_All_ContEnr_pts, "All_Pts_ContinuousEnrolled/short_g_receipt_diseases_All_ContEnr_pts.txt", sep="\t")







# vyndaqel.receipt_diseases with utagai flag

# - Only E's

short_e_receipt_diseases_utagai_All_ContEnr_pts <- data.table()

length(pages$max) # 

for(i in 1:length(pages$max)) {
  cat(i)
  start <- Sys.time()
  pts <- paste0(ContinuouslyEnrolled_Y3_tekio_weights$kojin_id[pages$min[i]:pages$max[i]], collapse = "','")
  query <- paste0("SELECT receipt_ym, kojin_id, diseases_code, utagai_flg FROM vyndaqel.short_e_receipt_diseases_utagai  WHERE kojin_id IN ('",pts,"');")
  data  <- setDT(dbGetQuery(con, query))
  short_e_receipt_diseases_utagai_All_ContEnr_pts <- rbind(short_e_receipt_diseases_utagai_All_ContEnr_pts, data)
  end   <- Sys.time()
  print(end - start)
}

fwrite(short_e_receipt_diseases_utagai_All_ContEnr_pts, "All_Pts_ContinuousEnrolled/short_e_receipt_diseases_utagai_All_ContEnr_pts.txt", sep="\t")

  

# - Only I's 

short_i_receipt_diseases_utagai_All_ContEnr_pts <- data.table()

length(pages$max) #

for(i in 1:length(pages$max)) {
  cat(i)
  start <- Sys.time()
  pts <- paste0(ContinuouslyEnrolled_Y3_tekio_weights$kojin_id[pages$min[i]:pages$max[i]], collapse = "','")
  query <- paste0("SELECT receipt_ym, kojin_id, diseases_code,utagai_flg FROM vyndaqel.short_i_receipt_diseases_utagai  WHERE kojin_id IN ('",pts,"');")
  data  <- setDT(dbGetQuery(con, query))
  short_i_receipt_diseases_utagai_All_ContEnr_pts <- rbind(short_i_receipt_diseases_utagai_All_ContEnr_pts, data)
  end   <- Sys.time()
  print(end - start)
}

fwrite(short_i_receipt_diseases_utagai_All_ContEnr_pts, "All_Pts_ContinuousEnrolled/short_i_receipt_diseases_utagai_All_ContEnr_pts.txt", sep="\t")



# - Only G's 

short_g_receipt_diseases_utagai_All_ContEnr_pts <- data.table()

length(pages$max) # 

for(i in 1:length(pages$max)) {
  cat(i)
  start <- Sys.time()
  pts <- paste0(ContinuouslyEnrolled_Y3_tekio_weights$kojin_id[pages$min[i]:pages$max[i]], collapse = "','")
  query <- paste0("SELECT receipt_ym, kojin_id, diseases_code, utagai_flg FROM vyndaqel.short_g_receipt_diseases_utagai  WHERE kojin_id IN ('",pts,"');")
  data  <- setDT(dbGetQuery(con, query))
  short_g_receipt_diseases_utagai_All_ContEnr_pts <- rbind(short_g_receipt_diseases_utagai_All_ContEnr_pts, data)
  end   <- Sys.time()
  print(end - start)
}

fwrite(short_g_receipt_diseases_utagai_All_ContEnr_pts, "All_Pts_ContinuousEnrolled/short_g_receipt_diseases_utagai_All_ContEnr_pts.txt", sep="\t")





# Drugs 

# created "copy_receipt_diseases" with only 3 colunms

# CREATE TABLE vyndaqel.copy_receipt_drug AS
# (SELECT receipt_drug.drug_code, 
#   receipt_drug.receipt_ym, 
#   receipt_drug.kojin_id FROM vyndaqel.receipt_drug);


# Filtered copy_receipt_drug table for CV system (plus thrombo prev. + ATTR)
# Create drugs subset of CV/thrombo/ATTR

Drug_Classes_lookup <- fread("Masters/Drug_Classes_lookup.csv", colClasses = "character")
Drug_Classes_lookup <-Drug_Classes_lookup <- Drug_Classes_lookup %>% select(drug_code) %>% distinct()

pages <- pagify(Drug_Classes_lookup$drug_code, 3873)
drugs <- paste0(Drug_Classes_lookup$drug_code[pages$min[1]:pages$max[1]], collapse = "','")



# Filter for the CV/ATTR drugs of interest

query <- paste0("CREATE TABLE vyndaqel.short_CV_receipt_drug AS
                 SELECT table2.* FROM 
                 (SELECT DISTINCT(drug_code) FROM vyndaqel.m_drug_main
                 WHERE drug_code IN ('",drugs,"')) AS table1
                  JOIN
                 (SELECT receipt_ym, kojin_id, drug_code	 FROM vyndaqel.copy_receipt_drug) AS table2
                  ON table1.drug_code = table2.drug_code;")

dbGetQuery(con, query)

# INDEX on kojin_id
query <- paste0("CREATE INDEX copy_receipt_drug_kojin_id ON vyndaqel.copy_receipt_drug (kojin_id);")
dbSendQuery(con, query)

query <- paste0("CREATE INDEX short_CV_receipt_drug_kojin_id ON vyndaqel.short_CV_receipt_drug (kojin_id);")
dbSendQuery(con, query)



pagify <- function(data = NULL, by = 1000){
    pagemin <- seq(1,length(data), by = by)
    pagemax <- pagemin - 1 + by
    pagemax[length(pagemax)] <- length(data)
    pages   <- list(min = pagemin, max = pagemax)
  }
  
  
# vector of continuosly enrolled patients
ContinuouslyEnrolled_Y3_tekio_weights <- fread("All_Pts_ContinuousEnrolled/ContinuouslyEnrolled_Y3_tekiyo_weights.txt", sep="\t")
ContinuouslyEnrolled_Y3_tekio_weights <- ContinuouslyEnrolled_Y3_tekio_weights %>% select(kojin_id) %>% distinct()

pages <- pagify(ContinuouslyEnrolled_Y3_tekio_weights$kojin_id, 1000)
  


short_CV_receipt_drug_All_ContEnr_pts <- data.table()


# vyndaqel.receipt_drug
for(i in 1:length(pages$max)) {
    cat(i)
    start <- Sys.time()
    pts <- paste0(ContinuouslyEnrolled_Y3_tekio_weights$kojin_id[pages$min[i]:pages$max[i]], collapse = "','")
    query <- paste0("SELECT receipt_ym, kojin_id, drug_code FROM vyndaqel.short_CV_receipt_drug WHERE kojin_id IN ('",pts,"');")
    data  <- setDT(dbGetQuery(con, query))
    short_CV_receipt_drug_All_ContEnr_pts <- rbind(short_CV_receipt_drug_All_ContEnr_pts, data)
    end   <- Sys.time()
    print(end - start)
}


fwrite(short_CV_receipt_drug_All_ContEnr_pts, "All_Pts_ContinuousEnrolled/short_CV_receipt_drug_All_ContEnr_pts.txt", sep="\t")

  
  

# Procedures 

# DROP TABLE IF EXISTS vyndaqel.copy_receipt_medical_practice;
# 
# CREATE TABLE vyndaqel.copy_receipt_medical_practice AS
# (SELECT receipt_ym, kojin_id, medical_practice_code, receipt_id FROM
# vyndaqel.receipt_medical_practice);
# 
# DROP TABLE IF EXISTS  vyndaqel.short_procedures_receipt_medical_practice;

  
receipt_medical_practice_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_medical_practice_Vyndaqel195pts.txt", colClasses = "character")
receipt_medical_practice_Vyndaqel195pts <- receipt_medical_practice_Vyndaqel195pts[,.(receipt_ym, kojin_id, medical_practice_code)]
receipt_medical_practice_Vyndaqel195pts$receipt_ym <- as.Date(paste0(as.character(receipt_medical_practice_Vyndaqel195pts$receipt_ym), '/01'))

Procedure_master <- fread("Masters/Procedure_master.csv", colClasses = "character")

receipt_medical_practice_Vyndaqel195pts <- 
  receipt_medical_practice_Vyndaqel195pts %>% 
  left_join(Procedure_master, 
            by=c("medical_practice_code"="standardized_procedure_code")) %>%
  select(kojin_id, receipt_ym, medical_practice_code, standardized_procedure_name) 
 
receipt_medical_practice_Vyndaqel195pts <- receipt_medical_practice_Vyndaqel195pts %>%
                                              filter(grepl("computerized tomog", standardized_procedure_name)|
                                                     grepl("CT imaging", standardized_procedure_name)|
                                                     grepl("nuclear medicine diagnosis", standardized_procedure_name)|
                                                     grepl("scintigraphy", standardized_procedure_name)|
                                                     grepl("MRI", standardized_procedure_name)|
                                                     grepl("electrocardiog", standardized_procedure_name)|
                                                     grepl("ECG", standardized_procedure_name)|
                                                     grepl("ultrasonography", standardized_procedure_name)|
                                                     grepl("SPECT", standardized_procedure_name)|
                                                     grepl("PET ", standardized_procedure_name)|
                                                     grepl("percutaneous needle biopsy", standardized_procedure_name)|
                                                     grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name)|
                                                     grepl("endoscopic biopsy", standardized_procedure_name)|
                                                     grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name)|
                                                     grepl("brain natriuretic peptide", standardized_procedure_name)|
                                                     grepl("BNP", standardized_procedure_name)|
                                                     grepl("troponin", standardized_procedure_name)|
                                                     grepl("genetic test", standardized_procedure_name)|
                                                     grepl("cardiac catheterization", standardized_procedure_name)|
                                                     grepl("Holter", standardized_procedure_name)|
                                                     grepl("pacemaker", standardized_procedure_name)|
                                                     grepl("gene-related", standardized_procedure_name)|
                                                     grepl("exercise test", standardized_procedure_name)|
                                                     grepl("hospitalization", standardized_procedure_name)|
                                                     grepl("serum amyloid A protein", standardized_procedure_name)|
                                                     grepl("prealbumin", standardized_procedure_name)|
                                                     grepl("transthyretin", standardized_procedure_name)|
                                                     grepl("amylase", standardized_procedure_name))

unique(receipt_medical_practice_Vyndaqel195pts$medical_practice_code)

medical_practice_code <- unique(receipt_medical_practice_Vyndaqel195pts$medical_practice_code)
medical_practice_code <- data.frame(medical_practice_code)
names(medical_practice_code)[1] <- "medical_practice_code"
  
  
pagify <- function(data = NULL, by = 1000){
    pagemin <- seq(1,length(data), by = by)
    pagemax <- pagemin - 1 + by
    pagemax[length(pagemax)] <- length(data)
    pages   <- list(min = pagemin, max = pagemax)
  }
  

pages <- pagify(medical_practice_code$medical_practice_code, 228)
procedures <- paste0(medical_practice_code$medical_practice_code[pages$min[1]:pages$max[1]], collapse = "','")



# Filter for the procedures of interest

query <- paste0("CREATE TABLE vyndaqel.short_procedures_receipt_medical_practice AS
                 SELECT table2.* FROM 
                 (SELECT DISTINCT(medical_practice_code) FROM vyndaqel.m_med_treat
                 WHERE medical_practice_code IN ('",procedures,"')) AS table1
                  JOIN
                 (SELECT receipt_ym, kojin_id, medical_practice_code, receipt_id	 FROM vyndaqel.copy_receipt_medical_practice) AS table2
                  ON table1.medical_practice_code = table2.medical_practice_code;")

dbGetQuery(con, query)


# INDEX on kojin_id
query <- paste0("CREATE INDEX short_procedures_receipt_medical_practice_kojin_id ON vyndaqel.short_procedures_receipt_medical_practice (kojin_id);")
dbSendQuery(con, query)




pagify <- function(data = NULL, by = 1000){
    pagemin <- seq(1,length(data), by = by)
    pagemax <- pagemin - 1 + by
    pagemax[length(pagemax)] <- length(data)
    pages   <- list(min = pagemin, max = pagemax)
  }
  
  
# vector of continuosly enrolled patients
ContinuouslyEnrolled_Y3_tekio_weights <- fread("All_Pts_ContinuousEnrolled/ContinuouslyEnrolled_Y3_tekiyo_weights.txt", sep="\t")
ContinuouslyEnrolled_Y3_tekio_weights <- ContinuouslyEnrolled_Y3_tekio_weights %>% select(kojin_id) %>% distinct()

pages <- pagify(ContinuouslyEnrolled_Y3_tekio_weights$kojin_id, 1000)
  


short_procedures_receipt_medical_practice_All_ContEnr_pts <- data.table()


# vyndaqel.receipt_drug
for(i in 1:length(pages$max)) {
    cat(i)
    start <- Sys.time()
    pts <- paste0(ContinuouslyEnrolled_Y3_tekio_weights$kojin_id[pages$min[i]:pages$max[i]], collapse = "','")
    query <- paste0("SELECT receipt_ym, kojin_id, medical_practice_code, receipt_id FROM vyndaqel.short_procedures_receipt_medical_practice WHERE kojin_id IN ('",pts,"');")
    data  <- setDT(dbGetQuery(con, query))
    short_procedures_receipt_medical_practice_All_ContEnr_pts <- rbind(short_procedures_receipt_medical_practice_All_ContEnr_pts, data)
    end   <- Sys.time()
    print(end - start)
}


fwrite(short_procedures_receipt_medical_practice_All_ContEnr_pts, "All_Pts_ContinuousEnrolled/short_procedures_receipt_medical_practice_All_ContEnr_pts.txt", sep="\t")










  





  
  
# -------------------
# All Continuously Enrolled patients -> ICD10 disease comorbidity penetrance ------------------------------

Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")
Vyndaqel_pats_CM_vs_PN %>% group_by(CM,PN, Combo) %>% count()
Vyndaqel_pats_CM_vs_PN %>% filter(CM==1) %>% select(kojin_id) 
Vyndaqel_pats_CM_vs_PN <- Vyndaqel_pats_CM_vs_PN %>% select(kojin_id, PN, CM, Combo)

VyndaqelPts195 <- fread("VyndaqelPts195/tekiyo_Vyndaqel195pts.txt", colClasses = "character")
VyndaqelPts195 <- VyndaqelPts195 %>% select(kojin_id, birth_ym, sex_code)
VyndaqelPts195[, gender:= ifelse(sex_code == 1, "M","F")]
VyndaqelPts195 <- VyndaqelPts195 %>% select(-sex_code)
VyndaqelPts195$birth_ym <- as.Date(paste0(as.character(VyndaqelPts195$birth_ym), '/01'))
VyndaqelPts195$age <- round(time_length(interval(VyndaqelPts195$birth_ym, ymd("2021-08-01")), "year"))
VyndaqelPts195 <- VyndaqelPts195 %>% select(-birth_ym)
VyndaqelPts195 <- VyndaqelPts195 %>% left_join(Vyndaqel_pats_CM_vs_PN)
VyndaqelPts195 <- VyndaqelPts195 %>% mutate(age=ifelse(age>=95,95,age))
VyndaqelPts195$age <- as.character(VyndaqelPts195$age)

VyndaqelPts195 <- VyndaqelPts195  %>% left_join(ContinuouslyEnrolled_Y3_tekiyo_weights %>% select(age, gender, weight) %>% distinct())

VyndaqelPts195 %>% group_by(CM, PN, Combo) %>% summarise(n=sum(as.numeric(weight))) 



tekiyo_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/tekiyo_All_ContEnr_pts.txt", colClasses = "character")
ContinuouslyEnrolled_Y3_tekiyo_weights <- fread("All_Pts_ContinuousEnrolled/ContinuouslyEnrolled_Y3_tekiyo_weights.txt", colClasses = "character")

tekiyo_All_ContEnr_pts <- tekiyo_All_ContEnr_pts %>% left_join(ContinuouslyEnrolled_Y3_tekiyo_weights %>% select(kojin_id, weight)) %>% select(kojin_id, weight)

sum(as.numeric(tekiyo_All_ContEnr_pts$weight)) # 


#  ICD10 codes
short_i_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_i_receipt_diseases_All_ContEnr_pts.txt", 
                                         colClasses = "character")

short_e_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_e_receipt_diseases_All_ContEnr_pts.txt", 
                                         colClasses = "character")

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()

m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code, icd10_name_en)

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code, icd10_name_en) %>% distinct()

short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code, icd10_name_en) %>% distinct()


tekiyo_All_ContEnr_pts %>% inner_join(short_i_receipt_diseases_All_ContEnr_pts %>% select(kojin_id) %>% distinct()) %>% 
  summarise(n=sum(as.numeric(weight))) #

tekiyo_All_ContEnr_pts %>% inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% select(kojin_id) %>% distinct()) %>% 
  summarise(n=sum(as.numeric(weight))) # 


short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I42",icd10_code)|grepl("I43",icd10_code)) %>% select(kojin_id) %>%
  distinct() %>% left_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 
short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>%
  distinct() %>% left_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 


short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code)) %>% select(kojin_id) %>%
  distinct() %>% left_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 

short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E854",icd10_code)) %>% select(kojin_id) %>%
  distinct() %>% left_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 


short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I50",icd10_code)) %>% select(kojin_id) %>%
  distinct() %>% left_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 

short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I50",icd10_code)) %>% select(kojin_id) %>%
  distinct() %>%
  inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code)) %>% select(kojin_id) %>% distinct()) %>% 
  left_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 

short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>%
  distinct() %>%
  full_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E851",icd10_code)) %>% select(kojin_id) %>% distinct()) %>% 
  left_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 


data.frame(short_i_receipt_diseases_All_ContEnr_pts %>% group_by(icd10_code, icd10_name_en) %>% count() %>%
  arrange(-n))

data.frame(short_e_receipt_diseases_All_ContEnr_pts %>% group_by(icd10_code, icd10_name_en) %>% count() %>%
  arrange(-n))

short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code)) %>% select(icd10_code) %>% distinct()



short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code)) %>%
  select(icd10_code, icd10_name_en, kojin_id) %>% distinct() %>%
  left_join(tekiyo_All_ContEnr_pts) %>%
  group_by(icd10_code, icd10_name_en) %>% summarise(n=sum(as.numeric(weight))) %>%
  mutate(penetrance=(100*n/26009563))


# --------------------------------------------------
# Vyndaqel / Patisiran penetrance in Continuously enrolled  patients -----------------
short_i_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_i_receipt_diseases_All_ContEnr_pts.txt", 
                                         colClasses = "character")

short_e_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_e_receipt_diseases_All_ContEnr_pts.txt", 
                                         colClasses = "character")

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()

m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code, icd10_name_en)

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code, icd10_name_en) %>% distinct()

short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code, icd10_name_en) %>% distinct()


CntEnrDxs <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id, icd10_code) %>%
  distinct() %>%
  full_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E851",icd10_code)) %>% select(kojin_id, icd10_code) %>% distinct()) 

# Drugs 
short_CV_receipt_drug_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_CV_receipt_drug_All_ContEnr_pts.txt", 
                                         colClasses = "character")

short_CV_receipt_drug_All_ContEnr_pts <- short_CV_receipt_drug_All_ContEnr_pts %>% select(kojin_id, drug_code) %>% distinct()
short_CV_receipt_drug_All_ContEnr_pts <- short_CV_receipt_drug_All_ContEnr_pts %>% filter(drug_code=="622687701")


CntEnrDxs %>% anti_join(VyndaqelPts195 %>% select(kojin_id))
VyndaqelPts195 <- fread("VyndaqelPts195/tekiyo_Vyndaqel195pts.txt", colClasses = "character")

CntEnrDxs %>% anti_join(VyndaqelPts195 %>% select(kojin_id))  %>% 
  left_join(short_CV_receipt_drug_All_ContEnr_pts) %>%
  group_by(icd10_code, drug_code) %>% count()


CntEnrDxs %>% anti_join(VyndaqelPts195 %>% select(kojin_id))
VyndaqelPts195 <- fread("VyndaqelPts195/tekiyo_Vyndaqel195pts.txt", colClasses = "character")

# --------------------------------------------
# Average Number of diagnostic moments in target CM target PN vyndaqel Cm and vyndaqel PN -----------------------------
TargetCM_patients
TargetPN_patients

short_i_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_i_receipt_diseases_All_ContEnr_pts.txt", 
                                         colClasses = "character")

m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
Codes_I431 <- m_icd10 %>% filter(icd10_code=="I431") %>% select(diseases_code)
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% inner_join(Codes_I431)


short_e_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_e_receipt_diseases_All_ContEnr_pts.txt", 
                                         colClasses = "character")

m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
Codes_E851 <- m_icd10 %>% filter(icd10_code=="E851") %>% select(diseases_code)
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% inner_join(Codes_E851)


Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")

TargetCM_patients %>% left_join(short_i_receipt_diseases_All_ContEnr_pts) %>%
  group_by(kojin_id) %>% count() %>% ungroup() %>% summarise(mean=mean(n)) # 


Vyndaqel_pats_CM_vs_PN %>% filter(CM==1) %>% select(kojin_id) %>% left_join(short_i_receipt_diseases_All_ContEnr_pts) %>%
  group_by(kojin_id) %>% count() %>% ungroup() %>% summarise(mean=mean(n))  # 


TargetPN_patients %>% left_join(short_e_receipt_diseases_All_ContEnr_pts) %>%
  group_by(kojin_id) %>% count() %>% ungroup() %>% summarise(mean=mean(n)) # 

Vyndaqel_pats_CM_vs_PN %>% filter(PN==1) %>% select(kojin_id) %>% left_join(short_e_receipt_diseases_All_ContEnr_pts) %>%
  group_by(kojin_id) %>% count() %>% ungroup() %>% summarise(mean=mean(n)) # 

# ------------------------------------------------------

# Stocks / Flows diagram CM and PN Vyndaqel patients funnel -------------------------------------------
tekiyo_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/tekiyo_All_ContEnr_pts.txt", colClasses = "character")
ContinuouslyEnrolled_Y3_tekiyo_weights <- fread("All_Pts_ContinuousEnrolled/ContinuouslyEnrolled_Y3_tekiyo_weights.txt", colClasses = "character")
tekiyo_All_ContEnr_pts <- tekiyo_All_ContEnr_pts %>% left_join(ContinuouslyEnrolled_Y3_tekiyo_weights %>% select(kojin_id, weight)) %>% select(kojin_id, weight)
sum(as.numeric(tekiyo_All_ContEnr_pts$weight)) # 26009563

Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")
Vyndaqel_pats_CM_vs_PN <- Vyndaqel_pats_CM_vs_PN %>% select(kojin_id) 
Vyndaqel_pats_CM_vs_PN %>% inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 







# Is LAST 3 YEARS
short_i_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_i_receipt_diseases_All_ContEnr_pts.txt", 
                                         colClasses = "character")
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym<="2021/03")
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym>="2018/04")

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()
m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code) %>% distinct()

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I50",icd10_code)|grepl("I42",icd10_code)|grepl("I43",icd10_code))


# Es LAST 3 YEARS
short_e_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_e_receipt_diseases_All_ContEnr_pts.txt", 
                                         colClasses = "character")
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym<="2021/03")
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym>="2018/04")
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()
m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code) %>% distinct()

short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code))


# HEART FAILURE LAST 3 YEARS
short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I50",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  left_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 

# HEART FAILURE LAST 3 YEARS & AMYLOIDOSIS & CARDIOMYOPATHY
short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I50",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
    inner_join(short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I42",icd10_code)|grepl("I43",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
  inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 

# HEART FAILURE LAST 3 YEARS & AMYLOIDOSIS & CARDIOMYOPATHY & CARDIOMYOPATHY DUE TO AMYLOIDOSIS
short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I50",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
    inner_join(short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I42",icd10_code)|grepl("I43",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
  inner_join(short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
  inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 

# HEART FAILURE LAST 3 YEARS & AMYLOIDOSIS & CARDIOMYOPATHY & CARDIOMYOPATHY DUE TO AMYLOIDOSIS & VYNDAQEL
short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I50",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
    inner_join(short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I42",icd10_code)|grepl("I43",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
  inner_join(short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
    inner_join(Vyndaqel_pats_CM_vs_PN) %>%
  inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 

# 
# TargetCM_patients <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I50",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
#   inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
#     inner_join(short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I42",icd10_code)|grepl("I43",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
#   inner_join(short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
#   inner_join(tekiyo_All_ContEnr_pts)


# Is   YEARS -3 and -2
short_i_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_i_receipt_diseases_All_ContEnr_pts.txt", 
                                         colClasses = "character")
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym<="2020/03")
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym>="2018/04")

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()
m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code) %>% distinct()

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I50",icd10_code)|grepl("I42",icd10_code)|grepl("I43",icd10_code))


# Es LYEARS -3 and -2
short_e_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_e_receipt_diseases_All_ContEnr_pts.txt", 
                                         colClasses = "character")
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym<="2020/03")
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym>="2018/04")
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()
m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code) %>% distinct()

short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code))


# HEART FAILURE  YEARS -3 and -2
short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I50",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  left_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 

# HEART FAILURE YEARS -3 and -2 & AMYLOIDOSIS & CARDIOMYOPATHY
short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I50",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
    inner_join(short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I42",icd10_code)|grepl("I43",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
  inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 

# HEART FAILURE YEARS -3 and -2 & AMYLOIDOSIS & CARDIOMYOPATHY & CARDIOMYOPATHY DUE TO AMYLOIDOSIS
short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I50",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
    inner_join(short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I42",icd10_code)|grepl("I43",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
  inner_join(short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
  inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 

# HEART FAILURE YEARS -3 and -2 & AMYLOIDOSIS & CARDIOMYOPATHY & CARDIOMYOPATHY DUE TO AMYLOIDOSIS & VYNDAQEL
short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I50",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
    inner_join(short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I42",icd10_code)|grepl("I43",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
  inner_join(short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
    inner_join(Vyndaqel_pats_CM_vs_PN) %>%
  inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 



receipt_drug_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_drug_Vyndaqel195pts.txt", colClasses = "character")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts[,.(kojin_id, receipt_ym, drug_code)]
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% filter(drug_code=="622278901")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% select(-c(drug_code))
Exact_Month_Lookup <- receipt_drug_Vyndaqel195pts %>% select(receipt_ym) %>% distinct() %>% arrange(receipt_ym) %>%
  mutate(Exact_Month=row_number())
names(Exact_Month_Lookup)[2] <- "Month"

GapFillVyndael <- fread("VyndaqelPts195/GapFill_Vyndaqel.csv", sep=",")
GapFillVyndael <- gather(GapFillVyndael, Month, Treat, 2:88, factor_key=TRUE)
GapFillVyndael$Month <- as.numeric(GapFillVyndael$Month)
GapFillVyndael <- GapFillVyndael %>% left_join(Exact_Month_Lookup)
GapFillVyndael$kojin_id <- as.character(GapFillVyndael$kojin_id)


Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")
Vyndaqel_pats_CM_vs_PN <- Vyndaqel_pats_CM_vs_PN %>% select(kojin_id, PN, CM, Combo)

VyndaqelPts195 <- fread("VyndaqelPts195/tekiyo_Vyndaqel195pts.txt", colClasses = "character")
VyndaqelPts195 <- VyndaqelPts195 %>% select(kojin_id, birth_ym, sex_code)
VyndaqelPts195[, gender:= ifelse(sex_code == 1, "M","F")]
VyndaqelPts195 <- VyndaqelPts195 %>% select(-sex_code)
VyndaqelPts195$birth_ym <- as.Date(paste0(as.character(VyndaqelPts195$birth_ym), '/01'))
VyndaqelPts195$age <- round(time_length(interval(VyndaqelPts195$birth_ym, ymd("2021-08-01")), "year"))
VyndaqelPts195 <- VyndaqelPts195 %>% select(-birth_ym)
VyndaqelPts195 <- VyndaqelPts195 %>% left_join(Vyndaqel_pats_CM_vs_PN)
VyndaqelPts195 <- VyndaqelPts195 %>% mutate(age=ifelse(age>=95,95,age))
VyndaqelPts195$age <- as.character(VyndaqelPts195$age)
VyndaqelPts195 <- VyndaqelPts195  %>% left_join(ContinuouslyEnrolled_Y3_tekiyo_weights %>% select(age, gender, weight) %>% distinct())
VyndaqelPts195 <- VyndaqelPts195 %>% select(kojin_id, weight)
sum(as.numeric(VyndaqelPts195$weight))

GapFillVyndael %>% filter(receipt_ym<="2021/03" & receipt_ym>="2018/04") %>% filter(Treat==1) %>% select(kojin_id) %>% distinct() %>%
  inner_join(Vyndaqel_pats_CM_vs_PN %>% filter(PN==1) %>% select(kojin_id)) %>% 
  inner_join(VyndaqelPts195) %>% summarise(n=sum(as.numeric(weight))) %>% # 1525.761
  anti_join(GapFillVyndael %>% filter(receipt_ym<="2020/03" & receipt_ym>="2018/04") %>% filter(Treat==1) %>% select(kojin_id) %>% distinct()) %>%
   left_join(VyndaqelPts195) %>% summarise(n=sum(as.numeric(weight)))  # 845.0034






# POLYNEUROPATHY

tekiyo_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/tekiyo_All_ContEnr_pts.txt", colClasses = "character")
ContinuouslyEnrolled_Y3_tekiyo_weights <- fread("All_Pts_ContinuousEnrolled/ContinuouslyEnrolled_Y3_tekiyo_weights.txt", colClasses = "character")
tekiyo_All_ContEnr_pts <- tekiyo_All_ContEnr_pts %>% left_join(ContinuouslyEnrolled_Y3_tekiyo_weights %>% select(kojin_id, weight)) %>% select(kojin_id, weight)
sum(as.numeric(tekiyo_All_ContEnr_pts$weight)) # 26009563

Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")
Vyndaqel_pats_CM_vs_PN <- Vyndaqel_pats_CM_vs_PN %>% select(kojin_id) 
Vyndaqel_pats_CM_vs_PN %>% inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 



# Is LAST 3 YEARS
short_i_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_i_receipt_diseases_All_ContEnr_pts.txt", 
                                         colClasses = "character")

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()
m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code) %>% distinct()

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% 
  filter(grepl("I50",icd10_code)|grepl("I42",icd10_code)|grepl("I43",icd10_code)) %>% select(kojin_id) %>% distinct()


# Gs LAST 3 YEARS
short_g_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_g_receipt_diseases_All_ContEnr_pts.txt", 
                                         colClasses = "character")
short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym<="2021/03")
short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym>="2018/04")

short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()
m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code) %>% distinct()

short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% filter(grepl("G6",icd10_code))



# Es LAST 3 YEARS
short_e_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_e_receipt_diseases_All_ContEnr_pts.txt", 
                                         colClasses = "character")
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym<="2021/03")
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym>="2018/04")
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()
m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code) %>% distinct()

short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code))





# POLYNEUROPATHY LAST 3 YEARS
short_g_receipt_diseases_All_ContEnr_pts %>% filter(grepl("G6",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  anti_join(short_i_receipt_diseases_All_ContEnr_pts) %>%
  left_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 

# POLYNEUROPATHY LAST 3 YEARS & AMYLOIDOSIS POLYNEUROPATHY
short_g_receipt_diseases_All_ContEnr_pts %>% filter(grepl("G6",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
    anti_join(short_i_receipt_diseases_All_ContEnr_pts) %>%
  inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
  inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 

# POLYNEUROPATHY LAST 3 YEARS & AMYLOIDOSIS & POLYNEUROPATHY DUE TO AMYLOIDOSIS
short_g_receipt_diseases_All_ContEnr_pts %>% filter(grepl("G6",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
    anti_join(short_i_receipt_diseases_All_ContEnr_pts) %>%
  inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
    inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E851",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
  inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 

# POLYNEUROPATHY LAST 3 YEARS & AMYLOIDOSIS & POLYNEUROPATHY DUE TO AMYLOIDOSIS
short_g_receipt_diseases_All_ContEnr_pts %>% filter(grepl("G6",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
    anti_join(short_i_receipt_diseases_All_ContEnr_pts) %>%
  inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
    inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E851",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
    inner_join(Vyndaqel_pats_CM_vs_PN) %>%
  inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 

TargetPN_patients <- short_g_receipt_diseases_All_ContEnr_pts %>% filter(grepl("G6",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
    anti_join(short_i_receipt_diseases_All_ContEnr_pts) %>%
  inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
    inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E851",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
  inner_join(tekiyo_All_ContEnr_pts) 





# Is YEARS -3 and -2
short_i_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_i_receipt_diseases_All_ContEnr_pts.txt", 
                                         colClasses = "character")
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()
m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code) %>% distinct()

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% 
  filter(grepl("I50",icd10_code)|grepl("I42",icd10_code)|grepl("I43",icd10_code)) %>% select(kojin_id) %>% distinct()


# Gs YEARS -3 and -2
short_g_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_g_receipt_diseases_All_ContEnr_pts.txt", 
                                         colClasses = "character")
short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym<="2020/03")
short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym>="2018/04")

short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()
m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code) %>% distinct()

short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% filter(grepl("G6",icd10_code))



# Es YEARS -3 and -2
short_e_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_e_receipt_diseases_All_ContEnr_pts.txt", 
                                         colClasses = "character")
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym<="2020/03")
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym>="2018/04")
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()
m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code) %>% distinct()

short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code))






# POLYNEUROPATHY YEARS -3 and -2
short_g_receipt_diseases_All_ContEnr_pts %>% filter(grepl("G6",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  anti_join(short_i_receipt_diseases_All_ContEnr_pts) %>%
  left_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 

# POLYNEUROPATHY YEARS -3 and -2 & AMYLOIDOSIS POLYNEUROPATHY
short_g_receipt_diseases_All_ContEnr_pts %>% filter(grepl("G6",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
    anti_join(short_i_receipt_diseases_All_ContEnr_pts) %>%
  inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
  inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 

# POLYNEUROPATHY YEARS -3 and -2 & AMYLOIDOSIS & POLYNEUROPATHY DUE TO AMYLOIDOSIS
short_g_receipt_diseases_All_ContEnr_pts %>% filter(grepl("G6",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
   anti_join(short_i_receipt_diseases_All_ContEnr_pts) %>%
  inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
    inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E851",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
  inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 

# POLYNEUROPATHYYEARS -3 and -2 & AMYLOIDOSIS & POLYNEUROPATHY DUE TO AMYLOIDOSIS
short_g_receipt_diseases_All_ContEnr_pts %>% filter(grepl("G6",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
   anti_join(short_i_receipt_diseases_All_ContEnr_pts) %>%
  inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
    inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E851",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
    inner_join(Vyndaqel_pats_CM_vs_PN) %>%
  inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 





receipt_drug_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_drug_Vyndaqel195pts.txt", colClasses = "character")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts[,.(kojin_id, receipt_ym, drug_code)]
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% filter(drug_code=="622278901")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% select(-c(drug_code))
Exact_Month_Lookup <- receipt_drug_Vyndaqel195pts %>% select(receipt_ym) %>% distinct() %>% arrange(receipt_ym) %>%
  mutate(Exact_Month=row_number())
names(Exact_Month_Lookup)[2] <- "Month"

GapFillVyndael <- fread("VyndaqelPts195/GapFill_Vyndaqel.csv", sep=",")
GapFillVyndael <- gather(GapFillVyndael, Month, Treat, 2:88, factor_key=TRUE)
GapFillVyndael$Month <- as.numeric(GapFillVyndael$Month)
GapFillVyndael <- GapFillVyndael %>% left_join(Exact_Month_Lookup)
GapFillVyndael$kojin_id <- as.character(GapFillVyndael$kojin_id)


Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")
Vyndaqel_pats_CM_vs_PN <- Vyndaqel_pats_CM_vs_PN %>% select(kojin_id, PN, CM, Combo)

VyndaqelPts195 <- fread("VyndaqelPts195/tekiyo_Vyndaqel195pts.txt", colClasses = "character")
VyndaqelPts195 <- VyndaqelPts195 %>% select(kojin_id, birth_ym, sex_code)
VyndaqelPts195[, gender:= ifelse(sex_code == 1, "M","F")]
VyndaqelPts195 <- VyndaqelPts195 %>% select(-sex_code)
VyndaqelPts195$birth_ym <- as.Date(paste0(as.character(VyndaqelPts195$birth_ym), '/01'))
VyndaqelPts195$age <- round(time_length(interval(VyndaqelPts195$birth_ym, ymd("2021-08-01")), "year"))
VyndaqelPts195 <- VyndaqelPts195 %>% select(-birth_ym)
VyndaqelPts195 <- VyndaqelPts195 %>% left_join(Vyndaqel_pats_CM_vs_PN)
VyndaqelPts195 <- VyndaqelPts195 %>% mutate(age=ifelse(age>=95,95,age))
VyndaqelPts195$age <- as.character(VyndaqelPts195$age)
VyndaqelPts195 <- VyndaqelPts195  %>% left_join(ContinuouslyEnrolled_Y3_tekiyo_weights %>% select(age, gender, weight) %>% distinct())
VyndaqelPts195 <- VyndaqelPts195 %>% select(kojin_id, weight)
sum(as.numeric(VyndaqelPts195$weight))

GapFillVyndael %>% filter(receipt_ym<="2021/03" & receipt_ym>="2018/04") %>% filter(Treat==1) %>% select(kojin_id) %>% distinct() %>%
  inner_join(Vyndaqel_pats_CM_vs_PN %>% filter(PN==1) %>% select(kojin_id)) %>% 
  inner_join(VyndaqelPts195) %>% summarise(n=sum(as.numeric(weight))) %>% # 1525.761
  anti_join(GapFillVyndael %>% filter(receipt_ym<="2020/03" & receipt_ym>="2018/04") %>% filter(Treat==1) %>% select(kojin_id) %>% distinct()) %>%
   left_join(VyndaqelPts195) %>% summarise(n=sum(as.numeric(weight)))  # 





# ------------------------------------------------


# Stocks / Flows diagram CM Vyndaqel patient funnel NEW RULES ------------------------------------------
tekiyo_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/tekiyo_All_ContEnr_pts.txt", colClasses = "character")
ContinuouslyEnrolled_Y3_tekiyo_weights <- fread("All_Pts_ContinuousEnrolled/ContinuouslyEnrolled_Y3_tekiyo_weights.txt", colClasses = "character")
tekiyo_All_ContEnr_pts <- tekiyo_All_ContEnr_pts %>% left_join(ContinuouslyEnrolled_Y3_tekiyo_weights %>% select(kojin_id, weight)) %>% select(kojin_id, weight)
sum(as.numeric(tekiyo_All_ContEnr_pts$weight)) # 

Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")
Vyndaqel_pats_CM_vs_PN <- Vyndaqel_pats_CM_vs_PN %>% select(kojin_id) 



# Is LAST 3 YEARS
short_i_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_i_receipt_diseases_utagai_All_ContEnr_pts.txt", 
                                         colClasses = "character")
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym<="2021/03")
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym>="2018/04")

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(utagai_flg==0) %>% select(-utagai_flg)


short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()
ATTR_SpecificCode <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(diseases_code=="8850066") %>% select(kojin_id) %>% distinct()


m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code) %>% distinct()

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I50",icd10_code)|grepl("I42",icd10_code)|grepl("I43",icd10_code))




# Es LAST 3 YEARS
short_e_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_e_receipt_diseases_utagai_All_ContEnr_pts.txt", 
                                         colClasses = "character")
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym<="2021/03")
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym>="2018/04")

short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(utagai_flg==0) %>% select(-utagai_flg)

AL_Amyloidosis <- short_e_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct() %>%
  filter(diseases_code=="8845844") %>% select(kojin_id) 

m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code) %>% distinct()

short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code))



# HEART FAILURE LAST 3 YEARS
short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I500",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  anti_join(short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I42",icd10_code)|grepl("I43",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
  left_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight)))  # 


Cardiomyopaty_Pats <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I42",icd10_code)|grepl("I43",icd10_code)) %>% filter(icd10_code!="I420"&
                                                                                                                  icd10_code!="I423"&
                                                                                                                  icd10_code!="I424"&
                                                                                                                  icd10_code!="I426"&
                                                                                                                  icd10_code!="I427") %>% select(kojin_id) %>% distinct() %>%
      anti_join(short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
      anti_join(Vyndaqel_pats_CM_vs_PN) 

fwrite(Cardiomyopaty_Pats, "Cardiomyopaty_Pats.txt", sep="\t")


short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I42",icd10_code)|grepl("I43",icd10_code)) %>% filter(icd10_code!="I420"&
                                                                                                                  icd10_code!="I423"&
                                                                                                                  icd10_code!="I424"&
                                                                                                                  icd10_code!="I426"&
                                                                                                                  icd10_code!="I427") %>% select(kojin_id) %>% distinct() %>%
      anti_join(short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
      anti_join(Vyndaqel_pats_CM_vs_PN) %>%
 #anti_join(short_e_receipt_diseases_All_ContEnr_pts %>% select(kojin_id) %>% distinct()) %>%
  left_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) 



# HEART FAILURE LAST 3 YEARS & AMYLOIDOSIS & CARDIOMYOPATHY & CARDIOMYOPATHY DUE TO AMYLOIDOSIS
short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  inner_join(ATTR_SpecificCode) %>%
  anti_join(Vyndaqel_pats_CM_vs_PN) %>%
  inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 


ATTR_CM_noVyn_Pats <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  inner_join(ATTR_SpecificCode) %>%
  anti_join(Vyndaqel_pats_CM_vs_PN) %>%
  inner_join(tekiyo_All_ContEnr_pts) %>% select(kojin_id)

fwrite(ATTR_CM_noVyn_Pats, "ATTR_CM_noVyn_Pats.txt", sep="\t")


Cardiac_Amyloidosis_Pats <- 
short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  anti_join(ATTR_SpecificCode) %>%
    anti_join(Vyndaqel_pats_CM_vs_PN)

short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  anti_join(ATTR_SpecificCode) %>%
    anti_join(Vyndaqel_pats_CM_vs_PN) %>%
  inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 

Cardiac_Amyloidosis_Pats <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  anti_join(ATTR_SpecificCode) %>%
    anti_join(Vyndaqel_pats_CM_vs_PN) %>%
  inner_join(tekiyo_All_ContEnr_pts) 


fwrite(Cardiac_Amyloidosis_Pats, "Cardiac_Amyloidosis_Pats.txt", sep="\t")




# Is LAST -3 -2 YEARS
short_i_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_i_receipt_diseases_utagai_All_ContEnr_pts.txt", 
                                         colClasses = "character")
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym<="2020/03")
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym>="2018/04")

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(utagai_flg==0) %>% select(-utagai_flg)


short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()
ATTR_SpecificCode <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(diseases_code=="8850066") %>% select(kojin_id) %>% distinct()


m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code) %>% distinct()

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I50",icd10_code)|grepl("I42",icd10_code)|grepl("I43",icd10_code))




# Es LAST -3 -2 YEARS
short_e_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_e_receipt_diseases_utagai_All_ContEnr_pts.txt", 
                                         colClasses = "character")
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym<="2020/03")
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym>="2018/04")

short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(utagai_flg==0) %>% select(-utagai_flg)

short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()


m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code) %>% distinct()

short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code))



# HEART FAILURE LAST -3 -2 YEARS
short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I500",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  anti_join(short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I42",icd10_code)|grepl("I43",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
      anti_join(short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
  left_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight)))  # 8194013


short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I42",icd10_code)|grepl("I43",icd10_code)) %>% filter(icd10_code!="I420"&
                                                                                                                  icd10_code!="I423"&
                                                                                                                  icd10_code!="I424"&
                                                                                                                  icd10_code!="I426"&
                                                                                                                  icd10_code!="I427") %>% select(kojin_id) %>% distinct() %>%
      anti_join(short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
      anti_join(Vyndaqel_pats_CM_vs_PN) %>%
  left_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) 

# HEART FAILURE LAST -3 -2 YEARS & AMYLOIDOSIS & CARDIOMYOPATHY & CARDIOMYOPATHY DUE TO AMYLOIDOSIS


short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  inner_join(ATTR_SpecificCode) %>%
  anti_join(Vyndaqel_pats_CM_vs_PN) %>%
  inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 


short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  anti_join(ATTR_SpecificCode) %>%
    anti_join(Vyndaqel_pats_CM_vs_PN) %>%
  inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 












receipt_drug_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_drug_Vyndaqel195pts.txt", colClasses = "character")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts[,.(kojin_id, receipt_ym, drug_code)]
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% filter(drug_code=="622278901")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% select(-c(drug_code))
Exact_Month_Lookup <- receipt_drug_Vyndaqel195pts %>% select(receipt_ym) %>% distinct() %>% arrange(receipt_ym) %>%
  mutate(Exact_Month=row_number())
names(Exact_Month_Lookup)[2] <- "Month"

GapFillVyndael <- fread("VyndaqelPts195/GapFill_Vyndaqel.csv", sep=",")
GapFillVyndael <- gather(GapFillVyndael, Month, Treat, 2:88, factor_key=TRUE)
GapFillVyndael$Month <- as.numeric(GapFillVyndael$Month)
GapFillVyndael <- GapFillVyndael %>% left_join(Exact_Month_Lookup)
GapFillVyndael$kojin_id <- as.character(GapFillVyndael$kojin_id)


Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")
Vyndaqel_pats_CM_vs_PN <- Vyndaqel_pats_CM_vs_PN %>% select(kojin_id, PN, CM, Combo)

VyndaqelPts195 <- fread("VyndaqelPts195/tekiyo_Vyndaqel195pts.txt", colClasses = "character")
VyndaqelPts195 <- VyndaqelPts195 %>% select(kojin_id, birth_ym, sex_code)
VyndaqelPts195[, gender:= ifelse(sex_code == 1, "M","F")]
VyndaqelPts195 <- VyndaqelPts195 %>% select(-sex_code)
VyndaqelPts195$birth_ym <- as.Date(paste0(as.character(VyndaqelPts195$birth_ym), '/01'))
VyndaqelPts195$age <- round(time_length(interval(VyndaqelPts195$birth_ym, ymd("2021-08-01")), "year"))
VyndaqelPts195 <- VyndaqelPts195 %>% select(-birth_ym)
VyndaqelPts195 <- VyndaqelPts195 %>% left_join(Vyndaqel_pats_CM_vs_PN)
VyndaqelPts195 <- VyndaqelPts195 %>% mutate(age=ifelse(age>=95,95,age))
VyndaqelPts195$age <- as.character(VyndaqelPts195$age)
VyndaqelPts195 <- VyndaqelPts195  %>% left_join(ContinuouslyEnrolled_Y3_tekiyo_weights %>% select(age, gender, weight) %>% distinct())
VyndaqelPts195 <- VyndaqelPts195 %>% select(kojin_id, weight)
sum(as.numeric(VyndaqelPts195$weight))

GapFillVyndael %>%  filter(receipt_ym=="2021/03") %>%
  filter(Treat==1) %>% select(kojin_id) %>% distinct() %>%
  inner_join(Vyndaqel_pats_CM_vs_PN %>% filter(CM==1|Combo==1) %>% select(kojin_id)) %>% 
  inner_join(VyndaqelPts195) %>% 
  inner_join(ContinuouslyEnrolled_Y3_tekiyo_weights %>% select(kojin_id)) %>% summarise(n=sum(as.numeric(weight)))  # 
  
  
  anti_join(GapFillVyndael %>% filter(receipt_ym<="2020/03" & receipt_ym>="2018/04") %>% filter(Treat==1) %>% select(kojin_id) %>% distinct()) %>%
   left_join(VyndaqelPts195) %>% summarise(n=sum(as.numeric(weight)))  # 



GapFillVyndael %>% filter(receipt_ym<="2020/04") %>% filter(Treat==1) %>% select(kojin_id) %>% distinct() %>%
  inner_join(Vyndaqel_pats_CM_vs_PN %>% filter(CM==1|Combo==1) %>% select(kojin_id)) %>% 
  inner_join(VyndaqelPts195) %>%  #  summarise(n=sum(as.numeric(weight)))
  inner_join(ContinuouslyEnrolled_Y3_tekiyo_weights %>% select(kojin_id)) %>% summarise(n=sum(as.numeric(weight)))


GapFillVyndael %>% filter(receipt_ym=="2020/04") %>% filter(Treat==1) %>% select(kojin_id) %>% distinct() %>%
  inner_join(Vyndaqel_pats_CM_vs_PN %>% filter(CM==1|Combo==1) %>% select(kojin_id)) %>% 
  inner_join(VyndaqelPts195) %>%  #  summarise(n=sum(as.numeric(weight)))
  inner_join(ContinuouslyEnrolled_Y3_tekiyo_weights %>% select(kojin_id)) %>% summarise(n=sum(as.numeric(weight)))
















# POLYNEUROPATHY

tekiyo_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/tekiyo_All_ContEnr_pts.txt", colClasses = "character")
ContinuouslyEnrolled_Y3_tekiyo_weights <- fread("All_Pts_ContinuousEnrolled/ContinuouslyEnrolled_Y3_tekiyo_weights.txt", colClasses = "character")
tekiyo_All_ContEnr_pts <- tekiyo_All_ContEnr_pts %>% left_join(ContinuouslyEnrolled_Y3_tekiyo_weights %>% select(kojin_id, weight)) %>% select(kojin_id, weight)
sum(as.numeric(tekiyo_All_ContEnr_pts$weight)) # 

Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")
Vyndaqel_pats_CM_vs_PN <- Vyndaqel_pats_CM_vs_PN %>% select(kojin_id) 
Vyndaqel_pats_CM_vs_PN %>% inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) #  cont. enroll.



# Is LAST 3 YEARS
short_i_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_i_receipt_diseases_utagai_All_ContEnr_pts.txt", 
                                         colClasses = "character")

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(utagai_flg==0) %>% select(-utagai_flg)

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()
m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code) %>% distinct()

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% 
  filter(grepl("I50",icd10_code)|grepl("I42",icd10_code)|grepl("I43",icd10_code)) %>% select(kojin_id) %>% distinct()


# Gs LAST 3 YEARS
short_g_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_g_receipt_diseases_utagai_All_ContEnr_pts.txt", 
                                         colClasses = "character")

short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% filter(utagai_flg==0) %>% select(-utagai_flg)


short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym<="2021/03")
short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym>="2018/04")

short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()
m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code) %>% distinct()

short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% filter(grepl("G6",icd10_code))



# Es LAST 3 YEARS
short_e_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_e_receipt_diseases_utagai_All_ContEnr_pts.txt", 
                                         colClasses = "character")

short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(utagai_flg==0) %>% select(-utagai_flg)


short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym<="2021/03")
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym>="2018/04")
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()
m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code) %>% distinct()

short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code))





# POLYNEUROPATHY LAST 3 YEARS
short_g_receipt_diseases_All_ContEnr_pts %>% filter(grepl("G6",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  anti_join(short_i_receipt_diseases_All_ContEnr_pts) %>%
  left_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 

# POLYNEUROPATHY LAST 3 YEARS & AMYLOIDOSIS POLYNEUROPATHY
short_g_receipt_diseases_All_ContEnr_pts %>% filter(grepl("G6",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
    anti_join(short_i_receipt_diseases_All_ContEnr_pts) %>%
  inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
  inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 


# POLYNEUROPATHY LAST 3 YEARS & AMYLOIDOSIS & POLYNEUROPATHY DUE TO AMYLOIDOSIS
short_g_receipt_diseases_All_ContEnr_pts %>% filter(grepl("G6",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
    anti_join(short_i_receipt_diseases_All_ContEnr_pts) %>%
  inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
    inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E851",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
  inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 

# POLYNEUROPATHY LAST 3 YEARS & AMYLOIDOSIS & POLYNEUROPATHY DUE TO AMYLOIDOSIS
# short_g_receipt_diseases_All_ContEnr_pts %>% filter(grepl("G6",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
#     anti_join(short_i_receipt_diseases_All_ContEnr_pts) %>%
#   inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
#     inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E851",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
#     inner_join(Vyndaqel_pats_CM_vs_PN) %>%
#   inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) 

# TargetPN_patients <- short_g_receipt_diseases_All_ContEnr_pts %>% filter(grepl("G6",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
#     anti_join(short_i_receipt_diseases_All_ContEnr_pts) %>%
#   inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
#     inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E851",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
#   inner_join(tekiyo_All_ContEnr_pts) 





# Is YEARS -3 and -2
short_i_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_i_receipt_diseases_utagai_All_ContEnr_pts.txt", 
                                         colClasses = "character")

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(utagai_flg==0) %>% select(-utagai_flg)

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()
m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code) %>% distinct()

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% 
  filter(grepl("I50",icd10_code)|grepl("I42",icd10_code)|grepl("I43",icd10_code)) %>% select(kojin_id) %>% distinct()


# Gs YEARS -3 and -2

short_g_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_g_receipt_diseases_utagai_All_ContEnr_pts.txt", 
                                         colClasses = "character")

short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% filter(utagai_flg==0) %>% select(-utagai_flg)


short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym<="2020/03")
short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym>="2018/04")

short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()
m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code) %>% distinct()

short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% filter(grepl("G6",icd10_code))



# Es YEARS -3 and -2
short_e_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_e_receipt_diseases_utagai_All_ContEnr_pts.txt", 
                                         colClasses = "character")

short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(utagai_flg==0) %>% select(-utagai_flg)


short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym<="2020/03")
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym>="2018/04")
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()
m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code) %>% distinct()

short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code))






# POLYNEUROPATHY YEARS -3 and -2
short_g_receipt_diseases_All_ContEnr_pts %>% filter(grepl("G6",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  anti_join(short_i_receipt_diseases_All_ContEnr_pts) %>%
  left_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 

# POLYNEUROPATHY YEARS -3 and -2 & AMYLOIDOSIS POLYNEUROPATHY
short_g_receipt_diseases_All_ContEnr_pts %>% filter(grepl("G6",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
    anti_join(short_i_receipt_diseases_All_ContEnr_pts) %>%
  inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
  inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 

# POLYNEUROPATHY YEARS -3 and -2 & AMYLOIDOSIS & POLYNEUROPATHY DUE TO AMYLOIDOSIS
short_g_receipt_diseases_All_ContEnr_pts %>% filter(grepl("G6",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
   anti_join(short_i_receipt_diseases_All_ContEnr_pts) %>%
  inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
    inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E851",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
  inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 

# POLYNEUROPATHYYEARS -3 and -2 & AMYLOIDOSIS & POLYNEUROPATHY DUE TO AMYLOIDOSIS + Vyndaqel
# short_g_receipt_diseases_All_ContEnr_pts %>% filter(grepl("G6",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
#    anti_join(short_i_receipt_diseases_All_ContEnr_pts) %>%
#   inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
#     inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E851",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
#     inner_join(Vyndaqel_pats_CM_vs_PN) %>% 
#   inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) 





receipt_drug_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_drug_Vyndaqel195pts.txt", colClasses = "character")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts[,.(kojin_id, receipt_ym, drug_code)]
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% filter(drug_code=="622278901")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% select(-c(drug_code))
Exact_Month_Lookup <- receipt_drug_Vyndaqel195pts %>% select(receipt_ym) %>% distinct() %>% arrange(receipt_ym) %>%
  mutate(Exact_Month=row_number())
names(Exact_Month_Lookup)[2] <- "Month"

GapFillVyndael <- fread("VyndaqelPts195/GapFill_Vyndaqel.csv", sep=",")
GapFillVyndael <- gather(GapFillVyndael, Month, Treat, 2:88, factor_key=TRUE)
GapFillVyndael$Month <- as.numeric(GapFillVyndael$Month)
GapFillVyndael <- GapFillVyndael %>% left_join(Exact_Month_Lookup)
GapFillVyndael$kojin_id <- as.character(GapFillVyndael$kojin_id)


Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")
Vyndaqel_pats_CM_vs_PN <- Vyndaqel_pats_CM_vs_PN %>% select(kojin_id, PN, CM, Combo)

VyndaqelPts195 <- fread("VyndaqelPts195/tekiyo_Vyndaqel195pts.txt", colClasses = "character")
VyndaqelPts195 <- VyndaqelPts195 %>% select(kojin_id, birth_ym, sex_code)
VyndaqelPts195[, gender:= ifelse(sex_code == 1, "M","F")]
VyndaqelPts195 <- VyndaqelPts195 %>% select(-sex_code)
VyndaqelPts195$birth_ym <- as.Date(paste0(as.character(VyndaqelPts195$birth_ym), '/01'))
VyndaqelPts195$age <- round(time_length(interval(VyndaqelPts195$birth_ym, ymd("2021-08-01")), "year"))
VyndaqelPts195 <- VyndaqelPts195 %>% select(-birth_ym)
VyndaqelPts195 <- VyndaqelPts195 %>% left_join(Vyndaqel_pats_CM_vs_PN)
VyndaqelPts195 <- VyndaqelPts195 %>% mutate(age=ifelse(age>=95,95,age))
VyndaqelPts195$age <- as.character(VyndaqelPts195$age)
VyndaqelPts195 <- VyndaqelPts195  %>% left_join(ContinuouslyEnrolled_Y3_tekiyo_weights %>% select(age, gender, weight) %>% distinct())
VyndaqelPts195 <- VyndaqelPts195 %>% select(kojin_id, weight)
sum(as.numeric(VyndaqelPts195$weight))

GapFillVyndael %>% filter(receipt_ym<="2021/03" & receipt_ym>="2018/04") %>% filter(Treat==1) %>% select(kojin_id) %>% distinct() %>%
  inner_join(Vyndaqel_pats_CM_vs_PN %>% filter(PN==1) %>% select(kojin_id)) %>% 
  inner_join(VyndaqelPts195) %>% summarise(n=sum(as.numeric(weight))) %>% # 1525.761
  anti_join(GapFillVyndael %>% filter(receipt_ym<="2020/03" & receipt_ym>="2018/04") %>% filter(Treat==1) %>% select(kojin_id) %>% distinct()) %>%
   left_join(VyndaqelPts195) %>% summarise(n=sum(as.numeric(weight)))  # 845.0034


# -------------------------------------

# Stocks / Flows diagram PN Vyndaqel patient funnel NEW RULES ---------------------------------

# POLYNEUROPATHY
tekiyo_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/tekiyo_All_ContEnr_pts.txt", colClasses = "character")
ContinuouslyEnrolled_Y3_tekiyo_weights <- fread("All_Pts_ContinuousEnrolled/ContinuouslyEnrolled_Y3_tekiyo_weights.txt", colClasses = "character")
tekiyo_All_ContEnr_pts <- tekiyo_All_ContEnr_pts %>% left_join(ContinuouslyEnrolled_Y3_tekiyo_weights %>% select(kojin_id, weight)) %>% select(kojin_id, weight)
sum(as.numeric(tekiyo_All_ContEnr_pts$weight)) # 26009563

Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")
Vyndaqel_pats_CM_vs_PN <- Vyndaqel_pats_CM_vs_PN %>% select(kojin_id) 
Vyndaqel_pats_CM_vs_PN %>% inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 


#Is ever
# Is LAST 3 YEARS
short_i_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_i_receipt_diseases_utagai_All_ContEnr_pts.txt", 
                                         colClasses = "character")

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(utagai_flg==0) %>% select(-utagai_flg)
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()

m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code) %>% distinct()

CardiomyopathyToRemove <- short_i_receipt_diseases_All_ContEnr_pts %>% 
  filter(grepl("I42",icd10_code)|grepl("I43",icd10_code)) %>% select(kojin_id) %>% distinct()



# Gs LAST 3 YEARS
short_g_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_g_receipt_diseases_utagai_All_ContEnr_pts.txt", 
                                         colClasses = "character")

short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% filter(utagai_flg==0) %>% select(-utagai_flg)

short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym<="2020/03")
short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym>="2018/04")

short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()

m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)

short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code) %>% distinct()

short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% filter(grepl("G6",icd10_code))



# Es LAST 3 YEARS
short_e_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_e_receipt_diseases_utagai_All_ContEnr_pts.txt", 
                                         colClasses = "character")

short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(utagai_flg==0) %>% select(-utagai_flg)


short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym<="2020/03")
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym>="2018/04")

short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()

m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)

short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% 
  left_join(m_icd10) %>% select(kojin_id, diseases_code, icd10_code) %>% distinct()

short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E851",icd10_code))





# POLYNEUROPATHY LAST 3 YEARS
short_g_receipt_diseases_All_ContEnr_pts %>% filter(grepl("G6",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  anti_join(CardiomyopathyToRemove) %>%
  anti_join(short_e_receipt_diseases_All_ContEnr_pts %>% select(kojin_id) %>% distinct()) %>%
  anti_join(Vyndaqel_pats_CM_vs_PN %>% select(kojin_id) %>% distinct()) %>%
  left_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 


# POLYNEUROPATHY E851
short_e_receipt_diseases_All_ContEnr_pts %>%  select(kojin_id) %>% distinct() %>%
  anti_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(diseases_code=="8848092") %>% select(kojin_id) %>% distinct()) %>%
    anti_join(CardiomyopathyToRemove) %>%
    anti_join(Vyndaqel_pats_CM_vs_PN %>% select(kojin_id) %>% distinct()) %>%
  inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 

short_e_receipt_diseases_All_ContEnr_pts %>% filter(diseases_code=="8848092") %>% select(kojin_id) %>% distinct() %>%
    anti_join(CardiomyopathyToRemove) %>%
      anti_join(Vyndaqel_pats_CM_vs_PN %>% select(kojin_id) %>% distinct()) %>%
  inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 










receipt_drug_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_drug_Vyndaqel195pts.txt", colClasses = "character")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts[,.(kojin_id, receipt_ym, drug_code)]
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% filter(drug_code=="622278901")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% select(-c(drug_code))
Exact_Month_Lookup <- receipt_drug_Vyndaqel195pts %>% select(receipt_ym) %>% distinct() %>% arrange(receipt_ym) %>%
  mutate(Exact_Month=row_number())
names(Exact_Month_Lookup)[2] <- "Month"

GapFillVyndael <- fread("VyndaqelPts195/GapFill_Vyndaqel.csv", sep=",")
GapFillVyndael <- gather(GapFillVyndael, Month, Treat, 2:88, factor_key=TRUE)
GapFillVyndael$Month <- as.numeric(GapFillVyndael$Month)
GapFillVyndael <- GapFillVyndael %>% left_join(Exact_Month_Lookup)
GapFillVyndael$kojin_id <- as.character(GapFillVyndael$kojin_id)


Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")
Vyndaqel_pats_CM_vs_PN <- Vyndaqel_pats_CM_vs_PN %>% select(kojin_id, PN, CM, Combo)

VyndaqelPts195 <- fread("VyndaqelPts195/tekiyo_Vyndaqel195pts.txt", colClasses = "character")
VyndaqelPts195 <- VyndaqelPts195 %>% select(kojin_id, birth_ym, sex_code)
VyndaqelPts195[, gender:= ifelse(sex_code == 1, "M","F")]
VyndaqelPts195 <- VyndaqelPts195 %>% select(-sex_code)
VyndaqelPts195$birth_ym <- as.Date(paste0(as.character(VyndaqelPts195$birth_ym), '/01'))
VyndaqelPts195$age <- round(time_length(interval(VyndaqelPts195$birth_ym, ymd("2021-08-01")), "year"))
VyndaqelPts195 <- VyndaqelPts195 %>% select(-birth_ym)
VyndaqelPts195 <- VyndaqelPts195 %>% left_join(Vyndaqel_pats_CM_vs_PN)
VyndaqelPts195 <- VyndaqelPts195 %>% mutate(age=ifelse(age>=95,95,age))
VyndaqelPts195$age <- as.character(VyndaqelPts195$age)
VyndaqelPts195 <- VyndaqelPts195  %>% left_join(ContinuouslyEnrolled_Y3_tekiyo_weights %>% select(age, gender, weight) %>% distinct())
VyndaqelPts195 <- VyndaqelPts195 %>% select(kojin_id, weight)
sum(as.numeric(VyndaqelPts195$weight))

GapFillVyndael %>%  
  filter(Treat==1) %>% select(kojin_id) %>% distinct() %>%
  inner_join(Vyndaqel_pats_CM_vs_PN %>% filter(PN==1) %>% select(kojin_id)) %>% 
  inner_join(VyndaqelPts195) %>% 
  inner_join(ContinuouslyEnrolled_Y3_tekiyo_weights %>% select(kojin_id)) %>% summarise(n=sum(as.numeric(weight)))  # 
  
  
  anti_join(GapFillVyndael %>% filter(receipt_ym<="2020/03" & receipt_ym>="2018/04") %>% filter(Treat==1) %>% select(kojin_id) %>% distinct()) %>%
   left_join(VyndaqelPts195) %>% summarise(n=sum(as.numeric(weight)))  # 


  
# -------------------------------------------------------
# ------------------------------------------

# Compare Drugs Penetrance across Vyndaqel, Diagnosed non-treated and non-diagnosed patients NEW RULES ------------

Cardiomyopathy_Pats <- fread("Cardiomyopathy_Pats.txt", colClasses = "character")
Cardiac_Amyloidosis_Pats <- fread("Cardiac_Amyloidosis_Pats.txt", colClasses = "character")
ATTR_CM_noVyn_Pats <- fread("ATTR_CM_noVyn_Pats.txt", colClasses = "character")
Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")
ATTR_CM_Vyndaqel_Pats <- Vyndaqel_pats_CM_vs_PN %>%filter(CM==1|Combo==1) %>%  select(kojin_id)


Drug_Classes_lookup <- fread("Masters/Drug_Classes_lookup.csv", colClasses = "character")
m_drug_who_atc <- fread("Masters/m_drug_who_atc.csv", colClasses = "character")
m_drug_who_atc <- m_drug_who_atc %>% select(drug_code, atc_major_name_en)


receipt_drug_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_drug_Vyndaqel195pts.txt", colClasses = "character")
receipt_drug_Vyndaqel195pts <- distinct(receipt_drug_Vyndaqel195pts[,.(kojin_id, drug_code)])


ATTR_CM_Vyndaqel_Pats_Drugs <- receipt_drug_Vyndaqel195pts %>%
  inner_join(ATTR_CM_Vyndaqel_Pats) %>%
  left_join(Drug_Classes_lookup) %>% select(kojin_id, drug_class) %>%
  distinct() %>%
  group_by(drug_class) %>% count() %>% mutate(penetrance=n/168) %>% arrange(-penetrance) %>%
  rename("ATTR_CM_Vyndaqel_Pats"="penetrance") %>% select(-n)


short_CV_receipt_drug_All_Cont_Enr <- fread("All_Pts_Continuousenrolled/short_CV_receipt_drug_All_ContEnr_pts.txt", colClasses = "character")
short_CV_receipt_drug_All_Cont_Enr <- short_CV_receipt_drug_All_Cont_Enr %>% select(kojin_id, drug_code) %>% distinct()

ATTR_CM_noVyn_Pats_Drugs <- ATTR_CM_noVyn_Pats %>% inner_join(short_CV_receipt_drug_All_Cont_Enr) %>%
    left_join(Drug_Classes_lookup) %>% select(kojin_id, drug_class) %>%
  distinct() %>%
  group_by(drug_class) %>% count() %>% mutate(penetrance=n/17) %>% arrange(-penetrance) %>%
  rename("ATTR_CM_noVyn_Pats"="penetrance") %>% select(-n)

  
Cardiac_Amyloidosis_Pats_Drugs <- Cardiac_Amyloidosis_Pats %>% inner_join(short_CV_receipt_drug_All_Cont_Enr) %>%
    left_join(Drug_Classes_lookup) %>% select(kojin_id, drug_class) %>%
  distinct() %>%
  group_by(drug_class) %>% count() %>% mutate(penetrance=n/307) %>% arrange(-penetrance) %>%
  rename("Cardiac_Amyloidosis_Pats"="penetrance") %>% select(-n)


Cardiomyopathy_Pats_drugs <- Cardiomyopathy_Pats %>% inner_join(short_CV_receipt_drug_All_Cont_Enr) %>%
    left_join(Drug_Classes_lookup) %>% select(kojin_id, drug_class) %>%
  distinct() %>%
  group_by(drug_class) %>% count() %>% mutate(penetrance=n/16896) %>% arrange(-penetrance) %>%
  rename("Cardiomyopathy_Pats"="penetrance") %>% select(-n)

   
temp <- ATTR_CM_Vyndaqel_Pats_Drugs %>% full_join(ATTR_CM_noVyn_Pats_Drugs) %>% full_join(Cardiac_Amyloidosis_Pats_Drugs) %>% full_join(Cardiomyopathy_Pats_drugs)

temp[is.na(temp)] <- 0

temp %>% arrange(-ATTR_CM_Vyndaqel_Pats)



# ----------------------------
# Compare Procedures Penetrance across Vyndaqel, Diagnosed non-treated and non-diagnosed patients NEW RULES ------------

Cardiomyopathy_Pats <- fread("Cardiomyopathy_Pats.txt", colClasses = "character")
Cardiac_Amyloidosis_Pats <- fread("Cardiac_Amyloidosis_Pats.txt", colClasses = "character")
ATTR_CM_noVyn_Pats <- fread("ATTR_CM_noVyn_Pats.txt", colClasses = "character")
Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")
ATTR_CM_Vyndaqel_Pats <- Vyndaqel_pats_CM_vs_PN %>%filter(CM==1|Combo==1) %>%  select(kojin_id)


receipt_medical_practice_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_medical_practice_Vyndaqel195pts.txt", colClasses = "character")
receipt_medical_practice_Vyndaqel195pts <- distinct(receipt_medical_practice_Vyndaqel195pts[,.(kojin_id, medical_practice_code)])

Procedure_master <- fread("Masters/Procedure_master.csv", colClasses = "character")

receipt_medical_practice_Vyndaqel195pts <- 
  receipt_medical_practice_Vyndaqel195pts %>% 
  left_join(Procedure_master, 
            by=c("medical_practice_code"="standardized_procedure_code")) %>%
  select(kojin_id, standardized_procedure_name) %>% distinct()

receipt_medical_practice_Vyndaqel195pts <- receipt_medical_practice_Vyndaqel195pts %>%
                                              filter(grepl("computerized tomog", standardized_procedure_name)|
                                                     grepl("CT imaging", standardized_procedure_name)|
                                                     grepl("nuclear medicine diagnosis", standardized_procedure_name)|
                                                     grepl("scintigraphy", standardized_procedure_name)|
                                                     grepl("MRI", standardized_procedure_name)|
                                                     grepl("electrocardiog", standardized_procedure_name)|
                                                     grepl("ECG", standardized_procedure_name)|
                                                     grepl("ultrasonography", standardized_procedure_name)|
                                                     grepl("SPECT", standardized_procedure_name)|
                                                     grepl("PET ", standardized_procedure_name)|
                                                     grepl("percutaneous needle biopsy", standardized_procedure_name)|
                                                     grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name)|
                                                     grepl("endoscopic biopsy", standardized_procedure_name)|
                                                     grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name)|
                                                     grepl("brain natriuretic peptide", standardized_procedure_name)|
                                                     grepl("BNP", standardized_procedure_name)|
                                                     grepl("troponin", standardized_procedure_name)|
                                                     grepl("genetic test", standardized_procedure_name)|
                                                     grepl("cardiac catheterization", standardized_procedure_name)|
                                                     grepl("Holter", standardized_procedure_name)|
                                                     grepl("pacemaker", standardized_procedure_name)|
                                                     grepl("gene-related", standardized_procedure_name)|
                                                     grepl("exercise test", standardized_procedure_name)|
                                                     grepl("hospitalization", standardized_procedure_name)|
                                                     grepl("serum amyloid A protein", standardized_procedure_name)|
                                                     grepl("prealbumin", standardized_procedure_name)|
                                                     grepl("transthyretin", standardized_procedure_name)|
                                                     grepl("amylase", standardized_procedure_name))

receipt_medical_practice_Vyndaqel195pts <-
  receipt_medical_practice_Vyndaqel195pts %>% mutate(standardized_procedure_name=
                                                     ifelse(grepl("computerized tomog",standardized_procedure_name), "CT",
                                                            ifelse(grepl("CT imaging,", standardized_procedure_name), "CT",
                                                                   ifelse(grepl("nuclear medicine diagnosis", standardized_procedure_name), "other nuclear medicine",
                                                                          ifelse(grepl("scintigraphy", standardized_procedure_name), "scintigraphy",
                                                                                 ifelse(grepl("MRI", standardized_procedure_name), "MRI",
                                                                                        ifelse(grepl("electrocardiog", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ECG", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ultrasonography", standardized_procedure_name), "ultrasonography",
                                                                                                      ifelse(grepl("SPECT", standardized_procedure_name), "scintigraphy",
                                                                                                             ifelse(grepl("PET ", standardized_procedure_name), "scintigraphy",
                                                                                                      ifelse(grepl("percutaneous needle biopsy", standardized_procedure_name), "biopsy",
                                                                                                             ifelse(grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("endoscopic biopsy", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name), "heart biopsy",
                                                                                                                           ifelse(grepl("brain natriuretic peptide", standardized_procedure_name), "BNP",
                                                                                                                                  ifelse(grepl("BNP", standardized_procedure_name), "BNP",
                                                                                                                                         ifelse(grepl("troponin", standardized_procedure_name), "troponin",
                                                                                                                                                ifelse(grepl("genetic test", standardized_procedure_name), "genetic test",
                                                                                                                                                       ifelse(grepl("cardiac catheterization", standardized_procedure_name), "cardiac catheterization",
                                                                                                                                                              ifelse(grepl("Holter", standardized_procedure_name), "Holter",
                                                                                                                                                                     ifelse(grepl("pacemaker", standardized_procedure_name), "pacemaker",
                                                                                                                                                                            ifelse(grepl("gene-related", standardized_procedure_name), "genetic test",
                                                                                                                                                                                          ifelse(grepl("exercise test", standardized_procedure_name), "exercise test",
                                                                                                                                                                                                 ifelse(grepl("hospitalization", standardized_procedure_name), "hospitalization",
                                                                                                                                                                                                        ifelse(grepl("serum amyloid A protein", standardized_procedure_name), "AmyloidA",
                                                                                                                                                                                                               ifelse(grepl("prealbumin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("transthyretin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("amylase", standardized_procedure_name), "amylase",NA)))))))))))))))))))))))))))))
                                                                   

receipt_medical_practice_Vyndaqel195pts <- receipt_medical_practice_Vyndaqel195pts %>% mutate(standardized_procedure_name=ifelse(is.na(standardized_procedure_name),"CT", standardized_procedure_name))



ATTR_CM_Vyndaqel_Pats_Proc <- receipt_medical_practice_Vyndaqel195pts %>% 
  inner_join(ATTR_CM_Vyndaqel_Pats) %>%
  select(kojin_id, standardized_procedure_name) %>% distinct() %>%
  group_by(standardized_procedure_name) %>% count() %>% mutate(penetrance=n/168) %>%
  arrange(-penetrance) %>% select(-n) %>% rename("ATTR_CM_Vyndaqel_Pats"="penetrance")




short_procedures_receipt_medical_practice_All_ContEnr_pts <- fread("All_Pts_Continuousenrolled/short_procedures_receipt_medical_practice_All_ContEnr_pts.txt", colClasses = "character")
short_procedures_receipt_medical_practice_All_ContEnr_pts <- short_procedures_receipt_medical_practice_All_ContEnr_pts %>% select(kojin_id, medical_practice_code) %>% distinct()
short_procedures_receipt_medical_practice_All_ContEnr_pts <- Cardiomyopathy_Pats %>% full_join(Cardiac_Amyloidosis_Pats) %>% full_join(ATTR_CM_noVyn_Pats) %>% select(-weight) %>% left_join(short_procedures_receipt_medical_practice_All_ContEnr_pts)


short_procedures_receipt_medical_practice_All_ContEnr_pts <- 
  short_procedures_receipt_medical_practice_All_ContEnr_pts %>% 
  left_join(Procedure_master, 
            by=c("medical_practice_code"="standardized_procedure_code")) %>%
  select(kojin_id, standardized_procedure_name) %>% distinct()

short_procedures_receipt_medical_practice_All_ContEnr_pts <- short_procedures_receipt_medical_practice_All_ContEnr_pts %>%
                                              filter(grepl("computerized tomog", standardized_procedure_name)|
                                                     grepl("CT imaging", standardized_procedure_name)|
                                                     grepl("nuclear medicine diagnosis", standardized_procedure_name)|
                                                     grepl("scintigraphy", standardized_procedure_name)|
                                                     grepl("MRI", standardized_procedure_name)|
                                                     grepl("electrocardiog", standardized_procedure_name)|
                                                     grepl("ECG", standardized_procedure_name)|
                                                     grepl("ultrasonography", standardized_procedure_name)|
                                                     grepl("SPECT", standardized_procedure_name)|
                                                     grepl("PET ", standardized_procedure_name)|
                                                     grepl("percutaneous needle biopsy", standardized_procedure_name)|
                                                     grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name)|
                                                     grepl("endoscopic biopsy", standardized_procedure_name)|
                                                     grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name)|
                                                     grepl("brain natriuretic peptide", standardized_procedure_name)|
                                                     grepl("BNP", standardized_procedure_name)|
                                                     grepl("troponin", standardized_procedure_name)|
                                                     grepl("genetic test", standardized_procedure_name)|
                                                     grepl("cardiac catheterization", standardized_procedure_name)|
                                                     grepl("Holter", standardized_procedure_name)|
                                                     grepl("pacemaker", standardized_procedure_name)|
                                                     grepl("gene-related", standardized_procedure_name)|
                                                     grepl("exercise test", standardized_procedure_name)|
                                                     grepl("hospitalization", standardized_procedure_name)|
                                                     grepl("serum amyloid A protein", standardized_procedure_name)|
                                                     grepl("prealbumin", standardized_procedure_name)|
                                                     grepl("transthyretin", standardized_procedure_name)|
                                                     grepl("amylase", standardized_procedure_name))

short_procedures_receipt_medical_practice_All_ContEnr_pts <-
  short_procedures_receipt_medical_practice_All_ContEnr_pts %>% mutate(standardized_procedure_name=
                                                     ifelse(grepl("computerized tomog",standardized_procedure_name), "CT",
                                                            ifelse(grepl("CT imaging,", standardized_procedure_name), "CT",
                                                                   ifelse(grepl("nuclear medicine diagnosis", standardized_procedure_name), "other nuclear medicine",
                                                                          ifelse(grepl("scintigraphy", standardized_procedure_name), "scintigraphy",
                                                                                 ifelse(grepl("MRI", standardized_procedure_name), "MRI",
                                                                                        ifelse(grepl("electrocardiog", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ECG", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ultrasonography", standardized_procedure_name), "ultrasonography",
                                                                                                      ifelse(grepl("SPECT", standardized_procedure_name), "scintigraphy",
                                                                                                             ifelse(grepl("PET ", standardized_procedure_name), "scintigraphy",
                                                                                                      ifelse(grepl("percutaneous needle biopsy", standardized_procedure_name), "biopsy",
                                                                                                             ifelse(grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("endoscopic biopsy", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name), "heart biopsy",
                                                                                                                           ifelse(grepl("brain natriuretic peptide", standardized_procedure_name), "BNP",
                                                                                                                                  ifelse(grepl("BNP", standardized_procedure_name), "BNP",
                                                                                                                                         ifelse(grepl("troponin", standardized_procedure_name), "troponin",
                                                                                                                                                ifelse(grepl("genetic test", standardized_procedure_name), "genetic test",
                                                                                                                                                       ifelse(grepl("cardiac catheterization", standardized_procedure_name), "cardiac catheterization",
                                                                                                                                                              ifelse(grepl("Holter", standardized_procedure_name), "Holter",
                                                                                                                                                                     ifelse(grepl("pacemaker", standardized_procedure_name), "pacemaker",
                                                                                                                                                                            ifelse(grepl("gene-related", standardized_procedure_name), "genetic test",
                                                                                                                                                                                          ifelse(grepl("exercise test", standardized_procedure_name), "exercise test",
                                                                                                                                                                                                 ifelse(grepl("hospitalization", standardized_procedure_name), "hospitalization",
                                                                                                                                                                                                        ifelse(grepl("serum amyloid A protein", standardized_procedure_name), "AmyloidA",
                                                                                                                                                                                                               ifelse(grepl("prealbumin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("transthyretin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("amylase", standardized_procedure_name), "amylase",NA)))))))))))))))))))))))))))))
                                                                   

short_procedures_receipt_medical_practice_All_ContEnr_pts <- short_procedures_receipt_medical_practice_All_ContEnr_pts %>% mutate(standardized_procedure_name=ifelse(is.na(standardized_procedure_name),"CT", standardized_procedure_name))





ATTR_CM_noVyn_Pats_Proc <- ATTR_CM_noVyn_Pats %>% inner_join(short_procedures_receipt_medical_practice_All_ContEnr_pts) %>%
  distinct() %>%
  group_by(standardized_procedure_name) %>% count() %>% mutate(penetrance=n/17) %>% arrange(-penetrance) %>%
  rename("ATTR_CM_noVyn_Pats"="penetrance") %>% select(-n)

  
Cardiac_Amyloidosis_Pats_Proc <- Cardiac_Amyloidosis_Pats %>% inner_join(short_procedures_receipt_medical_practice_All_ContEnr_pts) %>%
  distinct() %>%
  group_by(standardized_procedure_name) %>% count() %>% mutate(penetrance=n/307) %>% arrange(-penetrance) %>%
  rename("Cardiac_Amyloidosis_Pats"="penetrance") %>% select(-n)


Cardiomyopathy_Pats_Proc <- Cardiomyopathy_Pats %>% inner_join(short_procedures_receipt_medical_practice_All_ContEnr_pts) %>%
  distinct() %>%
  group_by(standardized_procedure_name) %>% count() %>% mutate(penetrance=n/16896) %>% arrange(-penetrance) %>%
  rename("Cardiomyopathy_Pats"="penetrance") %>% select(-n)

   
temp <- ATTR_CM_Vyndaqel_Pats_Proc %>% full_join(ATTR_CM_noVyn_Pats_Proc) %>% full_join(Cardiac_Amyloidosis_Pats_Proc) %>% full_join(Cardiomyopathy_Pats_Proc)

temp[is.na(temp)] <- 0

temp %>% mutate(standardized_procedure_name=str_replace_all(standardized_procedure_name, " ", "_")) %>%
  arrange(-ATTR_CM_Vyndaqel_Pats)
# ---------------------------------
# Compare Target "ATTR Dx" With vs Without Vyndaqel Demographics, Dxs, etc -----------------------------------------

ATTR_Dx_Vyndaqel <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I50",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
    inner_join(short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I42",icd10_code)|grepl("I43",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
  inner_join(short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
  inner_join(tekiyo_All_ContEnr_pts) %>% 
  inner_join(GapFillVyndael %>% filter(Treat==1) %>% select(kojin_id) %>% distinct() %>%
  inner_join(Vyndaqel_pats_CM_vs_PN %>% filter(CM==1|Combo==1) %>% select(kojin_id))) 


ATTR_Dx_NO_Vyndaqel <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I50",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
    inner_join(short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I42",icd10_code)|grepl("I43",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
  inner_join(short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
  inner_join(tekiyo_All_ContEnr_pts) %>% 
  anti_join(GapFillVyndael %>% filter(Treat==1) %>% select(kojin_id) %>% distinct() %>% select(kojin_id)) 


ATTR_Dx_Vyndaqel
ATTR_Dx_NO_Vyndaqel

# Age
ATTR_Dx_Vyndaqel %>% left_join(ContinuouslyEnrolled_Y3_tekiyo_weights) %>% summarise(n=weighted.mean(as.numeric(age),as.numeric(weight))) # 
ATTR_Dx_NO_Vyndaqel %>% left_join(ContinuouslyEnrolled_Y3_tekiyo_weights) %>% summarise(n=weighted.mean(as.numeric(age),as.numeric(weight))) # 





# Number of ATTR I431

short_i_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_i_receipt_diseases_utagai_All_ContEnr_pts.txt", 
                                         colClasses = "character")
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(utagai_flg==0) %>% select(-utagai_flg)
m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
m_icd10 <- m_icd10 %>% filter(icd10_code=="I431")

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>%  inner_join(m_icd10) 

ATTR_Dx_Vyndaqel %>% left_join(short_i_receipt_diseases_All_ContEnr_pts %>% group_by(kojin_id) %>% count()) %>% 
  summarise(n2=weighted.mean(as.numeric(n),as.numeric(weight))) # 

ATTR_Dx_NO_Vyndaqel %>% left_join(short_i_receipt_diseases_All_ContEnr_pts %>% group_by(kojin_id) %>% count()) %>% 
  summarise(n2=weighted.mean(as.numeric(n),as.numeric(weight))) # 




# Time since Dx to March 2021

short_i_receipt_diseases_All_ContEnr_pts$receipt_ym  <- as.Date(paste0(as.character(short_i_receipt_diseases_All_ContEnr_pts$receipt_ym ), '/01'))
short_i_receipt_diseases_All_ContEnr_pts$ElapsedTime <- round(time_length(interval(short_i_receipt_diseases_All_ContEnr_pts$receipt_ym, ymd("2021-03-01")), "year"))

# MOST RECENT 
ATTR_Dx_Vyndaqel %>% left_join(short_i_receipt_diseases_All_ContEnr_pts) %>% group_by(kojin_id) %>% filter(ElapsedTime==min(ElapsedTime)) %>% slice(1) %>%
  select(kojin_id, weight, ElapsedTime) %>% ungroup() %>% summarise(n=weighted.mean(as.numeric(ElapsedTime), as.numeric(weight))) # 


ATTR_Dx_NO_Vyndaqel %>% left_join(short_i_receipt_diseases_All_ContEnr_pts) %>% group_by(kojin_id) %>% filter(ElapsedTime==min(ElapsedTime)) %>% slice(1) %>%
  select(kojin_id, weight, ElapsedTime) %>% ungroup() %>% summarise(n=weighted.mean(as.numeric(ElapsedTime), as.numeric(weight))) # 
                               

# First
ATTR_Dx_Vyndaqel %>% left_join(short_i_receipt_diseases_All_ContEnr_pts) %>% group_by(kojin_id) %>% filter(ElapsedTime==max(ElapsedTime)) %>% slice(1) %>%
  select(kojin_id, weight, ElapsedTime) %>% ungroup() %>% summarise(n=weighted.mean(as.numeric(ElapsedTime), as.numeric(weight))) #


ATTR_Dx_NO_Vyndaqel %>% left_join(short_i_receipt_diseases_All_ContEnr_pts) %>% group_by(kojin_id) %>% filter(ElapsedTime==max(ElapsedTime)) %>% slice(1) %>%
  select(kojin_id, weight, ElapsedTime) %>% ungroup() %>% summarise(n=weighted.mean(as.numeric(ElapsedTime), as.numeric(weight))) # 



# Distinct Dxs
short_i_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_i_receipt_diseases_utagai_All_ContEnr_pts.txt", 
                                         colClasses = "character")
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(utagai_flg==0) %>% select(-utagai_flg)
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()

m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code) %>% distinct()



short_e_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_e_receipt_diseases_utagai_All_ContEnr_pts.txt", 
                                         colClasses = "character")
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(utagai_flg==0) %>% select(-utagai_flg)
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()

m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code) %>% distinct()



short_g_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_g_receipt_diseases_utagai_All_ContEnr_pts.txt", 
                                         colClasses = "character")
short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% filter(utagai_flg==0) %>% select(-utagai_flg)
short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()

m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code) %>% distinct()






# Is
sum(as.numeric(ATTR_Dx_Vyndaqel$weight)) # 
sum(as.numeric(ATTR_Dx_NO_Vyndaqel$weight)) # 


data.frame(
  ATTR_Dx_Vyndaqel %>% left_join(short_i_receipt_diseases_All_ContEnr_pts)  %>% group_by(icd10_code) %>% 
             summarise(n_Vynd=sum(as.numeric(weight))/668.1897) %>%
             full_join(ATTR_Dx_NO_Vyndaqel %>% left_join(short_i_receipt_diseases_All_ContEnr_pts)  %>% group_by(icd10_code) %>% 
                         summarise(n_noVynd=sum(as.numeric(weight))/3580.48)) %>%
    filter(grepl("I",icd10_code)) %>%
             mutate(FoldChange=n_Vynd/n_noVynd) %>%
    mutate(Diff=n_Vynd - n_noVynd) %>% drop_na() %>%
    arrange(-Diff)
           )


# Es
sum(as.numeric(ATTR_Dx_Vyndaqel$weight)) # 
sum(as.numeric(ATTR_Dx_NO_Vyndaqel$weight)) # 

data.frame(
  ATTR_Dx_Vyndaqel %>% left_join(short_e_receipt_diseases_All_ContEnr_pts)  %>% group_by(icd10_code) %>% 
             summarise(n_Vynd=sum(as.numeric(weight))/668.1897) %>%
             full_join(ATTR_Dx_NO_Vyndaqel %>% left_join(short_e_receipt_diseases_All_ContEnr_pts)  %>% group_by(icd10_code) %>% 
                         summarise(n_noVynd=sum(as.numeric(weight))/3580.48)) %>%
    filter(grepl("E",icd10_code)) %>%
             mutate(FoldChange=n_Vynd/n_noVynd) %>%
    mutate(Diff=n_Vynd - n_noVynd) %>% drop_na() %>%
    arrange(-Diff)
           )
# Gs
sum(as.numeric(ATTR_Dx_Vyndaqel$weight)) # 
sum(as.numeric(ATTR_Dx_NO_Vyndaqel$weight)) # 


data.frame(
  ATTR_Dx_Vyndaqel %>% left_join(short_g_receipt_diseases_All_ContEnr_pts)  %>% group_by(icd10_code) %>% 
             summarise(n_Vynd=sum(as.numeric(weight))/668.1897) %>%
             full_join(ATTR_Dx_NO_Vyndaqel %>% left_join(short_g_receipt_diseases_All_ContEnr_pts)  %>% group_by(icd10_code) %>% 
                         summarise(n_noVynd=sum(as.numeric(weight))/3580.48)) %>%
    filter(grepl("G",icd10_code)) %>%
             mutate(FoldChange=n_Vynd/n_noVynd) %>%
    mutate(Diff=n_Vynd - n_noVynd) %>% drop_na() %>%
    arrange(-Diff)
           )



temp <- ATTR_Dx_Vyndaqel %>% mutate(Group="Treat") %>% select(-weight) %>% left_join(short_i_receipt_diseases_All_ContEnr_pts) %>%
  full_join(ATTR_Dx_Vyndaqel %>% mutate(Group="Treat") %>% select(-weight) %>% left_join(short_e_receipt_diseases_All_ContEnr_pts)) %>%
  full_join(ATTR_Dx_Vyndaqel %>% mutate(Group="Treat") %>% select(-weight) %>% left_join(short_g_receipt_diseases_All_ContEnr_pts)) %>%
  distinct() %>%
  bind_rows(
    ATTR_Dx_NO_Vyndaqel %>% mutate(Group="None") %>% select(-weight) %>% left_join(short_i_receipt_diseases_All_ContEnr_pts) %>%
  full_join(ATTR_Dx_NO_Vyndaqel %>% mutate(Group="None") %>% select(-weight) %>% left_join(short_e_receipt_diseases_All_ContEnr_pts)) %>%
  full_join(ATTR_Dx_NO_Vyndaqel %>% mutate(Group="None") %>% select(-weight) %>% left_join(short_g_receipt_diseases_All_ContEnr_pts)) %>%
  distinct()
  )

temp <- temp %>% filter(grepl("I",icd10_code)|grepl("E",icd10_code)|grepl("G",icd10_code))

 
# temp %>% filter(Group=="Treat" & icd10_code=="E859") %>% select(kojin_id) %>% left_join(temp) %>% group_by(icd10_code) %>% count() %>% arrange(-n)


temp <- temp %>% mutate(Treat=1) %>% ungroup() %>% spread(key=icd10_code, value=Treat)

temp[is.na(temp)] <- 0

temp$Group <- as.factor(temp$Group)

temp$Group <- relevel(temp$Group,"None")

temp2 <- temp %>% select(-kojin_id)


# create_train_test <- function(data, size = 0.8, train = TRUE) {
#   n_row = nrow(data)
#   total_row = size * n_row
#   train_sample <- 1: total_row
#   if (train == TRUE) {
#     return (data[train_sample, ])
#   } else {
#     return (data[-train_sample, ])
#   }
# }
# 
# temp <- temp[sample(1:nrow(temp)), ]
# 
# temp %>% group_by(Group) %>% count()
# temp2 <- temp %>% group_by(Group) %>% sample_n(60)



# data_train <- create_train_test(temp2, 0.8, train = TRUE)
# data_test <- create_train_test(temp2, 0.8, train = FALSE)


Risk_pred_model <- glm( Group ~ ., data = temp2, family = binomial)

summary(Risk_pred_model)
plot(Risk_pred_model)


predict <- predict(Risk_pred_model, temp2, type = 'response')

table_mat <- table(temp$Group, predict > 0.50)
table_mat

plot(table_mat)

accuracy_Test <- sum(diag(table_mat)) / sum(table_mat)
accuracy_Test

wait  %>% ggplot(aes(`...3`, colour=Group)) +
  geom_density(size=2) +
  ggsci::scale_color_jco() +
   theme_minimal() + 
  theme(legend.title = element_blank()) +
  facet_wrap(~Group, scales="free_y")

precision <- function(matrix) {
  # True positive
  tp <- matrix[2, 2]
  # false positive
  fp <- matrix[1, 2]
  return (tp / (tp + fp))
}



recall <- function(matrix) {
  # true positive
  tp <- matrix[2, 2]# false positive
  fn <- matrix[2, 1]
  return (tp / (tp + fn))
}


prec <- precision(table_mat)
prec 

rec <- recall(table_mat)
rec 

f1 <- 2 * ((prec * rec) / (prec + rec))
f1 



library("randomForest")
temp_rf <- randomForest(Group ~ . , data = temp2)
summary(temp_rf)
temp_rf$importance

library("gbm")
GLP1_gbm <- gbm(Group == "Treat" ~ ., data = temp2, 
                n.trees = 15000, distribution = "bernoulli")
summary(GLP1_gbm)


# --------------------------------------------------
# Who has the different I431 codes ? ALL VYNDAQEL CM   vs ALL target ATTR Dx but no Rx -----------------------------

receipt_diseases_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_diseases_Vyndaqel195pts.txt", 
                                         colClasses = "character")
receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>% select(kojin_id, diseases_code) %>% distinct()


m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
m_icd10 <- m_icd10 %>% filter(icd10_code=="I431")

receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>%  inner_join(m_icd10) 

unique(receipt_diseases_Vyndaqel195pts$diseases_code)


Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")
Vyndaqel_pats_CM_vs_PN <- Vyndaqel_pats_CM_vs_PN %>% filter(CM==1|Combo==1)
Vyndaqel_pats_CM_vs_PN <- Vyndaqel_pats_CM_vs_PN %>% filter(I431==1) %>% select(kojin_id)

Vyndaqel_pats_CM_vs_PN %>% left_join(receipt_diseases_Vyndaqel195pts) %>%
  group_by(diseases_code) %>% count()



short_i_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_i_receipt_diseases_utagai_All_ContEnr_pts.txt", 
                                         colClasses = "character")
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()

m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
m_icd10 <- m_icd10 %>% filter(icd10_code=="I431")

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>%  inner_join(m_icd10) 

unique(short_i_receipt_diseases_All_ContEnr_pts$diseases_code)

ATTR_Dx_NO_Vyndaqel %>% select(-weight) %>%
  left_join(short_i_receipt_diseases_All_ContEnr_pts) %>%
  group_by(diseases_code) %>% count()


ATTR_Dx_Vyndaqel %>% select(-weight) %>%
  left_join(short_i_receipt_diseases_All_ContEnr_pts) %>%
  group_by(diseases_code) %>% count()

# ---------------------------------------------------------
# Stocks / Flows diagram CM and PN Vyndaqel patient funnel NEW RULES ------------------------------------------
tekiyo_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/tekiyo_All_ContEnr_pts.txt", colClasses = "character")
ContinuouslyEnrolled_Y3_tekiyo_weights <- fread("All_Pts_ContinuousEnrolled/ContinuouslyEnrolled_Y3_tekiyo_weights.txt", colClasses = "character")
tekiyo_All_ContEnr_pts <- tekiyo_All_ContEnr_pts %>% left_join(ContinuouslyEnrolled_Y3_tekiyo_weights %>% select(kojin_id, weight)) %>% select(kojin_id, weight)
sum(as.numeric(tekiyo_All_ContEnr_pts$weight)) # 

Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")
Vyndaqel_pats_CM_vs_PN <- Vyndaqel_pats_CM_vs_PN %>% select(kojin_id) 

# Is LAST 3 YEARS
short_i_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_i_receipt_diseases_utagai_All_ContEnr_pts.txt", 
                                         colClasses = "character")
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym<="2021/03")
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym>="2018/04")

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(utagai_flg==0) %>% select(-utagai_flg)


short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()
# short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(diseases_code != "4281005" & diseases_code != "5140016" & diseases_code != "4281010")
ATTR_SpecificCode <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(diseases_code=="8850066") %>% select(kojin_id) %>% distinct()


m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code) %>% distinct()

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I50",icd10_code)|grepl("I42",icd10_code)|grepl("I43",icd10_code))




# Es LAST 3 YEARS
short_e_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_e_receipt_diseases_utagai_All_ContEnr_pts.txt", 
                                         colClasses = "character")
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym<="2021/03")
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym>="2018/04")

short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(utagai_flg==0) %>% select(-utagai_flg)

short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()


m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code) %>% distinct()

short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code))



# HEART FAILURE LAST 3 YEARS
short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I50",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  anti_join(short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I42",icd10_code)|grepl("I43",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
  left_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight)))  # 68803.62

# HEART FAILURE LAST 3 YEARS & AMYLOIDOSIS & CARDIOMYOPATHY
short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
    inner_join(short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I42",icd10_code)|grepl("I43",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
    anti_join(short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
  inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 


# HEART FAILURE LAST 3 YEARS & AMYLOIDOSIS & CARDIOMYOPATHY & CARDIOMYOPATHY DUE TO AMYLOIDOSIS
short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  inner_join(ATTR_SpecificCode) %>%
  anti_join(Vyndaqel_pats_CM_vs_PN) %>%
  inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 

short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  anti_join(ATTR_SpecificCode) %>%
    anti_join(Vyndaqel_pats_CM_vs_PN) %>%
  inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 







# Is LAST -3 -2 YEARS
short_i_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_i_receipt_diseases_utagai_All_ContEnr_pts.txt", 
                                         colClasses = "character")
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym<="2020/03")
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym>="2018/04")

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(utagai_flg==0) %>% select(-utagai_flg)


short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()
# short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(diseases_code != "4281005" & diseases_code != "5140016" & diseases_code != "4281010")
ATTR_SpecificCode <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(diseases_code=="8850066") %>% select(kojin_id) %>% distinct()


m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code) %>% distinct()

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I50",icd10_code)|grepl("I42",icd10_code)|grepl("I43",icd10_code))




# Es LAST -3 -2 YEARS
short_e_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_e_receipt_diseases_utagai_All_ContEnr_pts.txt", 
                                         colClasses = "character")
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym<="2020/03")
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym>="2018/04")

short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(utagai_flg==0) %>% select(-utagai_flg)

short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()


m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code) %>% distinct()

short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code))



# HEART FAILURE LAST -3 -2 YEARS
short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I50",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  anti_join(short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I42",icd10_code)|grepl("I43",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
      anti_join(short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
  left_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight)))  # 

short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I42",icd10_code)|grepl("I43",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
      anti_join(short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
      anti_join(Vyndaqel_pats_CM_vs_PN) %>%
  left_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight)))  # 


# HEART FAILURE LAST -3 -2 YEARS & AMYLOIDOSIS & CARDIOMYOPATHY
short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
    inner_join(short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I42",icd10_code)|grepl("I43",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
    anti_join(short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
  inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) #  


# HEART FAILURE LAST -3 -2 YEARS & AMYLOIDOSIS & CARDIOMYOPATHY & CARDIOMYOPATHY DUE TO AMYLOIDOSIS
short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  inner_join(ATTR_SpecificCode) %>%
  anti_join(Vyndaqel_pats_CM_vs_PN) %>%
  inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 

short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  anti_join(ATTR_SpecificCode) %>%
    anti_join(Vyndaqel_pats_CM_vs_PN) %>%
  inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 












receipt_drug_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_drug_Vyndaqel195pts.txt", colClasses = "character")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts[,.(kojin_id, receipt_ym, drug_code)]
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% filter(drug_code=="622278901")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% select(-c(drug_code))
Exact_Month_Lookup <- receipt_drug_Vyndaqel195pts %>% select(receipt_ym) %>% distinct() %>% arrange(receipt_ym) %>%
  mutate(Exact_Month=row_number())
names(Exact_Month_Lookup)[2] <- "Month"

GapFillVyndael <- fread("VyndaqelPts195/GapFill_Vyndaqel.csv", sep=",")
GapFillVyndael <- gather(GapFillVyndael, Month, Treat, 2:88, factor_key=TRUE)
GapFillVyndael$Month <- as.numeric(GapFillVyndael$Month)
GapFillVyndael <- GapFillVyndael %>% left_join(Exact_Month_Lookup)
GapFillVyndael$kojin_id <- as.character(GapFillVyndael$kojin_id)


Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")
Vyndaqel_pats_CM_vs_PN <- Vyndaqel_pats_CM_vs_PN %>% select(kojin_id, PN, CM, Combo)

VyndaqelPts195 <- fread("VyndaqelPts195/tekiyo_Vyndaqel195pts.txt", colClasses = "character")
VyndaqelPts195 <- VyndaqelPts195 %>% select(kojin_id, birth_ym, sex_code)
VyndaqelPts195[, gender:= ifelse(sex_code == 1, "M","F")]
VyndaqelPts195 <- VyndaqelPts195 %>% select(-sex_code)
VyndaqelPts195$birth_ym <- as.Date(paste0(as.character(VyndaqelPts195$birth_ym), '/01'))
VyndaqelPts195$age <- round(time_length(interval(VyndaqelPts195$birth_ym, ymd("2021-08-01")), "year"))
VyndaqelPts195 <- VyndaqelPts195 %>% select(-birth_ym)
VyndaqelPts195 <- VyndaqelPts195 %>% left_join(Vyndaqel_pats_CM_vs_PN)
VyndaqelPts195 <- VyndaqelPts195 %>% mutate(age=ifelse(age>=95,95,age))
VyndaqelPts195$age <- as.character(VyndaqelPts195$age)
VyndaqelPts195 <- VyndaqelPts195  %>% left_join(ContinuouslyEnrolled_Y3_tekiyo_weights %>% select(age, gender, weight) %>% distinct())
VyndaqelPts195 <- VyndaqelPts195 %>% select(kojin_id, weight)
sum(as.numeric(VyndaqelPts195$weight))

GapFillVyndael %>%  filter(Treat==1) %>% select(kojin_id) %>% distinct() %>%
  inner_join(Vyndaqel_pats_CM_vs_PN %>% filter(CM==1|Combo==1) %>% select(kojin_id)) %>% 
  inner_join(VyndaqelPts195) %>% 
  inner_join(ContinuouslyEnrolled_Y3_tekiyo_weights %>% select(kojin_id)) %>% summarise(n=sum(as.numeric(weight)))  # 
  
  
  anti_join(GapFillVyndael %>% filter(receipt_ym<="2020/03" & receipt_ym>="2018/04") %>% filter(Treat==1) %>% select(kojin_id) %>% distinct()) %>%
   left_join(VyndaqelPts195) %>% summarise(n=sum(as.numeric(weight)))  # 




GapFillVyndael %>% filter(receipt_ym=="2021/03") %>% filter(Treat==1) %>% select(kojin_id) %>% distinct() %>%
  inner_join(Vyndaqel_pats_CM_vs_PN %>% filter(CM==1|Combo==1) %>% select(kojin_id)) %>% 
  inner_join(VyndaqelPts195) %>%  #  summarise(n=sum(as.numeric(weight)))
  inner_join(ContinuouslyEnrolled_Y3_tekiyo_weights %>% select(kojin_id)) %>% summarise(n=sum(as.numeric(weight)))
















# POLYNEUROPATHY

tekiyo_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/tekiyo_All_ContEnr_pts.txt", colClasses = "character")
ContinuouslyEnrolled_Y3_tekiyo_weights <- fread("All_Pts_ContinuousEnrolled/ContinuouslyEnrolled_Y3_tekiyo_weights.txt", colClasses = "character")
tekiyo_All_ContEnr_pts <- tekiyo_All_ContEnr_pts %>% left_join(ContinuouslyEnrolled_Y3_tekiyo_weights %>% select(kojin_id, weight)) %>% select(kojin_id, weight)
sum(as.numeric(tekiyo_All_ContEnr_pts$weight)) # 

Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")
Vyndaqel_pats_CM_vs_PN <- Vyndaqel_pats_CM_vs_PN %>% select(kojin_id) 
Vyndaqel_pats_CM_vs_PN %>% inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) #  cont. enroll.



# Is LAST 3 YEARS
short_i_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_i_receipt_diseases_utagai_All_ContEnr_pts.txt", 
                                         colClasses = "character")

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(utagai_flg==0) %>% select(-utagai_flg)

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()
m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code) %>% distinct()

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% 
  filter(grepl("I50",icd10_code)|grepl("I42",icd10_code)|grepl("I43",icd10_code)) %>% select(kojin_id) %>% distinct()


# Gs LAST 3 YEARS
short_g_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_g_receipt_diseases_utagai_All_ContEnr_pts.txt", 
                                         colClasses = "character")

short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% filter(utagai_flg==0) %>% select(-utagai_flg)


short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym<="2021/03")
short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym>="2018/04")

short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()
m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code) %>% distinct()

short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% filter(grepl("G6",icd10_code))



# Es LAST 3 YEARS
short_e_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_e_receipt_diseases_utagai_All_ContEnr_pts.txt", 
                                         colClasses = "character")

short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(utagai_flg==0) %>% select(-utagai_flg)


short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym<="2021/03")
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym>="2018/04")
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()
m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code) %>% distinct()

short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code))





# POLYNEUROPATHY LAST 3 YEARS
short_g_receipt_diseases_All_ContEnr_pts %>% filter(grepl("G6",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  anti_join(short_i_receipt_diseases_All_ContEnr_pts) %>%
  left_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 

# POLYNEUROPATHY LAST 3 YEARS & AMYLOIDOSIS POLYNEUROPATHY
short_g_receipt_diseases_All_ContEnr_pts %>% filter(grepl("G6",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
    anti_join(short_i_receipt_diseases_All_ContEnr_pts) %>%
  inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
  inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 


# POLYNEUROPATHY LAST 3 YEARS & AMYLOIDOSIS & POLYNEUROPATHY DUE TO AMYLOIDOSIS
short_g_receipt_diseases_All_ContEnr_pts %>% filter(grepl("G6",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
    anti_join(short_i_receipt_diseases_All_ContEnr_pts) %>%
  inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
    inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E851",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
  inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 

# POLYNEUROPATHY LAST 3 YEARS & AMYLOIDOSIS & POLYNEUROPATHY DUE TO AMYLOIDOSIS
# short_g_receipt_diseases_All_ContEnr_pts %>% filter(grepl("G6",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
#     anti_join(short_i_receipt_diseases_All_ContEnr_pts) %>%
#   inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
#     inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E851",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
#     inner_join(Vyndaqel_pats_CM_vs_PN) %>%
#   inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) 

# TargetPN_patients <- short_g_receipt_diseases_All_ContEnr_pts %>% filter(grepl("G6",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
#     anti_join(short_i_receipt_diseases_All_ContEnr_pts) %>%
#   inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
#     inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E851",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
#   inner_join(tekiyo_All_ContEnr_pts) 





# Is YEARS -3 and -2
short_i_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_i_receipt_diseases_utagai_All_ContEnr_pts.txt", 
                                         colClasses = "character")

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(utagai_flg==0) %>% select(-utagai_flg)

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()
m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code) %>% distinct()

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% 
  filter(grepl("I50",icd10_code)|grepl("I42",icd10_code)|grepl("I43",icd10_code)) %>% select(kojin_id) %>% distinct()


# Gs YEARS -3 and -2

short_g_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_g_receipt_diseases_utagai_All_ContEnr_pts.txt", 
                                         colClasses = "character")

short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% filter(utagai_flg==0) %>% select(-utagai_flg)


short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym<="2020/03")
short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym>="2018/04")

short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()
m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code) %>% distinct()

short_g_receipt_diseases_All_ContEnr_pts <- short_g_receipt_diseases_All_ContEnr_pts %>% filter(grepl("G6",icd10_code))



# Es YEARS -3 and -2
short_e_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_e_receipt_diseases_utagai_All_ContEnr_pts.txt", 
                                         colClasses = "character")

short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(utagai_flg==0) %>% select(-utagai_flg)


short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym<="2020/03")
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym>="2018/04")
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()
m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code) %>% distinct()

short_e_receipt_diseases_All_ContEnr_pts <- short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code))






# POLYNEUROPATHY YEARS -3 and -2
short_g_receipt_diseases_All_ContEnr_pts %>% filter(grepl("G6",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  anti_join(short_i_receipt_diseases_All_ContEnr_pts) %>%
  left_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) #

# POLYNEUROPATHY YEARS -3 and -2 & AMYLOIDOSIS POLYNEUROPATHY
short_g_receipt_diseases_All_ContEnr_pts %>% filter(grepl("G6",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
    anti_join(short_i_receipt_diseases_All_ContEnr_pts) %>%
  inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
  inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 

# POLYNEUROPATHY YEARS -3 and -2 & AMYLOIDOSIS & POLYNEUROPATHY DUE TO AMYLOIDOSIS
short_g_receipt_diseases_All_ContEnr_pts %>% filter(grepl("G6",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
   anti_join(short_i_receipt_diseases_All_ContEnr_pts) %>%
  inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
    inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E851",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
  inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 

# POLYNEUROPATHYYEARS -3 and -2 & AMYLOIDOSIS & POLYNEUROPATHY DUE TO AMYLOIDOSIS + Vyndaqel
# short_g_receipt_diseases_All_ContEnr_pts %>% filter(grepl("G6",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
#    anti_join(short_i_receipt_diseases_All_ContEnr_pts) %>%
#   inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E85",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
#     inner_join(short_e_receipt_diseases_All_ContEnr_pts %>% filter(grepl("E851",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
#     inner_join(Vyndaqel_pats_CM_vs_PN) %>% 
#   inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) 





receipt_drug_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_drug_Vyndaqel195pts.txt", colClasses = "character")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts[,.(kojin_id, receipt_ym, drug_code)]
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% filter(drug_code=="622278901")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% select(-c(drug_code))
Exact_Month_Lookup <- receipt_drug_Vyndaqel195pts %>% select(receipt_ym) %>% distinct() %>% arrange(receipt_ym) %>%
  mutate(Exact_Month=row_number())
names(Exact_Month_Lookup)[2] <- "Month"

GapFillVyndael <- fread("VyndaqelPts195/GapFill_Vyndaqel.csv", sep=",")
GapFillVyndael <- gather(GapFillVyndael, Month, Treat, 2:88, factor_key=TRUE)
GapFillVyndael$Month <- as.numeric(GapFillVyndael$Month)
GapFillVyndael <- GapFillVyndael %>% left_join(Exact_Month_Lookup)
GapFillVyndael$kojin_id <- as.character(GapFillVyndael$kojin_id)


Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")
Vyndaqel_pats_CM_vs_PN <- Vyndaqel_pats_CM_vs_PN %>% select(kojin_id, PN, CM, Combo)

VyndaqelPts195 <- fread("VyndaqelPts195/tekiyo_Vyndaqel195pts.txt", colClasses = "character")
VyndaqelPts195 <- VyndaqelPts195 %>% select(kojin_id, birth_ym, sex_code)
VyndaqelPts195[, gender:= ifelse(sex_code == 1, "M","F")]
VyndaqelPts195 <- VyndaqelPts195 %>% select(-sex_code)
VyndaqelPts195$birth_ym <- as.Date(paste0(as.character(VyndaqelPts195$birth_ym), '/01'))
VyndaqelPts195$age <- round(time_length(interval(VyndaqelPts195$birth_ym, ymd("2021-08-01")), "year"))
VyndaqelPts195 <- VyndaqelPts195 %>% select(-birth_ym)
VyndaqelPts195 <- VyndaqelPts195 %>% left_join(Vyndaqel_pats_CM_vs_PN)
VyndaqelPts195 <- VyndaqelPts195 %>% mutate(age=ifelse(age>=95,95,age))
VyndaqelPts195$age <- as.character(VyndaqelPts195$age)
VyndaqelPts195 <- VyndaqelPts195  %>% left_join(ContinuouslyEnrolled_Y3_tekiyo_weights %>% select(age, gender, weight) %>% distinct())
VyndaqelPts195 <- VyndaqelPts195 %>% select(kojin_id, weight)
sum(as.numeric(VyndaqelPts195$weight))

GapFillVyndael %>% filter(receipt_ym<="2021/03" & receipt_ym>="2018/04") %>% filter(Treat==1) %>% select(kojin_id) %>% distinct() %>%
  inner_join(Vyndaqel_pats_CM_vs_PN %>% filter(PN==1) %>% select(kojin_id)) %>% 
  inner_join(VyndaqelPts195) %>% summarise(n=sum(as.numeric(weight))) %>% # 1525.761
  anti_join(GapFillVyndael %>% filter(receipt_ym<="2020/03" & receipt_ym>="2018/04") %>% filter(Treat==1) %>% select(kojin_id) %>% distinct()) %>%
   left_join(VyndaqelPts195) %>% summarise(n=sum(as.numeric(weight)))  # 845.0034


# ----------------------------
# Proportion of Vyndaqel patient swith specific Dx with Biopsy/Scintigrapy -------------------

                                         colClasses = "character")

Vyndaqel_8850066 <- receipt_diseases_Vyndaqel195pts %>% filter(diseases_code=="8850066") %>% select(kojin_id) %>% distinct()

ALL_Vyndaqel <- receipt_diseases_Vyndaqel195pts %>% select(kojin_id) %>% distinct()



receipt_medical_practice_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_medical_practice_Vyndaqel195pts.txt", colClasses = "character")
receipt_medical_practice_Vyndaqel195pts <- receipt_medical_practice_Vyndaqel195pts[,.(receipt_ym, kojin_id, medical_practice_code)]
receipt_medical_practice_Vyndaqel195pts$receipt_ym <- as.Date(paste0(as.character(receipt_medical_practice_Vyndaqel195pts$receipt_ym), '/01'))

Procedure_master <- fread("Masters/Procedure_master.csv", colClasses = "character")


receipt_medical_practice_Vyndaqel195pts <- 
  receipt_medical_practice_Vyndaqel195pts %>% 
  left_join(Procedure_master, 
            by=c("medical_practice_code"="standardized_procedure_code")) %>%
  select(kojin_id, receipt_ym, medical_practice_code, standardized_procedure_name) 
 
# 150k ou of 2.2m, 
# 250 codes out of 40k


receipt_medical_practice_Vyndaqel195pts <- receipt_medical_practice_Vyndaqel195pts %>%
                                              filter(grepl("computerized tomog", standardized_procedure_name)|
                                                     grepl("CT imaging", standardized_procedure_name)|
                                                     grepl("nuclear medicine diagnosis", standardized_procedure_name)|
                                                     grepl("scintigraphy", standardized_procedure_name)|
                                                     grepl("MRI", standardized_procedure_name)|
                                                     grepl("electrocardiog", standardized_procedure_name)|
                                                     grepl("ECG", standardized_procedure_name)|
                                                     grepl("ultrasonography", standardized_procedure_name)|
                                                     grepl("SPECT", standardized_procedure_name)|
                                                     grepl("PET ", standardized_procedure_name)|
                                                     grepl("percutaneous needle biopsy", standardized_procedure_name)|
                                                     grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name)|
                                                     grepl("endoscopic biopsy", standardized_procedure_name)|
                                                     grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name)|
                                                     grepl("brain natriuretic peptide", standardized_procedure_name)|
                                                     grepl("BNP", standardized_procedure_name)|
                                                     grepl("troponin", standardized_procedure_name)|
                                                     grepl("genetic test", standardized_procedure_name)|
                                                     grepl("cardiac catheterization", standardized_procedure_name)|
                                                     grepl("Holter", standardized_procedure_name)|
                                                     grepl("pacemaker", standardized_procedure_name)|
                                                     grepl("gene-related", standardized_procedure_name)|
                                                     grepl("exercise test", standardized_procedure_name)|
                                                     grepl("hospitalization", standardized_procedure_name)|
                                                     grepl("serum amyloid A protein", standardized_procedure_name)|
                                                     grepl("prealbumin", standardized_procedure_name)|
                                                     grepl("transthyretin", standardized_procedure_name)|
                                                     grepl("amylase", standardized_procedure_name))

unique(receipt_medical_practice_Vyndaqel195pts$medical_practice_code)

unique(Procedure_master$standardized_procedure_name[grepl("biopsy", Procedure_master$standardized_procedure_name)])

receipt_medical_practice_Vyndaqel195pts <-
  receipt_medical_practice_Vyndaqel195pts %>% mutate(standardized_procedure_name=
                                                     ifelse(grepl("computerized tomog",standardized_procedure_name), "CT",
                                                            ifelse(grepl("CT imaging,", standardized_procedure_name), "CT",
                                                                   ifelse(grepl("nuclear medicine diagnosis", standardized_procedure_name), "other nuclear medicine",
                                                                          ifelse(grepl("scintigraphy", standardized_procedure_name), "scintigraphy",
                                                                                 ifelse(grepl("MRI", standardized_procedure_name), "MRI",
                                                                                        ifelse(grepl("electrocardiog", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ECG", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ultrasonography", standardized_procedure_name), "ultrasonography",
                                                                                                      ifelse(grepl("SPECT", standardized_procedure_name), "scintigraphy",
                                                                                                             ifelse(grepl("PET ", standardized_procedure_name), "scintigraphy",
                                                                                                      ifelse(grepl("percutaneous needle biopsy", standardized_procedure_name), "biopsy",
                                                                                                             ifelse(grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("endoscopic biopsy", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name), "heart biopsy",
                                                                                                                           ifelse(grepl("brain natriuretic peptide", standardized_procedure_name), "BNP",
                                                                                                                                  ifelse(grepl("BNP", standardized_procedure_name), "BNP",
                                                                                                                                         ifelse(grepl("troponin", standardized_procedure_name), "troponin",
                                                                                                                                                ifelse(grepl("genetic test", standardized_procedure_name), "genetic test",
                                                                                                                                                       ifelse(grepl("cardiac catheterization", standardized_procedure_name), "cardiac catheterization",
                                                                                                                                                              ifelse(grepl("Holter", standardized_procedure_name), "Holter",
                                                                                                                                                                     ifelse(grepl("pacemaker", standardized_procedure_name), "pacemaker",
                                                                                                                                                                            ifelse(grepl("gene-related", standardized_procedure_name), "genetic test",
                                                                                                                                                                                          ifelse(grepl("exercise test", standardized_procedure_name), "exercise test",
                                                                                                                                                                                                 ifelse(grepl("hospitalization", standardized_procedure_name), "hospitalization",
                                                                                                                                                                                                        ifelse(grepl("serum amyloid A protein", standardized_procedure_name), "AmyloidA",
                                                                                                                                                                                                               ifelse(grepl("prealbumin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("transthyretin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("amylase", standardized_procedure_name), "amylase",NA)))))))))))))))))))))))))))))
                                                                   

receipt_medical_practice_Vyndaqel195pts <- receipt_medical_practice_Vyndaqel195pts %>% mutate(standardized_procedure_name=ifelse(is.na(standardized_procedure_name),"CT", standardized_procedure_name))

unique(receipt_medical_practice_Vyndaqel195pts$standardized_procedure_name)

receipt_medical_practice_Vyndaqel195pts <- receipt_medical_practice_Vyndaqel195pts %>% filter(standardized_procedure_name=="biopsy"|standardized_procedure_name=="scintigraphy") %>%
  select(kojin_id, standardized_procedure_name) %>% distinct()

ALL_Vyndaqel %>% anti_join(Vyndaqel_8850066) %>% left_join(receipt_medical_practice_Vyndaqel195pts) %>%
  group_by(standardized_procedure_name) %>% count()


Vyndaqel_8850066 %>% left_join(receipt_medical_practice_Vyndaqel195pts) %>%
  group_by(standardized_procedure_name) %>% count()



# --------------------------------------------------
# Subset continuously enrolled tables for target CM patients NEW RULES ---------------------

Cardiomyopathy_Pats <- fread("Cardiomyopathy_Pats.txt", colClasses = "character")
Cardiac_Amyloidosis_Pats <- fread("Cardiac_Amyloidosis_Pats.txt", colClasses = "character")
ATTR_CM_noVyn_Pats <- fread("ATTR_CM_noVyn_Pats.txt", colClasses = "character")
Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")
ATTR_CM_Vyndaqel_Pats <- Vyndaqel_pats_CM_vs_PN %>%filter(CM==1|Combo==1) %>%  select(kojin_id)

temp <- Cardiomyopathy_Pats %>% 
  full_join(Cardiac_Amyloidosis_Pats) %>% 
  full_join(ATTR_CM_noVyn_Pats) %>% 
  full_join(ATTR_CM_Vyndaqel_Pats)

temp <- temp %>% select(kojin_id) %>% distinct()

pagify <- function(data = NULL, by = 1000){
    pagemin <- seq(1,length(data), by = by)
    pagemax <- pagemin - 1 + by
    pagemax[length(pagemax)] <- length(data)
    pages   <- list(min = pagemin, max = pagemax)
  }
  
pages <- pagify(temp$kojin_id, 17388)

receipt_medical_institution_CM_Targets <- data.table()  

for(i in 1:length(pages$max)) {
    cat(i)
    pts <- paste0(temp$kojin_id[pages$min[i]:pages$max[i]], collapse = "','")
    query <- paste0("SELECT * FROM vyndaqel.receipt_medical_institution  WHERE kojin_id IN ('",pts,"');")
    data  <- setDT(dbGetQuery(con, query))
    receipt_medical_institution_CM_Targets <- rbind(receipt_medical_institution_CM_Targets, data)
}

fwrite(receipt_medical_institution_CM_Targets, "All_Pts_ContinuousEnrolled/receipt_medical_institution_CM_Targets.txt", sep="\t")




short_E_receipt_diseases_facility_CM_Targets <- data.table()  

for(i in 1:length(pages$max)) {
    cat(i)
    start <- Sys.time()
    pts <- paste0(temp$kojin_id[pages$min[i]:pages$max[i]], collapse = "','")
    query <- paste0("SELECT * FROM vyndaqel.short_E_receipt_diseases_facility  WHERE kojin_id IN ('",pts,"');")
    data  <- setDT(dbGetQuery(con, query))
    short_E_receipt_diseases_facility_CM_Targets <- rbind(short_E_receipt_diseases_facility_CM_Targets, data)
    end   <- Sys.time()
    print(end - start)
}

fwrite(short_E_receipt_diseases_facility_CM_Targets, "All_Pts_ContinuousEnrolled/short_E_receipt_diseases_facility_CM_Targets.txt", sep="\t")





short_I_receipt_diseases_facility_CM_Targets <- data.table()  

for(i in 1:length(pages$max)) {
    cat(i)
    start <- Sys.time()
    pts <- paste0(temp$kojin_id[pages$min[i]:pages$max[i]], collapse = "','")
    query <- paste0("SELECT * FROM vyndaqel.short_I_receipt_diseases_facility  WHERE kojin_id IN ('",pts,"');")
    data  <- setDT(dbGetQuery(con, query))
    short_I_receipt_diseases_facility_CM_Targets <- rbind(short_I_receipt_diseases_facility_CM_Targets, data)
    end   <- Sys.time()
    print(end - start)
}

fwrite(short_I_receipt_diseases_facility_CM_Targets, "All_Pts_ContinuousEnrolled/short_I_receipt_diseases_facility_CM_Targets.txt", sep="\t")




short_G_receipt_diseases_facility_CM_Targets <- data.table()  

for(i in 1:length(pages$max)) {
    cat(i)
    start <- Sys.time()
    pts <- paste0(temp$kojin_id[pages$min[i]:pages$max[i]], collapse = "','")
    query <- paste0("SELECT * FROM vyndaqel.short_G_receipt_diseases_facility  WHERE kojin_id IN ('",pts,"');")
    data  <- setDT(dbGetQuery(con, query))
    short_G_receipt_diseases_facility_CM_Targets <- rbind(short_G_receipt_diseases_facility_CM_Targets, data)
    end   <- Sys.time()
    print(end - start)
}

fwrite(short_G_receipt_diseases_facility_CM_Targets, "All_Pts_ContinuousEnrolled/short_G_receipt_diseases_facility_CM_Targets.txt", sep="\t")

# --------------------------
# Facilities seen by TARGET CM patients ---------------------------------

# Receipts IDs of the First Vyndaqel
receipt_drug_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_drug_Vyndaqel195pts.txt", colClasses = "character")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts[,.(receipt_ym, kojin_id, drug_code, receipt_id)]
receipt_drug_Vyndaqel195pts$receipt_ym <- as.Date(paste0(as.character(receipt_drug_Vyndaqel195pts$receipt_ym), '/01'))
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% filter(drug_code=="622278901")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% group_by(kojin_id) %>% filter(receipt_ym==min(receipt_ym))

# Facilities associated with that Vyndaqel receipt
receipt_medical_institution_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_medical_institution_Vyndaqel195pts.txt", colClasses = "character")
receipt_medical_institution_Vyndaqel195pts <- receipt_medical_institution_Vyndaqel195pts %>% select(kojin_id, receipt_ym, iryokikan_no, receipt_id)
receipt_medical_institution_Vyndaqel195pts$receipt_ym  <- as.Date(paste0(as.character(receipt_medical_institution_Vyndaqel195pts$receipt_ym ), '/01'))

temp <- receipt_drug_Vyndaqel195pts %>% 
  left_join(receipt_medical_institution_Vyndaqel195pts,
            by=c("kojin_id"="kojin_id", "receipt_id"="receipt_id", "receipt_ym"="receipt_ym")) 

length(unique(temp$kojin_id)) # 195
length(unique(temp$iryokikan_no)) # # 53

Vyndaqel_Facilities <- unique(temp$iryokikan_no)
Vyndaqel_Facilities <- as.data.frame(Vyndaqel_Facilities)
names(Vyndaqel_Facilities)[1] <- "iryokikan_no"

Cardiomyopathy_Pats <- fread("Cardiomyopathy_Pats.txt", colClasses = "character")
Cardiac_Amyloidosis_Pats <- fread("Cardiac_Amyloidosis_Pats.txt", colClasses = "character")
Cardiac_Amyloidosis_Pats <- Cardiac_Amyloidosis_Pats %>% select(1)
ATTR_CM_noVyn_Pats <- fread("ATTR_CM_noVyn_Pats.txt", colClasses = "character")
Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")
ATTR_CM_Vyndaqel_Pats <- Vyndaqel_pats_CM_vs_PN %>%filter(CM==1|Combo==1) %>%  select(kojin_id)


Cardiomyopathy_Pats$Group <- "Cardiomiopathy"
Cardiac_Amyloidosis_Pats$Group <-  "CardiacAMyloidosis"
ATTR_CM_noVyn_Pats$Group <- "ATTRCM_noVyn"

Target_CM_Pats <- Cardiomyopathy_Pats %>% bind_rows(Cardiac_Amyloidosis_Pats, ATTR_CM_noVyn_Pats)

receipt_medical_institution_CM_Targets <- fread("All_Pts_ContinuousEnrolled/receipt_medical_institution_CM_Targets.txt", sep="\t", colClasses = "character")

receipt_medical_institution_CM_Targets <- receipt_medical_institution_CM_Targets %>% select(kojin_id, iryokikan_no, receipt_id) %>% distinct()

receipt_medical_institution_CM_Targets <- Target_CM_Pats %>% left_join(receipt_medical_institution_CM_Targets)

length(
  unique(
    receipt_medical_institution_CM_Targets$kojin_id[receipt_medical_institution_CM_Targets$Group=="Cardiomiopathy"]
    )
  ) # 

length(
  unique(
    receipt_medical_institution_CM_Targets$kojin_id[receipt_medical_institution_CM_Targets$Group=="CardiacAMyloidosis"]
    )
  ) # 

length(
  unique(
    receipt_medical_institution_CM_Targets$kojin_id[receipt_medical_institution_CM_Targets$Group=="ATTRCM_noVyn"]
    )
  ) # 




# Vyndaqel Faiclities Only 

receipt_medical_institution_CM_Targets <- receipt_medical_institution_CM_Targets %>% inner_join(Vyndaqel_Facilities)

length(unique(receipt_medical_institution_CM_Targets$iryokikan_no)) # 

length(
  unique(
    receipt_medical_institution_CM_Targets$kojin_id[receipt_medical_institution_CM_Targets$Group=="Cardiomiopathy"]
    )
  ) # 

length(
  unique(
    receipt_medical_institution_CM_Targets$kojin_id[receipt_medical_institution_CM_Targets$Group=="CardiacAMyloidosis"]
    )
  ) # 

length(
  unique(
    receipt_medical_institution_CM_Targets$kojin_id[receipt_medical_institution_CM_Targets$Group=="ATTRCM_noVyn"]
    )
  ) # 

short_E_receipt_diseases_facility_CM_Targets <- fread("All_Pts_ContinuousEnrolled/short_E_receipt_diseases_facility_CM_Targets.txt", sep="\t", colClasses = "character")
short_I_receipt_diseases_facility_CM_Targets <- fread("All_Pts_ContinuousEnrolled/short_I_receipt_diseases_facility_CM_Targets.txt", sep="\t", colClasses = "character")

short_E_receipt_diseases_facility_CM_Targets <- short_E_receipt_diseases_facility_CM_Targets[short_E_receipt_diseases_facility_CM_Targets$utagai_flg==1]
short_I_receipt_diseases_facility_CM_Targets <- short_I_receipt_diseases_facility_CM_Targets[short_I_receipt_diseases_facility_CM_Targets$utagai_flg==1]

short_I_receipt_diseases_facility_CM_Targets %>% filter(diseases_code=="8850066") %>% select(kojin_id, receipt_id) %>% distinct() %>%
  inner_join(receipt_medical_institution_CM_Targets) %>%
  filter(Group=="ATTRCM_noVyn") %>% select(kojin_id) %>% distinct() # 

m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)

short_I_receipt_diseases_facility_CM_Targets %>% 
  left_join(m_icd10) %>% filter(icd10_code=="I431") %>% select(kojin_id, receipt_id) %>% distinct() %>%
  inner_join(receipt_medical_institution_CM_Targets) %>%
  filter(Group=="CardiacAMyloidosis") %>% select(kojin_id) %>% distinct() #


short_I_receipt_diseases_facility_CM_Targets %>% 
  left_join(m_icd10) %>% filter(grepl("I43",icd10_code)|grepl("I42",icd10_code)) %>% select(kojin_id, receipt_id) %>% distinct() %>%
  inner_join(receipt_medical_institution_CM_Targets) %>%
  filter(Group=="Cardiomiopathy") %>% select(kojin_id) %>% distinct() # 

# -------------------------------------------------------------------
# Vyndaqel faiclities seeng X # of ATTR CM, Cardiac Amyloidosis, etc -------------------------------

Vyndaqel_Facilities

receipt_medical_institution_CM_Targets <- fread("All_Pts_ContinuousEnrolled/receipt_medical_institution_CM_Targets.txt", sep="\t", colClasses = "character")
receipt_medical_institution_CM_Targets <- receipt_medical_institution_CM_Targets %>% select(kojin_id, iryokikan_no, receipt_id) %>% distinct()


short_I_receipt_diseases_facility_CM_Targets <- 
  fread("All_Pts_ContinuousEnrolled/short_I_receipt_diseases_facility_CM_Targets.txt", sep="\t", colClasses = "character")

short_I_receipt_diseases_facility_CM_Targets <- 
  short_I_receipt_diseases_facility_CM_Targets[short_I_receipt_diseases_facility_CM_Targets$utagai_flg==1]

short_I_receipt_diseases_facility_CM_Targets %>% left_join(receipt_medical_institution_CM_Targets) %>%
  filter(diseases_code=="8850066") %>% select(iryokikan_no) %>% distinct() %>% mutate(ATTR_CM=1)


short_I_receipt_diseases_facility_CM_Targets %>% left_join(receipt_medical_institution_CM_Targets) %>%
  left_join(m_icd10) %>% filter(icd10_code=="I431")  %>% 
  select(iryokikan_no) %>% distinct() %>% mutate(Cardiac_Amyloidosis=1)


short_I_receipt_diseases_facility_CM_Targets %>% left_join(receipt_medical_institution_CM_Targets) %>%
  left_join(m_icd10) %>% filter(grepl("I43",icd10_code)|grepl("I42",icd10_code))  %>% 
  select(iryokikan_no) %>% distinct() %>% mutate(Cardiac_Amyloidosis=1)


temp <- Vyndaqel_Facilities %>% 
  left_join(
  short_I_receipt_diseases_facility_CM_Targets %>% left_join(receipt_medical_institution_CM_Targets) %>%
  filter(diseases_code=="8850066") %>% select(iryokikan_no, kojin_id) %>% distinct() %>% group_by(iryokikan_no) %>% count() %>% rename("ATTR_CM"="n")
) %>% 
  left_join(
  short_I_receipt_diseases_facility_CM_Targets %>% left_join(receipt_medical_institution_CM_Targets) %>%
  left_join(m_icd10) %>% filter(icd10_code=="I431")  %>% 
  select(iryokikan_no, kojin_id) %>% distinct() %>% group_by(iryokikan_no) %>% count() %>% rename("Cardiac_Amyloidosis"="n")
) %>% 
  left_join(
  short_I_receipt_diseases_facility_CM_Targets %>% left_join(receipt_medical_institution_CM_Targets) %>%
  left_join(m_icd10) %>% filter(grepl("I43",icd10_code)|grepl("I42",icd10_code))  %>% 
  select(iryokikan_no, kojin_id) %>% distinct() %>% group_by(iryokikan_no) %>% count() %>% rename("Cardiomiopathy"="n")
)

temp[is.na(temp)] <- 0

data.frame(temp %>% group_by(iryokikan_no ) %>% summarise(n=sum(ATTR_CM)) %>% arrange(-n))
data.frame(temp %>% group_by(iryokikan_no ) %>% summarise(n=sum(Cardiac_Amyloidosis)) %>% arrange(-n))
data.frame(temp %>% group_by(iryokikan_no ) %>% summarise(n=sum(Cardiomiopathy)) %>% arrange(-n))

# -----------------------------------------------------------------------------

# Forecast population ON Vyndaqel --------------------------------------------------

library(readr)
library(ggplot2)
library(forecast)
library(TTR)
library(dplyr)

ForecastingVYN <- fread("ForecastingVYN.txt")
ForecastingVYN$date <- as.Date(paste0(as.character(ForecastingVYN$date), '/01'))
ForecastingVYN$CM <- ForecastingVYN$Combo + ForecastingVYN$CM
ForecastingVYN <- ForecastingVYN[71:82,c(1,3)]

dat_ts  <- ts(ForecastingVYN[, 2], start = c(2020, 04), end = c(2021, 03), frequency = 12)

# holt ses  naive
holt_model  <- holt(dat_ts, h = 24)
summary(holt_model)

ses_model  <- ses(dat_ts, h = 12)
summary(ses_model)

naive_model  <- naive(dat_ts, h = 12)
summary(naive_model)


arima_model <- auto.arima(dat_ts)
summary(arima_model)
forecast::forecast(arima_model, h=12)

model_tbats <- tbats(dat_ts)
summary(model_tbats)
forecast::forecast(model_tbats, h = 12)

# ---------------------
# Time between each subsequent Dx ----------------------------------------------------

Cardiomyopathy_Pats <- fread("Cardiomyopathy_Pats.txt", colClasses = "character")
Cardiac_Amyloidosis_Pats <- fread("Cardiac_Amyloidosis_Pats.txt", colClasses = "character")
Cardiac_Amyloidosis_Pats <- Cardiac_Amyloidosis_Pats[,1]
ATTR_CM_noVyn_Pats <- fread("ATTR_CM_noVyn_Pats.txt", colClasses = "character")
Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")
ATTR_CM_Vyndaqel_Pats <- Vyndaqel_pats_CM_vs_PN %>%filter(CM==1|Combo==1) %>%  select(kojin_id)



short_i_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_i_receipt_diseases_utagai_All_ContEnr_pts.txt", colClasses = "character")
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(utagai_flg==0) %>% select(-utagai_flg)
short_i_receipt_diseases_All_ContEnr_pts <- Cardiac_Amyloidosis_Pats %>% inner_join(short_i_receipt_diseases_All_ContEnr_pts)

m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% left_join(m_icd10) %>% select(kojin_id, receipt_ym, icd10_code) %>% distinct()
short_i_receipt_diseases_All_ContEnr_pts$receipt_ym <- as.Date(paste0(as.character(short_i_receipt_diseases_All_ContEnr_pts$receipt_ym), '/01'))


Cardiac_Amyloidosis_Pats %>% left_join(short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I43",icd10_code)|grepl("I42",icd10_code))) %>%
  group_by(kojin_id) %>% filter(receipt_ym==min(receipt_ym)) %>% slice(1) %>% select(-icd10_code) %>% rename("FirstCardiomiopathy"="receipt_ym") %>%
  left_join(
Cardiac_Amyloidosis_Pats %>% left_join(short_i_receipt_diseases_All_ContEnr_pts %>% filter(icd10_code=="I431")) %>%
  group_by(kojin_id) %>% filter(receipt_ym==min(receipt_ym)) %>% slice(1)  %>% select(-icd10_code) %>% rename("FirstI431"="receipt_ym")
  ) %>%
  mutate(Diff=FirstI431 - FirstCardiomiopathy  ) %>%  
  ungroup() %>% summarise(n=mean(Diff)) # 



short_i_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_i_receipt_diseases_utagai_All_ContEnr_pts.txt", colClasses = "character")
short_i_receipt_diseases_All_ContEnr_pts <- ATTR_CM_noVyn_Pats %>% inner_join(short_i_receipt_diseases_All_ContEnr_pts)
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(utagai_flg==0) %>% select(-utagai_flg)

m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% left_join(m_icd10) %>% select(kojin_id, receipt_ym, diseases_code, icd10_code) %>% distinct()
short_i_receipt_diseases_All_ContEnr_pts$receipt_ym <- as.Date(paste0(as.character(short_i_receipt_diseases_All_ContEnr_pts$receipt_ym), '/01'))


ATTR_CM_noVyn_Pats %>% left_join(short_i_receipt_diseases_All_ContEnr_pts %>% filter(icd10_code=="I431")) %>%
  group_by(kojin_id) %>% filter(receipt_ym==min(receipt_ym)) %>% slice(1) %>% select(-icd10_code) %>% rename("FirstI431"="receipt_ym") %>%
  left_join(
ATTR_CM_noVyn_Pats %>% left_join(short_i_receipt_diseases_All_ContEnr_pts %>% filter(diseases_code=="8850066")) %>%
  group_by(kojin_id) %>% filter(receipt_ym==min(receipt_ym)) %>% slice(1)  %>% select(-icd10_code) %>% rename("FirstATTRSpec"="receipt_ym")
  ) %>%
  drop_na() %>%
  mutate(Diff=FirstATTRSpec - FirstI431) %>%  
  ungroup() %>% summarise(n=mean(Diff)) # 0 days


receipt_diseases_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_diseases_Vyndaqel195pts.txt", 
                                         colClasses = "character")

receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>% 
  filter(diseases_code=="8850066") %>% select(kojin_id, receipt_ym, sinryo_start_ymd) %>% distinct()

Earliest_Cardiac_Amyloidosis <- receipt_diseases_Vyndaqel195pts %>% group_by(kojin_id) %>% 
  filter(receipt_ym==min(receipt_ym))  %>% select(kojin_id, receipt_ym) %>% distinct() %>%
  full_join(receipt_diseases_Vyndaqel195pts %>% group_by(kojin_id) %>% 
  filter(sinryo_start_ymd==min(sinryo_start_ymd))  %>% select(kojin_id, sinryo_start_ymd) %>% distinct())

Earliest_Cardiac_Amyloidosis$receipt_ym <- as.Date(paste0(as.character(Earliest_Cardiac_Amyloidosis$receipt_ym), '/01'))
names(Earliest_Cardiac_Amyloidosis)[2] <- "First_CardiacAmyloidosis"

receipt_drug_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_drug_Vyndaqel195pts.txt", colClasses = "character")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts[,.(receipt_ym, kojin_id, drug_code)]
receipt_drug_Vyndaqel195pts$receipt_ym <- as.Date(paste0(as.character(receipt_drug_Vyndaqel195pts$receipt_ym), '/01'))

temp <- receipt_drug_Vyndaqel195pts %>% filter(drug_code=="622278901") %>% 
  group_by(kojin_id) %>% filter(receipt_ym==min(receipt_ym)) %>% distinct() %>% 
  select(-drug_code) %>%
  left_join(Earliest_Cardiac_Amyloidosis) 
  
temp %>% mutate(ElapsedTime=as.numeric(First_CardiacAmyloidosis -receipt_ym)) %>% 
    ungroup() %>% summarise(n=mean(ElapsedTime, na.rm=T)) # 118 days 

temp %>% mutate(ElapsedTime=as.numeric(First_CardiacAmyloidosis -receipt_ym)) %>% 
    ungroup()  %>% drop_na() %>% filter(ElapsedTime >=0) %>%  filter(ElapsedTime<=61)

receipt_diseases_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_diseases_Vyndaqel195pts.txt", 
                                         colClasses = "character")
receipt_diseases_Vyndaqel195pts$receipt_ym <- as.Date(paste0(as.character(receipt_diseases_Vyndaqel195pts$receipt_ym), '/01'))

receipt_diseases_Vyndaqel195pts %>% 
  filter(diseases_code=="8850066") %>% select(kojin_id, receipt_ym) %>% 
  group_by(kojin_id) %>% 
  filter(receipt_ym==min(receipt_ym)) %>% distinct() %>%
  rename("First_ATTRSpec"="receipt_ym") %>%
  left_join(
    receipt_diseases_Vyndaqel195pts %>% 
    filter(diseases_code=="8850066"|diseases_code=="8846224"|diseases_code=="8836892"|diseases_code=="8834886") %>% select(kojin_id, receipt_ym) %>% 
    group_by(kojin_id) %>% 
    filter(receipt_ym==min(receipt_ym)) %>% distinct() %>%
    rename("First_I431"="receipt_ym")
  ) %>%
  ungroup() %>%
  mutate(Diff=First_ATTRSpec - First_I431) %>%  
  ungroup() %>% summarise(n=mean(Diff)) 
  


# -------------------
# I42 and I43 codes used --------------------------------------

m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code, icd10_name_en)
m_icd10 <- m_icd10 %>% filter(grepl("I42",icd10_code )|grepl("I43", icd10_code))

Diagnosis_master <- fread("Masters/Diagnosis_master.csv", colClasses = "character")
Diagnosis_master <- Diagnosis_master[,.(standard_disease_code, standard_disease_name)]
names(Diagnosis_master)[1] <- "diseases_code"

m_icd10 <- m_icd10 %>% left_join(Diagnosis_master)
# -----------------------------

# Heart Failure patients ---------------------------------------
tekiyo_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/tekiyo_All_ContEnr_pts.txt", colClasses = "character")
ContinuouslyEnrolled_Y3_tekiyo_weights <- fread("All_Pts_ContinuousEnrolled/ContinuouslyEnrolled_Y3_tekiyo_weights.txt", colClasses = "character")
tekiyo_All_ContEnr_pts <- tekiyo_All_ContEnr_pts %>% left_join(ContinuouslyEnrolled_Y3_tekiyo_weights %>% select(kojin_id, weight)) %>% select(kojin_id, weight)
sum(as.numeric(tekiyo_All_ContEnr_pts$weight)) # 26009563

Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")
Vyndaqel_pats_CM_vs_PN <- Vyndaqel_pats_CM_vs_PN %>% select(kojin_id) 

# Is LAST 3 YEARS
short_i_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_i_receipt_diseases_utagai_All_ContEnr_pts.txt", 
                                         colClasses = "character")
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym<="2021/03")
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym>="2018/04")
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(utagai_flg==0) %>% select(-utagai_flg)


m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>%  left_join(m_icd10) 
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I50",icd10_code)|grepl("I42",icd10_code)|grepl("I43",icd10_code))

# HEART FAILURE LAST 3 YEARS
short_i_receipt_diseases_All_ContEnr_pts %>% 
  filter(grepl("I500",icd10_code)) %>% group_by(kojin_id) %>% count() %>% filter(n>=2) %>% select(kojin_id) %>% distinct() %>% ungroup() %>%
  inner_join(short_i_receipt_diseases_All_ContEnr_pts %>% 
  filter(grepl("I509",icd10_code)) %>% group_by(kojin_id) %>% count() %>% filter(n>=2) %>% select(kojin_id) %>% distinct() %>% ungroup()) %>%
  anti_join(short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I42",icd10_code)|grepl("I43",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
  select(kojin_id) %>% distinct() %>%
  left_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight)))  



# ------------------------------------------
# % Facilities vs percentage diagnosed patients ----------------------------
receipt_medical_institution_CM_Targets <- fread("All_Pts_ContinuousEnrolled/receipt_medical_institution_CM_Targets.txt", sep="\t", colClasses = "character")
receipt_medical_institution_CM_Targets <- receipt_medical_institution_CM_Targets %>% select(kojin_id, iryokikan_no, receipt_id) %>% distinct()

short_I_receipt_diseases_facility_CM_Targets <- fread("All_Pts_ContinuousEnrolled/short_I_receipt_diseases_facility_CM_Targets.txt", sep="\t", colClasses = "character")
short_I_receipt_diseases_facility_CM_Targets <- short_I_receipt_diseases_facility_CM_Targets %>% filter(diseases_code=="8850066") %>% select(kojin_id, receipt_id) %>% distinct()

receipt_medical_institution_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_medical_institution_Vyndaqel195pts.txt", colClasses = "character")
receipt_medical_institution_Vyndaqel195pts <- receipt_medical_institution_Vyndaqel195pts %>% select(kojin_id, iryokikan_no, receipt_id) %>% distinct()

receipt_diseases_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_diseases_Vyndaqel195pts.txt",  colClasses = "character")
receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>% 
  filter(diseases_code=="8850066") %>% select(kojin_id, receipt_id) %>% distinct()

data.frame(receipt_diseases_Vyndaqel195pts %>% inner_join(receipt_medical_institution_Vyndaqel195pts) %>% 
  select(kojin_id, iryokikan_no) %>% distinct() %>% 
  bind_rows(
    short_I_receipt_diseases_facility_CM_Targets %>% inner_join(receipt_medical_institution_CM_Targets) %>%
  select(kojin_id, iryokikan_no) %>% distinct()
  ) %>% distinct() %>%
    group_by(iryokikan_no) %>% count() %>% arrange(-n) %>% ungroup() %>%
  mutate(Total=sum(n)) %>%
  mutate(percent=n/Total) %>% mutate(cumpercent=cumsum(percent)) %>%
  mutate(facilities=1/38) %>% mutate(cumfac=cumsum(facilities))) %>%
  ggplot(aes(100*cumfac, 100*cumpercent)) +
  ylim(0,100) +
  geom_point(colour="firebrick", size=3) +
  xlab("\n Cummulative Percentage \n Facilities Diagnosing ATTR-CM") +
  ylab("Cummulative Percentage of \n ATTR-CM diagnosed patients \n") + 
  theme_minimal() + 
  theme(legend.title = element_blank())
  
 
m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
m_icd10 <- m_icd10 %>% filter(icd10_code=="I431") %>% select(diseases_code)



receipt_medical_institution_CM_Targets <- fread("All_Pts_ContinuousEnrolled/receipt_medical_institution_CM_Targets.txt", sep="\t", colClasses = "character")
receipt_medical_institution_CM_Targets <- receipt_medical_institution_CM_Targets %>% select(kojin_id, iryokikan_no, receipt_id) %>% distinct()

short_I_receipt_diseases_facility_CM_Targets <- fread("All_Pts_ContinuousEnrolled/short_I_receipt_diseases_facility_CM_Targets.txt", sep="\t", colClasses = "character")
short_I_receipt_diseases_facility_CM_Targets <- short_I_receipt_diseases_facility_CM_Targets %>% inner_join(m_icd10) %>% select(kojin_id, receipt_id) %>% distinct()

receipt_medical_institution_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_medical_institution_Vyndaqel195pts.txt", colClasses = "character")
receipt_medical_institution_Vyndaqel195pts <- receipt_medical_institution_Vyndaqel195pts %>% select(kojin_id, iryokikan_no, receipt_id) %>% distinct()

receipt_diseases_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_diseases_Vyndaqel195pts.txt",  colClasses = "character")
receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>% 
  inner_join(m_icd10) %>% select(kojin_id, receipt_id) %>% distinct()

data.frame(receipt_diseases_Vyndaqel195pts %>% inner_join(receipt_medical_institution_Vyndaqel195pts) %>% 
  select(kojin_id, iryokikan_no) %>% distinct() %>% 
  bind_rows(
    short_I_receipt_diseases_facility_CM_Targets %>% inner_join(receipt_medical_institution_CM_Targets) %>%
  select(kojin_id, iryokikan_no) %>% distinct()
  ) %>% distinct() %>%
    group_by(iryokikan_no) %>% count() %>% arrange(-n) %>% ungroup() %>%
  mutate(Total=sum(n)) %>%
  mutate(percent=n/Total) %>% mutate(cumpercent=cumsum(percent)) %>%
  mutate(facilities=1/313) %>% mutate(cumfac=cumsum(facilities))) %>%
  ggplot(aes(100*cumfac, 100*cumpercent)) +
  geom_point(colour="deepskyblue4", size=1) +
  xlab("\n Cummulative Percentage \n Facilities Diagnosing Cardiac Amyloidosis") +
  ylab("Cummulative Percentage of \n Cardiac Amyloidosis diagnosed patients \n") + 
  theme_minimal() + 
  theme(legend.title = element_blank())

# --------------------------------------
# Collect All disease_codes for Is for all patients -----------------------------------

query <- paste0("SELECT kojin_id, birth_ym, sex_code FROM vyndaqel.tekiyo_all;")
  AllPats  <- setDT(dbGetQuery(con, query))
  
  fwrite(AllPats, "All_Pts_ContinuousEnrolled/All_Pats_11m.txt", sep="\t")
  
  
  pagify <- function(data = NULL, by = 1000){
    pagemin <- seq(1,length(data), by = by)
    pagemax <- pagemin - 1 + by
    pagemax[length(pagemax)] <- length(data)
    pages   <- list(min = pagemin, max = pagemax)
  }
  
  
pages <- pagify(AllPats$kojin_id, 5000)
  

short_i_receipt_diseases_utagai_AllPatients <- data.table()

length(pages$max) 

for(i in 1:length(pages$max)) {
  cat(i)
  start <- Sys.time()
  pts <- paste0(AllPats$kojin_id[pages$min[i]:pages$max[i]], collapse = "','")
  query <- paste0("SELECT receipt_ym, kojin_id, diseases_code, utagai_flg FROM vyndaqel.short_i_receipt_diseases_utagai  WHERE kojin_id IN ('",pts,"');")
  data  <- setDT(dbGetQuery(con, query))
  short_i_receipt_diseases_utagai_AllPatients <- rbind(short_i_receipt_diseases_utagai_AllPatients, data)
  end   <- Sys.time()
  print(end - start)
}

fwrite(short_i_receipt_diseases_utagai_AllPatients, "All_Pts_ContinuousEnrolled/short_i_receipt_diseases_utagai_AllPatients.txt", sep="\t")


rm(short_i_receipt_diseases_utagai_AllPatients)


# -----------------------------



# Stocks / Flows diagram CM Vyndaqel patient funnel NEW RULES /ALL Pats non cont enr. inc. ------------------------------------------

All_Pats_11m <- fread("All_Pts_ContinuousEnrolled/All_Pats_11m.txt", colClasses = "character")
All_Pats_11m[, gender:= ifelse(sex_code == 1, "M","F")]
All_Pats_11m <- All_Pats_11m %>% select(-sex_code)
All_Pats_11m$birth_ym <- as.Date(paste0(as.character(All_Pats_11m$birth_ym), '/01'))
All_Pats_11m$age <- round(time_length(interval(All_Pats_11m$birth_ym, ymd("2021-08-01")), "year"))
All_Pats_11m <- All_Pats_11m %>% select(-birth_ym)
All_Pats_11m <- All_Pats_11m %>% filter(age>=18 & age<=100)
All_Pats_11m <- All_Pats_11m %>% mutate(age=ifelse(age>=95,95,age))

All_Pats_11m <- data.table(All_Pats_11m)
All_Pats_11m <- All_Pats_11m[, .(samples_count = .N), keyby = .(gender,age)]
All_Pats_11m <- All_Pats_11m[,.(age,gender, samples_count)]

pop <- fread("Documentation/JMDC Japan Insurances.txt") 
pop <- pop[,3:5]


All_Pats_11m <- merge(All_Pats_11m, pop, by.x=c("age","gender"),  by.y=c("age","gender"), all.x = TRUE)

All_Pats_11m[,weight:=total_population/samples_count]

sum(All_Pats_11m$samples_count)
sum(All_Pats_11m$total_population)

New_weights_AllPats <- All_Pats_11m
New_weights_AllPats <- New_weights_AllPats %>% select(age, gender, weight)



All_Pats_11m <- fread("All_Pts_ContinuousEnrolled/All_Pats_11m.txt", colClasses = "character")
All_Pats_11m[, gender:= ifelse(sex_code == 1, "M","F")]
All_Pats_11m <- All_Pats_11m %>% select(-sex_code)
All_Pats_11m$birth_ym <- as.Date(paste0(as.character(All_Pats_11m$birth_ym), '/01'))
All_Pats_11m$age <- round(time_length(interval(All_Pats_11m$birth_ym, ymd("2021-08-01")), "year"))
All_Pats_11m <- All_Pats_11m %>% select(-birth_ym)
All_Pats_11m <- All_Pats_11m %>% filter(age>=18 & age<=100)
All_Pats_11m <- All_Pats_11m %>% mutate(age=ifelse(age>=95,95,age))

All_Pats_11m <- All_Pats_11m %>% left_join(New_weights_AllPats)

sum(as.numeric(All_Pats_11m$weight)) # 107186025


Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")
Vyndaqel_pats_CM_vs_PN <- Vyndaqel_pats_CM_vs_PN %>% select(kojin_id) 



# Is LAST 3 YEARS
short_i_receipt_diseases_utagai_AllPatients <- fread("All_Pts_ContinuousEnrolled/short_i_receipt_diseases_utagai_AllPatients.txt", colClasses = "character")

short_i_receipt_diseases_utagai_AllPatients <- short_i_receipt_diseases_utagai_AllPatients %>% filter(receipt_ym<="2021/03")
short_i_receipt_diseases_utagai_AllPatients <- short_i_receipt_diseases_utagai_AllPatients %>% filter(receipt_ym>="2018/04")

short_i_receipt_diseases_utagai_AllPatients <- short_i_receipt_diseases_utagai_AllPatients %>% filter(utagai_flg==0) %>% select(-utagai_flg)


short_i_receipt_diseases_utagai_AllPatients <- short_i_receipt_diseases_utagai_AllPatients %>% select(kojin_id, diseases_code) %>% distinct()
ATTR_SpecificCode <- short_i_receipt_diseases_utagai_AllPatients %>% filter(diseases_code=="8850066") %>% select(kojin_id) %>% distinct()


m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_i_receipt_diseases_utagai_AllPatients <- short_i_receipt_diseases_utagai_AllPatients %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code) %>% distinct()

short_i_receipt_diseases_utagai_AllPatients <- short_i_receipt_diseases_utagai_AllPatients %>% filter(grepl("I50",icd10_code)|grepl("I42",icd10_code)|grepl("I43",icd10_code))


# CM LAST 3 YEARS
short_i_receipt_diseases_utagai_AllPatients %>% filter(grepl("I42",icd10_code)|grepl("I43",icd10_code)) %>% filter(icd10_code!="I420"&
                                                                                                                  icd10_code!="I423"&
                                                                                                                  icd10_code!="I424"&
                                                                                                                  icd10_code!="I426"&
                                                                                                                  icd10_code!="I427") %>% select(kojin_id) %>% distinct() %>%
      anti_join(short_i_receipt_diseases_utagai_AllPatients %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
      anti_join(Vyndaqel_pats_CM_vs_PN) %>%
  inner_join(All_Pats_11m) %>% drop_na() %>% summarise(n=sum(as.numeric(weight)))   # 195443.6 # 151359.1 # 324260.3



# HEART FAILURE LAST 3 YEARS & AMYLOIDOSIS & CARDIOMYOPATHY & CARDIOMYOPATHY DUE TO AMYLOIDOSIS
short_i_receipt_diseases_utagai_AllPatients %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  inner_join(ATTR_SpecificCode) %>%
  anti_join(Vyndaqel_pats_CM_vs_PN) %>%
   left_join(All_Pats_11m) %>% drop_na() %>% summarise(n=sum(as.numeric(weight)))   # 


short_i_receipt_diseases_utagai_AllPatients %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  anti_join(ATTR_SpecificCode) %>%
    anti_join(Vyndaqel_pats_CM_vs_PN) %>%
left_join(All_Pats_11m) %>% drop_na() %>% summarise(n=sum(as.numeric(weight)))  #






receipt_drug_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_drug_Vyndaqel195pts.txt", colClasses = "character")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts[,.(kojin_id, receipt_ym, drug_code)]
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% filter(drug_code=="622278901")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% select(-c(drug_code))
Exact_Month_Lookup <- receipt_drug_Vyndaqel195pts %>% select(receipt_ym) %>% distinct() %>% arrange(receipt_ym) %>%
  mutate(Exact_Month=row_number())
names(Exact_Month_Lookup)[2] <- "Month"

GapFillVyndael <- fread("VyndaqelPts195/GapFill_Vyndaqel.csv", sep=",")
GapFillVyndael <- gather(GapFillVyndael, Month, Treat, 2:88, factor_key=TRUE)
GapFillVyndael$Month <- as.numeric(GapFillVyndael$Month)
GapFillVyndael <- GapFillVyndael %>% left_join(Exact_Month_Lookup)
GapFillVyndael$kojin_id <- as.character(GapFillVyndael$kojin_id)


Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")
Vyndaqel_pats_CM_vs_PN <- Vyndaqel_pats_CM_vs_PN %>% select(kojin_id, PN, CM, Combo)

VyndaqelPts195 <- fread("VyndaqelPts195/tekiyo_Vyndaqel195pts.txt", colClasses = "character")
VyndaqelPts195 <- VyndaqelPts195 %>% select(kojin_id, birth_ym, sex_code)
VyndaqelPts195[, gender:= ifelse(sex_code == 1, "M","F")]
VyndaqelPts195 <- VyndaqelPts195 %>% select(-sex_code)
VyndaqelPts195$birth_ym <- as.Date(paste0(as.character(VyndaqelPts195$birth_ym), '/01'))
VyndaqelPts195$age <- round(time_length(interval(VyndaqelPts195$birth_ym, ymd("2021-08-01")), "year"))
VyndaqelPts195 <- VyndaqelPts195 %>% select(-birth_ym)
VyndaqelPts195 <- VyndaqelPts195 %>% left_join(Vyndaqel_pats_CM_vs_PN)
VyndaqelPts195 <- VyndaqelPts195 %>% mutate(age=ifelse(age>=95,95,age))
VyndaqelPts195$age <- as.character(VyndaqelPts195$age)
VyndaqelPts195 <- VyndaqelPts195  %>% left_join(All_Pats_11m %>% select(age, gender, weight) %>% distinct() %>% mutate(age=as.character(age)))
VyndaqelPts195 <- VyndaqelPts195 %>% select(kojin_id, weight)
sum(as.numeric(VyndaqelPts195$weight)) # 1211.086


GapFillVyndael %>%  filter(receipt_ym=="2021/03") %>%
  filter(Treat==1) %>% select(kojin_id) %>% distinct() %>%
  inner_join(Vyndaqel_pats_CM_vs_PN %>% filter(CM==1|Combo==1) %>% select(kojin_id)) %>% 
  inner_join(VyndaqelPts195) %>%  summarise(n=sum(as.numeric(weight))) # 768.1043


GapFillVyndael %>%  filter(receipt_ym<="2021/03") %>%
  filter(Treat==1) %>% select(kojin_id) %>% distinct() %>%
  inner_join(Vyndaqel_pats_CM_vs_PN %>% filter(CM==1|Combo==1) %>% select(kojin_id)) %>% 
  inner_join(VyndaqelPts195) %>%  summarise(n=sum(as.numeric(weight))) # 915.764

    

GapFillVyndael %>%  filter(receipt_ym=="2020/03") %>%
  filter(Treat==1) %>% select(kojin_id) %>% distinct() %>%
  inner_join(Vyndaqel_pats_CM_vs_PN %>% filter(CM==1|Combo==1) %>% select(kojin_id)) %>% 
  inner_join(VyndaqelPts195) %>%  summarise(n=sum(as.numeric(weight))) # 


GapFillVyndael %>%  filter(receipt_ym<="2020/03") %>%
  filter(Treat==1) %>% select(kojin_id) %>% distinct() %>%
  inner_join(Vyndaqel_pats_CM_vs_PN %>% filter(CM==1|Combo==1) %>% select(kojin_id)) %>% 
  inner_join(VyndaqelPts195) %>%  summarise(n=sum(as.numeric(weight))) # 

  


# HF


Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")
Vyndaqel_pats_CM_vs_PN <- Vyndaqel_pats_CM_vs_PN %>% select(kojin_id) 




# Is LAST 3 YEARS
short_i_receipt_diseases_utagai_AllPatients <- fread("All_Pts_ContinuousEnrolled/short_i_receipt_diseases_utagai_AllPatients.txt", colClasses = "character")

short_i_receipt_diseases_utagai_AllPatients <- short_i_receipt_diseases_utagai_AllPatients %>% filter(receipt_ym<="2021/03")
short_i_receipt_diseases_utagai_AllPatients <- short_i_receipt_diseases_utagai_AllPatients %>% filter(receipt_ym>="2018/04")

short_i_receipt_diseases_utagai_AllPatients <- short_i_receipt_diseases_utagai_AllPatients %>% select(-utagai_flg)


m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)

short_i_receipt_diseases_utagai_AllPatients <- short_i_receipt_diseases_utagai_AllPatients %>%  left_join(m_icd10) 
short_i_receipt_diseases_utagai_AllPatients <- short_i_receipt_diseases_utagai_AllPatients %>% filter(grepl("I50",icd10_code)|grepl("I42",icd10_code)|grepl("I43",icd10_code))

# HEART FAILURE LAST 3 YEARS
short_i_receipt_diseases_utagai_AllPatients %>% 
  filter(grepl("I500",icd10_code)) %>% group_by(kojin_id) %>% count() %>% filter(n>=2) %>% select(kojin_id) %>% distinct() %>% ungroup() %>%
  inner_join(short_i_receipt_diseases_utagai_AllPatients %>% 
  filter(grepl("I509",icd10_code)) %>% group_by(kojin_id) %>% count() %>% filter(n>=2) %>% select(kojin_id) %>% distinct() %>% ungroup()) %>%
  anti_join(short_i_receipt_diseases_utagai_AllPatients %>% filter(grepl("I42",icd10_code)|grepl("I43",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
  select(kojin_id) %>% distinct() %>%
left_join(All_Pats_11m) %>% drop_na() %>% summarise(n=sum(as.numeric(weight))) 


# --------------------------------------------------
# First ATTR-CM, Cardiac Amyloidosis, Cardiomyopathy ever -------------------------------------------------------

ATTR_CM_noVyn_Pats <- fread("ATTR_CM_noVyn_Pats.txt")
Cardiac_Amyloidosis_Pats <- fread("Cardiac_Amyloidosis_Pats.txt")
Cardiac_Amyloidosis_Pats <- Cardiac_Amyloidosis_Pats %>% select(1)
Cardiomyopathy_Pats <- fread("Cardiomyopathy_Pats.txt")

short_i_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_i_receipt_diseases_utagai_All_ContEnr_pts.txt", colClasses = "character")

min(short_i_receipt_diseases_All_ContEnr_pts$receipt_ym)
max(short_i_receipt_diseases_All_ContEnr_pts$receipt_ym)

m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% left_join(m_icd10) %>%
  select(kojin_id, icd10_code, diseases_code, receipt_ym) %>% distinct()

short_i_receipt_diseases_All_ContEnr_pts <- ATTR_CM_noVyn_Pats %>% full_join(Cardiac_Amyloidosis_Pats) %>% full_join(Cardiomyopathy_Pats) %>%
  left_join(short_i_receipt_diseases_All_ContEnr_pts)

FIrst_ATTR <- ATTR_CM_noVyn_Pats %>% mutate(kojin_id=as.character(kojin_id)) %>% left_join(short_i_receipt_diseases_All_ContEnr_pts) %>%
  filter(diseases_code=="8850066") %>% group_by(kojin_id) %>% filter(receipt_ym==min(receipt_ym)) %>% slice(1) %>% ungroup()
FIrst_ATTR <- FIrst_ATTR %>% select(kojin_id, receipt_ym)

FIrst_CardiacAmyloidosis <- Cardiac_Amyloidosis_Pats %>% mutate(kojin_id=as.character(kojin_id)) %>% left_join(short_i_receipt_diseases_All_ContEnr_pts) %>%
  filter(grepl("I431",icd10_code)) %>% group_by(kojin_id) %>% filter(receipt_ym==min(receipt_ym)) %>% slice(1) %>% ungroup()
FIrst_CardiacAmyloidosis <- FIrst_CardiacAmyloidosis %>% select(kojin_id, receipt_ym)

First_Cardiomyopathy <- Cardiomyopathy_Pats %>% mutate(kojin_id=as.character(kojin_id)) %>% left_join(short_i_receipt_diseases_All_ContEnr_pts) %>%
  filter(grepl("I42",icd10_code)|grepl("I43",icd10_code)) %>% filter(icd10_code!="I420" & icd10_code!="I423" & icd10_code!="I424" & icd10_code!="I426" &  icd10_code!="I427") %>%
  group_by(kojin_id) %>% filter(receipt_ym==min(receipt_ym)) %>% slice(1) %>% ungroup()
First_Cardiomyopathy <- First_Cardiomyopathy %>% select(kojin_id, receipt_ym)


Lookup <- data.frame(First_Cardiomyopathy %>% select(receipt_ym) %>% distinct() %>%
  full_join(FIrst_CardiacAmyloidosis %>% select(receipt_ym) %>% distinct()) %>%
  full_join(FIrst_ATTR %>% select(receipt_ym) %>% distinct()) %>%
  arrange(receipt_ym) %>%
  mutate(monthnumber=row_number()))



Lookup %>% left_join(First_Cardiomyopathy) %>% select(receipt_ym, monthnumber) %>% mutate(Group="Cardiomyopathy") %>%
  full_join(
Lookup %>% left_join(FIrst_CardiacAmyloidosis) %>% select(receipt_ym, monthnumber) %>% mutate(Group="CardiacAmyloidosis")
  ) %>%
  full_join(
    Lookup %>% left_join(FIrst_ATTR) %>% select(receipt_ym, monthnumber) %>% mutate(Group="ATTR-CM")
  ) %>% group_by(Group) %>%
  summarise(n=mean(monthnumber))



Lookup %>% left_join(First_Cardiomyopathy) %>% select(receipt_ym, monthnumber) %>% mutate(Group="Cardiomyopathy") %>%
  full_join(
Lookup %>% left_join(FIrst_CardiacAmyloidosis) %>% select(receipt_ym, monthnumber) %>% mutate(Group="CardiacAmyloidosis")
  ) %>%
  full_join(
    Lookup %>% left_join(FIrst_ATTR) %>% select(receipt_ym, monthnumber) %>% mutate(Group="ATTR-CM")
  ) %>%
  ggplot(aes(monthnumber, colour=Group, fill=Group)) +
  geom_density(alpha=0.5) + 
  theme_minimal() +
  ggsci::scale_color_jco()+
  ggsci::scale_fill_jco() +
  ylab("First Dx Patient proportion \n") + xlab("Exact Month [Apr 2014 - Mar 2021])")


Lookup %>% left_join(First_Cardiomyopathy) %>% select(receipt_ym, monthnumber) %>% mutate(Group="Cardiomyopathy") %>%
  full_join(
Lookup %>% left_join(FIrst_CardiacAmyloidosis) %>% select(receipt_ym, monthnumber) %>% mutate(Group="CardiacAmyloidosis")
  ) %>%
  ggplot(aes(monthnumber, colour=Group, fill=Group)) +
  geom_density(alpha=0.5) + 
  theme_minimal() +
  ggsci::scale_color_jco()+
  ggsci::scale_fill_jco() +
  ylab("First Dx Patient proportion \n") + xlab("Exact Month [Apr 2014 - Mar 2021])")

# -------------------------------------------------
# For Vyndaqel patients, time from I431 to Vyndaqel for specific ATTR vs nonspecific -------------------------------

receipt_drug_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_drug_Vyndaqel195pts.txt", colClasses = "character")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts[,.(receipt_ym, kojin_id, drug_code, receipt_id)]
receipt_drug_Vyndaqel195pts$receipt_ym <- as.Date(paste0(as.character(receipt_drug_Vyndaqel195pts$receipt_ym), '/01'))
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% filter(drug_code=="622278901")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% group_by(kojin_id) %>% filter(receipt_ym==min(receipt_ym))
First_Vyndaqel <-  receipt_drug_Vyndaqel195pts %>% select(receipt_ym, kojin_id) %>% distinct()
names(First_Vyndaqel)[1] <- "FirstVyndaqel"




receipt_diseases_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_diseases_Vyndaqel195pts.txt", colClasses = "character")
receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>% select(receipt_ym, kojin_id, diseases_code)
ATTR_specific <- receipt_diseases_Vyndaqel195pts %>% filter(diseases_code=="8850066") %>% select(kojin_id) %>% distinct()

m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_subdiv_code, icd10_subdiv_name_en)
receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>% left_join(m_icd10) %>% select(receipt_ym, kojin_id, icd10_subdiv_code) %>% distinct() %>%
  filter(grepl("I431", icd10_subdiv_code)) %>% select(kojin_id, receipt_ym) %>% group_by(kojin_id) %>%  filter(receipt_ym==min(receipt_ym)) %>%
  slice(1)
names(receipt_diseases_Vyndaqel195pts)[2] <- "FirstI431"

receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>% inner_join(First_Vyndaqel) 
receipt_diseases_Vyndaqel195pts$FirstI431 <- as.Date(paste0(as.character(receipt_diseases_Vyndaqel195pts$FirstI431), '/01'))

receipt_diseases_Vyndaqel195pts %>% ungroup() %>% mutate(Lapsed = as.numeric(FirstVyndaqel)-as.numeric(FirstI431)) %>%
  inner_join(ATTR_specific) %>% summarise(n=mean(Lapsed)) # 

receipt_diseases_Vyndaqel195pts %>% ungroup() %>% mutate(Lapsed = as.numeric(FirstVyndaqel)-as.numeric(FirstI431)) %>%
  anti_join(ATTR_specific) %>% summarise(n=mean(Lapsed)) # 
                                           


# ----------------------------------------------------
# What do patients do between Dxs? -----------------------------------------------

# ATTR-CM to Vyndaqel
receipt_drug_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_drug_Vyndaqel195pts.txt", colClasses = "character")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts[,.(receipt_ym, kojin_id, drug_code, receipt_id)]
receipt_drug_Vyndaqel195pts$receipt_ym <- as.Date(paste0(as.character(receipt_drug_Vyndaqel195pts$receipt_ym), '/01'))
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% filter(drug_code=="622278901")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% group_by(kojin_id) %>% filter(receipt_ym==min(receipt_ym))
First_Vyndaqel <-  receipt_drug_Vyndaqel195pts %>% select(receipt_ym, kojin_id) %>% distinct()
names(First_Vyndaqel)[1] <- "FirstVyndaqel"


receipt_diseases_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_diseases_Vyndaqel195pts.txt", colClasses = "character")
receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>% select(receipt_ym, kojin_id, diseases_code)
receipt_diseases_Vyndaqel195pts$receipt_ym <- as.Date(paste0(as.character(receipt_diseases_Vyndaqel195pts$receipt_ym), '/01'))
First_ATTR_specific <- receipt_diseases_Vyndaqel195pts %>% filter(diseases_code=="8850066") %>% group_by(kojin_id) %>%
  filter(receipt_ym==min(receipt_ym)) %>% select(kojin_id, receipt_ym) %>% distinct()
names(First_ATTR_specific)[2] <- "First_ATTR"

First_Vyndaqel_ATTR <- First_ATTR_specific %>% inner_join(First_Vyndaqel)
First_Vyndaqel_ATTR$Difference <- First_Vyndaqel_ATTR$FirstVyndaqel - First_Vyndaqel_ATTR$First_ATTR
First_Vyndaqel_ATTR <- First_Vyndaqel_ATTR[First_Vyndaqel_ATTR$Difference>0,]
First_Vyndaqel_ATTR$Difference <- as.numeric(First_Vyndaqel_ATTR$Difference)


receipt_medical_practice_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_medical_practice_Vyndaqel195pts.txt", colClasses = "character")
receipt_medical_practice_Vyndaqel195pts <- receipt_medical_practice_Vyndaqel195pts[,.(receipt_ym, kojin_id, medical_practice_code)]
receipt_medical_practice_Vyndaqel195pts$receipt_ym <- as.Date(paste0(as.character(receipt_medical_practice_Vyndaqel195pts$receipt_ym), '/01'))
receipt_medical_practice_Vyndaqel195pts <- First_Vyndaqel_ATTR %>% inner_join(receipt_medical_practice_Vyndaqel195pts)
receipt_medical_practice_Vyndaqel195pts <- receipt_medical_practice_Vyndaqel195pts %>% filter(receipt_ym > First_ATTR & receipt_ym < FirstVyndaqel) %>%
  select(kojin_id, medical_practice_code)

Procedure_master <- fread("Masters/Procedure_master.csv", colClasses = "character")

receipt_medical_practice_Vyndaqel195pts <- 
  receipt_medical_practice_Vyndaqel195pts %>% 
  left_join(Procedure_master, 
            by=c("medical_practice_code"="standardized_procedure_code")) %>%
  select(kojin_id, standardized_procedure_name) %>% distinct()
 
receipt_medical_practice_Vyndaqel195pts <- receipt_medical_practice_Vyndaqel195pts %>%
                                              filter(grepl("computerized tomog", standardized_procedure_name)|
                                                     grepl("CT imaging", standardized_procedure_name)|
                                                     grepl("nuclear medicine diagnosis", standardized_procedure_name)|
                                                     grepl("scintigraphy", standardized_procedure_name)|
                                                     grepl("MRI", standardized_procedure_name)|
                                                     grepl("electrocardiog", standardized_procedure_name)|
                                                     grepl("ECG", standardized_procedure_name)|
                                                     grepl("ultrasonography", standardized_procedure_name)|
                                                     grepl("SPECT", standardized_procedure_name)|
                                                     grepl("PET ", standardized_procedure_name)|
                                                     grepl("percutaneous needle biopsy", standardized_procedure_name)|
                                                     grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name)|
                                                     grepl("endoscopic biopsy", standardized_procedure_name)|
                                                     grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name)|
                                                     grepl("brain natriuretic peptide", standardized_procedure_name)|
                                                     grepl("BNP", standardized_procedure_name)|
                                                     grepl("troponin", standardized_procedure_name)|
                                                     grepl("genetic test", standardized_procedure_name)|
                                                     grepl("cardiac catheterization", standardized_procedure_name)|
                                                     grepl("Holter", standardized_procedure_name)|
                                                     grepl("pacemaker", standardized_procedure_name)|
                                                     grepl("gene-related", standardized_procedure_name)|
                                                     grepl("exercise test", standardized_procedure_name)|
                                                     grepl("hospitalization", standardized_procedure_name)|
                                                     grepl("serum amyloid A protein", standardized_procedure_name)|
                                                     grepl("prealbumin", standardized_procedure_name)|
                                                     grepl("transthyretin", standardized_procedure_name)|
                                                     grepl("amylase", standardized_procedure_name))

unique(receipt_medical_practice_Vyndaqel195pts$standardized_procedure)

unique(Procedure_master$standardized_procedure_name[grepl("biopsy", Procedure_master$standardized_procedure_name)])

receipt_medical_practice_Vyndaqel195pts <-
  receipt_medical_practice_Vyndaqel195pts %>% mutate(standardized_procedure_name=
                                                     ifelse(grepl("computerized tomog",standardized_procedure_name), "CT",
                                                            ifelse(grepl("CT imaging,", standardized_procedure_name), "CT",
                                                                   ifelse(grepl("nuclear medicine diagnosis", standardized_procedure_name), "other nuclear medicine",
                                                                          ifelse(grepl("scintigraphy", standardized_procedure_name), "scintigraphy",
                                                                                 ifelse(grepl("MRI", standardized_procedure_name), "MRI",
                                                                                        ifelse(grepl("electrocardiog", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ECG", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ultrasonography", standardized_procedure_name), "ultrasonography",
                                                                                                      ifelse(grepl("SPECT", standardized_procedure_name), "scintigraphy",
                                                                                                             ifelse(grepl("PET ", standardized_procedure_name), "scintigraphy",
                                                                                                      ifelse(grepl("percutaneous needle biopsy", standardized_procedure_name), "biopsy",
                                                                                                             ifelse(grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("endoscopic biopsy", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name), "heart biopsy",
                                                                                                                           ifelse(grepl("brain natriuretic peptide", standardized_procedure_name), "BNP",
                                                                                                                                  ifelse(grepl("BNP", standardized_procedure_name), "BNP",
                                                                                                                                         ifelse(grepl("troponin", standardized_procedure_name), "troponin",
                                                                                                                                                ifelse(grepl("genetic test", standardized_procedure_name), "genetic test",
                                                                                                                                                       ifelse(grepl("cardiac catheterization", standardized_procedure_name), "cardiac catheterization",
                                                                                                                                                              ifelse(grepl("Holter", standardized_procedure_name), "Holter",
                                                                                                                                                                     ifelse(grepl("pacemaker", standardized_procedure_name), "pacemaker",
                                                                                                                                                                            ifelse(grepl("gene-related", standardized_procedure_name), "genetic test",
                                                                                                                                                                                          ifelse(grepl("exercise test", standardized_procedure_name), "exercise test",
                                                                                                                                                                                                 ifelse(grepl("hospitalization", standardized_procedure_name), "hospitalization",
                                                                                                                                                                                                        ifelse(grepl("serum amyloid A protein", standardized_procedure_name), "AmyloidA",
                                                                                                                                                                                                               ifelse(grepl("prealbumin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("transthyretin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("amylase", standardized_procedure_name), "amylase",NA)))))))))))))))))))))))))))))
                                                                   

receipt_medical_practice_Vyndaqel195pts <- receipt_medical_practice_Vyndaqel195pts %>% mutate(standardized_procedure_name=ifelse(is.na(standardized_procedure_name),"CT", standardized_procedure_name))

receipt_medical_practice_Vyndaqel195pts %>% 
  select(kojin_id, standardized_procedure_name) %>% distinct() %>%
  group_by(standardized_procedure_name) %>% count() %>% arrange(-n) %>%
  mutate(percent=100*n/14)




# CM to ATTR-CM

short_i_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_i_receipt_diseases_All_ContEnr_pts.txt", 
                                         colClasses = "character")
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(diseases_code=="8850066") %>% select(kojin_id) %>% distinct() %>%
  left_join(short_i_receipt_diseases_All_ContEnr_pts)
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym<="2021/03")
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(receipt_ym>="2018/04")


m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% 
  left_join(m_icd10) %>% select(kojin_id, receipt_ym, diseases_code, icd10_code) 

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I43",icd10_code))

temp <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(diseases_code=="8850066") %>%
  group_by(kojin_id) %>% filter(receipt_ym==min(receipt_ym)) %>% slice(1) %>% rename("FirstATTRCM"="receipt_ym") %>% select(1,2) %>%
  inner_join(
    short_i_receipt_diseases_All_ContEnr_pts %>% filter(icd10_code=="I431") %>%
  group_by(kojin_id) %>% filter(receipt_ym==min(receipt_ym)) %>% slice(1) %>% rename("FirstI431"="receipt_ym") %>% select(1,2)
  )

temp$FirstATTRCM <- as.Date(paste0(as.character(temp$FirstATTRCM), '/01'))
temp$FirstI431 <- as.Date(paste0(as.character(temp$FirstI431), '/01'))
temp$Difference <- temp$FirstATTRCM - temp$FirstI431
temp <- temp[temp$Difference>0,]
temp$Difference <- as.numeric(temp$Difference)

temp

short_procedures_receipt_medical_practice_All_ContEnr_pts <- fread("All_Pts_Continuousenrolled/short_procedures_receipt_medical_practice_All_ContEnr_pts.txt", colClasses = "character")
short_procedures_receipt_medical_practice_All_ContEnr_pts <- short_procedures_receipt_medical_practice_All_ContEnr_pts %>% select(kojin_id, medical_practice_code, receipt_ym) %>% distinct()
short_procedures_receipt_medical_practice_All_ContEnr_pts <- temp %>% left_join(short_procedures_receipt_medical_practice_All_ContEnr_pts)
short_procedures_receipt_medical_practice_All_ContEnr_pts$receipt_ym <- as.Date(paste0(as.character(short_procedures_receipt_medical_practice_All_ContEnr_pts$receipt_ym), '/01'))

short_procedures_receipt_medical_practice_All_ContEnr_pts <- short_procedures_receipt_medical_practice_All_ContEnr_pts %>% filter(receipt_ym > FirstI431   & receipt_ym < FirstATTRCM ) %>%
  select(kojin_id, medical_practice_code)

short_procedures_receipt_medical_practice_All_ContEnr_pts <- 
  short_procedures_receipt_medical_practice_All_ContEnr_pts %>% 
  left_join(Procedure_master, 
            by=c("medical_practice_code"="standardized_procedure_code")) %>%
  select(kojin_id, standardized_procedure_name) %>% distinct()


short_procedures_receipt_medical_practice_All_ContEnr_pts <- short_procedures_receipt_medical_practice_All_ContEnr_pts %>%
                                              filter(grepl("computerized tomog", standardized_procedure_name)|
                                                     grepl("CT imaging", standardized_procedure_name)|
                                                     grepl("nuclear medicine diagnosis", standardized_procedure_name)|
                                                     grepl("scintigraphy", standardized_procedure_name)|
                                                     grepl("MRI", standardized_procedure_name)|
                                                     grepl("electrocardiog", standardized_procedure_name)|
                                                     grepl("ECG", standardized_procedure_name)|
                                                     grepl("ultrasonography", standardized_procedure_name)|
                                                     grepl("SPECT", standardized_procedure_name)|
                                                     grepl("PET ", standardized_procedure_name)|
                                                     grepl("percutaneous needle biopsy", standardized_procedure_name)|
                                                     grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name)|
                                                     grepl("endoscopic biopsy", standardized_procedure_name)|
                                                     grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name)|
                                                     grepl("brain natriuretic peptide", standardized_procedure_name)|
                                                     grepl("BNP", standardized_procedure_name)|
                                                     grepl("troponin", standardized_procedure_name)|
                                                     grepl("genetic test", standardized_procedure_name)|
                                                     grepl("cardiac catheterization", standardized_procedure_name)|
                                                     grepl("Holter", standardized_procedure_name)|
                                                     grepl("pacemaker", standardized_procedure_name)|
                                                     grepl("gene-related", standardized_procedure_name)|
                                                     grepl("exercise test", standardized_procedure_name)|
                                                     grepl("hospitalization", standardized_procedure_name)|
                                                     grepl("serum amyloid A protein", standardized_procedure_name)|
                                                     grepl("prealbumin", standardized_procedure_name)|
                                                     grepl("transthyretin", standardized_procedure_name)|
                                                     grepl("amylase", standardized_procedure_name))

short_procedures_receipt_medical_practice_All_ContEnr_pts <-
  short_procedures_receipt_medical_practice_All_ContEnr_pts %>% mutate(standardized_procedure_name=
                                                     ifelse(grepl("computerized tomog",standardized_procedure_name), "CT",
                                                            ifelse(grepl("CT imaging,", standardized_procedure_name), "CT",
                                                                   ifelse(grepl("nuclear medicine diagnosis", standardized_procedure_name), "other nuclear medicine",
                                                                          ifelse(grepl("scintigraphy", standardized_procedure_name), "scintigraphy",
                                                                                 ifelse(grepl("MRI", standardized_procedure_name), "MRI",
                                                                                        ifelse(grepl("electrocardiog", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ECG", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ultrasonography", standardized_procedure_name), "ultrasonography",
                                                                                                      ifelse(grepl("SPECT", standardized_procedure_name), "scintigraphy",
                                                                                                             ifelse(grepl("PET ", standardized_procedure_name), "scintigraphy",
                                                                                                      ifelse(grepl("percutaneous needle biopsy", standardized_procedure_name), "biopsy",
                                                                                                             ifelse(grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("endoscopic biopsy", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name), "heart biopsy",
                                                                                                                           ifelse(grepl("brain natriuretic peptide", standardized_procedure_name), "BNP",
                                                                                                                                  ifelse(grepl("BNP", standardized_procedure_name), "BNP",
                                                                                                                                         ifelse(grepl("troponin", standardized_procedure_name), "troponin",
                                                                                                                                                ifelse(grepl("genetic test", standardized_procedure_name), "genetic test",
                                                                                                                                                       ifelse(grepl("cardiac catheterization", standardized_procedure_name), "cardiac catheterization",
                                                                                                                                                              ifelse(grepl("Holter", standardized_procedure_name), "Holter",
                                                                                                                                                                     ifelse(grepl("pacemaker", standardized_procedure_name), "pacemaker",
                                                                                                                                                                            ifelse(grepl("gene-related", standardized_procedure_name), "genetic test",
                                                                                                                                                                                          ifelse(grepl("exercise test", standardized_procedure_name), "exercise test",
                                                                                                                                                                                                 ifelse(grepl("hospitalization", standardized_procedure_name), "hospitalization",
                                                                                                                                                                                                        ifelse(grepl("serum amyloid A protein", standardized_procedure_name), "AmyloidA",
                                                                                                                                                                                                               ifelse(grepl("prealbumin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("transthyretin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("amylase", standardized_procedure_name), "amylase",NA)))))))))))))))))))))))))))))
                                                                   

short_procedures_receipt_medical_practice_All_ContEnr_pts <- short_procedures_receipt_medical_practice_All_ContEnr_pts %>% mutate(standardized_procedure_name=ifelse(is.na(standardized_procedure_name),"CT", standardized_procedure_name))

short_procedures_receipt_medical_practice_All_ContEnr_pts %>% ungroup() %>% 
  select(kojin_id, standardized_procedure_name) %>% distinct() %>%
  group_by(standardized_procedure_name) %>% count() %>% mutate(penetrance=100*n/33) %>%
  arrange(-penetrance)




# CM to CA


Cardiomyopathy_Pats <- fread("Cardiomyopathy_Pats.txt", colClasses = "character")
Cardiac_Amyloidosis_Pats <- fread("Cardiac_Amyloidosis_Pats.txt", colClasses = "character")
Cardiac_Amyloidosis_Pats <- Cardiac_Amyloidosis_Pats[,1]
ATTR_CM_noVyn_Pats <- fread("ATTR_CM_noVyn_Pats.txt", colClasses = "character")
Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")
ATTR_CM_Vyndaqel_Pats <- Vyndaqel_pats_CM_vs_PN %>%filter(CM==1|Combo==1) %>%  select(kojin_id)



short_i_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_i_receipt_diseases_utagai_All_ContEnr_pts.txt", colClasses = "character")
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(utagai_flg==0) %>% select(-utagai_flg)
short_i_receipt_diseases_All_ContEnr_pts <- Cardiac_Amyloidosis_Pats %>% inner_join(short_i_receipt_diseases_All_ContEnr_pts)

m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% left_join(m_icd10) %>% select(kojin_id, receipt_ym, icd10_code) %>% distinct()
short_i_receipt_diseases_All_ContEnr_pts$receipt_ym <- as.Date(paste0(as.character(short_i_receipt_diseases_All_ContEnr_pts$receipt_ym), '/01'))


temp <- Cardiac_Amyloidosis_Pats %>% left_join(short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I43",icd10_code)|grepl("I42",icd10_code))) %>%
  group_by(kojin_id) %>% filter(receipt_ym==min(receipt_ym)) %>% slice(1) %>% select(-icd10_code) %>% rename("FirstCardiomiopathy"="receipt_ym") %>%
  left_join(
Cardiac_Amyloidosis_Pats %>% left_join(short_i_receipt_diseases_All_ContEnr_pts %>% filter(icd10_code=="I431")) %>%
  group_by(kojin_id) %>% filter(receipt_ym==min(receipt_ym)) %>% slice(1)  %>% select(-icd10_code) %>% rename("FirstI431"="receipt_ym")
  ) 

length(unique(temp$kojin_id)) # 

short_procedures_receipt_medical_practice_All_ContEnr_pts <- fread("All_Pts_Continuousenrolled/short_procedures_receipt_medical_practice_All_ContEnr_pts.txt", colClasses = "character")
short_procedures_receipt_medical_practice_All_ContEnr_pts <- short_procedures_receipt_medical_practice_All_ContEnr_pts %>% select(kojin_id, medical_practice_code, receipt_ym) %>% distinct()
short_procedures_receipt_medical_practice_All_ContEnr_pts <- temp %>% left_join(short_procedures_receipt_medical_practice_All_ContEnr_pts)
short_procedures_receipt_medical_practice_All_ContEnr_pts$receipt_ym <- as.Date(paste0(as.character(short_procedures_receipt_medical_practice_All_ContEnr_pts$receipt_ym), '/01'))

short_procedures_receipt_medical_practice_All_ContEnr_pts <- short_procedures_receipt_medical_practice_All_ContEnr_pts %>% filter(receipt_ym > FirstCardiomiopathy    & receipt_ym < FirstI431  ) %>%
  select(kojin_id, medical_practice_code)

short_procedures_receipt_medical_practice_All_ContEnr_pts <- 
  short_procedures_receipt_medical_practice_All_ContEnr_pts %>% 
  left_join(Procedure_master, 
            by=c("medical_practice_code"="standardized_procedure_code")) %>%
  select(kojin_id, standardized_procedure_name) %>% distinct()


short_procedures_receipt_medical_practice_All_ContEnr_pts <- short_procedures_receipt_medical_practice_All_ContEnr_pts %>%
                                              filter(grepl("computerized tomog", standardized_procedure_name)|
                                                     grepl("CT imaging", standardized_procedure_name)|
                                                     grepl("nuclear medicine diagnosis", standardized_procedure_name)|
                                                     grepl("scintigraphy", standardized_procedure_name)|
                                                     grepl("MRI", standardized_procedure_name)|
                                                     grepl("electrocardiog", standardized_procedure_name)|
                                                     grepl("ECG", standardized_procedure_name)|
                                                     grepl("ultrasonography", standardized_procedure_name)|
                                                     grepl("SPECT", standardized_procedure_name)|
                                                     grepl("PET ", standardized_procedure_name)|
                                                     grepl("percutaneous needle biopsy", standardized_procedure_name)|
                                                     grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name)|
                                                     grepl("endoscopic biopsy", standardized_procedure_name)|
                                                     grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name)|
                                                     grepl("brain natriuretic peptide", standardized_procedure_name)|
                                                     grepl("BNP", standardized_procedure_name)|
                                                     grepl("troponin", standardized_procedure_name)|
                                                     grepl("genetic test", standardized_procedure_name)|
                                                     grepl("cardiac catheterization", standardized_procedure_name)|
                                                     grepl("Holter", standardized_procedure_name)|
                                                     grepl("pacemaker", standardized_procedure_name)|
                                                     grepl("gene-related", standardized_procedure_name)|
                                                     grepl("exercise test", standardized_procedure_name)|
                                                     grepl("hospitalization", standardized_procedure_name)|
                                                     grepl("serum amyloid A protein", standardized_procedure_name)|
                                                     grepl("prealbumin", standardized_procedure_name)|
                                                     grepl("transthyretin", standardized_procedure_name)|
                                                     grepl("amylase", standardized_procedure_name))

short_procedures_receipt_medical_practice_All_ContEnr_pts <-
  short_procedures_receipt_medical_practice_All_ContEnr_pts %>% mutate(standardized_procedure_name=
                                                     ifelse(grepl("computerized tomog",standardized_procedure_name), "CT",
                                                            ifelse(grepl("CT imaging,", standardized_procedure_name), "CT",
                                                                   ifelse(grepl("nuclear medicine diagnosis", standardized_procedure_name), "other nuclear medicine",
                                                                          ifelse(grepl("scintigraphy", standardized_procedure_name), "scintigraphy",
                                                                                 ifelse(grepl("MRI", standardized_procedure_name), "MRI",
                                                                                        ifelse(grepl("electrocardiog", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ECG", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ultrasonography", standardized_procedure_name), "ultrasonography",
                                                                                                      ifelse(grepl("SPECT", standardized_procedure_name), "scintigraphy",
                                                                                                             ifelse(grepl("PET ", standardized_procedure_name), "scintigraphy",
                                                                                                      ifelse(grepl("percutaneous needle biopsy", standardized_procedure_name), "biopsy",
                                                                                                             ifelse(grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("endoscopic biopsy", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name), "heart biopsy",
                                                                                                                           ifelse(grepl("brain natriuretic peptide", standardized_procedure_name), "BNP",
                                                                                                                                  ifelse(grepl("BNP", standardized_procedure_name), "BNP",
                                                                                                                                         ifelse(grepl("troponin", standardized_procedure_name), "troponin",
                                                                                                                                                ifelse(grepl("genetic test", standardized_procedure_name), "genetic test",
                                                                                                                                                       ifelse(grepl("cardiac catheterization", standardized_procedure_name), "cardiac catheterization",
                                                                                                                                                              ifelse(grepl("Holter", standardized_procedure_name), "Holter",
                                                                                                                                                                     ifelse(grepl("pacemaker", standardized_procedure_name), "pacemaker",
                                                                                                                                                                            ifelse(grepl("gene-related", standardized_procedure_name), "genetic test",
                                                                                                                                                                                          ifelse(grepl("exercise test", standardized_procedure_name), "exercise test",
                                                                                                                                                                                                 ifelse(grepl("hospitalization", standardized_procedure_name), "hospitalization",
                                                                                                                                                                                                        ifelse(grepl("serum amyloid A protein", standardized_procedure_name), "AmyloidA",
                                                                                                                                                                                                               ifelse(grepl("prealbumin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("transthyretin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("amylase", standardized_procedure_name), "amylase",NA)))))))))))))))))))))))))))))
                                                                   

short_procedures_receipt_medical_practice_All_ContEnr_pts <- short_procedures_receipt_medical_practice_All_ContEnr_pts %>% mutate(standardized_procedure_name=ifelse(is.na(standardized_procedure_name),"CT", standardized_procedure_name))

short_procedures_receipt_medical_practice_All_ContEnr_pts %>% ungroup() %>% 
   mutate(standardized_procedure_name=ifelse(standardized_procedure_name=="biopsy", "cardiac catheterization",  standardized_procedure_name)) %>%
  select(kojin_id, standardized_procedure_name) %>% distinct() %>%
  group_by(standardized_procedure_name) %>% count() %>% mutate(penetrance=100*n/307) %>%
  arrange(-penetrance)



# -------------------------------------------------------------------
# Type of facility for Target Cardiomyopathy, Cardiac Amyloidosis --------------------------------------------------
  
# Receipts IDs of the First Vyndaqel
receipt_drug_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_drug_Vyndaqel195pts.txt", colClasses = "character")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts[,.(receipt_ym, kojin_id, drug_code, receipt_id)]
receipt_drug_Vyndaqel195pts$receipt_ym <- as.Date(paste0(as.character(receipt_drug_Vyndaqel195pts$receipt_ym), '/01'))
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% filter(drug_code=="622278901")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% group_by(kojin_id) %>% filter(receipt_ym==min(receipt_ym))

# Facilities associated with that Vyndaqel receipt
receipt_medical_institution_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_medical_institution_Vyndaqel195pts.txt", colClasses = "character")
receipt_medical_institution_Vyndaqel195pts <- receipt_medical_institution_Vyndaqel195pts %>% select(kojin_id, receipt_ym, iryokikan_no, receipt_id)
receipt_medical_institution_Vyndaqel195pts$receipt_ym  <- as.Date(paste0(as.character(receipt_medical_institution_Vyndaqel195pts$receipt_ym ), '/01'))

temp <- receipt_drug_Vyndaqel195pts %>% 
  left_join(receipt_medical_institution_Vyndaqel195pts,
            by=c("kojin_id"="kojin_id", "receipt_id"="receipt_id", "receipt_ym"="receipt_ym")) 

length(unique(temp$kojin_id)) # 
length(unique(temp$iryokikan_no)) # # 

Vyndaqel_Facilities <- unique(temp$iryokikan_no)
Vyndaqel_Facilities <- as.data.frame(Vyndaqel_Facilities)
names(Vyndaqel_Facilities)[1] <- "iryokikan_no"

Cardiomyopathy_Pats <- fread("Cardiomyopathy_Pats.txt", colClasses = "character")
Cardiac_Amyloidosis_Pats <- fread("Cardiac_Amyloidosis_Pats.txt", colClasses = "character")
Cardiac_Amyloidosis_Pats <- Cardiac_Amyloidosis_Pats %>% select(1)
ATTR_CM_noVyn_Pats <- fread("ATTR_CM_noVyn_Pats.txt", colClasses = "character")
Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")
ATTR_CM_Vyndaqel_Pats <- Vyndaqel_pats_CM_vs_PN %>%filter(CM==1|Combo==1) %>%  select(kojin_id)


Cardiomyopathy_Pats$Group <- "Cardiomiopathy"
Cardiac_Amyloidosis_Pats$Group <-  "CardiacAMyloidosis"
ATTR_CM_noVyn_Pats$Group <- "ATTRCM_noVyn"

Target_CM_Pats <- Cardiomyopathy_Pats %>% bind_rows(Cardiac_Amyloidosis_Pats, ATTR_CM_noVyn_Pats)

receipt_medical_institution_CM_Targets <- fread("All_Pts_ContinuousEnrolled/receipt_medical_institution_CM_Targets.txt", sep="\t", colClasses = "character")

receipt_medical_institution_CM_Targets <- receipt_medical_institution_CM_Targets %>% filter(receipt_ym >= "2020-04" & receipt_ym <= "2021-03") %>%
  select(kojin_id, iryokikan_no, receipt_id) %>% distinct()

receipt_medical_institution_CM_Targets <- Target_CM_Pats %>% left_join(receipt_medical_institution_CM_Targets)

length(
  unique(
    receipt_medical_institution_CM_Targets$kojin_id[receipt_medical_institution_CM_Targets$Group=="Cardiomiopathy"]
    )
  ) # 

length(
  unique(
    receipt_medical_institution_CM_Targets$kojin_id[receipt_medical_institution_CM_Targets$Group=="CardiacAMyloidosis"]
    )
  ) # 

length(
  unique(
    receipt_medical_institution_CM_Targets$kojin_id[receipt_medical_institution_CM_Targets$Group=="ATTRCM_noVyn"]
    )
  ) # 


m_hco_med <- fread("Masters/m_hco_med.csv",  colClasses = "character")
m_hco_xref <- fread("Masters/m_hco_xref_specialty.csv", colClasses = "character")


receipt_medical_institution_CM_Targets %>% select(kojin_id, Group, iryokikan_no) %>% 
  left_join(m_hco_med) %>%
  select(Group, kojin_id, shisetsu_kbn_code) %>% 
  group_by(Group, shisetsu_kbn_code ) %>% count()

receipt_medical_institution_CM_Targets %>% select(kojin_id, Group, iryokikan_no) %>% 
  left_join(m_hco_med) %>%
  select(Group, kojin_id, univ_hosp_flag) %>% 
  group_by(Group, univ_hosp_flag ) %>% count()


receipt_medical_institution_CM_Targets %>% select(kojin_id, Group, iryokikan_no) %>% 
  left_join(m_hco_med) %>%
  select(Group, kojin_id, univ_hosp_flag) %>% distinct() %>%
  group_by(Group, univ_hosp_flag ) %>% count()



receipt_medical_institution_CM_Targets %>% select(kojin_id, Group, iryokikan_no) %>% 
  left_join(m_hco_med) %>%
  select(Group, kojin_id, total_byoshousuu_code) %>% filter(total_byoshousuu_code!="0") %>%
  mutate(total_byoshousuu_code=as.numeric(total_byoshousuu_code)) %>%
  drop_na() %>%
  group_by(Group ) %>% summarise(n=median(as.numeric(total_byoshousuu_code)))


receipt_medical_institution_CM_Targets %>% select(kojin_id, Group, iryokikan_no) %>% 
  left_join(m_hco_med) %>%
  select(Group, kojin_id, total_byoshousuu_code) %>% filter(total_byoshousuu_code!="0") %>%
  mutate(total_byoshousuu_code=as.numeric(total_byoshousuu_code)) %>%
  drop_na() %>%
  group_by(kojin_id) %>% filter(total_byoshousuu_code==max(total_byoshousuu_code)) %>% ungroup() %>%
  group_by(Group ) %>% summarise(n=mean(as.numeric(total_byoshousuu_code)))


# ----------------------------------------------------------------------------------
# Stocks / Flows diagram CM Vyndaqel patient funnel NEW RULES - Dx only in JsC facilities --------------------------

# Receipts IDs of the First Vyndaqel
receipt_drug_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_drug_Vyndaqel195pts.txt", colClasses = "character")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts[,.(receipt_ym, kojin_id, drug_code, receipt_id)]
receipt_drug_Vyndaqel195pts$receipt_ym <- as.Date(paste0(as.character(receipt_drug_Vyndaqel195pts$receipt_ym), '/01'))
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% filter(drug_code=="622278901")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% group_by(kojin_id) %>% filter(receipt_ym==min(receipt_ym))

# Facilities associated with that Vyndaqel receipt
receipt_medical_institution_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_medical_institution_Vyndaqel195pts.txt", colClasses = "character")
receipt_medical_institution_Vyndaqel195pts <- receipt_medical_institution_Vyndaqel195pts %>% select(kojin_id, receipt_ym, iryokikan_no, receipt_id)
receipt_medical_institution_Vyndaqel195pts$receipt_ym  <- as.Date(paste0(as.character(receipt_medical_institution_Vyndaqel195pts$receipt_ym ), '/01'))

temp <- receipt_drug_Vyndaqel195pts %>% 
  left_join(receipt_medical_institution_Vyndaqel195pts,
            by=c("kojin_id"="kojin_id", "receipt_id"="receipt_id", "receipt_ym"="receipt_ym")) 

length(unique(temp$kojin_id)) # 
length(unique(temp$iryokikan_no)) # # 

Vyndaqel_Facilities <- unique(temp$iryokikan_no)
Vyndaqel_Facilities <- as.data.frame(Vyndaqel_Facilities)
names(Vyndaqel_Facilities)[1] <- "iryokikan_no"


Cardiomyopathy_Pats <- fread("Cardiomyopathy_Pats.txt", colClasses = "character")
Cardiac_Amyloidosis_Pats <- fread("Cardiac_Amyloidosis_Pats.txt", colClasses = "character")
Cardiac_Amyloidosis_Pats <- Cardiac_Amyloidosis_Pats %>% select(1)
ATTR_CM_noVyn_Pats <- fread("ATTR_CM_noVyn_Pats.txt", colClasses = "character")
Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")
ATTR_CM_Vyndaqel_Pats <- Vyndaqel_pats_CM_vs_PN %>%filter(CM==1|Combo==1) %>%  select(kojin_id)
Cardiomyopathy_Pats$Group <- "Cardiomiopathy"
Cardiac_Amyloidosis_Pats$Group <-  "CardiacAMyloidosis"
ATTR_CM_noVyn_Pats$Group <- "ATTRCM_noVyn"
Target_CM_Pats <- Cardiomyopathy_Pats %>% bind_rows(Cardiac_Amyloidosis_Pats, ATTR_CM_noVyn_Pats)


receipt_medical_institution_CM_Targets <- fread("All_Pts_ContinuousEnrolled/receipt_medical_institution_CM_Targets.txt", sep="\t", colClasses = "character")
receipt_medical_institution_CM_Targets <- receipt_medical_institution_CM_Targets %>% select(kojin_id, iryokikan_no, receipt_ym, receipt_id) %>% distinct()
receipt_medical_institution_CM_Targets <- Target_CM_Pats %>% select(kojin_id) %>% left_join(receipt_medical_institution_CM_Targets)
receipt_medical_institution_CM_Targets <- receipt_medical_institution_CM_Targets %>% inner_join(Vyndaqel_Facilities)
receipt_medical_institution_CM_Targets <- receipt_medical_institution_CM_Targets %>% select(kojin_id, receipt_ym, receipt_id)


# Stocks / Flows diagram CM Vyndaqel patient funnel NEW RULES
tekiyo_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/tekiyo_All_ContEnr_pts.txt", colClasses = "character")
ContinuouslyEnrolled_Y3_tekiyo_weights <- fread("All_Pts_ContinuousEnrolled/ContinuouslyEnrolled_Y3_tekiyo_weights.txt", colClasses = "character")
tekiyo_All_ContEnr_pts <- tekiyo_All_ContEnr_pts %>% left_join(ContinuouslyEnrolled_Y3_tekiyo_weights %>% select(kojin_id, weight)) %>% select(kojin_id, weight)
sum(as.numeric(tekiyo_All_ContEnr_pts$weight)) # 
Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")
Vyndaqel_pats_CM_vs_PN <- Vyndaqel_pats_CM_vs_PN %>% select(kojin_id) 




# Is LAST 3 YEARS
short_I_receipt_diseases_facility_CM_Targets <- 
  fread("All_Pts_ContinuousEnrolled/short_I_receipt_diseases_facility_CM_Targets.txt", sep="\t", colClasses = "character")

short_I_receipt_diseases_facility_CM_Targets <- short_I_receipt_diseases_facility_CM_Targets %>% inner_join(Target_CM_Pats %>% select(kojin_id))
short_I_receipt_diseases_facility_CM_Targets <- short_I_receipt_diseases_facility_CM_Targets %>% inner_join(receipt_medical_institution_CM_Targets)

short_I_receipt_diseases_facility_CM_Targets <- short_I_receipt_diseases_facility_CM_Targets %>% filter(utagai_flg==1) %>% select(-utagai_flg)

short_I_receipt_diseases_facility_CM_Targets <- short_I_receipt_diseases_facility_CM_Targets %>% filter(receipt_ym<="2021/03")
short_I_receipt_diseases_facility_CM_Targets <- short_I_receipt_diseases_facility_CM_Targets %>% filter(receipt_ym>="2018/04")



short_I_receipt_diseases_facility_CM_Targets <- short_I_receipt_diseases_facility_CM_Targets %>% select(kojin_id, diseases_code) %>% distinct()
ATTR_SpecificCode <- short_I_receipt_diseases_facility_CM_Targets %>% filter(diseases_code=="8850066") %>% select(kojin_id) %>% distinct()


m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_I_receipt_diseases_facility_CM_Targets <- short_I_receipt_diseases_facility_CM_Targets %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code) %>% distinct()

short_I_receipt_diseases_facility_CM_Targets <- short_I_receipt_diseases_facility_CM_Targets %>% filter(grepl("I50",icd10_code)|grepl("I42",icd10_code)|grepl("I43",icd10_code))



short_I_receipt_diseases_facility_CM_Targets %>% filter(grepl("I42",icd10_code)|grepl("I43",icd10_code)) %>% filter(icd10_code!="I420"&
                                                                                                                  icd10_code!="I423"&
                                                                                                                  icd10_code!="I424"&
                                                                                                                  icd10_code!="I426"&
                                                                                                                  icd10_code!="I427") %>% select(kojin_id) %>% distinct() %>%
      anti_join(short_I_receipt_diseases_facility_CM_Targets %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
      anti_join(Vyndaqel_pats_CM_vs_PN) %>%
  select(kojin_id) %>% distinct()%>%
  left_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight)))  # 
short_I_receipt_diseases_facility_CM_Targets %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  anti_join(ATTR_SpecificCode) %>%
    anti_join(Vyndaqel_pats_CM_vs_PN) %>%
  inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 


short_I_receipt_diseases_facility_CM_Targets %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  inner_join(ATTR_SpecificCode) %>%
  anti_join(Vyndaqel_pats_CM_vs_PN) %>%
  inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 



# -----------------------------------------
# Flows to jSC - At which stage ? ---------------------------------------

receipt_drug_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_drug_Vyndaqel195pts.txt", colClasses = "character")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts[,.(receipt_ym, kojin_id, drug_code, receipt_id)]
receipt_drug_Vyndaqel195pts$receipt_ym <- as.Date(paste0(as.character(receipt_drug_Vyndaqel195pts$receipt_ym), '/01'))
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% filter(drug_code=="622278901")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% group_by(kojin_id) %>% filter(receipt_ym==min(receipt_ym))
# Facilities associated with that Vyndaqel receipt
receipt_medical_institution_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_medical_institution_Vyndaqel195pts.txt", colClasses = "character")
receipt_medical_institution_Vyndaqel195pts <- receipt_medical_institution_Vyndaqel195pts %>% select(kojin_id, receipt_ym, iryokikan_no, receipt_id)
receipt_medical_institution_Vyndaqel195pts$receipt_ym  <- as.Date(paste0(as.character(receipt_medical_institution_Vyndaqel195pts$receipt_ym ), '/01'))
temp <- receipt_drug_Vyndaqel195pts %>% 
  left_join(receipt_medical_institution_Vyndaqel195pts,
            by=c("kojin_id"="kojin_id", "receipt_id"="receipt_id", "receipt_ym"="receipt_ym")) 
length(unique(temp$kojin_id)) # 
length(unique(temp$iryokikan_no)) # # 
Vyndaqel_Facilities <- unique(temp$iryokikan_no)
Vyndaqel_Facilities <- as.data.frame(Vyndaqel_Facilities)
names(Vyndaqel_Facilities)[1] <- "iryokikan_no"
Vyndaqel_Facilities$Group <- "JsC"

receipt_diseases_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_diseases_Vyndaqel195pts.txt", colClasses = "character")
receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>%  filter(utagai_flg==0) %>% filter(diseases_code=="8850066") %>%
  select(kojin_id) %>% distinct() %>% left_join(receipt_diseases_Vyndaqel195pts) %>% filter(utagai_flg==0)
receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>% select(kojin_id, receipt_ym, receipt_id, diseases_code)

m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>% left_join(m_icd10) %>% distinct()

receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>% filter(grepl("I50",icd10_code)|grepl("I42",icd10_code)|grepl("I43",icd10_code))

receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>% filter(diseases_code=="8850066") %>% select(kojin_id) %>% distinct() %>% 
  inner_join(receipt_diseases_Vyndaqel195pts %>% filter(grepl("I42", icd10_code)|grepl("I43", icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
  inner_join(receipt_diseases_Vyndaqel195pts %>% filter(grepl("I50", icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
  left_join(receipt_diseases_Vyndaqel195pts)

receipt_medical_institution_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_medical_institution_Vyndaqel195pts.txt", colClasses = "character")
receipt_medical_institution_Vyndaqel195pts <- receipt_medical_institution_Vyndaqel195pts %>% select(kojin_id, receipt_ym, iryokikan_no, receipt_id)

receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>% inner_join(receipt_medical_institution_Vyndaqel195pts) %>% select(-c(receipt_ym ,receipt_id))
receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>% left_join(Vyndaqel_Facilities) %>% mutate(Group=ifelse(is.na(Group), "Unkown", Group))

temp <- receipt_diseases_Vyndaqel195pts %>% select(kojin_id) %>% distinct() %>%
  left_join(receipt_diseases_Vyndaqel195pts %>% filter(diseases_code=="8850066") %>% select(kojin_id, Group) %>% distinct() %>%
  filter(Group=="JsC") %>% rename("ATTR-CM"="Group")) %>% 
  left_join(receipt_diseases_Vyndaqel195pts %>% filter(icd10_code=="I431" & diseases_code!="8850066") %>% select(kojin_id, Group) %>% distinct() %>%
  filter(Group=="JsC") %>% rename("CardiacAmyloidosis"="Group")) %>%
  left_join(receipt_diseases_Vyndaqel195pts %>% filter( (grepl("I43", icd10_code) | grepl("I42", icd10_code) ) & icd10_code!="I431") %>% select(kojin_id, Group) %>% distinct() %>%
  filter(Group=="JsC") %>% rename("Cardiomyopathy"="Group")) %>%
  left_join(receipt_diseases_Vyndaqel195pts %>% filter(grepl("I50", icd10_code)) %>% select(kojin_id, Group) %>% distinct() %>%
  filter(Group=="JsC") %>% rename("HF"="Group"))


temp[is.na(temp)] <- "Unknown"

temp %>% group_by(`ATTR-CM`, CardiacAmyloidosis, Cardiomyopathy) %>% count()


# ---------------------------------------
# 195 vyndaqel patients -> Comorbidities Exclusion Criteria Profile Patient Journey  -------------------------------------------------


Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")
Vyndaqel_pats_CM_vs_PN <- Vyndaqel_pats_CM_vs_PN %>% select(kojin_id, PN, CM, Combo) 
Vyndaqel_pats_CM_vs_PN %>% group_by(PN, CM, Combo) %>% count()

receipt_diseases_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_diseases_Vyndaqel195pts.txt", 
                                         colClasses = "character")
receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>% select(receipt_ym, kojin_id, diseases_code)
m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_subdiv_code, icd10_subdiv_name_en)

temp <- receipt_diseases_Vyndaqel195pts %>% left_join(m_icd10) %>%
  select(kojin_id, icd10_subdiv_code) %>% distinct() %>%
  inner_join(Vyndaqel_pats_CM_vs_PN %>% filter(CM==1|Combo==1) %>% select(kojin_id))  %>%
  filter(icd10_subdiv_code != "")

length(unique(temp$kojin_id)) # 

temp %>% filter(grepl("E11", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct() # 
temp %>% filter(grepl("D50", icd10_subdiv_code)|
                  grepl("D51", icd10_subdiv_code)|
                  grepl("D52", icd10_subdiv_code)|
                  grepl("D53", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct() #

temp %>% filter(grepl("N18", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct() #

# temp %>% filter(grepl("N0", icd10_subdiv_code)|
#                   grepl("N1", icd10_subdiv_code)|
#                   grepl("N2", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct() #


temp %>% filter(grepl("K7", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct() # 


temp %>% filter(grepl("J4", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct() # 


temp %>% filter(grepl("E00", icd10_subdiv_code)|
                  grepl("E01", icd10_subdiv_code)|
                  grepl("E02", icd10_subdiv_code)|
                  grepl("E03", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct() # 

temp %>% filter(grepl("E03", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct() #

temp %>% filter(grepl("I2", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct() # 

temp %>% filter(grepl("I1", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct() # 

temp %>% filter(grepl("I34", icd10_subdiv_code)|
                  grepl("I35", icd10_subdiv_code)|
                  grepl("I36", icd10_subdiv_code)|
                  grepl("I37", icd10_subdiv_code)|
                  grepl("I38", icd10_subdiv_code)|
                  grepl("I39", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct()  # 

# ----------------------------------------------------------
# Cardiac Amyloidosis % Cardiomyopathy after removing codes from patient profile journey --------------------------

tekiyo_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/tekiyo_All_ContEnr_pts.txt", colClasses = "character")
ContinuouslyEnrolled_Y3_tekiyo_weights <- fread("All_Pts_ContinuousEnrolled/ContinuouslyEnrolled_Y3_tekiyo_weights.txt", colClasses = "character")
tekiyo_All_ContEnr_pts <- tekiyo_All_ContEnr_pts %>% left_join(ContinuouslyEnrolled_Y3_tekiyo_weights %>% select(kojin_id, weight)) %>% select(kojin_id, weight)
sum(as.numeric(tekiyo_All_ContEnr_pts$weight)) # 


Cardiomyopathy_Pats <- fread("Cardiomyopathy_Pats.txt", colClasses = "character")
Cardiac_Amyloidosis_Pats <- fread("Cardiac_Amyloidosis_Pats.txt", colClasses = "character")
Cardiac_Amyloidosis_Pats <- Cardiac_Amyloidosis_Pats %>% select(1)


short_i_receipt_diseases_Utagai_All_ContEnr_pts <- fread("All_Pts_Continuousenrolled/short_i_receipt_diseases_Utagai_All_ContEnr_pts.txt", colClasses = "character")
short_i_receipt_diseases_Utagai_All_ContEnr_pts <- short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% filter(utagai_flg==0)
short_i_receipt_diseases_Utagai_All_ContEnr_pts <- short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()
short_i_receipt_diseases_Utagai_All_ContEnr_pts <- Cardiomyopathy_Pats %>% full_join(Cardiac_Amyloidosis_Pats) %>% left_join(short_i_receipt_diseases_Utagai_All_ContEnr_pts)
short_i_receipt_diseases_Utagai_All_ContEnr_pts <- short_i_receipt_diseases_Utagai_All_ContEnr_pts



m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_subdiv_code)

short_i_receipt_diseases_Utagai_All_ContEnr_pts <- short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% left_join(m_icd10) %>% select(kojin_id, icd10_subdiv_code) %>% distinct()

Cardiomyopathy_Pats %>% left_join(tekiyo_All_ContEnr_pts) %>% summarise(n=1.37*sum(as.numeric(weight))) # 
Cardiac_Amyloidosis_Pats %>% left_join(tekiyo_All_ContEnr_pts) %>% summarise(n=1.37*sum(as.numeric(weight))) # 

                                                                        
Cardiomyopathy_Pats %>% 
  anti_join(short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% filter(grepl("I1", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct()) %>%
  left_join(tekiyo_All_ContEnr_pts) %>% summarise(n=1.37*sum(as.numeric(weight))) # 


Cardiomyopathy_Pats %>% 
  anti_join(short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% filter(grepl("I1", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct()) %>%
    anti_join(short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% filter(grepl("I25", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct()) %>%
  left_join(tekiyo_All_ContEnr_pts) %>% summarise(n=1.37*sum(as.numeric(weight))) # 

Cardiomyopathy_Pats %>% 
  anti_join(short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% filter(grepl("I1", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct()) %>%
    anti_join(short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% filter(grepl("I25", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct()) %>%
      anti_join(short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% filter(grepl("I34", icd10_subdiv_code)|
                  grepl("I35", icd10_subdiv_code)|
                  grepl("I36", icd10_subdiv_code)|
                  grepl("I37", icd10_subdiv_code)|
                  grepl("I38", icd10_subdiv_code)|
                  grepl("I39", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct()) %>%
  left_join(tekiyo_All_ContEnr_pts) %>% summarise(n=1.37*sum(as.numeric(weight))) # 

Cardiomyopathy_Pats %>% 
  anti_join(short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% filter(grepl("I1", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct()) %>%
    anti_join(short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% filter(grepl("I2", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct()) %>%
      anti_join(short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% filter(grepl("I34", icd10_subdiv_code)|
                  grepl("I35", icd10_subdiv_code)|
                  grepl("I36", icd10_subdiv_code)|
                  grepl("I37", icd10_subdiv_code)|
                  grepl("I38", icd10_subdiv_code)|
                  grepl("I39", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct()) %>%
  left_join(tekiyo_All_ContEnr_pts) %>% summarise(n=1.37*sum(as.numeric(weight))) # 


Cardiomyopathy_Pats %>% 
  anti_join(short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% filter(grepl("I1", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct()) %>%
    anti_join(short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% filter(grepl("I2", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct()) %>%
      anti_join(short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% filter(grepl("I34", icd10_subdiv_code)|
                  grepl("I35", icd10_subdiv_code)|
                  grepl("I36", icd10_subdiv_code)|
                  grepl("I37", icd10_subdiv_code)|
                  grepl("I38", icd10_subdiv_code)|
                  grepl("I39", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct()) %>%
      inner_join(short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% filter(grepl("I44", icd10_subdiv_code)|
                                                                              grepl("I45", icd10_subdiv_code)|
                                                                              grepl("I47", icd10_subdiv_code)|
                                                                              grepl("I48", icd10_subdiv_code)|
                                                                              grepl("I49", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct()) %>%
  left_join(tekiyo_All_ContEnr_pts) %>% summarise(n=1.37*sum(as.numeric(weight))) # 



Cardiomyopathy_Pats_short <- Cardiomyopathy_Pats %>% 
  anti_join(short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% filter(grepl("I1", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct()) %>%
    anti_join(short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% filter(grepl("I2", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct()) %>%
      anti_join(short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% filter(grepl("I34", icd10_subdiv_code)|
                  grepl("I35", icd10_subdiv_code)|
                  grepl("I36", icd10_subdiv_code)|
                  grepl("I37", icd10_subdiv_code)|
                  grepl("I38", icd10_subdiv_code)|
                  grepl("I39", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct()) %>%
      inner_join(short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% filter(grepl("I44", icd10_subdiv_code)|
                                                                              grepl("I45", icd10_subdiv_code)|
                                                                              grepl("I47", icd10_subdiv_code)|
                                                                              grepl("I48", icd10_subdiv_code)|
                                                                              grepl("I49", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct())



                                           
Cardiac_Amyloidosis_Pats %>% 
  anti_join(short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% filter(grepl("I1", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct()) %>%
  left_join(tekiyo_All_ContEnr_pts) %>% summarise(n=1.37*sum(as.numeric(weight))) # 

Cardiac_Amyloidosis_Pats %>% 
  anti_join(short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% filter(grepl("I1", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct()) %>%
    anti_join(short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% filter(grepl("I25", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct()) %>%
  left_join(tekiyo_All_ContEnr_pts) %>% summarise(n=1.37*sum(as.numeric(weight))) # 5,453

Cardiac_Amyloidosis_Pats %>% 
  anti_join(short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% filter(grepl("I1", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct()) %>%
    anti_join(short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% filter(grepl("I25", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct()) %>%
      anti_join(short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% filter(grepl("I34", icd10_subdiv_code)|
                  grepl("I35", icd10_subdiv_code)|
                  grepl("I36", icd10_subdiv_code)|
                  grepl("I37", icd10_subdiv_code)|
                  grepl("I38", icd10_subdiv_code)|
                  grepl("I39", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct()) %>%
  left_join(tekiyo_All_ContEnr_pts) %>% summarise(n=1.37*sum(as.numeric(weight))) # 

Cardiac_Amyloidosis_Pats %>% 
  anti_join(short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% filter(grepl("I1", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct()) %>%
    anti_join(short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% filter(grepl("I2", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct()) %>%
      anti_join(short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% filter(grepl("I34", icd10_subdiv_code)|
                  grepl("I35", icd10_subdiv_code)|
                  grepl("I36", icd10_subdiv_code)|
                  grepl("I37", icd10_subdiv_code)|
                  grepl("I38", icd10_subdiv_code)|
                  grepl("I39", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct()) %>%
  left_join(tekiyo_All_ContEnr_pts) %>% summarise(n=1.37*sum(as.numeric(weight))) # 

Cardiac_Amyloidosis_Pats %>% 
  anti_join(short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% filter(grepl("I1", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct()) %>%
    anti_join(short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% filter(grepl("I2", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct()) %>%
      anti_join(short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% filter(grepl("I34", icd10_subdiv_code)|
                  grepl("I35", icd10_subdiv_code)|
                  grepl("I36", icd10_subdiv_code)|
                  grepl("I37", icd10_subdiv_code)|
                  grepl("I38", icd10_subdiv_code)|
                  grepl("I39", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct()) %>%
      inner_join(short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% filter(grepl("I44", icd10_subdiv_code)|
                                                                              grepl("I45", icd10_subdiv_code)|
                                                                              grepl("I47", icd10_subdiv_code)|
                                                                              grepl("I48", icd10_subdiv_code)|
                                                                              grepl("I49", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct()) %>%
  left_join(tekiyo_All_ContEnr_pts) %>% summarise(n=1.37*sum(as.numeric(weight))) # 



Cardiac_Amyloidosis_Pats_short <- Cardiac_Amyloidosis_Pats %>% 
  anti_join(short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% filter(grepl("I1", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct()) %>%
    anti_join(short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% filter(grepl("I2", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct()) %>%
      anti_join(short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% filter(grepl("I34", icd10_subdiv_code)|
                  grepl("I35", icd10_subdiv_code)|
                  grepl("I36", icd10_subdiv_code)|
                  grepl("I37", icd10_subdiv_code)|
                  grepl("I38", icd10_subdiv_code)|
                  grepl("I39", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct()) %>%
      inner_join(short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% filter(grepl("I44", icd10_subdiv_code)|
                                                                              grepl("I45", icd10_subdiv_code)|
                                                                              grepl("I47", icd10_subdiv_code)|
                                                                              grepl("I48", icd10_subdiv_code)|
                                                                              grepl("I49", icd10_subdiv_code)) %>% select(kojin_id) %>% distinct())



Cardiomyopathy_Pats_short
Cardiac_Amyloidosis_Pats_short




# CONFIRMED Is
short_i_receipt_diseases_Utagai_All_ContEnr_pts <- fread("All_Pts_Continuousenrolled/short_i_receipt_diseases_Utagai_All_ContEnr_pts.txt", colClasses = "character")
short_i_receipt_diseases_Utagai_All_ContEnr_pts <- short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% filter(utagai_flg==0)
short_i_receipt_diseases_Utagai_All_ContEnr_pts <- short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()
short_i_receipt_diseases_Utagai_All_ContEnr_pts <- Cardiomyopathy_Pats_short %>% full_join(Cardiac_Amyloidosis_Pats_short) %>% left_join(short_i_receipt_diseases_Utagai_All_ContEnr_pts)

# CONFIRMED Es
short_e_receipt_diseases_Utagai_All_ContEnr_pts <- fread("All_Pts_Continuousenrolled/short_e_receipt_diseases_Utagai_All_ContEnr_pts.txt", colClasses = "character")
short_e_receipt_diseases_Utagai_All_ContEnr_pts <- short_e_receipt_diseases_Utagai_All_ContEnr_pts %>% filter(utagai_flg==0)
short_e_receipt_diseases_Utagai_All_ContEnr_pts <- short_e_receipt_diseases_Utagai_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()
short_e_receipt_diseases_Utagai_All_ContEnr_pts <- Cardiomyopathy_Pats_short %>% full_join(Cardiac_Amyloidosis_Pats_short) %>% left_join(short_e_receipt_diseases_Utagai_All_ContEnr_pts)

# CONFIRMED Gs
short_g_receipt_diseases_Utagai_All_ContEnr_pts <- fread("All_Pts_Continuousenrolled/short_g_receipt_diseases_Utagai_All_ContEnr_pts.txt", colClasses = "character")
short_g_receipt_diseases_Utagai_All_ContEnr_pts <- short_g_receipt_diseases_Utagai_All_ContEnr_pts %>% filter(utagai_flg==0)
short_g_receipt_diseases_Utagai_All_ContEnr_pts <- short_g_receipt_diseases_Utagai_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()
short_g_receipt_diseases_Utagai_All_ContEnr_pts <- Cardiomyopathy_Pats_short %>% full_join(Cardiac_Amyloidosis_Pats_short) %>% left_join(short_g_receipt_diseases_Utagai_All_ContEnr_pts)


ALL_Dxs <- short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% bind_rows(short_e_receipt_diseases_Utagai_All_ContEnr_pts) %>% bind_rows(short_g_receipt_diseases_Utagai_All_ContEnr_pts) %>% distinct() %>% drop_na()


m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_subdiv_code)

ALL_Dxs <- ALL_Dxs %>%
  left_join(m_icd10) %>%
  select(kojin_id, icd10_subdiv_code) %>% distinct()

temp <- Cardiac_Amyloidosis_Pats_short %>% inner_join(ALL_Dxs) %>%
  group_by(icd10_subdiv_code) %>% count() %>% mutate(n=n/40) %>% arrange(-n) %>% rename("CardiacAmyloidosis"="n") %>%
  full_join(Cardiomyopathy_Pats_short %>% inner_join(ALL_Dxs) %>%
  group_by(icd10_subdiv_code) %>% count() %>% mutate(n=n/2906) %>% arrange(-n) %>% rename("Cardiomyopathy"="n"))

temp[is.na(temp)] <- 0
temp <- temp %>% mutate(Diff=CardiacAmyloidosis-Cardiomyopathy) %>% arrange(-Diff)

data.frame(temp)

# --------------------------------
# Cardiac Amyloidosis vs Cardiomyopathy random forest --------------------------

Cardiomyopathy_Pats <- fread("Cardiomyopathy_Pats.txt", colClasses = "character")
Cardiac_Amyloidosis_Pats <- fread("Cardiac_Amyloidosis_Pats.txt", colClasses = "character")
Cardiac_Amyloidosis_Pats <- Cardiac_Amyloidosis_Pats %>% select(1)

# CONFIRMED Is
short_i_receipt_diseases_Utagai_All_ContEnr_pts <- fread("All_Pts_Continuousenrolled/short_i_receipt_diseases_Utagai_All_ContEnr_pts.txt", colClasses = "character")
short_i_receipt_diseases_Utagai_All_ContEnr_pts <- short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% filter(utagai_flg==0)
short_i_receipt_diseases_Utagai_All_ContEnr_pts <- short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()
short_i_receipt_diseases_Utagai_All_ContEnr_pts <- Cardiomyopathy_Pats %>% full_join(Cardiac_Amyloidosis_Pats) %>% left_join(short_i_receipt_diseases_Utagai_All_ContEnr_pts)

# CONFIRMED Es
short_e_receipt_diseases_Utagai_All_ContEnr_pts <- fread("All_Pts_Continuousenrolled/short_e_receipt_diseases_Utagai_All_ContEnr_pts.txt", colClasses = "character")
short_e_receipt_diseases_Utagai_All_ContEnr_pts <- short_e_receipt_diseases_Utagai_All_ContEnr_pts %>% filter(utagai_flg==0)
short_e_receipt_diseases_Utagai_All_ContEnr_pts <- short_e_receipt_diseases_Utagai_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()
short_e_receipt_diseases_Utagai_All_ContEnr_pts <- Cardiomyopathy_Pats %>% full_join(Cardiac_Amyloidosis_Pats) %>% left_join(short_e_receipt_diseases_Utagai_All_ContEnr_pts)

# CONFIRMED Gs
short_g_receipt_diseases_Utagai_All_ContEnr_pts <- fread("All_Pts_Continuousenrolled/short_g_receipt_diseases_Utagai_All_ContEnr_pts.txt", colClasses = "character")
short_g_receipt_diseases_Utagai_All_ContEnr_pts <- short_g_receipt_diseases_Utagai_All_ContEnr_pts %>% filter(utagai_flg==0)
short_g_receipt_diseases_Utagai_All_ContEnr_pts <- short_g_receipt_diseases_Utagai_All_ContEnr_pts %>% select(kojin_id, diseases_code) %>% distinct()
short_g_receipt_diseases_Utagai_All_ContEnr_pts <- Cardiomyopathy_Pats %>% full_join(Cardiac_Amyloidosis_Pats) %>% left_join(short_g_receipt_diseases_Utagai_All_ContEnr_pts)

ALL_Dxs <- short_i_receipt_diseases_Utagai_All_ContEnr_pts %>% bind_rows(short_e_receipt_diseases_Utagai_All_ContEnr_pts) %>% bind_rows(short_g_receipt_diseases_Utagai_All_ContEnr_pts) %>% distinct() %>% drop_na()

m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_subdiv_code)

ALL_Dxs <- ALL_Dxs %>%
  left_join(m_icd10) %>%
  select(kojin_id, icd10_subdiv_code) %>% distinct()


temp <- Cardiomyopathy_Pats %>% mutate(Group="Cardiomyopathy") %>% left_join(ALL_Dxs) %>%
  distinct() %>%
  bind_rows(
    Cardiac_Amyloidosis_Pats %>% mutate(Group="CardiacAmyloidosis") %>% left_join(ALL_Dxs) %>%
  distinct()
  )

temp <- temp %>% filter(grepl("I",icd10_subdiv_code)|grepl("E",icd10_subdiv_code)|grepl("G",icd10_subdiv_code))

temp <- temp %>% mutate(Treat=1) %>% ungroup() %>% spread(key=icd10_subdiv_code, value=Treat)

temp[is.na(temp)] <- 0

temp$Group <- as.factor(temp$Group)

temp$Group <- relevel(temp$Group,"Cardiomyopathy")

temp2 <- temp %>% select(-kojin_id)

temp2 <- temp2 %>% group_by(Group) %>% sample_n(307)

library("randomForest")
temp_rf <- randomForest(Group ~ . , data = temp2)
summary(temp_rf)
temp_rf$importance


library("gbm")
GLP1_gbm <- gbm(Group == "CardiacAmyloidosis" ~ ., data = temp2, 
                n.trees = 15000, distribution = "bernoulli")
summary(GLP1_gbm)


# ----------------------------------------------------
# % Scintigraphy Before vs After CM or CA -----------------------------------

Procedure_master <- fread("Masters/Procedure_master.csv", colClasses = "character")

Cardiomyopathy_Pats <- fread("Cardiomyopathy_Pats.txt", colClasses = "character")
Cardiac_Amyloidosis_Pats <- fread("Cardiac_Amyloidosis_Pats.txt", colClasses = "character")
Cardiac_Amyloidosis_Pats <- Cardiac_Amyloidosis_Pats[,1]


short_i_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_i_receipt_diseases_utagai_All_ContEnr_pts.txt", colClasses = "character")

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(utagai_flg==0) %>% select(-utagai_flg)

m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)

short_i_receipt_diseases_All_ContEnr_pts <- Cardiomyopathy_Pats %>% select(kojin_id) %>% distinct() %>%
  full_join(Cardiac_Amyloidosis_Pats) %>% select(kojin_id) %>% distinct() %>%
  left_join(short_i_receipt_diseases_All_ContEnr_pts)

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% left_join(m_icd10) %>% select(kojin_id, receipt_ym, icd10_code) %>% distinct()
short_i_receipt_diseases_All_ContEnr_pts$receipt_ym <- as.Date(paste0(as.character(short_i_receipt_diseases_All_ContEnr_pts$receipt_ym), '/01'))

Cardiomyopathy_Pats <- Cardiomyopathy_Pats %>% left_join(short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I43",icd10_code)|grepl("I42",icd10_code))) %>%
  group_by(kojin_id) %>% filter(receipt_ym==min(receipt_ym)) %>% slice(1) %>% select(-icd10_code) %>% rename("FirstCardiomiopathy"="receipt_ym")

Cardiac_Amyloidosis_Pats <- Cardiac_Amyloidosis_Pats %>% left_join(short_i_receipt_diseases_All_ContEnr_pts %>% filter(icd10_code=="I431")) %>%
  group_by(kojin_id) %>% filter(receipt_ym==min(receipt_ym)) %>% slice(1)  %>% select(-icd10_code) %>% rename("FirstI431"="receipt_ym")


short_procedures_receipt_medical_practice_All_ContEnr_pts <- fread("All_Pts_Continuousenrolled/short_procedures_receipt_medical_practice_All_ContEnr_pts.txt", colClasses = "character")
short_procedures_receipt_medical_practice_All_ContEnr_pts <- short_procedures_receipt_medical_practice_All_ContEnr_pts %>% select(kojin_id, medical_practice_code, receipt_ym) %>% distinct()
short_procedures_receipt_medical_practice_All_ContEnr_pts <- Cardiomyopathy_Pats %>% select(kojin_id) %>% distinct() %>%
                                                              full_join(Cardiac_Amyloidosis_Pats) %>% select(kojin_id) %>% distinct() %>% 
                                                              left_join(short_procedures_receipt_medical_practice_All_ContEnr_pts)
short_procedures_receipt_medical_practice_All_ContEnr_pts$receipt_ym <- as.Date(paste0(as.character(short_procedures_receipt_medical_practice_All_ContEnr_pts$receipt_ym), '/01'))

short_procedures_receipt_medical_practice_All_ContEnr_pts <- 
  short_procedures_receipt_medical_practice_All_ContEnr_pts %>% 
  left_join(Procedure_master, 
            by=c("medical_practice_code"="standardized_procedure_code")) %>%
  select(kojin_id, standardized_procedure_name, receipt_ym) %>% distinct()

short_procedures_receipt_medical_practice_All_ContEnr_pts <- short_procedures_receipt_medical_practice_All_ContEnr_pts %>%
                                              filter(grepl("computerized tomog", standardized_procedure_name)|
                                                     grepl("CT imaging", standardized_procedure_name)|
                                                     grepl("nuclear medicine diagnosis", standardized_procedure_name)|
                                                     grepl("scintigraphy", standardized_procedure_name)|
                                                     grepl("MRI", standardized_procedure_name)|
                                                     grepl("electrocardiog", standardized_procedure_name)|
                                                     grepl("ECG", standardized_procedure_name)|
                                                     grepl("ultrasonography", standardized_procedure_name)|
                                                     grepl("SPECT", standardized_procedure_name)|
                                                     grepl("PET ", standardized_procedure_name)|
                                                     grepl("percutaneous needle biopsy", standardized_procedure_name)|
                                                     grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name)|
                                                     grepl("endoscopic biopsy", standardized_procedure_name)|
                                                     grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name)|
                                                     grepl("brain natriuretic peptide", standardized_procedure_name)|
                                                     grepl("BNP", standardized_procedure_name)|
                                                     grepl("troponin", standardized_procedure_name)|
                                                     grepl("genetic test", standardized_procedure_name)|
                                                     grepl("cardiac catheterization", standardized_procedure_name)|
                                                     grepl("Holter", standardized_procedure_name)|
                                                     grepl("pacemaker", standardized_procedure_name)|
                                                     grepl("gene-related", standardized_procedure_name)|
                                                     grepl("exercise test", standardized_procedure_name)|
                                                     grepl("hospitalization", standardized_procedure_name)|
                                                     grepl("serum amyloid A protein", standardized_procedure_name)|
                                                     grepl("prealbumin", standardized_procedure_name)|
                                                     grepl("transthyretin", standardized_procedure_name)|
                                                     grepl("amylase", standardized_procedure_name))

short_procedures_receipt_medical_practice_All_ContEnr_pts <-
  short_procedures_receipt_medical_practice_All_ContEnr_pts %>% mutate(standardized_procedure_name=
                                                     ifelse(grepl("computerized tomog",standardized_procedure_name), "CT",
                                                            ifelse(grepl("CT imaging,", standardized_procedure_name), "CT",
                                                                   ifelse(grepl("nuclear medicine diagnosis", standardized_procedure_name), "other nuclear medicine",
                                                                          ifelse(grepl("scintigraphy", standardized_procedure_name), "scintigraphy",
                                                                                 ifelse(grepl("MRI", standardized_procedure_name), "MRI",
                                                                                        ifelse(grepl("electrocardiog", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ECG", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ultrasonography", standardized_procedure_name), "ultrasonography",
                                                                                                      ifelse(grepl("SPECT", standardized_procedure_name), "scintigraphy",
                                                                                                             ifelse(grepl("PET ", standardized_procedure_name), "scintigraphy",
                                                                                                      ifelse(grepl("percutaneous needle biopsy", standardized_procedure_name), "biopsy",
                                                                                                             ifelse(grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("endoscopic biopsy", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name), "heart biopsy",
                                                                                                                           ifelse(grepl("brain natriuretic peptide", standardized_procedure_name), "BNP",
                                                                                                                                  ifelse(grepl("BNP", standardized_procedure_name), "BNP",
                                                                                                                                         ifelse(grepl("troponin", standardized_procedure_name), "troponin",
                                                                                                                                                ifelse(grepl("genetic test", standardized_procedure_name), "genetic test",
                                                                                                                                                       ifelse(grepl("cardiac catheterization", standardized_procedure_name), "cardiac catheterization",
                                                                                                                                                              ifelse(grepl("Holter", standardized_procedure_name), "Holter",
                                                                                                                                                                     ifelse(grepl("pacemaker", standardized_procedure_name), "pacemaker",
                                                                                                                                                                            ifelse(grepl("gene-related", standardized_procedure_name), "genetic test",
                                                                                                                                                                                          ifelse(grepl("exercise test", standardized_procedure_name), "exercise test",
                                                                                                                                                                                                 ifelse(grepl("hospitalization", standardized_procedure_name), "hospitalization",
                                                                                                                                                                                                        ifelse(grepl("serum amyloid A protein", standardized_procedure_name), "AmyloidA",
                                                                                                                                                                                                               ifelse(grepl("prealbumin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("transthyretin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("amylase", standardized_procedure_name), "amylase",NA)))))))))))))))))))))))))))))
                                                                   

short_procedures_receipt_medical_practice_All_ContEnr_pts <- short_procedures_receipt_medical_practice_All_ContEnr_pts %>% mutate(standardized_procedure_name=ifelse(is.na(standardized_procedure_name),"CT", standardized_procedure_name))

short_procedures_receipt_medical_practice_All_ContEnr_pts <- short_procedures_receipt_medical_practice_All_ContEnr_pts %>% filter(standardized_procedure_name=="scintigraphy") %>% 
  filter(receipt_ym==min(receipt_ym)) %>% slice(1)  %>%
  select(kojin_id, receipt_ym) %>% rename("FirstScinti"="receipt_ym")

Cardiomyopathy_Pats %>% left_join(short_procedures_receipt_medical_practice_All_ContEnr_pts) %>%
  drop_na() %>% # 2362
  filter(FirstCardiomiopathy   > FirstScinti) # 

Cardiomyopathy_Pats %>% left_join(short_procedures_receipt_medical_practice_All_ContEnr_pts) %>%
  drop_na() %>% # 2362
  filter(FirstCardiomiopathy   <= FirstScinti) 

Cardiac_Amyloidosis_Pats %>% left_join(short_procedures_receipt_medical_practice_All_ContEnr_pts) %>%
  drop_na() %>% # 154
  filter(FirstI431     > FirstScinti) # 

Cardiac_Amyloidosis_Pats %>% left_join(short_procedures_receipt_medical_practice_All_ContEnr_pts) %>%
  drop_na() %>% # 154
  filter(FirstI431     <= FirstScinti) # 


# ---------------------------------------------------------------------
# Time CA to Vyndaqel (Scintigraphy before vs after) -------------------------------------------

receipt_medical_practice_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_medical_practice_Vyndaqel195pts.txt", colClasses = "character")
receipt_medical_practice_Vyndaqel195pts <- receipt_medical_practice_Vyndaqel195pts[,.(receipt_ym, kojin_id, medical_practice_code)]
receipt_medical_practice_Vyndaqel195pts$receipt_ym <- as.Date(paste0(as.character(receipt_medical_practice_Vyndaqel195pts$receipt_ym), '/01'))

Procedure_master <- fread("Masters/Procedure_master.csv", colClasses = "character")

receipt_medical_practice_Vyndaqel195pts <- 
  receipt_medical_practice_Vyndaqel195pts %>% 
  left_join(Procedure_master, 
            by=c("medical_practice_code"="standardized_procedure_code")) %>%
  select(kojin_id, receipt_ym, medical_practice_code, standardized_procedure_name) 
 

receipt_medical_practice_Vyndaqel195pts <- receipt_medical_practice_Vyndaqel195pts %>%
                                              filter(grepl("computerized tomog", standardized_procedure_name)|
                                                     grepl("CT imaging", standardized_procedure_name)|
                                                     grepl("nuclear medicine diagnosis", standardized_procedure_name)|
                                                     grepl("scintigraphy", standardized_procedure_name)|
                                                     grepl("MRI", standardized_procedure_name)|
                                                     grepl("electrocardiog", standardized_procedure_name)|
                                                     grepl("ECG", standardized_procedure_name)|
                                                     grepl("ultrasonography", standardized_procedure_name)|
                                                     grepl("SPECT", standardized_procedure_name)|
                                                     grepl("PET ", standardized_procedure_name)|
                                                     grepl("percutaneous needle biopsy", standardized_procedure_name)|
                                                     grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name)|
                                                     grepl("endoscopic biopsy", standardized_procedure_name)|
                                                     grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name)|
                                                     grepl("brain natriuretic peptide", standardized_procedure_name)|
                                                     grepl("BNP", standardized_procedure_name)|
                                                     grepl("troponin", standardized_procedure_name)|
                                                     grepl("genetic test", standardized_procedure_name)|
                                                     grepl("cardiac catheterization", standardized_procedure_name)|
                                                     grepl("Holter", standardized_procedure_name)|
                                                     grepl("pacemaker", standardized_procedure_name)|
                                                     grepl("gene-related", standardized_procedure_name)|
                                                     grepl("exercise test", standardized_procedure_name)|
                                                     grepl("hospitalization", standardized_procedure_name)|
                                                     grepl("serum amyloid A protein", standardized_procedure_name)|
                                                     grepl("prealbumin", standardized_procedure_name)|
                                                     grepl("transthyretin", standardized_procedure_name)|
                                                     grepl("amylase", standardized_procedure_name))

unique(receipt_medical_practice_Vyndaqel195pts$medical_practice_code)


receipt_medical_practice_Vyndaqel195pts <-
  receipt_medical_practice_Vyndaqel195pts %>% mutate(standardized_procedure_name=
                                                     ifelse(grepl("computerized tomog",standardized_procedure_name), "CT",
                                                            ifelse(grepl("CT imaging,", standardized_procedure_name), "CT",
                                                                   ifelse(grepl("nuclear medicine diagnosis", standardized_procedure_name), "other nuclear medicine",
                                                                          ifelse(grepl("scintigraphy", standardized_procedure_name), "scintigraphy",
                                                                                 ifelse(grepl("MRI", standardized_procedure_name), "MRI",
                                                                                        ifelse(grepl("electrocardiog", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ECG", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ultrasonography", standardized_procedure_name), "ultrasonography",
                                                                                                      ifelse(grepl("SPECT", standardized_procedure_name), "scintigraphy",
                                                                                                             ifelse(grepl("PET ", standardized_procedure_name), "scintigraphy",
                                                                                                      ifelse(grepl("percutaneous needle biopsy", standardized_procedure_name), "biopsy",
                                                                                                             ifelse(grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("endoscopic biopsy", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name), "heart biopsy",
                                                                                                                           ifelse(grepl("brain natriuretic peptide", standardized_procedure_name), "BNP",
                                                                                                                                  ifelse(grepl("BNP", standardized_procedure_name), "BNP",
                                                                                                                                         ifelse(grepl("troponin", standardized_procedure_name), "troponin",
                                                                                                                                                ifelse(grepl("genetic test", standardized_procedure_name), "genetic test",
                                                                                                                                                       ifelse(grepl("cardiac catheterization", standardized_procedure_name), "cardiac catheterization",
                                                                                                                                                              ifelse(grepl("Holter", standardized_procedure_name), "Holter",
                                                                                                                                                                     ifelse(grepl("pacemaker", standardized_procedure_name), "pacemaker",
                                                                                                                                                                            ifelse(grepl("gene-related", standardized_procedure_name), "genetic test",
                                                                                                                                                                                          ifelse(grepl("exercise test", standardized_procedure_name), "exercise test",
                                                                                                                                                                                                 ifelse(grepl("hospitalization", standardized_procedure_name), "hospitalization",
                                                                                                                                                                                                        ifelse(grepl("serum amyloid A protein", standardized_procedure_name), "AmyloidA",
                                                                                                                                                                                                               ifelse(grepl("prealbumin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("transthyretin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("amylase", standardized_procedure_name), "amylase",NA)))))))))))))))))))))))))))))
                                                                   

receipt_medical_practice_Vyndaqel195pts <- receipt_medical_practice_Vyndaqel195pts %>% mutate(standardized_procedure_name=ifelse(is.na(standardized_procedure_name),"CT", standardized_procedure_name))


First_scintigraphy <- receipt_medical_practice_Vyndaqel195pts %>% filter(standardized_procedure_name=="scintigraphy") %>%
  group_by(kojin_id) %>% filter(receipt_ym==min(receipt_ym)) %>% slice(1) %>% select(kojin_id, receipt_ym)
names(First_scintigraphy)[2] <- "First_scintigraphy"





receipt_diseases_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_diseases_Vyndaqel195pts.txt", colClasses = "character")
receipt_diseases_Vyndaqel195pts <- receipt_diseases_Vyndaqel195pts %>% select(receipt_ym, kojin_id, diseases_code, receipt_id)
m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_subdiv_code, icd10_subdiv_name_en)
receipt_diseases_Vyndaqel195pts$receipt_ym <- as.Date(paste0(as.character(receipt_diseases_Vyndaqel195pts$receipt_ym), '/01'))

First_CA <- receipt_diseases_Vyndaqel195pts %>% left_join(m_icd10) %>%
  select(kojin_id, receipt_ym , icd10_subdiv_code, receipt_id) %>% distinct() %>%
    filter(grepl("I431",icd10_subdiv_code)) %>% group_by(kojin_id) %>% filter(receipt_ym==min(receipt_ym)) %>% slice(1) %>%
  select(kojin_id, receipt_ym)
names(First_CA)[2] <- "First_CA"

receipt_drug_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_drug_Vyndaqel195pts.txt", colClasses = "character")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts[,.(receipt_ym, kojin_id, drug_code, receipt_id)]
receipt_drug_Vyndaqel195pts$receipt_ym <- as.Date(paste0(as.character(receipt_drug_Vyndaqel195pts$receipt_ym), '/01'))
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% filter(drug_code=="622278901")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% group_by(kojin_id) %>% filter(receipt_ym==min(receipt_ym))
First_Vyndaqel <-  receipt_drug_Vyndaqel195pts %>% select(kojin_id, receipt_ym) %>% distinct()
names(First_Vyndaqel)[2] <- "FirstVyndaqel"


First_Vyndaqel %>% left_join(First_CA) %>% left_join(First_scintigraphy) %>%
  filter(!is.na(First_CA)) %>%
  mutate(Diff=as.numeric(First_CA-FirstVyndaqel)/30.5) %>%
  ungroup() %>% filter(Diff>=0) %>% 
  drop_na() %>%
  filter(First_scintigraphy<First_CA) %>%
  summarise(n=mean(Diff))


# ---------------------------------------------------------
# Type of facility for Cardiomyopathy, Cardiac Amyloidosis All Dxs --------------------------------------------------
  

Cardiomyopathy_Pats <- fread("Cardiomyopathy_Pats.txt", colClasses = "character")
Cardiac_Amyloidosis_Pats <- fread("Cardiac_Amyloidosis_Pats.txt", colClasses = "character")
Cardiac_Amyloidosis_Pats <- Cardiac_Amyloidosis_Pats[,1]


short_i_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_i_receipt_diseases_utagai_All_ContEnr_pts.txt", colClasses = "character")
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(utagai_flg==0) %>% select(-utagai_flg)
m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)

short_i_receipt_diseases_All_ContEnr_pts <- Cardiomyopathy_Pats %>% full_join(Cardiac_Amyloidosis_Pats) %>% left_join(short_i_receipt_diseases_All_ContEnr_pts)
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% left_join(m_icd10) %>% select(kojin_id, receipt_ym, icd10_code) %>% distinct()

CM_Dx <- short_i_receipt_diseases_All_ContEnr_pts %>% filter( (grepl("I42",icd10_code)|grepl("I43",icd10_code)) & icd10_code!="I431" ) %>% select(kojin_id, receipt_ym)
CA_Dx <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(icd10_code=="I431" ) %>% select(kojin_id, receipt_ym)



receipt_medical_institution_CM_Targets <- fread("All_Pts_ContinuousEnrolled/receipt_medical_institution_CM_Targets.txt", sep="\t", colClasses = "character")
receipt_medical_institution_CM_Targets <- receipt_medical_institution_CM_Targets %>%  select(kojin_id, iryokikan_no, receipt_ym ) %>% distinct()

CM_Dx <- receipt_medical_institution_CM_Targets %>% inner_join(CM_Dx)
CA_Dx <- receipt_medical_institution_CM_Targets %>% inner_join(CA_Dx)

m_hco_med <- fread("Masters/m_hco_med.csv",  colClasses = "character")


CM_Dx %>% select(kojin_id, iryokikan_no) %>% 
  left_join(m_hco_med) %>%
  select(kojin_id, shisetsu_kbn_code) %>% 
  group_by(shisetsu_kbn_code ) %>% count()

CA_Dx %>% select(kojin_id, iryokikan_no) %>% 
  left_join(m_hco_med) %>%
  select(kojin_id, shisetsu_kbn_code) %>% 
  group_by(shisetsu_kbn_code ) %>% count()

# -------------------------------------------------
# Type of facility for Cardiomyopathy, Cardiac Amyloidosis 1st --------------------------------------------------
  

Cardiomyopathy_Pats <- fread("Cardiomyopathy_Pats.txt", colClasses = "character")
Cardiac_Amyloidosis_Pats <- fread("Cardiac_Amyloidosis_Pats.txt", colClasses = "character")
Cardiac_Amyloidosis_Pats <- Cardiac_Amyloidosis_Pats[,1]


short_i_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_i_receipt_diseases_utagai_All_ContEnr_pts.txt", colClasses = "character")
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(utagai_flg==0) %>% select(-utagai_flg)
m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)

short_i_receipt_diseases_All_ContEnr_pts <- Cardiomyopathy_Pats %>% full_join(Cardiac_Amyloidosis_Pats) %>% left_join(short_i_receipt_diseases_All_ContEnr_pts)
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% left_join(m_icd10) %>% select(kojin_id, receipt_ym, icd10_code) %>% distinct()

CM_Dx <- short_i_receipt_diseases_All_ContEnr_pts %>% filter( (grepl("I42",icd10_code)|grepl("I43",icd10_code)) & icd10_code!="I431" ) %>% select(kojin_id, receipt_ym) %>% group_by(kojin_id) %>% filter(receipt_ym==min(receipt_ym)) %>% slice(1)
CA_Dx <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(icd10_code=="I431" ) %>% select(kojin_id, receipt_ym) %>% group_by(kojin_id) %>% filter(receipt_ym==min(receipt_ym)) %>% slice(1)



receipt_medical_institution_CM_Targets <- fread("All_Pts_ContinuousEnrolled/receipt_medical_institution_CM_Targets.txt", sep="\t", colClasses = "character")
receipt_medical_institution_CM_Targets <- receipt_medical_institution_CM_Targets %>%  select(kojin_id, iryokikan_no, receipt_ym ) %>% distinct()

CM_Dx <- receipt_medical_institution_CM_Targets %>% inner_join(CM_Dx)
CA_Dx <- receipt_medical_institution_CM_Targets %>% inner_join(CA_Dx)

m_hco_med <- fread("Masters/m_hco_med.csv",  colClasses = "character")


CM_Dx %>% select(kojin_id, iryokikan_no) %>% 
  left_join(m_hco_med) %>%
  select(kojin_id, shisetsu_kbn_code) %>% 
  group_by(shisetsu_kbn_code ) %>% count()

CA_Dx %>% select(kojin_id, iryokikan_no) %>% 
  left_join(m_hco_med) %>%
  select(kojin_id, shisetsu_kbn_code) %>% 
  group_by(shisetsu_kbn_code ) %>% count()


# ------------------------------------
# No. Cardiac Amyloidosis Dxs vs No. Scintigraphies per facility --------------------------------------------------
  
short_i_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_i_receipt_diseases_utagai_All_ContEnr_pts.txt", colClasses = "character")
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(utagai_flg==0) %>% select(-utagai_flg)
m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% left_join(m_icd10) %>% select(kojin_id, receipt_ym, icd10_code) %>% distinct()
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(icd10_code=="I431" ) %>% select(kojin_id, receipt_ym) %>% distinct()

receipt_medical_institution_CM_Targets <- fread("All_Pts_ContinuousEnrolled/receipt_medical_institution_CM_Targets.txt", sep="\t", colClasses = "character")
receipt_medical_institution_CM_Targets <- receipt_medical_institution_CM_Targets %>%  select(kojin_id, iryokikan_no, receipt_ym ) %>% distinct()

short_i_receipt_diseases_All_ContEnr_pts <- receipt_medical_institution_CM_Targets %>% inner_join(short_i_receipt_diseases_All_ContEnr_pts)

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% select(kojin_id, iryokikan_no) %>% distinct()

length(unique(short_i_receipt_diseases_All_ContEnr_pts$kojin_id)) # 
short_i_receipt_diseases_All_ContEnr_pts %>% group_by(iryokikan_no) %>% count() %>% arrange(-n)



short_procedures_receipt_medical_practice_All_ContEnr_pts <- fread("All_Pts_Continuousenrolled/short_procedures_receipt_medical_practice_All_ContEnr_pts.txt", colClasses = "character")
short_procedures_receipt_medical_practice_All_ContEnr_pts <- short_procedures_receipt_medical_practice_All_ContEnr_pts %>% select(kojin_id, medical_practice_code, receipt_ym) %>% distinct()
short_procedures_receipt_medical_practice_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% select(kojin_id) %>% distinct() %>% left_join(short_procedures_receipt_medical_practice_All_ContEnr_pts)

Procedure_master <- fread("Masters/Procedure_master.csv", colClasses = "character")

short_procedures_receipt_medical_practice_All_ContEnr_pts <- 
  short_procedures_receipt_medical_practice_All_ContEnr_pts %>% 
  left_join(Procedure_master, 
            by=c("medical_practice_code"="standardized_procedure_code")) %>%
  select(kojin_id, standardized_procedure_name, receipt_ym) %>% distinct()

short_procedures_receipt_medical_practice_All_ContEnr_pts <- short_procedures_receipt_medical_practice_All_ContEnr_pts %>%
                                              filter(grepl("computerized tomog", standardized_procedure_name)|
                                                     grepl("CT imaging", standardized_procedure_name)|
                                                     grepl("nuclear medicine diagnosis", standardized_procedure_name)|
                                                     grepl("scintigraphy", standardized_procedure_name)|
                                                     grepl("MRI", standardized_procedure_name)|
                                                     grepl("electrocardiog", standardized_procedure_name)|
                                                     grepl("ECG", standardized_procedure_name)|
                                                     grepl("ultrasonography", standardized_procedure_name)|
                                                     grepl("SPECT", standardized_procedure_name)|
                                                     grepl("PET ", standardized_procedure_name)|
                                                     grepl("percutaneous needle biopsy", standardized_procedure_name)|
                                                     grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name)|
                                                     grepl("endoscopic biopsy", standardized_procedure_name)|
                                                     grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name)|
                                                     grepl("brain natriuretic peptide", standardized_procedure_name)|
                                                     grepl("BNP", standardized_procedure_name)|
                                                     grepl("troponin", standardized_procedure_name)|
                                                     grepl("genetic test", standardized_procedure_name)|
                                                     grepl("cardiac catheterization", standardized_procedure_name)|
                                                     grepl("Holter", standardized_procedure_name)|
                                                     grepl("pacemaker", standardized_procedure_name)|
                                                     grepl("gene-related", standardized_procedure_name)|
                                                     grepl("exercise test", standardized_procedure_name)|
                                                     grepl("hospitalization", standardized_procedure_name)|
                                                     grepl("serum amyloid A protein", standardized_procedure_name)|
                                                     grepl("prealbumin", standardized_procedure_name)|
                                                     grepl("transthyretin", standardized_procedure_name)|
                                                     grepl("amylase", standardized_procedure_name))

short_procedures_receipt_medical_practice_All_ContEnr_pts <-
  short_procedures_receipt_medical_practice_All_ContEnr_pts %>% mutate(standardized_procedure_name=
                                                     ifelse(grepl("computerized tomog",standardized_procedure_name), "CT",
                                                            ifelse(grepl("CT imaging,", standardized_procedure_name), "CT",
                                                                   ifelse(grepl("nuclear medicine diagnosis", standardized_procedure_name), "other nuclear medicine",
                                                                          ifelse(grepl("scintigraphy", standardized_procedure_name), "scintigraphy",
                                                                                 ifelse(grepl("MRI", standardized_procedure_name), "MRI",
                                                                                        ifelse(grepl("electrocardiog", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ECG", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ultrasonography", standardized_procedure_name), "ultrasonography",
                                                                                                      ifelse(grepl("SPECT", standardized_procedure_name), "scintigraphy",
                                                                                                             ifelse(grepl("PET ", standardized_procedure_name), "scintigraphy",
                                                                                                      ifelse(grepl("percutaneous needle biopsy", standardized_procedure_name), "biopsy",
                                                                                                             ifelse(grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("endoscopic biopsy", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name), "heart biopsy",
                                                                                                                           ifelse(grepl("brain natriuretic peptide", standardized_procedure_name), "BNP",
                                                                                                                                  ifelse(grepl("BNP", standardized_procedure_name), "BNP",
                                                                                                                                         ifelse(grepl("troponin", standardized_procedure_name), "troponin",
                                                                                                                                                ifelse(grepl("genetic test", standardized_procedure_name), "genetic test",
                                                                                                                                                       ifelse(grepl("cardiac catheterization", standardized_procedure_name), "cardiac catheterization",
                                                                                                                                                              ifelse(grepl("Holter", standardized_procedure_name), "Holter",
                                                                                                                                                                     ifelse(grepl("pacemaker", standardized_procedure_name), "pacemaker",
                                                                                                                                                                            ifelse(grepl("gene-related", standardized_procedure_name), "genetic test",
                                                                                                                                                                                          ifelse(grepl("exercise test", standardized_procedure_name), "exercise test",
                                                                                                                                                                                                 ifelse(grepl("hospitalization", standardized_procedure_name), "hospitalization",
                                                                                                                                                                                                        ifelse(grepl("serum amyloid A protein", standardized_procedure_name), "AmyloidA",
                                                                                                                                                                                                               ifelse(grepl("prealbumin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("transthyretin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("amylase", standardized_procedure_name), "amylase",NA)))))))))))))))))))))))))))))
                                                                   

short_procedures_receipt_medical_practice_All_ContEnr_pts <- short_procedures_receipt_medical_practice_All_ContEnr_pts %>% mutate(standardized_procedure_name=ifelse(is.na(standardized_procedure_name),"CT", standardized_procedure_name))

short_procedures_receipt_medical_practice_All_ContEnr_pts <- short_procedures_receipt_medical_practice_All_ContEnr_pts %>% filter(standardized_procedure_name=="scintigraphy") %>% select(kojin_id, receipt_ym) %>% distinct() 



receipt_medical_institution_CM_Targets <- fread("All_Pts_ContinuousEnrolled/receipt_medical_institution_CM_Targets.txt", sep="\t", colClasses = "character")
receipt_medical_institution_CM_Targets <- receipt_medical_institution_CM_Targets %>%  select(kojin_id, iryokikan_no, receipt_ym ) %>% distinct()

short_procedures_receipt_medical_practice_All_ContEnr_pts <- receipt_medical_institution_CM_Targets %>% inner_join(short_procedures_receipt_medical_practice_All_ContEnr_pts)

short_procedures_receipt_medical_practice_All_ContEnr_pts <- short_procedures_receipt_medical_practice_All_ContEnr_pts %>% select(kojin_id, iryokikan_no) %>% distinct()


short_i_receipt_diseases_All_ContEnr_pts %>% group_by(iryokikan_no) %>% count() %>% arrange(-n) %>%
  rename("No_CA_Dxs"=n) %>%
  full_join(
    short_procedures_receipt_medical_practice_All_ContEnr_pts %>% group_by(iryokikan_no) %>% count() %>% arrange(-n) %>%
  rename("No_Scintig"=n) 
  ) %>% ungroup() %>%
  ggplot(aes(No_Scintig, No_CA_Dxs )) +
  #geom_smooth(colour="red4", fill="plum4") +
  geom_jitter(size=3, alpha=0.7) +
  xlab("\n No Scintigraphies Performed") + ylab("No. of Cardiac Amyloidosis patients diagnosed \n") +
  theme_minimal()




# Normalize by number of CM patients
short_i_receipt_diseases_All_ContEnr_pts_CM <- fread("All_Pts_ContinuousEnrolled/short_i_receipt_diseases_utagai_All_ContEnr_pts.txt", colClasses = "character")
short_i_receipt_diseases_All_ContEnr_pts_CM <- short_i_receipt_diseases_All_ContEnr_pts_CM %>% filter(utagai_flg==0) %>% select(-utagai_flg)
m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_i_receipt_diseases_All_ContEnr_pts_CM <- short_i_receipt_diseases_All_ContEnr_pts_CM %>% left_join(m_icd10) %>% select(kojin_id, receipt_ym, icd10_code) %>% distinct()
short_i_receipt_diseases_All_ContEnr_pts_CM <- short_i_receipt_diseases_All_ContEnr_pts_CM %>% filter( (grepl("I43",icd10_code)|grepl("I42",icd10_code)) & icd10_code!= "I431" ) %>% select(kojin_id, receipt_ym) %>% distinct()

receipt_medical_institution_CM_Targets_CM <- fread("All_Pts_ContinuousEnrolled/receipt_medical_institution_CM_Targets.txt", sep="\t", colClasses = "character")
receipt_medical_institution_CM_Targets_CM <- receipt_medical_institution_CM_Targets_CM %>%  select(kojin_id, iryokikan_no, receipt_ym ) %>% distinct()

short_i_receipt_diseases_All_ContEnr_pts_CM <- receipt_medical_institution_CM_Targets_CM %>% inner_join(short_i_receipt_diseases_All_ContEnr_pts_CM)

short_i_receipt_diseases_All_ContEnr_pts_CM <- short_i_receipt_diseases_All_ContEnr_pts_CM %>% select(kojin_id, iryokikan_no) %>% distinct()

length(unique(short_i_receipt_diseases_All_ContEnr_pts_CM$kojin_id)) # 
short_i_receipt_diseases_All_ContEnr_pts_CM %>% group_by(iryokikan_no) %>% count() %>% arrange(-n) %>% rename("No_CM_Pats"="n")


short_i_receipt_diseases_All_ContEnr_pts %>% group_by(iryokikan_no) %>% count() %>% arrange(-n) %>%
  rename("No_CA_Dxs"=n) %>%
  full_join(
    short_procedures_receipt_medical_practice_All_ContEnr_pts %>% group_by(iryokikan_no) %>% count() %>% arrange(-n) %>%
  rename("No_Scintig"=n) 
  ) %>% ungroup() %>%
 # left_join(short_i_receipt_diseases_All_ContEnr_pts_CM %>% group_by(iryokikan_no) %>% count() %>% arrange(-n) %>% rename("No_CM_Pats"="n")) %>%
  #mutate(No_CA_Dxs=No_CA_Dxs/No_CM_Pats) %>%
  m#utate(No_Scintig=No_Scintig/No_CM_Pats) %>%
  ggplot(aes(No_Scintig, No_CA_Dxs )) +
  geom_smooth(colour="red4", fill="plum4") +
  #geom_jitter(size=3, alpha=0.7) +
  xlab("\n No Scintigraphies Performed") + ylab("No. of Cardiac Amyloidosis patients diagnosed \n") +
  theme_minimal()



# ----------------------------------------------
  # No. Cardiomyopathy Dxs vs No. Scintigraphies per facility --------------------------------------------------

short_i_receipt_diseases_All_ContEnr_pts_CM <- fread("All_Pts_ContinuousEnrolled/short_i_receipt_diseases_utagai_All_ContEnr_pts.txt", colClasses = "character")
short_i_receipt_diseases_All_ContEnr_pts_CM <- short_i_receipt_diseases_All_ContEnr_pts_CM %>% filter(utagai_flg==0) %>% select(-utagai_flg)
m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_i_receipt_diseases_All_ContEnr_pts_CM <- short_i_receipt_diseases_All_ContEnr_pts_CM %>% left_join(m_icd10) %>% select(kojin_id, receipt_ym, icd10_code) %>% distinct()
short_i_receipt_diseases_All_ContEnr_pts_CM <- short_i_receipt_diseases_All_ContEnr_pts_CM %>% filter( (grepl("I43",icd10_code)|grepl("I42",icd10_code)) & icd10_code!= "I431" ) %>% select(kojin_id, receipt_ym) %>% distinct()

receipt_medical_institution_CM_Targets_CM <- fread("All_Pts_ContinuousEnrolled/receipt_medical_institution_CM_Targets.txt", sep="\t", colClasses = "character")
receipt_medical_institution_CM_Targets_CM <- receipt_medical_institution_CM_Targets_CM %>%  select(kojin_id, iryokikan_no, receipt_ym ) %>% distinct()

short_i_receipt_diseases_All_ContEnr_pts_CM <- receipt_medical_institution_CM_Targets_CM %>% inner_join(short_i_receipt_diseases_All_ContEnr_pts_CM)

short_i_receipt_diseases_All_ContEnr_pts_CM <- short_i_receipt_diseases_All_ContEnr_pts_CM %>% select(kojin_id, iryokikan_no) %>% distinct()

length(unique(short_i_receipt_diseases_All_ContEnr_pts_CM$kojin_id)) # 
short_i_receipt_diseases_All_ContEnr_pts_CM %>% group_by(iryokikan_no) %>% count() %>% arrange(-n) %>% rename("No_CM_Pats"="n")





short_procedures_receipt_medical_practice_All_ContEnr_pts <- fread("All_Pts_Continuousenrolled/short_procedures_receipt_medical_practice_All_ContEnr_pts.txt", colClasses = "character")
short_procedures_receipt_medical_practice_All_ContEnr_pts <- short_procedures_receipt_medical_practice_All_ContEnr_pts %>% select(kojin_id, medical_practice_code, receipt_ym) %>% distinct()
short_procedures_receipt_medical_practice_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts_CM %>% select(kojin_id) %>% distinct() %>% left_join(short_procedures_receipt_medical_practice_All_ContEnr_pts)

Procedure_master <- fread("Masters/Procedure_master.csv", colClasses = "character")

short_procedures_receipt_medical_practice_All_ContEnr_pts <- 
  short_procedures_receipt_medical_practice_All_ContEnr_pts %>% 
  left_join(Procedure_master, 
            by=c("medical_practice_code"="standardized_procedure_code")) %>%
  select(kojin_id, standardized_procedure_name, receipt_ym) %>% distinct()

short_procedures_receipt_medical_practice_All_ContEnr_pts <- short_procedures_receipt_medical_practice_All_ContEnr_pts %>%
                                              filter(grepl("computerized tomog", standardized_procedure_name)|
                                                     grepl("CT imaging", standardized_procedure_name)|
                                                     grepl("nuclear medicine diagnosis", standardized_procedure_name)|
                                                     grepl("scintigraphy", standardized_procedure_name)|
                                                     grepl("MRI", standardized_procedure_name)|
                                                     grepl("electrocardiog", standardized_procedure_name)|
                                                     grepl("ECG", standardized_procedure_name)|
                                                     grepl("ultrasonography", standardized_procedure_name)|
                                                     grepl("SPECT", standardized_procedure_name)|
                                                     grepl("PET ", standardized_procedure_name)|
                                                     grepl("percutaneous needle biopsy", standardized_procedure_name)|
                                                     grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name)|
                                                     grepl("endoscopic biopsy", standardized_procedure_name)|
                                                     grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name)|
                                                     grepl("brain natriuretic peptide", standardized_procedure_name)|
                                                     grepl("BNP", standardized_procedure_name)|
                                                     grepl("troponin", standardized_procedure_name)|
                                                     grepl("genetic test", standardized_procedure_name)|
                                                     grepl("cardiac catheterization", standardized_procedure_name)|
                                                     grepl("Holter", standardized_procedure_name)|
                                                     grepl("pacemaker", standardized_procedure_name)|
                                                     grepl("gene-related", standardized_procedure_name)|
                                                     grepl("exercise test", standardized_procedure_name)|
                                                     grepl("hospitalization", standardized_procedure_name)|
                                                     grepl("serum amyloid A protein", standardized_procedure_name)|
                                                     grepl("prealbumin", standardized_procedure_name)|
                                                     grepl("transthyretin", standardized_procedure_name)|
                                                     grepl("amylase", standardized_procedure_name))

short_procedures_receipt_medical_practice_All_ContEnr_pts <-
  short_procedures_receipt_medical_practice_All_ContEnr_pts %>% mutate(standardized_procedure_name=
                                                     ifelse(grepl("computerized tomog",standardized_procedure_name), "CT",
                                                            ifelse(grepl("CT imaging,", standardized_procedure_name), "CT",
                                                                   ifelse(grepl("nuclear medicine diagnosis", standardized_procedure_name), "other nuclear medicine",
                                                                          ifelse(grepl("scintigraphy", standardized_procedure_name), "scintigraphy",
                                                                                 ifelse(grepl("MRI", standardized_procedure_name), "MRI",
                                                                                        ifelse(grepl("electrocardiog", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ECG", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ultrasonography", standardized_procedure_name), "ultrasonography",
                                                                                                      ifelse(grepl("SPECT", standardized_procedure_name), "scintigraphy",
                                                                                                             ifelse(grepl("PET ", standardized_procedure_name), "scintigraphy",
                                                                                                      ifelse(grepl("percutaneous needle biopsy", standardized_procedure_name), "biopsy",
                                                                                                             ifelse(grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("endoscopic biopsy", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name), "heart biopsy",
                                                                                                                           ifelse(grepl("brain natriuretic peptide", standardized_procedure_name), "BNP",
                                                                                                                                  ifelse(grepl("BNP", standardized_procedure_name), "BNP",
                                                                                                                                         ifelse(grepl("troponin", standardized_procedure_name), "troponin",
                                                                                                                                                ifelse(grepl("genetic test", standardized_procedure_name), "genetic test",
                                                                                                                                                       ifelse(grepl("cardiac catheterization", standardized_procedure_name), "cardiac catheterization",
                                                                                                                                                              ifelse(grepl("Holter", standardized_procedure_name), "Holter",
                                                                                                                                                                     ifelse(grepl("pacemaker", standardized_procedure_name), "pacemaker",
                                                                                                                                                                            ifelse(grepl("gene-related", standardized_procedure_name), "genetic test",
                                                                                                                                                                                          ifelse(grepl("exercise test", standardized_procedure_name), "exercise test",
                                                                                                                                                                                                 ifelse(grepl("hospitalization", standardized_procedure_name), "hospitalization",
                                                                                                                                                                                                        ifelse(grepl("serum amyloid A protein", standardized_procedure_name), "AmyloidA",
                                                                                                                                                                                                               ifelse(grepl("prealbumin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("transthyretin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("amylase", standardized_procedure_name), "amylase",NA)))))))))))))))))))))))))))))
                                                                   

short_procedures_receipt_medical_practice_All_ContEnr_pts <- short_procedures_receipt_medical_practice_All_ContEnr_pts %>% mutate(standardized_procedure_name=ifelse(is.na(standardized_procedure_name),"CT", standardized_procedure_name))

short_procedures_receipt_medical_practice_All_ContEnr_pts <- short_procedures_receipt_medical_practice_All_ContEnr_pts %>% filter(standardized_procedure_name=="scintigraphy") %>% select(kojin_id, receipt_ym) %>% distinct() 



receipt_medical_institution_CM_Targets <- fread("All_Pts_ContinuousEnrolled/receipt_medical_institution_CM_Targets.txt", sep="\t", colClasses = "character")
receipt_medical_institution_CM_Targets <- receipt_medical_institution_CM_Targets %>%  select(kojin_id, iryokikan_no, receipt_ym ) %>% distinct()

short_procedures_receipt_medical_practice_All_ContEnr_pts <- receipt_medical_institution_CM_Targets %>% inner_join(short_procedures_receipt_medical_practice_All_ContEnr_pts)

short_procedures_receipt_medical_practice_All_ContEnr_pts <- short_procedures_receipt_medical_practice_All_ContEnr_pts %>% select(kojin_id, iryokikan_no) %>% distinct()


short_i_receipt_diseases_All_ContEnr_pts_CM %>% group_by(iryokikan_no) %>% count() %>% arrange(-n) %>%
  rename("No_CM_Dxs"=n) %>%
  full_join(
    short_procedures_receipt_medical_practice_All_ContEnr_pts %>% group_by(iryokikan_no) %>% count() %>% arrange(-n) %>%
  rename("No_Scintig"=n) 
  ) %>% ungroup() %>%
  ggplot(aes(No_Scintig, No_CM_Dxs )) +
  #geom_smooth(colour="midnightblue", fill="deepskyblue3") +
  geom_jitter(size=1, alpha=0.7) +
  xlab("\n No Scintigraphies Performed") + ylab("No. of Cardiomyopathy patients diagnosed \n") +
  theme_minimal()



# -------------------------------------------------------
# Stocks / Flows diagram CM Vyndaqel patient funnel NEW RULES - Dx only in JsC facilities Flows origine between boxes --------------------------

# Receipts IDs of the First Vyndaqel
receipt_drug_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_drug_Vyndaqel195pts.txt", colClasses = "character")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts[,.(receipt_ym, kojin_id, drug_code, receipt_id)]
receipt_drug_Vyndaqel195pts$receipt_ym <- as.Date(paste0(as.character(receipt_drug_Vyndaqel195pts$receipt_ym), '/01'))
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% filter(drug_code=="622278901")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% group_by(kojin_id) %>% filter(receipt_ym==min(receipt_ym))

# Facilities associated with that Vyndaqel receipt
receipt_medical_institution_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_medical_institution_Vyndaqel195pts.txt", colClasses = "character")
receipt_medical_institution_Vyndaqel195pts <- receipt_medical_institution_Vyndaqel195pts %>% select(kojin_id, receipt_ym, iryokikan_no, receipt_id)
receipt_medical_institution_Vyndaqel195pts$receipt_ym  <- as.Date(paste0(as.character(receipt_medical_institution_Vyndaqel195pts$receipt_ym ), '/01'))

temp <- receipt_drug_Vyndaqel195pts %>% 
  left_join(receipt_medical_institution_Vyndaqel195pts,
            by=c("kojin_id"="kojin_id", "receipt_id"="receipt_id", "receipt_ym"="receipt_ym")) 

length(unique(temp$kojin_id)) # 195
length(unique(temp$iryokikan_no)) # # 53

Vyndaqel_Facilities <- unique(temp$iryokikan_no)
Vyndaqel_Facilities <- as.data.frame(Vyndaqel_Facilities)
names(Vyndaqel_Facilities)[1] <- "iryokikan_no"


Cardiomyopathy_Pats <- fread("Cardiomyopathy_Pats.txt", colClasses = "character")
Cardiac_Amyloidosis_Pats <- fread("Cardiac_Amyloidosis_Pats.txt", colClasses = "character")
Cardiac_Amyloidosis_Pats <- Cardiac_Amyloidosis_Pats %>% select(1)
ATTR_CM_noVyn_Pats <- fread("ATTR_CM_noVyn_Pats.txt", colClasses = "character")
Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")
ATTR_CM_Vyndaqel_Pats <- Vyndaqel_pats_CM_vs_PN %>%filter(CM==1|Combo==1) %>%  select(kojin_id)
Cardiomyopathy_Pats$Group <- "Cardiomiopathy"
Cardiac_Amyloidosis_Pats$Group <-  "CardiacAMyloidosis"
ATTR_CM_noVyn_Pats$Group <- "ATTRCM_noVyn"
Target_CM_Pats <- Cardiomyopathy_Pats %>% bind_rows(Cardiac_Amyloidosis_Pats, ATTR_CM_noVyn_Pats)


receipt_medical_institution_CM_Targets <- fread("All_Pts_ContinuousEnrolled/receipt_medical_institution_CM_Targets.txt", sep="\t", colClasses = "character")
receipt_medical_institution_CM_Targets <- receipt_medical_institution_CM_Targets %>% select(kojin_id, iryokikan_no, receipt_ym, receipt_id) %>% distinct()
receipt_medical_institution_CM_Targets <- Target_CM_Pats %>% select(kojin_id) %>% left_join(receipt_medical_institution_CM_Targets)
receipt_medical_institution_CM_Targets <- receipt_medical_institution_CM_Targets %>% inner_join(Vyndaqel_Facilities)
receipt_medical_institution_CM_Targets <- receipt_medical_institution_CM_Targets %>% select(kojin_id, receipt_ym, receipt_id)


# Stocks / Flows diagram CM Vyndaqel patient funnel NEW RULES
tekiyo_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/tekiyo_All_ContEnr_pts.txt", colClasses = "character")
ContinuouslyEnrolled_Y3_tekiyo_weights <- fread("All_Pts_ContinuousEnrolled/ContinuouslyEnrolled_Y3_tekiyo_weights.txt", colClasses = "character")
tekiyo_All_ContEnr_pts <- tekiyo_All_ContEnr_pts %>% left_join(ContinuouslyEnrolled_Y3_tekiyo_weights %>% select(kojin_id, weight)) %>% select(kojin_id, weight)
sum(as.numeric(tekiyo_All_ContEnr_pts$weight)) # 26009563
Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")
Vyndaqel_pats_CM_vs_PN <- Vyndaqel_pats_CM_vs_PN %>% select(kojin_id) 




# Is LAST 3 YEARS
short_I_receipt_diseases_facility_CM_Targets <- 
  fread("All_Pts_ContinuousEnrolled/short_I_receipt_diseases_facility_CM_Targets.txt", sep="\t", colClasses = "character")

short_I_receipt_diseases_facility_CM_Targets <- short_I_receipt_diseases_facility_CM_Targets %>% inner_join(Target_CM_Pats %>% select(kojin_id))
short_I_receipt_diseases_facility_CM_Targets <- short_I_receipt_diseases_facility_CM_Targets %>% inner_join(receipt_medical_institution_CM_Targets)

short_I_receipt_diseases_facility_CM_Targets <- short_I_receipt_diseases_facility_CM_Targets %>% filter(utagai_flg==0) %>% select(-utagai_flg)

short_I_receipt_diseases_facility_CM_Targets <- short_I_receipt_diseases_facility_CM_Targets %>% filter(receipt_ym<="2021/03")
short_I_receipt_diseases_facility_CM_Targets <- short_I_receipt_diseases_facility_CM_Targets %>% filter(receipt_ym>="2018/04")



short_I_receipt_diseases_facility_CM_Targets <- short_I_receipt_diseases_facility_CM_Targets %>% select(kojin_id, diseases_code) %>% distinct()
ATTR_SpecificCode <- short_I_receipt_diseases_facility_CM_Targets %>% filter(diseases_code=="8850066") %>% select(kojin_id) %>% distinct()


m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_I_receipt_diseases_facility_CM_Targets <- short_I_receipt_diseases_facility_CM_Targets %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code) %>% distinct()

short_I_receipt_diseases_facility_CM_Targets <- short_I_receipt_diseases_facility_CM_Targets %>% filter(grepl("I50",icd10_code)|grepl("I42",icd10_code)|grepl("I43",icd10_code))



short_I_receipt_diseases_facility_CM_Targets %>% filter(grepl("I42",icd10_code)|grepl("I43",icd10_code)) %>% filter(icd10_code!="I420"&
                                                                                                                  icd10_code!="I423"&
                                                                                                                  icd10_code!="I424"&
                                                                                                                  icd10_code!="I426"&
                                                                                                                  icd10_code!="I427") %>% select(kojin_id) %>% distinct() %>%
      anti_join(short_I_receipt_diseases_facility_CM_Targets %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
      anti_join(Vyndaqel_pats_CM_vs_PN) %>%
  select(kojin_id) %>% distinct()%>%
  left_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight)))  # 

JsC_CM <- short_I_receipt_diseases_facility_CM_Targets %>% filter(grepl("I42",icd10_code)|grepl("I43",icd10_code)) %>% filter(icd10_code!="I420"&
                                                                                                                  icd10_code!="I423"&
                                                                                                                  icd10_code!="I424"&
                                                                                                                  icd10_code!="I426"&
                                                                                                                  icd10_code!="I427") %>% select(kojin_id) %>% distinct() %>%
      anti_join(short_I_receipt_diseases_facility_CM_Targets %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
      anti_join(Vyndaqel_pats_CM_vs_PN) %>%
  select(kojin_id) %>% distinct()

short_I_receipt_diseases_facility_CM_Targets %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  anti_join(ATTR_SpecificCode) %>%
    anti_join(Vyndaqel_pats_CM_vs_PN) %>%
  inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 


JsC_CA <- short_I_receipt_diseases_facility_CM_Targets %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  anti_join(ATTR_SpecificCode) %>%
    anti_join(Vyndaqel_pats_CM_vs_PN)

short_I_receipt_diseases_facility_CM_Targets %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  inner_join(ATTR_SpecificCode) %>%
  anti_join(Vyndaqel_pats_CM_vs_PN) %>%
  inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 


JsC_ATTR <- short_I_receipt_diseases_facility_CM_Targets %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  inner_join(ATTR_SpecificCode) %>%
  anti_join(Vyndaqel_pats_CM_vs_PN) 



short_I_receipt_diseases_facility_CM_Targets <- 
  fread("All_Pts_ContinuousEnrolled/short_I_receipt_diseases_facility_CM_Targets.txt", sep="\t", colClasses = "character")

JsC_ATTR %>% full_join(JsC_CA) %>% full_join(JsC_CM)
short_I_receipt_diseases_facility_CM_Targets <- JsC_ATTR %>% full_join(JsC_CA) %>% full_join(JsC_CM) %>% left_join(short_I_receipt_diseases_facility_CM_Targets)
short_I_receipt_diseases_facility_CM_Targets <- short_I_receipt_diseases_facility_CM_Targets %>% filter(utagai_flg==0) %>% select(-utagai_flg)
short_I_receipt_diseases_facility_CM_Targets <- short_I_receipt_diseases_facility_CM_Targets %>% filter(receipt_ym<="2021/03")
short_I_receipt_diseases_facility_CM_Targets <- short_I_receipt_diseases_facility_CM_Targets %>% filter(receipt_ym>="2018/04")


m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_I_receipt_diseases_facility_CM_Targets <- short_I_receipt_diseases_facility_CM_Targets %>% left_join(m_icd10) 

short_I_receipt_diseases_facility_CM_Targets <- short_I_receipt_diseases_facility_CM_Targets %>% filter(grepl("I42",icd10_code)|grepl("I43",icd10_code)|grepl("I50",icd10_code))

JsC_CM <- JsC_CM %>% left_join(short_I_receipt_diseases_facility_CM_Targets) 
JsC_CA <- JsC_CA %>% left_join(short_I_receipt_diseases_facility_CM_Targets) 
JsC_ATTR <- JsC_ATTR %>% left_join(short_I_receipt_diseases_facility_CM_Targets) 

JsC_CM <- JsC_CM %>% select(kojin_id, receipt_ym, receipt_id, diseases_code, icd10_code)
JsC_CA <- JsC_CA %>% select(kojin_id, receipt_ym, receipt_id, diseases_code, icd10_code)
JsC_ATTR <- JsC_ATTR %>% select(kojin_id, receipt_ym, receipt_id, diseases_code, icd10_code)


receipt_medical_institution_CM_Targets <- fread("All_Pts_ContinuousEnrolled/receipt_medical_institution_CM_Targets.txt", sep="\t", colClasses = "character")
receipt_medical_institution_CM_Targets <- receipt_medical_institution_CM_Targets %>% select(kojin_id, iryokikan_no, receipt_ym, receipt_id) %>% distinct()

JsC_CM <- JsC_CM %>% left_join(receipt_medical_institution_CM_Targets)
JsC_CA <- JsC_CA %>% left_join(receipt_medical_institution_CM_Targets)
JsC_ATTR <- JsC_ATTR %>% left_join(receipt_medical_institution_CM_Targets)

Vyndaqel_Facilities$Group <- "VyndaqelFacility"


JsC_CM <- JsC_CM %>% left_join(Vyndaqel_Facilities)
JsC_CA <- JsC_CA %>% left_join(Vyndaqel_Facilities)
JsC_ATTR <- JsC_ATTR %>% left_join(Vyndaqel_Facilities)

JsC_CM %>% group_by(kojin_id) %>% filter(receipt_id==min(receipt_id)) %>% slice(1) %>% ungroup() %>%
  left_join(tekiyo_All_ContEnr_pts) %>% group_by(Group) %>% summarise(n=1.37*sum(as.numeric(weight)))

JsC_CA %>% group_by(kojin_id) %>% filter(receipt_id==min(receipt_id)) %>% slice(1) %>% ungroup() %>%
  left_join(tekiyo_All_ContEnr_pts) %>% group_by(Group) %>% summarise(n=1.37*sum(as.numeric(weight)))

JsC_ATTR %>% group_by(kojin_id) %>% filter(receipt_id==min(receipt_id)) %>% slice(1) %>% ungroup() %>%
  left_join(tekiyo_All_ContEnr_pts) %>% group_by(Group) %>% summarise(n=1.37*sum(as.numeric(weight)))



data.frame(JsC_CM %>% group_by(kojin_id) %>% filter(receipt_id==min(receipt_id)) %>% slice(1) %>% ungroup() %>%
  left_join(tekiyo_All_ContEnr_pts) %>% group_by(icd10_code, Group) %>% summarise(n=1.37*sum(as.numeric(weight))))


JsC_CA %>% group_by(kojin_id) %>% filter(receipt_id==min(receipt_id)) %>% slice(1) %>% ungroup() %>%
  left_join(tekiyo_All_ContEnr_pts) %>% group_by(icd10_code, diseases_code, Group) %>% summarise(n=1.37*sum(as.numeric(weight)))


JsC_ATTR %>% group_by(kojin_id) %>% filter(receipt_id==min(receipt_id)) %>% slice(1) %>% ungroup() %>%
  left_join(tekiyo_All_ContEnr_pts) %>% group_by(icd10_code, diseases_code , Group) %>% summarise(n=1.37*sum(as.numeric(weight)))


# ----------------------------------------------------------
# Fetch All procedures from Target CM patients, with receip_id for facility tracking -----------------------------------------

Cardiomyopathy_Pats <- fread("Cardiomyopathy_Pats.txt", colClasses = "character")
Cardiac_Amyloidosis_Pats <- fread("Cardiac_Amyloidosis_Pats.txt", colClasses = "character")
Cardiac_Amyloidosis_Pats <- Cardiac_Amyloidosis_Pats %>% select(1)
ATTR_CM_noVyn_Pats <- fread("ATTR_CM_noVyn_Pats.txt", colClasses = "character")

Target_CM_Pats <- Cardiomyopathy_Pats %>% bind_rows(Cardiac_Amyloidosis_Pats, ATTR_CM_noVyn_Pats)

pagify <- function(data = NULL, by = 1000){
    pagemin <- seq(1,length(data), by = by)
    pagemax <- pagemin - 1 + by
    pagemax[length(pagemax)] <- length(data)
    pages   <- list(min = pagemin, max = pagemax)
  }
  
  
pages <- pagify(Target_CM_Pats$kojin_id, 100)
  


receipt_medical_practice_Target_CM <- data.table()


for(i in 1:length(pages$max)) {
    cat(i)
    start <- Sys.time()
    pts <- paste0(Target_CM_Pats$kojin_id[pages$min[i]:pages$max[i]], collapse = "','")
    query <- paste0("SELECT receipt_ym, kojin_id, medical_practice_code, receipt_id FROM vyndaqel.short_procedures_receipt_medical_practice WHERE kojin_id IN ('",pts,"');")
    data  <- setDT(dbGetQuery(con, query))
    receipt_medical_practice_Target_CM <- rbind(receipt_medical_practice_Target_CM, data)
    end   <- Sys.time()
    print(end - start)
}


fwrite(receipt_medical_practice_Target_CM, "All_Pts_ContinuousEnrolled/receipt_medical_practice_Target_CM.txt", sep="\t")



# --------------------------------------------------
  # No. Cardiomyopathy Dxs vs No. Scintigraphies per facility with known receipt_id --------------------------------------------------
Cardiomyopathy_Pats <- fread("Cardiomyopathy_Pats.txt", colClasses = "character")
Cardiac_Amyloidosis_Pats <- fread("Cardiac_Amyloidosis_Pats.txt", colClasses = "character")
Cardiac_Amyloidosis_Pats <- Cardiac_Amyloidosis_Pats %>% select(1)
ATTR_CM_noVyn_Pats <- fread("ATTR_CM_noVyn_Pats.txt", colClasses = "character")
Target_CM_Pats <- Cardiomyopathy_Pats %>% bind_rows(Cardiac_Amyloidosis_Pats, ATTR_CM_noVyn_Pats)

short_I_receipt_diseases_facility_CM_Targets <- fread("All_Pts_ContinuousEnrolled/short_I_receipt_diseases_facility_CM_Targets.txt", colClasses = "character")
short_I_receipt_diseases_facility_CM_Targets <- Target_CM_Pats %>% left_join(short_I_receipt_diseases_facility_CM_Targets) %>% filter(utagai_flg==0) %>% select(-utagai_flg)
m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_I_receipt_diseases_facility_CM_Targets <- short_I_receipt_diseases_facility_CM_Targets %>% left_join(m_icd10) %>% select(kojin_id, receipt_id , icd10_code) %>% distinct()
short_I_receipt_diseases_facility_CM_Targets <- short_I_receipt_diseases_facility_CM_Targets %>% filter( (grepl("I43",icd10_code)|grepl("I42",icd10_code))) %>% select(kojin_id, receipt_id) %>% distinct()

receipt_medical_institution_CM_Targets_CM <- fread("All_Pts_ContinuousEnrolled/receipt_medical_institution_CM_Targets.txt", sep="\t", colClasses = "character")
receipt_medical_institution_CM_Targets_CM <- receipt_medical_institution_CM_Targets_CM %>%  select(kojin_id, iryokikan_no, receipt_id ) %>% distinct()

short_I_receipt_diseases_facility_CM_Targets <- receipt_medical_institution_CM_Targets_CM %>% inner_join(short_I_receipt_diseases_facility_CM_Targets)

short_I_receipt_diseases_facility_CM_Targets <- short_I_receipt_diseases_facility_CM_Targets %>% select(kojin_id, iryokikan_no , receipt_id) %>% distinct()

length(unique(short_I_receipt_diseases_facility_CM_Targets$kojin_id)) # 17220
short_I_receipt_diseases_facility_CM_Targets %>% group_by(iryokikan_no) %>% count() %>% arrange(-n) %>% rename("No_CM_Pats"="n")





receipt_medical_practice_Target_CM <- fread("All_Pts_Continuousenrolled/receipt_medical_practice_Target_CM.txt", colClasses = "character")
receipt_medical_practice_Target_CM <- receipt_medical_practice_Target_CM %>% select(kojin_id, medical_practice_code, receipt_id) %>% distinct()
receipt_medical_practice_Target_CM <- short_I_receipt_diseases_facility_CM_Targets %>% inner_join(receipt_medical_practice_Target_CM)

Procedure_master <- fread("Masters/Procedure_master.csv", colClasses = "character")

receipt_medical_practice_Target_CM <- 
  receipt_medical_practice_Target_CM %>% 
  left_join(Procedure_master, 
            by=c("medical_practice_code"="standardized_procedure_code")) %>%
  select(kojin_id, standardized_procedure_name, iryokikan_no ) %>% distinct()

receipt_medical_practice_Target_CM <- receipt_medical_practice_Target_CM %>%
                                              filter(grepl("computerized tomog", standardized_procedure_name)|
                                                     grepl("CT imaging", standardized_procedure_name)|
                                                     grepl("nuclear medicine diagnosis", standardized_procedure_name)|
                                                     grepl("scintigraphy", standardized_procedure_name)|
                                                     grepl("MRI", standardized_procedure_name)|
                                                     grepl("electrocardiog", standardized_procedure_name)|
                                                     grepl("ECG", standardized_procedure_name)|
                                                     grepl("ultrasonography", standardized_procedure_name)|
                                                     grepl("SPECT", standardized_procedure_name)|
                                                     grepl("PET ", standardized_procedure_name)|
                                                     grepl("percutaneous needle biopsy", standardized_procedure_name)|
                                                     grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name)|
                                                     grepl("endoscopic biopsy", standardized_procedure_name)|
                                                     grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name)|
                                                     grepl("brain natriuretic peptide", standardized_procedure_name)|
                                                     grepl("BNP", standardized_procedure_name)|
                                                     grepl("troponin", standardized_procedure_name)|
                                                     grepl("genetic test", standardized_procedure_name)|
                                                     grepl("cardiac catheterization", standardized_procedure_name)|
                                                     grepl("Holter", standardized_procedure_name)|
                                                     grepl("pacemaker", standardized_procedure_name)|
                                                     grepl("gene-related", standardized_procedure_name)|
                                                     grepl("exercise test", standardized_procedure_name)|
                                                     grepl("hospitalization", standardized_procedure_name)|
                                                     grepl("serum amyloid A protein", standardized_procedure_name)|
                                                     grepl("prealbumin", standardized_procedure_name)|
                                                     grepl("transthyretin", standardized_procedure_name)|
                                                     grepl("amylase", standardized_procedure_name))

receipt_medical_practice_Target_CM <-
  receipt_medical_practice_Target_CM %>% mutate(standardized_procedure_name=
                                                     ifelse(grepl("computerized tomog",standardized_procedure_name), "CT",
                                                            ifelse(grepl("CT imaging,", standardized_procedure_name), "CT",
                                                                   ifelse(grepl("nuclear medicine diagnosis", standardized_procedure_name), "other nuclear medicine",
                                                                          ifelse(grepl("scintigraphy", standardized_procedure_name), "scintigraphy",
                                                                                 ifelse(grepl("MRI", standardized_procedure_name), "MRI",
                                                                                        ifelse(grepl("electrocardiog", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ECG", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ultrasonography", standardized_procedure_name), "ultrasonography",
                                                                                                      ifelse(grepl("SPECT", standardized_procedure_name), "scintigraphy",
                                                                                                             ifelse(grepl("PET ", standardized_procedure_name), "scintigraphy",
                                                                                                      ifelse(grepl("percutaneous needle biopsy", standardized_procedure_name), "biopsy",
                                                                                                             ifelse(grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("endoscopic biopsy", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name), "heart biopsy",
                                                                                                                           ifelse(grepl("brain natriuretic peptide", standardized_procedure_name), "BNP",
                                                                                                                                  ifelse(grepl("BNP", standardized_procedure_name), "BNP",
                                                                                                                                         ifelse(grepl("troponin", standardized_procedure_name), "troponin",
                                                                                                                                                ifelse(grepl("genetic test", standardized_procedure_name), "genetic test",
                                                                                                                                                       ifelse(grepl("cardiac catheterization", standardized_procedure_name), "cardiac catheterization",
                                                                                                                                                              ifelse(grepl("Holter", standardized_procedure_name), "Holter",
                                                                                                                                                                     ifelse(grepl("pacemaker", standardized_procedure_name), "pacemaker",
                                                                                                                                                                            ifelse(grepl("gene-related", standardized_procedure_name), "genetic test",
                                                                                                                                                                                          ifelse(grepl("exercise test", standardized_procedure_name), "exercise test",
                                                                                                                                                                                                 ifelse(grepl("hospitalization", standardized_procedure_name), "hospitalization",
                                                                                                                                                                                                        ifelse(grepl("serum amyloid A protein", standardized_procedure_name), "AmyloidA",
                                                                                                                                                                                                               ifelse(grepl("prealbumin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("transthyretin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("amylase", standardized_procedure_name), "amylase",NA)))))))))))))))))))))))))))))
                                                                   

receipt_medical_practice_Target_CM <- receipt_medical_practice_Target_CM %>% mutate(standardized_procedure_name=ifelse(is.na(standardized_procedure_name),"CT", standardized_procedure_name))

receipt_medical_practice_Target_CM <- receipt_medical_practice_Target_CM %>% filter(standardized_procedure_name=="scintigraphy") %>% select(kojin_id, iryokikan_no ) %>% distinct() 




short_I_receipt_diseases_facility_CM_Targets %>% select(kojin_id, iryokikan_no) %>% distinct() %>% group_by(iryokikan_no) %>% count() %>% arrange(-n) %>%
  rename("No_CM_Dxs"=n) %>%
  full_join(
    receipt_medical_practice_Target_CM %>% group_by(iryokikan_no) %>% count() %>% arrange(-n) %>%
  rename("No_Scintig"=n) 
  ) %>% ungroup() %>%
   filter(!is.na(No_Scintig )) %>%
  mutate(No_CM_Dxs=ifelse(is.na(No_CM_Dxs),0,No_CM_Dxs)) %>%
    mutate(No_Scintig=ifelse(is.na(No_Scintig),0,No_Scintig)) %>%
  arrange(-No_Scintig) %>%
   mutate(Facility_No=row_number()) %>%
  mutate(percent=Facility_No/221) %>% 
  mutate(facilities=No_Scintig/963) %>% mutate(cumfac=cumsum(facilities)) %>%
  ggplot(aes(100*percent, 100*cumfac, size=-100*cumfac)) +
  ylim(0,100) +
  geom_point(colour="navy", alpha=0.5) +
  xlab("\n Cummulative Percentage \n Facilities Performing Scintigraphy") +
  ylab("Cummulative Percentage of \n Scintigraphies Performed \n") + 
  theme_minimal() + # scale_x_continuous(trans='log10') +
  theme(legend.title = element_blank())
  
    ggplot(aes(No_Scintig, No_CM_Dxs )) +
  #geom_smooth(colour="midnightblue", fill="deepskyblue3") +
  geom_point(size=1, alpha=0.5) +
  xlim(0,30) + ylim(0,200) +
  xlab("\n No Scintigraphies Performed") + ylab("No. of Cardiomyopathy patients diagnosed \n") +
  theme_minimal()




    
# -------------------------------------------------
# No. Scintigraphies Jsc vs non-Jsc ------------------------------------------------

receipt_medical_institution_CM_Targets_CM <- fread("All_Pts_ContinuousEnrolled/receipt_medical_institution_CM_Targets.txt", sep="\t", colClasses = "character")
receipt_medical_institution_CM_Targets_CM <- receipt_medical_institution_CM_Targets_CM %>%  select(kojin_id, iryokikan_no, receipt_id ) %>% distinct()

receipt_medical_practice_Target_CM <- fread("All_Pts_Continuousenrolled/receipt_medical_practice_Target_CM.txt", colClasses = "character")
receipt_medical_practice_Target_CM <- receipt_medical_practice_Target_CM %>% select(kojin_id, medical_practice_code, receipt_id) %>% distinct()
receipt_medical_practice_Target_CM <- receipt_medical_practice_Target_CM %>% inner_join(receipt_medical_institution_CM_Targets_CM)

Procedure_master <- fread("Masters/Procedure_master.csv", colClasses = "character")

receipt_medical_practice_Target_CM <- 
  receipt_medical_practice_Target_CM %>% 
  left_join(Procedure_master, 
            by=c("medical_practice_code"="standardized_procedure_code")) %>%
  select(kojin_id, standardized_procedure_name, iryokikan_no ) %>% distinct()

receipt_medical_practice_Target_CM <- receipt_medical_practice_Target_CM %>%
                                              filter(grepl("computerized tomog", standardized_procedure_name)|
                                                     grepl("CT imaging", standardized_procedure_name)|
                                                     grepl("nuclear medicine diagnosis", standardized_procedure_name)|
                                                     grepl("scintigraphy", standardized_procedure_name)|
                                                     grepl("MRI", standardized_procedure_name)|
                                                     grepl("electrocardiog", standardized_procedure_name)|
                                                     grepl("ECG", standardized_procedure_name)|
                                                     grepl("ultrasonography", standardized_procedure_name)|
                                                     grepl("SPECT", standardized_procedure_name)|
                                                     grepl("PET ", standardized_procedure_name)|
                                                     grepl("percutaneous needle biopsy", standardized_procedure_name)|
                                                     grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name)|
                                                     grepl("endoscopic biopsy", standardized_procedure_name)|
                                                     grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name)|
                                                     grepl("brain natriuretic peptide", standardized_procedure_name)|
                                                     grepl("BNP", standardized_procedure_name)|
                                                     grepl("troponin", standardized_procedure_name)|
                                                     grepl("genetic test", standardized_procedure_name)|
                                                     grepl("cardiac catheterization", standardized_procedure_name)|
                                                     grepl("Holter", standardized_procedure_name)|
                                                     grepl("pacemaker", standardized_procedure_name)|
                                                     grepl("gene-related", standardized_procedure_name)|
                                                     grepl("exercise test", standardized_procedure_name)|
                                                     grepl("hospitalization", standardized_procedure_name)|
                                                     grepl("serum amyloid A protein", standardized_procedure_name)|
                                                     grepl("prealbumin", standardized_procedure_name)|
                                                     grepl("transthyretin", standardized_procedure_name)|
                                                     grepl("amylase", standardized_procedure_name))

receipt_medical_practice_Target_CM <-
  receipt_medical_practice_Target_CM %>% mutate(standardized_procedure_name=
                                                     ifelse(grepl("computerized tomog",standardized_procedure_name), "CT",
                                                            ifelse(grepl("CT imaging,", standardized_procedure_name), "CT",
                                                                   ifelse(grepl("nuclear medicine diagnosis", standardized_procedure_name), "other nuclear medicine",
                                                                          ifelse(grepl("scintigraphy", standardized_procedure_name), "scintigraphy",
                                                                                 ifelse(grepl("MRI", standardized_procedure_name), "MRI",
                                                                                        ifelse(grepl("electrocardiog", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ECG", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ultrasonography", standardized_procedure_name), "ultrasonography",
                                                                                                      ifelse(grepl("SPECT", standardized_procedure_name), "scintigraphy",
                                                                                                             ifelse(grepl("PET ", standardized_procedure_name), "scintigraphy",
                                                                                                      ifelse(grepl("percutaneous needle biopsy", standardized_procedure_name), "biopsy",
                                                                                                             ifelse(grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("endoscopic biopsy", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name), "heart biopsy",
                                                                                                                           ifelse(grepl("brain natriuretic peptide", standardized_procedure_name), "BNP",
                                                                                                                                  ifelse(grepl("BNP", standardized_procedure_name), "BNP",
                                                                                                                                         ifelse(grepl("troponin", standardized_procedure_name), "troponin",
                                                                                                                                                ifelse(grepl("genetic test", standardized_procedure_name), "genetic test",
                                                                                                                                                       ifelse(grepl("cardiac catheterization", standardized_procedure_name), "cardiac catheterization",
                                                                                                                                                              ifelse(grepl("Holter", standardized_procedure_name), "Holter",
                                                                                                                                                                     ifelse(grepl("pacemaker", standardized_procedure_name), "pacemaker",
                                                                                                                                                                            ifelse(grepl("gene-related", standardized_procedure_name), "genetic test",
                                                                                                                                                                                          ifelse(grepl("exercise test", standardized_procedure_name), "exercise test",
                                                                                                                                                                                                 ifelse(grepl("hospitalization", standardized_procedure_name), "hospitalization",
                                                                                                                                                                                                        ifelse(grepl("serum amyloid A protein", standardized_procedure_name), "AmyloidA",
                                                                                                                                                                                                               ifelse(grepl("prealbumin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("transthyretin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("amylase", standardized_procedure_name), "amylase",NA)))))))))))))))))))))))))))))
                                                                   

receipt_medical_practice_Target_CM <- receipt_medical_practice_Target_CM %>% mutate(standardized_procedure_name=ifelse(is.na(standardized_procedure_name),"CT", standardized_procedure_name))

receipt_medical_practice_Target_CM <- receipt_medical_practice_Target_CM %>% filter(standardized_procedure_name=="scintigraphy") %>% select(kojin_id, iryokikan_no ) %>% distinct() 

receipt_medical_practice_Target_CM %>% group_by(iryokikan_no) %>% count() %>% arrange(-n)
 




receipt_drug_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_drug_Vyndaqel195pts.txt", colClasses = "character")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts[,.(receipt_ym, kojin_id, drug_code, receipt_id)]
receipt_drug_Vyndaqel195pts$receipt_ym <- as.Date(paste0(as.character(receipt_drug_Vyndaqel195pts$receipt_ym), '/01'))
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% filter(drug_code=="622278901")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% group_by(kojin_id) %>% filter(receipt_ym==min(receipt_ym))

# Facilities associated with that Vyndaqel receipt
receipt_medical_institution_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_medical_institution_Vyndaqel195pts.txt", colClasses = "character")
receipt_medical_institution_Vyndaqel195pts <- receipt_medical_institution_Vyndaqel195pts %>% select(kojin_id, receipt_ym, iryokikan_no, receipt_id)
receipt_medical_institution_Vyndaqel195pts$receipt_ym  <- as.Date(paste0(as.character(receipt_medical_institution_Vyndaqel195pts$receipt_ym ), '/01'))

temp <- receipt_drug_Vyndaqel195pts %>% 
  left_join(receipt_medical_institution_Vyndaqel195pts,
            by=c("kojin_id"="kojin_id", "receipt_id"="receipt_id", "receipt_ym"="receipt_ym")) 

length(unique(temp$kojin_id)) # 195
length(unique(temp$iryokikan_no)) # # 53

Vyndaqel_Facilities <- unique(temp$iryokikan_no)
Vyndaqel_Facilities <- as.data.frame(Vyndaqel_Facilities)
names(Vyndaqel_Facilities)[1] <- "iryokikan_no"
Vyndaqel_Facilities$Group <- "VyndaqelFacility"

tekiyo_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/tekiyo_All_ContEnr_pts.txt", colClasses = "character")
ContinuouslyEnrolled_Y3_tekiyo_weights <- fread("All_Pts_ContinuousEnrolled/ContinuouslyEnrolled_Y3_tekiyo_weights.txt", colClasses = "character")
tekiyo_All_ContEnr_pts <- tekiyo_All_ContEnr_pts %>% left_join(ContinuouslyEnrolled_Y3_tekiyo_weights %>% select(kojin_id, weight)) %>% select(kojin_id, weight)
sum(as.numeric(tekiyo_All_ContEnr_pts$weight))

receipt_medical_practice_Target_CM %>% left_join(Vyndaqel_Facilities) %>% select(Group, iryokikan_no) %>% distinct() %>% group_by(Group) %>% count()



receipt_medical_practice_Target_CM %>% left_join(Vyndaqel_Facilities) %>% group_by(Group) %>% count()



receipt_medical_practice_Target_CM %>% left_join(Vyndaqel_Facilities) %>% group_by(Group, iryokikan_no) %>% left_join(tekiyo_All_ContEnr_pts) %>%
   summarise(n=sum(as.numeric(weight)))   %>% arrange(-n) %>%
  ungroup() %>% group_by(Group) %>% summarise(n2=mean(n))



# --------------------------------------------------
# % JsC vt no JsC Dx patients with vs without sicntigraphy -------------------

# Target CM with scintigraphy
receipt_medical_practice_Target_CM <- fread("All_Pts_Continuousenrolled/receipt_medical_practice_Target_CM.txt", colClasses = "character")
receipt_medical_practice_Target_CM <- receipt_medical_practice_Target_CM %>% select(kojin_id, medical_practice_code) %>% distinct()

Procedure_master <- fread("Masters/Procedure_master.csv", colClasses = "character")

receipt_medical_practice_Target_CM <- receipt_medical_practice_Target_CM %>% 
  left_join(Procedure_master, by=c("medical_practice_code"="standardized_procedure_code")) %>%
  select(kojin_id, standardized_procedure_name ) %>% distinct()

receipt_medical_practice_Target_CM <- receipt_medical_practice_Target_CM %>%
                                              filter(grepl("computerized tomog", standardized_procedure_name)|
                                                     grepl("CT imaging", standardized_procedure_name)|
                                                     grepl("nuclear medicine diagnosis", standardized_procedure_name)|
                                                     grepl("scintigraphy", standardized_procedure_name)|
                                                     grepl("MRI", standardized_procedure_name)|
                                                     grepl("electrocardiog", standardized_procedure_name)|
                                                     grepl("ECG", standardized_procedure_name)|
                                                     grepl("ultrasonography", standardized_procedure_name)|
                                                     grepl("SPECT", standardized_procedure_name)|
                                                     grepl("PET ", standardized_procedure_name)|
                                                     grepl("percutaneous needle biopsy", standardized_procedure_name)|
                                                     grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name)|
                                                     grepl("endoscopic biopsy", standardized_procedure_name)|
                                                     grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name)|
                                                     grepl("brain natriuretic peptide", standardized_procedure_name)|
                                                     grepl("BNP", standardized_procedure_name)|
                                                     grepl("troponin", standardized_procedure_name)|
                                                     grepl("genetic test", standardized_procedure_name)|
                                                     grepl("cardiac catheterization", standardized_procedure_name)|
                                                     grepl("Holter", standardized_procedure_name)|
                                                     grepl("pacemaker", standardized_procedure_name)|
                                                     grepl("gene-related", standardized_procedure_name)|
                                                     grepl("exercise test", standardized_procedure_name)|
                                                     grepl("hospitalization", standardized_procedure_name)|
                                                     grepl("serum amyloid A protein", standardized_procedure_name)|
                                                     grepl("prealbumin", standardized_procedure_name)|
                                                     grepl("transthyretin", standardized_procedure_name)|
                                                     grepl("amylase", standardized_procedure_name))

receipt_medical_practice_Target_CM <-
  receipt_medical_practice_Target_CM %>% mutate(standardized_procedure_name=
                                                     ifelse(grepl("computerized tomog",standardized_procedure_name), "CT",
                                                            ifelse(grepl("CT imaging,", standardized_procedure_name), "CT",
                                                                   ifelse(grepl("nuclear medicine diagnosis", standardized_procedure_name), "other nuclear medicine",
                                                                          ifelse(grepl("scintigraphy", standardized_procedure_name), "scintigraphy",
                                                                                 ifelse(grepl("MRI", standardized_procedure_name), "MRI",
                                                                                        ifelse(grepl("electrocardiog", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ECG", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ultrasonography", standardized_procedure_name), "ultrasonography",
                                                                                                      ifelse(grepl("SPECT", standardized_procedure_name), "scintigraphy",
                                                                                                             ifelse(grepl("PET ", standardized_procedure_name), "scintigraphy",
                                                                                                      ifelse(grepl("percutaneous needle biopsy", standardized_procedure_name), "biopsy",
                                                                                                             ifelse(grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("endoscopic biopsy", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name), "heart biopsy",
                                                                                                                           ifelse(grepl("brain natriuretic peptide", standardized_procedure_name), "BNP",
                                                                                                                                  ifelse(grepl("BNP", standardized_procedure_name), "BNP",
                                                                                                                                         ifelse(grepl("troponin", standardized_procedure_name), "troponin",
                                                                                                                                                ifelse(grepl("genetic test", standardized_procedure_name), "genetic test",
                                                                                                                                                       ifelse(grepl("cardiac catheterization", standardized_procedure_name), "cardiac catheterization",
                                                                                                                                                              ifelse(grepl("Holter", standardized_procedure_name), "Holter",
                                                                                                                                                                     ifelse(grepl("pacemaker", standardized_procedure_name), "pacemaker",
                                                                                                                                                                            ifelse(grepl("gene-related", standardized_procedure_name), "genetic test",
                                                                                                                                                                                          ifelse(grepl("exercise test", standardized_procedure_name), "exercise test",
                                                                                                                                                                                                 ifelse(grepl("hospitalization", standardized_procedure_name), "hospitalization",
                                                                                                                                                                                                        ifelse(grepl("serum amyloid A protein", standardized_procedure_name), "AmyloidA",
                                                                                                                                                                                                               ifelse(grepl("prealbumin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("transthyretin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("amylase", standardized_procedure_name), "amylase",NA)))))))))))))))))))))))))))))
                                                                   

receipt_medical_practice_Target_CM <- receipt_medical_practice_Target_CM %>% mutate(standardized_procedure_name=ifelse(is.na(standardized_procedure_name),"CT", standardized_procedure_name))

TargetCM_withScintigraphy <- receipt_medical_practice_Target_CM %>% filter(standardized_procedure_name=="scintigraphy") %>% select(kojin_id ) %>% distinct() 
































receipt_drug_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_drug_Vyndaqel195pts.txt", colClasses = "character")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts[,.(receipt_ym, kojin_id, drug_code, receipt_id)]
receipt_drug_Vyndaqel195pts$receipt_ym <- as.Date(paste0(as.character(receipt_drug_Vyndaqel195pts$receipt_ym), '/01'))
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% filter(drug_code=="622278901")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% group_by(kojin_id) %>% filter(receipt_ym==min(receipt_ym))

# Facilities associated with that Vyndaqel receipt
receipt_medical_institution_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_medical_institution_Vyndaqel195pts.txt", colClasses = "character")
receipt_medical_institution_Vyndaqel195pts <- receipt_medical_institution_Vyndaqel195pts %>% select(kojin_id, receipt_ym, iryokikan_no, receipt_id)
receipt_medical_institution_Vyndaqel195pts$receipt_ym  <- as.Date(paste0(as.character(receipt_medical_institution_Vyndaqel195pts$receipt_ym ), '/01'))

temp <- receipt_drug_Vyndaqel195pts %>% 
  left_join(receipt_medical_institution_Vyndaqel195pts,
            by=c("kojin_id"="kojin_id", "receipt_id"="receipt_id", "receipt_ym"="receipt_ym")) 

length(unique(temp$kojin_id)) # 
length(unique(temp$iryokikan_no)) #

Vyndaqel_Facilities <- unique(temp$iryokikan_no)
Vyndaqel_Facilities <- as.data.frame(Vyndaqel_Facilities)
names(Vyndaqel_Facilities)[1] <- "iryokikan_no"


Cardiomyopathy_Pats <- fread("Cardiomyopathy_Pats.txt", colClasses = "character")
Cardiac_Amyloidosis_Pats <- fread("Cardiac_Amyloidosis_Pats.txt", colClasses = "character")
Cardiac_Amyloidosis_Pats <- Cardiac_Amyloidosis_Pats %>% select(1)
ATTR_CM_noVyn_Pats <- fread("ATTR_CM_noVyn_Pats.txt", colClasses = "character")
Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")
ATTR_CM_Vyndaqel_Pats <- Vyndaqel_pats_CM_vs_PN %>%filter(CM==1|Combo==1) %>%  select(kojin_id)
Cardiomyopathy_Pats$Group <- "Cardiomiopathy"
Cardiac_Amyloidosis_Pats$Group <-  "CardiacAMyloidosis"
ATTR_CM_noVyn_Pats$Group <- "ATTRCM_noVyn"
Target_CM_Pats <- Cardiomyopathy_Pats %>% bind_rows(Cardiac_Amyloidosis_Pats, ATTR_CM_noVyn_Pats)


receipt_medical_institution_CM_Targets <- fread("All_Pts_ContinuousEnrolled/receipt_medical_institution_CM_Targets.txt", sep="\t", colClasses = "character")
receipt_medical_institution_CM_Targets <- receipt_medical_institution_CM_Targets %>% select(kojin_id, iryokikan_no, receipt_ym, receipt_id) %>% distinct()
receipt_medical_institution_CM_Targets <- Target_CM_Pats %>% select(kojin_id) %>% left_join(receipt_medical_institution_CM_Targets)
receipt_medical_institution_CM_Targets <- receipt_medical_institution_CM_Targets %>% inner_join(Vyndaqel_Facilities)
receipt_medical_institution_CM_Targets <- receipt_medical_institution_CM_Targets %>% select(kojin_id, receipt_ym, receipt_id)
ALL_Pats_JsC <- receipt_medical_institution_CM_Targets %>% select(kojin_id) %>% distinct()

ALL_Pats_JsC$Jsc <- "Jsc"

TargetCM_withScintigraphy$Scint <- "Scint"

Target_CM_Pats %>% select(kojin_id) %>% distinct() %>% left_join(ALL_Pats_JsC) %>% left_join(TargetCM_withScintigraphy) %>%
  group_by(Jsc, Scint) %>% count()



# Stocks / Flows diagram CM Vyndaqel patient funnel NEW RULES
tekiyo_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/tekiyo_All_ContEnr_pts.txt", colClasses = "character")
ContinuouslyEnrolled_Y3_tekiyo_weights <- fread("All_Pts_ContinuousEnrolled/ContinuouslyEnrolled_Y3_tekiyo_weights.txt", colClasses = "character")
tekiyo_All_ContEnr_pts <- tekiyo_All_ContEnr_pts %>% left_join(ContinuouslyEnrolled_Y3_tekiyo_weights %>% select(kojin_id, weight)) %>% select(kojin_id, weight)
sum(as.numeric(tekiyo_All_ContEnr_pts$weight)) # 26009563
Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")
Vyndaqel_pats_CM_vs_PN <- Vyndaqel_pats_CM_vs_PN %>% select(kojin_id) 




# Is LAST 3 YEARS
short_I_receipt_diseases_facility_CM_Targets <- 
  fread("All_Pts_ContinuousEnrolled/short_I_receipt_diseases_facility_CM_Targets.txt", sep="\t", colClasses = "character")

short_I_receipt_diseases_facility_CM_Targets <- short_I_receipt_diseases_facility_CM_Targets %>% inner_join(Target_CM_Pats %>% select(kojin_id))
short_I_receipt_diseases_facility_CM_Targets <- short_I_receipt_diseases_facility_CM_Targets %>% inner_join(receipt_medical_institution_CM_Targets)

short_I_receipt_diseases_facility_CM_Targets <- short_I_receipt_diseases_facility_CM_Targets %>% filter(utagai_flg==1) %>% select(-utagai_flg)

short_I_receipt_diseases_facility_CM_Targets <- short_I_receipt_diseases_facility_CM_Targets %>% filter(receipt_ym<="2021/03")
short_I_receipt_diseases_facility_CM_Targets <- short_I_receipt_diseases_facility_CM_Targets %>% filter(receipt_ym>="2018/04")



short_I_receipt_diseases_facility_CM_Targets <- short_I_receipt_diseases_facility_CM_Targets %>% select(kojin_id, diseases_code) %>% distinct()
ATTR_SpecificCode <- short_I_receipt_diseases_facility_CM_Targets %>% filter(diseases_code=="8850066") %>% select(kojin_id) %>% distinct()


m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)
short_I_receipt_diseases_facility_CM_Targets <- short_I_receipt_diseases_facility_CM_Targets %>% 
  left_join(m_icd10) %>% select(kojin_id, icd10_code) %>% distinct()

short_I_receipt_diseases_facility_CM_Targets <- short_I_receipt_diseases_facility_CM_Targets %>% filter(grepl("I50",icd10_code)|grepl("I42",icd10_code)|grepl("I43",icd10_code))



short_I_receipt_diseases_facility_CM_Targets %>% filter(grepl("I42",icd10_code)|grepl("I43",icd10_code)) %>% filter(icd10_code!="I420"&
                                                                                                                  icd10_code!="I423"&
                                                                                                                  icd10_code!="I424"&
                                                                                                                  icd10_code!="I426"&
                                                                                                                  icd10_code!="I427") %>% select(kojin_id) %>% distinct() %>%
      anti_join(short_I_receipt_diseases_facility_CM_Targets %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>% distinct()) %>%
      anti_join(Vyndaqel_pats_CM_vs_PN) %>%
  select(kojin_id) %>% distinct()%>%
  left_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight)))  # 

short_I_receipt_diseases_facility_CM_Targets %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  anti_join(ATTR_SpecificCode) %>%
    anti_join(Vyndaqel_pats_CM_vs_PN) %>%
  inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 


short_I_receipt_diseases_facility_CM_Targets %>% filter(grepl("I431",icd10_code)) %>% select(kojin_id) %>% distinct() %>%
  inner_join(ATTR_SpecificCode) %>%
  anti_join(Vyndaqel_pats_CM_vs_PN) %>%
  inner_join(tekiyo_All_ContEnr_pts) %>% summarise(n=sum(as.numeric(weight))) # 

# -----------------------------------------------------------------------------

# % Cardiac Amyloidosis + Biopsy that had Vyndaqel ---------------------------------------------
Cardiac_Amyloidosis_Pats <- fread("Cardiac_Amyloidosis_Pats.txt", colClasses = "character")
Cardiac_Amyloidosis_Pats <- Cardiac_Amyloidosis_Pats %>% select(1)
ATTR_CM_noVyn_Pats <- fread("ATTR_CM_noVyn_Pats.txt", colClasses = "character")
Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")
ATTR_CM_Vyndaqel_Pats <- Vyndaqel_pats_CM_vs_PN %>%filter(CM==1|Combo==1) %>%  select(kojin_id)

CA_Pats <- Cardiac_Amyloidosis_Pats %>% full_join(ATTR_CM_noVyn_Pats) %>% full_join(ATTR_CM_Vyndaqel_Pats) %>% distinct()

receipt_medical_practice_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_medical_practice_Vyndaqel195pts.txt", colClasses = "character")
receipt_medical_practice_Vyndaqel195pts <- distinct(receipt_medical_practice_Vyndaqel195pts[,.(kojin_id, medical_practice_code)])

Procedure_master <- fread("Masters/Procedure_master.csv", colClasses = "character")

receipt_medical_practice_Vyndaqel195pts <- 
  receipt_medical_practice_Vyndaqel195pts %>% 
  left_join(Procedure_master, 
            by=c("medical_practice_code"="standardized_procedure_code")) %>%
  select(kojin_id, standardized_procedure_name) %>% distinct()

receipt_medical_practice_Vyndaqel195pts <- receipt_medical_practice_Vyndaqel195pts %>%
                                              filter(grepl("computerized tomog", standardized_procedure_name)|
                                                     grepl("CT imaging", standardized_procedure_name)|
                                                     grepl("nuclear medicine diagnosis", standardized_procedure_name)|
                                                     grepl("scintigraphy", standardized_procedure_name)|
                                                     grepl("MRI", standardized_procedure_name)|
                                                     grepl("electrocardiog", standardized_procedure_name)|
                                                     grepl("ECG", standardized_procedure_name)|
                                                     grepl("ultrasonography", standardized_procedure_name)|
                                                     grepl("SPECT", standardized_procedure_name)|
                                                     grepl("PET ", standardized_procedure_name)|
                                                     grepl("percutaneous needle biopsy", standardized_procedure_name)|
                                                     grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name)|
                                                     grepl("endoscopic biopsy", standardized_procedure_name)|
                                                     grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name)|
                                                     grepl("brain natriuretic peptide", standardized_procedure_name)|
                                                     grepl("BNP", standardized_procedure_name)|
                                                     grepl("troponin", standardized_procedure_name)|
                                                     grepl("genetic test", standardized_procedure_name)|
                                                     grepl("cardiac catheterization", standardized_procedure_name)|
                                                     grepl("Holter", standardized_procedure_name)|
                                                     grepl("pacemaker", standardized_procedure_name)|
                                                     grepl("gene-related", standardized_procedure_name)|
                                                     grepl("exercise test", standardized_procedure_name)|
                                                     grepl("hospitalization", standardized_procedure_name)|
                                                     grepl("serum amyloid A protein", standardized_procedure_name)|
                                                     grepl("prealbumin", standardized_procedure_name)|
                                                     grepl("transthyretin", standardized_procedure_name)|
                                                     grepl("amylase", standardized_procedure_name))

receipt_medical_practice_Vyndaqel195pts <-
  receipt_medical_practice_Vyndaqel195pts %>% mutate(standardized_procedure_name=
                                                     ifelse(grepl("computerized tomog",standardized_procedure_name), "CT",
                                                            ifelse(grepl("CT imaging,", standardized_procedure_name), "CT",
                                                                   ifelse(grepl("nuclear medicine diagnosis", standardized_procedure_name), "other nuclear medicine",
                                                                          ifelse(grepl("scintigraphy", standardized_procedure_name), "scintigraphy",
                                                                                 ifelse(grepl("MRI", standardized_procedure_name), "MRI",
                                                                                        ifelse(grepl("electrocardiog", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ECG", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ultrasonography", standardized_procedure_name), "ultrasonography",
                                                                                                      ifelse(grepl("SPECT", standardized_procedure_name), "scintigraphy",
                                                                                                             ifelse(grepl("PET ", standardized_procedure_name), "scintigraphy",
                                                                                                      ifelse(grepl("percutaneous needle biopsy", standardized_procedure_name), "biopsy",
                                                                                                             ifelse(grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("endoscopic biopsy", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name), "heart biopsy",
                                                                                                                           ifelse(grepl("brain natriuretic peptide", standardized_procedure_name), "BNP",
                                                                                                                                  ifelse(grepl("BNP", standardized_procedure_name), "BNP",
                                                                                                                                         ifelse(grepl("troponin", standardized_procedure_name), "troponin",
                                                                                                                                                ifelse(grepl("genetic test", standardized_procedure_name), "genetic test",
                                                                                                                                                       ifelse(grepl("cardiac catheterization", standardized_procedure_name), "cardiac catheterization",
                                                                                                                                                              ifelse(grepl("Holter", standardized_procedure_name), "Holter",
                                                                                                                                                                     ifelse(grepl("pacemaker", standardized_procedure_name), "pacemaker",
                                                                                                                                                                            ifelse(grepl("gene-related", standardized_procedure_name), "genetic test",
                                                                                                                                                                                          ifelse(grepl("exercise test", standardized_procedure_name), "exercise test",
                                                                                                                                                                                                 ifelse(grepl("hospitalization", standardized_procedure_name), "hospitalization",
                                                                                                                                                                                                        ifelse(grepl("serum amyloid A protein", standardized_procedure_name), "AmyloidA",
                                                                                                                                                                                                               ifelse(grepl("prealbumin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("transthyretin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("amylase", standardized_procedure_name), "amylase",NA)))))))))))))))))))))))))))))
                                                                   

receipt_medical_practice_Vyndaqel195pts <- receipt_medical_practice_Vyndaqel195pts %>% mutate(standardized_procedure_name=ifelse(is.na(standardized_procedure_name),"CT", standardized_procedure_name))

Vyn_Biopsy_Pats <- receipt_medical_practice_Vyndaqel195pts %>% filter(standardized_procedure_name=="biopsy") %>% 
  select(kojin_id) %>% distinct() %>% mutate(Group="biopsy")






short_procedures_receipt_medical_practice_All_ContEnr_pts <- fread("All_Pts_Continuousenrolled/short_procedures_receipt_medical_practice_All_ContEnr_pts.txt", colClasses = "character")
short_procedures_receipt_medical_practice_All_ContEnr_pts <- short_procedures_receipt_medical_practice_All_ContEnr_pts %>% select(kojin_id, medical_practice_code) %>% distinct()
short_procedures_receipt_medical_practice_All_ContEnr_pts <- CA_Pats  %>% left_join(short_procedures_receipt_medical_practice_All_ContEnr_pts)


short_procedures_receipt_medical_practice_All_ContEnr_pts <- 
  short_procedures_receipt_medical_practice_All_ContEnr_pts %>% 
  left_join(Procedure_master, 
            by=c("medical_practice_code"="standardized_procedure_code")) %>%
  select(kojin_id, standardized_procedure_name) %>% distinct()

short_procedures_receipt_medical_practice_All_ContEnr_pts <- short_procedures_receipt_medical_practice_All_ContEnr_pts %>%
                                              filter(grepl("computerized tomog", standardized_procedure_name)|
                                                     grepl("CT imaging", standardized_procedure_name)|
                                                     grepl("nuclear medicine diagnosis", standardized_procedure_name)|
                                                     grepl("scintigraphy", standardized_procedure_name)|
                                                     grepl("MRI", standardized_procedure_name)|
                                                     grepl("electrocardiog", standardized_procedure_name)|
                                                     grepl("ECG", standardized_procedure_name)|
                                                     grepl("ultrasonography", standardized_procedure_name)|
                                                     grepl("SPECT", standardized_procedure_name)|
                                                     grepl("PET ", standardized_procedure_name)|
                                                     grepl("percutaneous needle biopsy", standardized_procedure_name)|
                                                     grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name)|
                                                     grepl("endoscopic biopsy", standardized_procedure_name)|
                                                     grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name)|
                                                     grepl("brain natriuretic peptide", standardized_procedure_name)|
                                                     grepl("BNP", standardized_procedure_name)|
                                                     grepl("troponin", standardized_procedure_name)|
                                                     grepl("genetic test", standardized_procedure_name)|
                                                     grepl("cardiac catheterization", standardized_procedure_name)|
                                                     grepl("Holter", standardized_procedure_name)|
                                                     grepl("pacemaker", standardized_procedure_name)|
                                                     grepl("gene-related", standardized_procedure_name)|
                                                     grepl("exercise test", standardized_procedure_name)|
                                                     grepl("hospitalization", standardized_procedure_name)|
                                                     grepl("serum amyloid A protein", standardized_procedure_name)|
                                                     grepl("prealbumin", standardized_procedure_name)|
                                                     grepl("transthyretin", standardized_procedure_name)|
                                                     grepl("amylase", standardized_procedure_name))

short_procedures_receipt_medical_practice_All_ContEnr_pts <-
  short_procedures_receipt_medical_practice_All_ContEnr_pts %>% mutate(standardized_procedure_name=
                                                     ifelse(grepl("computerized tomog",standardized_procedure_name), "CT",
                                                            ifelse(grepl("CT imaging,", standardized_procedure_name), "CT",
                                                                   ifelse(grepl("nuclear medicine diagnosis", standardized_procedure_name), "other nuclear medicine",
                                                                          ifelse(grepl("scintigraphy", standardized_procedure_name), "scintigraphy",
                                                                                 ifelse(grepl("MRI", standardized_procedure_name), "MRI",
                                                                                        ifelse(grepl("electrocardiog", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ECG", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ultrasonography", standardized_procedure_name), "ultrasonography",
                                                                                                      ifelse(grepl("SPECT", standardized_procedure_name), "scintigraphy",
                                                                                                             ifelse(grepl("PET ", standardized_procedure_name), "scintigraphy",
                                                                                                      ifelse(grepl("percutaneous needle biopsy", standardized_procedure_name), "biopsy",
                                                                                                             ifelse(grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("endoscopic biopsy", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name), "heart biopsy",
                                                                                                                           ifelse(grepl("brain natriuretic peptide", standardized_procedure_name), "BNP",
                                                                                                                                  ifelse(grepl("BNP", standardized_procedure_name), "BNP",
                                                                                                                                         ifelse(grepl("troponin", standardized_procedure_name), "troponin",
                                                                                                                                                ifelse(grepl("genetic test", standardized_procedure_name), "genetic test",
                                                                                                                                                       ifelse(grepl("cardiac catheterization", standardized_procedure_name), "cardiac catheterization",
                                                                                                                                                              ifelse(grepl("Holter", standardized_procedure_name), "Holter",
                                                                                                                                                                     ifelse(grepl("pacemaker", standardized_procedure_name), "pacemaker",
                                                                                                                                                                            ifelse(grepl("gene-related", standardized_procedure_name), "genetic test",
                                                                                                                                                                                          ifelse(grepl("exercise test", standardized_procedure_name), "exercise test",
                                                                                                                                                                                                 ifelse(grepl("hospitalization", standardized_procedure_name), "hospitalization",
                                                                                                                                                                                                        ifelse(grepl("serum amyloid A protein", standardized_procedure_name), "AmyloidA",
                                                                                                                                                                                                               ifelse(grepl("prealbumin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("transthyretin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("amylase", standardized_procedure_name), "amylase",NA)))))))))))))))))))))))))))))
                                                                   

short_procedures_receipt_medical_practice_All_ContEnr_pts <- short_procedures_receipt_medical_practice_All_ContEnr_pts %>% mutate(standardized_procedure_name=ifelse(is.na(standardized_procedure_name),"CT", standardized_procedure_name))

CA_Pats_Biopsy <- short_procedures_receipt_medical_practice_All_ContEnr_pts %>% filter(standardized_procedure_name=="biopsy")  %>% 
  select(kojin_id) %>% distinct() %>% mutate(Group="biopsy")


CA_Pats %>% left_join(CA_Pats_Biopsy %>% full_join(Vyn_Biopsy_Pats)) %>%
  filter(Group=="biopsy") %>%  # 
  inner_join(ATTR_CM_Vyndaqel_Pats) #

# --------------------------------

# % ATTR CM + biopsy that had Vyndaqel ------------------------------------------------


ATTR_CM_noVyn_Pats <- fread("ATTR_CM_noVyn_Pats.txt", colClasses = "character")
Vyndaqel_pats_CM_vs_PN <- fread("VyndaqelPts195/Vyndaqel_pats_CM_vs_PN.txt", colClasses = "character")
ATTR_CM_Vyndaqel_Pats <- Vyndaqel_pats_CM_vs_PN %>%filter(CM==1|Combo==1) %>%  select(kojin_id)

ATTR_CM_Pats <- ATTR_CM_noVyn_Pats %>% full_join(ATTR_CM_Vyndaqel_Pats) %>% distinct()

receipt_medical_practice_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_medical_practice_Vyndaqel195pts.txt", colClasses = "character")
receipt_medical_practice_Vyndaqel195pts <- distinct(receipt_medical_practice_Vyndaqel195pts[,.(kojin_id, medical_practice_code)])

Procedure_master <- fread("Masters/Procedure_master.csv", colClasses = "character")

receipt_medical_practice_Vyndaqel195pts <- 
  receipt_medical_practice_Vyndaqel195pts %>% 
  left_join(Procedure_master, 
            by=c("medical_practice_code"="standardized_procedure_code")) %>%
  select(kojin_id, standardized_procedure_name) %>% distinct()

receipt_medical_practice_Vyndaqel195pts <- receipt_medical_practice_Vyndaqel195pts %>%
                                              filter(grepl("computerized tomog", standardized_procedure_name)|
                                                     grepl("CT imaging", standardized_procedure_name)|
                                                     grepl("nuclear medicine diagnosis", standardized_procedure_name)|
                                                     grepl("scintigraphy", standardized_procedure_name)|
                                                     grepl("MRI", standardized_procedure_name)|
                                                     grepl("electrocardiog", standardized_procedure_name)|
                                                     grepl("ECG", standardized_procedure_name)|
                                                     grepl("ultrasonography", standardized_procedure_name)|
                                                     grepl("SPECT", standardized_procedure_name)|
                                                     grepl("PET ", standardized_procedure_name)|
                                                     grepl("percutaneous needle biopsy", standardized_procedure_name)|
                                                     grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name)|
                                                     grepl("endoscopic biopsy", standardized_procedure_name)|
                                                     grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name)|
                                                     grepl("brain natriuretic peptide", standardized_procedure_name)|
                                                     grepl("BNP", standardized_procedure_name)|
                                                     grepl("troponin", standardized_procedure_name)|
                                                     grepl("genetic test", standardized_procedure_name)|
                                                     grepl("cardiac catheterization", standardized_procedure_name)|
                                                     grepl("Holter", standardized_procedure_name)|
                                                     grepl("pacemaker", standardized_procedure_name)|
                                                     grepl("gene-related", standardized_procedure_name)|
                                                     grepl("exercise test", standardized_procedure_name)|
                                                     grepl("hospitalization", standardized_procedure_name)|
                                                     grepl("serum amyloid A protein", standardized_procedure_name)|
                                                     grepl("prealbumin", standardized_procedure_name)|
                                                     grepl("transthyretin", standardized_procedure_name)|
                                                     grepl("amylase", standardized_procedure_name))

receipt_medical_practice_Vyndaqel195pts <-
  receipt_medical_practice_Vyndaqel195pts %>% mutate(standardized_procedure_name=
                                                     ifelse(grepl("computerized tomog",standardized_procedure_name), "CT",
                                                            ifelse(grepl("CT imaging,", standardized_procedure_name), "CT",
                                                                   ifelse(grepl("nuclear medicine diagnosis", standardized_procedure_name), "other nuclear medicine",
                                                                          ifelse(grepl("scintigraphy", standardized_procedure_name), "scintigraphy",
                                                                                 ifelse(grepl("MRI", standardized_procedure_name), "MRI",
                                                                                        ifelse(grepl("electrocardiog", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ECG", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ultrasonography", standardized_procedure_name), "ultrasonography",
                                                                                                      ifelse(grepl("SPECT", standardized_procedure_name), "scintigraphy",
                                                                                                             ifelse(grepl("PET ", standardized_procedure_name), "scintigraphy",
                                                                                                      ifelse(grepl("percutaneous needle biopsy", standardized_procedure_name), "biopsy",
                                                                                                             ifelse(grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("endoscopic biopsy", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name), "heart biopsy",
                                                                                                                           ifelse(grepl("brain natriuretic peptide", standardized_procedure_name), "BNP",
                                                                                                                                  ifelse(grepl("BNP", standardized_procedure_name), "BNP",
                                                                                                                                         ifelse(grepl("troponin", standardized_procedure_name), "troponin",
                                                                                                                                                ifelse(grepl("genetic test", standardized_procedure_name), "genetic test",
                                                                                                                                                       ifelse(grepl("cardiac catheterization", standardized_procedure_name), "cardiac catheterization",
                                                                                                                                                              ifelse(grepl("Holter", standardized_procedure_name), "Holter",
                                                                                                                                                                     ifelse(grepl("pacemaker", standardized_procedure_name), "pacemaker",
                                                                                                                                                                            ifelse(grepl("gene-related", standardized_procedure_name), "genetic test",
                                                                                                                                                                                          ifelse(grepl("exercise test", standardized_procedure_name), "exercise test",
                                                                                                                                                                                                 ifelse(grepl("hospitalization", standardized_procedure_name), "hospitalization",
                                                                                                                                                                                                        ifelse(grepl("serum amyloid A protein", standardized_procedure_name), "AmyloidA",
                                                                                                                                                                                                               ifelse(grepl("prealbumin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("transthyretin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("amylase", standardized_procedure_name), "amylase",NA)))))))))))))))))))))))))))))
                                                                   

receipt_medical_practice_Vyndaqel195pts <- receipt_medical_practice_Vyndaqel195pts %>% mutate(standardized_procedure_name=ifelse(is.na(standardized_procedure_name),"CT", standardized_procedure_name))

Vyn_Biopsy_Pats <- receipt_medical_practice_Vyndaqel195pts %>% filter(standardized_procedure_name=="biopsy") %>% 
  select(kojin_id) %>% distinct() %>% mutate(Group="biopsy")






short_procedures_receipt_medical_practice_All_ContEnr_pts <- fread("All_Pts_Continuousenrolled/short_procedures_receipt_medical_practice_All_ContEnr_pts.txt", colClasses = "character")
short_procedures_receipt_medical_practice_All_ContEnr_pts <- short_procedures_receipt_medical_practice_All_ContEnr_pts %>% select(kojin_id, medical_practice_code) %>% distinct()
short_procedures_receipt_medical_practice_All_ContEnr_pts <- ATTR_CM_Pats  %>% left_join(short_procedures_receipt_medical_practice_All_ContEnr_pts)


short_procedures_receipt_medical_practice_All_ContEnr_pts <- 
  short_procedures_receipt_medical_practice_All_ContEnr_pts %>% 
  left_join(Procedure_master, 
            by=c("medical_practice_code"="standardized_procedure_code")) %>%
  select(kojin_id, standardized_procedure_name) %>% distinct()

short_procedures_receipt_medical_practice_All_ContEnr_pts <- short_procedures_receipt_medical_practice_All_ContEnr_pts %>%
                                              filter(grepl("computerized tomog", standardized_procedure_name)|
                                                     grepl("CT imaging", standardized_procedure_name)|
                                                     grepl("nuclear medicine diagnosis", standardized_procedure_name)|
                                                     grepl("scintigraphy", standardized_procedure_name)|
                                                     grepl("MRI", standardized_procedure_name)|
                                                     grepl("electrocardiog", standardized_procedure_name)|
                                                     grepl("ECG", standardized_procedure_name)|
                                                     grepl("ultrasonography", standardized_procedure_name)|
                                                     grepl("SPECT", standardized_procedure_name)|
                                                     grepl("PET ", standardized_procedure_name)|
                                                     grepl("percutaneous needle biopsy", standardized_procedure_name)|
                                                     grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name)|
                                                     grepl("endoscopic biopsy", standardized_procedure_name)|
                                                     grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name)|
                                                     grepl("brain natriuretic peptide", standardized_procedure_name)|
                                                     grepl("BNP", standardized_procedure_name)|
                                                     grepl("troponin", standardized_procedure_name)|
                                                     grepl("genetic test", standardized_procedure_name)|
                                                     grepl("cardiac catheterization", standardized_procedure_name)|
                                                     grepl("Holter", standardized_procedure_name)|
                                                     grepl("pacemaker", standardized_procedure_name)|
                                                     grepl("gene-related", standardized_procedure_name)|
                                                     grepl("exercise test", standardized_procedure_name)|
                                                     grepl("hospitalization", standardized_procedure_name)|
                                                     grepl("serum amyloid A protein", standardized_procedure_name)|
                                                     grepl("prealbumin", standardized_procedure_name)|
                                                     grepl("transthyretin", standardized_procedure_name)|
                                                     grepl("amylase", standardized_procedure_name))

short_procedures_receipt_medical_practice_All_ContEnr_pts <-
  short_procedures_receipt_medical_practice_All_ContEnr_pts %>% mutate(standardized_procedure_name=
                                                     ifelse(grepl("computerized tomog",standardized_procedure_name), "CT",
                                                            ifelse(grepl("CT imaging,", standardized_procedure_name), "CT",
                                                                   ifelse(grepl("nuclear medicine diagnosis", standardized_procedure_name), "other nuclear medicine",
                                                                          ifelse(grepl("scintigraphy", standardized_procedure_name), "scintigraphy",
                                                                                 ifelse(grepl("MRI", standardized_procedure_name), "MRI",
                                                                                        ifelse(grepl("electrocardiog", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ECG", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ultrasonography", standardized_procedure_name), "ultrasonography",
                                                                                                      ifelse(grepl("SPECT", standardized_procedure_name), "scintigraphy",
                                                                                                             ifelse(grepl("PET ", standardized_procedure_name), "scintigraphy",
                                                                                                      ifelse(grepl("percutaneous needle biopsy", standardized_procedure_name), "biopsy",
                                                                                                             ifelse(grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("endoscopic biopsy", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name), "heart biopsy",
                                                                                                                           ifelse(grepl("brain natriuretic peptide", standardized_procedure_name), "BNP",
                                                                                                                                  ifelse(grepl("BNP", standardized_procedure_name), "BNP",
                                                                                                                                         ifelse(grepl("troponin", standardized_procedure_name), "troponin",
                                                                                                                                                ifelse(grepl("genetic test", standardized_procedure_name), "genetic test",
                                                                                                                                                       ifelse(grepl("cardiac catheterization", standardized_procedure_name), "cardiac catheterization",
                                                                                                                                                              ifelse(grepl("Holter", standardized_procedure_name), "Holter",
                                                                                                                                                                     ifelse(grepl("pacemaker", standardized_procedure_name), "pacemaker",
                                                                                                                                                                            ifelse(grepl("gene-related", standardized_procedure_name), "genetic test",
                                                                                                                                                                                          ifelse(grepl("exercise test", standardized_procedure_name), "exercise test",
                                                                                                                                                                                                 ifelse(grepl("hospitalization", standardized_procedure_name), "hospitalization",
                                                                                                                                                                                                        ifelse(grepl("serum amyloid A protein", standardized_procedure_name), "AmyloidA",
                                                                                                                                                                                                               ifelse(grepl("prealbumin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("transthyretin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("amylase", standardized_procedure_name), "amylase",NA)))))))))))))))))))))))))))))
                                                                   

short_procedures_receipt_medical_practice_All_ContEnr_pts <- short_procedures_receipt_medical_practice_All_ContEnr_pts %>% mutate(standardized_procedure_name=ifelse(is.na(standardized_procedure_name),"CT", standardized_procedure_name))

ATTR_CM_Pats_Biopsy <- short_procedures_receipt_medical_practice_All_ContEnr_pts %>% filter(standardized_procedure_name=="biopsy")  %>% 
  select(kojin_id) %>% distinct() %>% mutate(Group="biopsy")


ATTR_CM_Pats %>% left_join(CA_Pats_Biopsy %>% full_join(Vyn_Biopsy_Pats)) %>%
  filter(Group=="biopsy") %>%  #
  inner_join(ATTR_CM_Vyndaqel_Pats) # 




# ------------------------------------------------------------

# % Test Penetrance up until first cardiomyopathy or first cardiac amyloidosis Dx ------------------------------------

Cardiomyopathy_Pats <- fread("Cardiomyopathy_Pats.txt", colClasses = "character")
Cardiac_Amyloidosis_Pats <- fread("Cardiac_Amyloidosis_Pats.txt", colClasses = "character")
Cardiac_Amyloidosis_Pats <- Cardiac_Amyloidosis_Pats[,1]

short_i_receipt_diseases_All_ContEnr_pts <- fread("All_Pts_ContinuousEnrolled/short_i_receipt_diseases_utagai_All_ContEnr_pts.txt", colClasses = "character")
short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% filter(utagai_flg==0) %>% select(-utagai_flg)
short_i_receipt_diseases_All_ContEnr_pts <- Cardiomyopathy_Pats %>% full_join(Cardiac_Amyloidosis_Pats) %>% inner_join(short_i_receipt_diseases_All_ContEnr_pts)

m_icd10 <- fread("Masters/m_icd10.csv", colClasses = "character")
m_icd10 <- m_icd10 %>% select(diseases_code, icd10_code)

short_i_receipt_diseases_All_ContEnr_pts <- short_i_receipt_diseases_All_ContEnr_pts %>% left_join(m_icd10) %>% select(kojin_id, receipt_ym, icd10_code) %>% distinct()
short_i_receipt_diseases_All_ContEnr_pts$receipt_ym <- as.Date(paste0(as.character(short_i_receipt_diseases_All_ContEnr_pts$receipt_ym), '/01'))

FirstCardiomiopathy <- Cardiomyopathy_Pats %>% left_join(short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I43",icd10_code)|grepl("I42",icd10_code))) %>%
  group_by(kojin_id) %>% filter(receipt_ym==min(receipt_ym)) %>% slice(1) %>% select(-icd10_code) %>% rename("FirstCardiomiopathy"="receipt_ym") %>% ungroup()

length(unique(FirstCardiomiopathy$kojin_id)) # 

FirstCardiacAmyloidosis <- Cardiac_Amyloidosis_Pats %>% left_join(short_i_receipt_diseases_All_ContEnr_pts %>% filter(grepl("I431",icd10_code))) %>%
  group_by(kojin_id) %>% filter(receipt_ym==min(receipt_ym)) %>% slice(1) %>% select(-icd10_code) %>% rename("FirstCardiacAmyloidosis"="receipt_ym") %>% ungroup()

length(unique(FirstCardiacAmyloidosis$kojin_id)) # 


short_procedures_receipt_medical_practice_All_ContEnr_pts <- fread("All_Pts_Continuousenrolled/short_procedures_receipt_medical_practice_All_ContEnr_pts.txt", colClasses = "character")
short_procedures_receipt_medical_practice_All_ContEnr_pts <- short_procedures_receipt_medical_practice_All_ContEnr_pts %>% select(kojin_id, medical_practice_code, receipt_ym) %>% distinct()
short_procedures_receipt_medical_practice_All_ContEnr_pts <- FirstCardiacAmyloidosis %>% left_join(short_procedures_receipt_medical_practice_All_ContEnr_pts)
short_procedures_receipt_medical_practice_All_ContEnr_pts$receipt_ym <- as.Date(paste0(as.character(short_procedures_receipt_medical_practice_All_ContEnr_pts$receipt_ym), '/01'))

FirstCardiacAmyloidosis <- short_procedures_receipt_medical_practice_All_ContEnr_pts %>% filter(receipt_ym<FirstCardiacAmyloidosis)

short_procedures_receipt_medical_practice_All_ContEnr_pts <- fread("All_Pts_Continuousenrolled/short_procedures_receipt_medical_practice_All_ContEnr_pts.txt", colClasses = "character")
short_procedures_receipt_medical_practice_All_ContEnr_pts <- short_procedures_receipt_medical_practice_All_ContEnr_pts %>% select(kojin_id, medical_practice_code, receipt_ym) %>% distinct()
short_procedures_receipt_medical_practice_All_ContEnr_pts <- FirstCardiomiopathy %>% left_join(short_procedures_receipt_medical_practice_All_ContEnr_pts)
short_procedures_receipt_medical_practice_All_ContEnr_pts$receipt_ym <- as.Date(paste0(as.character(short_procedures_receipt_medical_practice_All_ContEnr_pts$receipt_ym), '/01'))

FirstCardiomiopathy <- short_procedures_receipt_medical_practice_All_ContEnr_pts %>% filter(receipt_ym<FirstCardiomiopathy)

Procedure_master <- fread("Masters/Procedure_master.csv", colClasses = "character")

FirstCardiacAmyloidosis <- 
  FirstCardiacAmyloidosis %>% 
  left_join(Procedure_master, 
            by=c("medical_practice_code"="standardized_procedure_code")) %>%
  select(kojin_id, standardized_procedure_name) %>% distinct()


FirstCardiacAmyloidosis <- FirstCardiacAmyloidosis %>%
                                              filter(grepl("computerized tomog", standardized_procedure_name)|
                                                     grepl("CT imaging", standardized_procedure_name)|
                                                     grepl("nuclear medicine diagnosis", standardized_procedure_name)|
                                                     grepl("scintigraphy", standardized_procedure_name)|
                                                     grepl("MRI", standardized_procedure_name)|
                                                     grepl("electrocardiog", standardized_procedure_name)|
                                                     grepl("ECG", standardized_procedure_name)|
                                                     grepl("ultrasonography", standardized_procedure_name)|
                                                     grepl("SPECT", standardized_procedure_name)|
                                                     grepl("PET ", standardized_procedure_name)|
                                                     grepl("percutaneous needle biopsy", standardized_procedure_name)|
                                                     grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name)|
                                                     grepl("endoscopic biopsy", standardized_procedure_name)|
                                                     grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name)|
                                                     grepl("brain natriuretic peptide", standardized_procedure_name)|
                                                     grepl("BNP", standardized_procedure_name)|
                                                     grepl("troponin", standardized_procedure_name)|
                                                     grepl("genetic test", standardized_procedure_name)|
                                                     grepl("cardiac catheterization", standardized_procedure_name)|
                                                     grepl("Holter", standardized_procedure_name)|
                                                     grepl("pacemaker", standardized_procedure_name)|
                                                     grepl("gene-related", standardized_procedure_name)|
                                                     grepl("exercise test", standardized_procedure_name)|
                                                     grepl("hospitalization", standardized_procedure_name)|
                                                     grepl("serum amyloid A protein", standardized_procedure_name)|
                                                     grepl("prealbumin", standardized_procedure_name)|
                                                     grepl("transthyretin", standardized_procedure_name)|
                                                     grepl("amylase", standardized_procedure_name))

FirstCardiacAmyloidosis <-
  FirstCardiacAmyloidosis %>% mutate(standardized_procedure_name=
                                                     ifelse(grepl("computerized tomog",standardized_procedure_name), "CT",
                                                            ifelse(grepl("CT imaging,", standardized_procedure_name), "CT",
                                                                   ifelse(grepl("nuclear medicine diagnosis", standardized_procedure_name), "other nuclear medicine",
                                                                          ifelse(grepl("scintigraphy", standardized_procedure_name), "scintigraphy",
                                                                                 ifelse(grepl("MRI", standardized_procedure_name), "MRI",
                                                                                        ifelse(grepl("electrocardiog", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ECG", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ultrasonography", standardized_procedure_name), "ultrasonography",
                                                                                                      ifelse(grepl("SPECT", standardized_procedure_name), "scintigraphy",
                                                                                                             ifelse(grepl("PET ", standardized_procedure_name), "scintigraphy",
                                                                                                      ifelse(grepl("percutaneous needle biopsy", standardized_procedure_name), "biopsy",
                                                                                                             ifelse(grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("endoscopic biopsy", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name), "heart biopsy",
                                                                                                                           ifelse(grepl("brain natriuretic peptide", standardized_procedure_name), "BNP",
                                                                                                                                  ifelse(grepl("BNP", standardized_procedure_name), "BNP",
                                                                                                                                         ifelse(grepl("troponin", standardized_procedure_name), "troponin",
                                                                                                                                                ifelse(grepl("genetic test", standardized_procedure_name), "genetic test",
                                                                                                                                                       ifelse(grepl("cardiac catheterization", standardized_procedure_name), "cardiac catheterization",
                                                                                                                                                              ifelse(grepl("Holter", standardized_procedure_name), "Holter",
                                                                                                                                                                     ifelse(grepl("pacemaker", standardized_procedure_name), "pacemaker",
                                                                                                                                                                            ifelse(grepl("gene-related", standardized_procedure_name), "genetic test",
                                                                                                                                                                                          ifelse(grepl("exercise test", standardized_procedure_name), "exercise test",
                                                                                                                                                                                                 ifelse(grepl("hospitalization", standardized_procedure_name), "hospitalization",
                                                                                                                                                                                                        ifelse(grepl("serum amyloid A protein", standardized_procedure_name), "AmyloidA",
                                                                                                                                                                                                               ifelse(grepl("prealbumin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("transthyretin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("amylase", standardized_procedure_name), "amylase",NA)))))))))))))))))))))))))))))
                                                                   

FirstCardiacAmyloidosis <- FirstCardiacAmyloidosis %>% mutate(standardized_procedure_name=ifelse(is.na(standardized_procedure_name),"CT", standardized_procedure_name))

FirstCardiacAmyloidosis %>% ungroup() %>% 
  select(kojin_id, standardized_procedure_name) %>% distinct() %>%
  group_by(standardized_procedure_name) %>% count() %>% mutate(penetrance=100*n/307) %>%
  arrange(-penetrance)


# Split Jsc vs no Jsc patient
receipt_drug_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_drug_Vyndaqel195pts.txt", colClasses = "character")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts[,.(receipt_ym, kojin_id, drug_code, receipt_id)]
receipt_drug_Vyndaqel195pts$receipt_ym <- as.Date(paste0(as.character(receipt_drug_Vyndaqel195pts$receipt_ym), '/01'))
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% filter(drug_code=="622278901")
receipt_drug_Vyndaqel195pts <- receipt_drug_Vyndaqel195pts %>% group_by(kojin_id) %>% filter(receipt_ym==min(receipt_ym))

# Facilities associated with that Vyndaqel receipt
receipt_medical_institution_Vyndaqel195pts <- fread("VyndaqelPts195/receipt_medical_institution_Vyndaqel195pts.txt", colClasses = "character")
receipt_medical_institution_Vyndaqel195pts <- receipt_medical_institution_Vyndaqel195pts %>% select(kojin_id, receipt_ym, iryokikan_no, receipt_id)
receipt_medical_institution_Vyndaqel195pts$receipt_ym  <- as.Date(paste0(as.character(receipt_medical_institution_Vyndaqel195pts$receipt_ym ), '/01'))

temp <- receipt_drug_Vyndaqel195pts %>% 
  left_join(receipt_medical_institution_Vyndaqel195pts,
            by=c("kojin_id"="kojin_id", "receipt_id"="receipt_id", "receipt_ym"="receipt_ym")) 

length(unique(temp$kojin_id)) # 195
length(unique(temp$iryokikan_no)) # # 53

Vyndaqel_Facilities <- unique(temp$iryokikan_no)
Vyndaqel_Facilities <- as.data.frame(Vyndaqel_Facilities)
names(Vyndaqel_Facilities)[1] <- "iryokikan_no"

receipt_medical_institution_CM_Targets <- fread("All_Pts_ContinuousEnrolled/receipt_medical_institution_CM_Targets.txt", sep="\t", colClasses = "character")
receipt_medical_institution_CM_Targets <- receipt_medical_institution_CM_Targets %>% select(kojin_id, iryokikan_no, receipt_ym, receipt_id) %>% distinct()
receipt_medical_institution_CM_Targets <- FirstCardiacAmyloidosis %>% select(kojin_id) %>% left_join(receipt_medical_institution_CM_Targets)
receipt_medical_institution_CM_Targets <- receipt_medical_institution_CM_Targets %>% inner_join(Vyndaqel_Facilities)
receipt_medical_institution_CM_Targets <- receipt_medical_institution_CM_Targets %>% select(kojin_id, receipt_ym, receipt_id)
ALL_Pats_JsC <- receipt_medical_institution_CM_Targets %>% select(kojin_id) %>% distinct() # 123





FirstCardiacAmyloidosis %>% ungroup() %>% 
  inner_join(ALL_Pats_JsC) %>%
  select(kojin_id, standardized_procedure_name) %>% distinct() %>%
  group_by(standardized_procedure_name) %>% count() %>% mutate(penetrance=100*n/123) %>%
  arrange(-penetrance)

FirstCardiacAmyloidosis %>% ungroup() %>% 
  inner_join(ALL_Pats_JsC) %>%
  select(kojin_id, standardized_procedure_name) %>% distinct() %>%
  group_by(standardized_procedure_name) %>% count() %>% mutate(penetrance=100*n/184) %>%
  arrange(-penetrance)
FirstCardiomiopathy <- 
  FirstCardiomiopathy %>% 
  left_join(Procedure_master, 
            by=c("medical_practice_code"="standardized_procedure_code")) %>%
  select(kojin_id, standardized_procedure_name) %>% distinct()


FirstCardiomiopathy <- FirstCardiomiopathy %>%
                                              filter(grepl("computerized tomog", standardized_procedure_name)|
                                                     grepl("CT imaging", standardized_procedure_name)|
                                                     grepl("nuclear medicine diagnosis", standardized_procedure_name)|
                                                     grepl("scintigraphy", standardized_procedure_name)|
                                                     grepl("MRI", standardized_procedure_name)|
                                                     grepl("electrocardiog", standardized_procedure_name)|
                                                     grepl("ECG", standardized_procedure_name)|
                                                     grepl("ultrasonography", standardized_procedure_name)|
                                                     grepl("SPECT", standardized_procedure_name)|
                                                     grepl("PET ", standardized_procedure_name)|
                                                     grepl("percutaneous needle biopsy", standardized_procedure_name)|
                                                     grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name)|
                                                     grepl("endoscopic biopsy", standardized_procedure_name)|
                                                     grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name)|
                                                     grepl("brain natriuretic peptide", standardized_procedure_name)|
                                                     grepl("BNP", standardized_procedure_name)|
                                                     grepl("troponin", standardized_procedure_name)|
                                                     grepl("genetic test", standardized_procedure_name)|
                                                     grepl("cardiac catheterization", standardized_procedure_name)|
                                                     grepl("Holter", standardized_procedure_name)|
                                                     grepl("pacemaker", standardized_procedure_name)|
                                                     grepl("gene-related", standardized_procedure_name)|
                                                     grepl("exercise test", standardized_procedure_name)|
                                                     grepl("hospitalization", standardized_procedure_name)|
                                                     grepl("serum amyloid A protein", standardized_procedure_name)|
                                                     grepl("prealbumin", standardized_procedure_name)|
                                                     grepl("transthyretin", standardized_procedure_name)|
                                                     grepl("amylase", standardized_procedure_name))

FirstCardiomiopathy <-
  FirstCardiomiopathy %>% mutate(standardized_procedure_name=
                                                     ifelse(grepl("computerized tomog",standardized_procedure_name), "CT",
                                                            ifelse(grepl("CT imaging,", standardized_procedure_name), "CT",
                                                                   ifelse(grepl("nuclear medicine diagnosis", standardized_procedure_name), "other nuclear medicine",
                                                                          ifelse(grepl("scintigraphy", standardized_procedure_name), "scintigraphy",
                                                                                 ifelse(grepl("MRI", standardized_procedure_name), "MRI",
                                                                                        ifelse(grepl("electrocardiog", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ECG", standardized_procedure_name), "ECG",
                                                                                               ifelse(grepl("ultrasonography", standardized_procedure_name), "ultrasonography",
                                                                                                      ifelse(grepl("SPECT", standardized_procedure_name), "scintigraphy",
                                                                                                             ifelse(grepl("PET ", standardized_procedure_name), "scintigraphy",
                                                                                                      ifelse(grepl("percutaneous needle biopsy", standardized_procedure_name), "biopsy",
                                                                                                             ifelse(grepl("endoscopic ultrasound-guided fine-needle aspiration biopsy (EUS-FNA)", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("endoscopic biopsy", standardized_procedure_name), "biopsy",
                                                                                                                    ifelse(grepl("tissue sampling, excision method (heart muscle)", standardized_procedure_name), "heart biopsy",
                                                                                                                           ifelse(grepl("brain natriuretic peptide", standardized_procedure_name), "BNP",
                                                                                                                                  ifelse(grepl("BNP", standardized_procedure_name), "BNP",
                                                                                                                                         ifelse(grepl("troponin", standardized_procedure_name), "troponin",
                                                                                                                                                ifelse(grepl("genetic test", standardized_procedure_name), "genetic test",
                                                                                                                                                       ifelse(grepl("cardiac catheterization", standardized_procedure_name), "cardiac catheterization",
                                                                                                                                                              ifelse(grepl("Holter", standardized_procedure_name), "Holter",
                                                                                                                                                                     ifelse(grepl("pacemaker", standardized_procedure_name), "pacemaker",
                                                                                                                                                                            ifelse(grepl("gene-related", standardized_procedure_name), "genetic test",
                                                                                                                                                                                          ifelse(grepl("exercise test", standardized_procedure_name), "exercise test",
                                                                                                                                                                                                 ifelse(grepl("hospitalization", standardized_procedure_name), "hospitalization",
                                                                                                                                                                                                        ifelse(grepl("serum amyloid A protein", standardized_procedure_name), "AmyloidA",
                                                                                                                                                                                                               ifelse(grepl("prealbumin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("transthyretin", standardized_procedure_name), "TTR",
                                                                                                                                                                                                                      ifelse(grepl("amylase", standardized_procedure_name), "amylase",NA)))))))))))))))))))))))))))))
                                                                   

FirstCardiomiopathy <- FirstCardiomiopathy %>% mutate(standardized_procedure_name=ifelse(is.na(standardized_procedure_name),"CT", standardized_procedure_name))

FirstCardiomiopathy %>% ungroup() %>% 
  select(kojin_id, standardized_procedure_name) %>% distinct() %>%
  group_by(standardized_procedure_name) %>% count() %>% mutate(penetrance=100*n/16896) %>%
  arrange(-penetrance)
