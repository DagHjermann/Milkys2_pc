
standardize_tissues <- function(
  df,
  tissues_to_change = c("Blood"),
  varname_tissue = "TISSUE_NAME"){
  tissue <- df[[varname_tissue]]
  if ("Blood" %in% tissues_to_change){
    sel <- tissue %in% "Blood"
    tissue[sel] <- "Blod"
    cat(sum(sel), "records changed from Blod to Blood\n")
  }    
  df[[varname_tissue]] <- tissue
  df
}
# dat_all <- standardize_tissues(dat_all)



#
# Slightly changed version compared to the ones used in 2017-2018
# 'synonymfile' should have the 'standard' name (the name you want to change to) in the first column
#    and the other names from column 2 on
#


get_standard_parametername <- function(x, synonymfile){
  if (is.factor(x))
    x <- levels(x)[as.numeric(x)]
  synonyms <- read.csv2(synonymfile, stringsAsFactors = FALSE)
  n_cols <- ncol(synonyms)
  # will search in all columns named "substance"
  cols_synonyms <- grep("substance", colnames(synonyms))  # returns number
  # except the first one
  cols_synonyms <- cols_synonyms[cols_synonyms > 1]
  # note that number of synonyms is 7, must be changed if file is changed!
  for (col in cols_synonyms){
    for (row in seq_len(nrow(synonyms))){
      sel <- x %in% synonyms[row,col]
      x[sel] <- synonyms[row, 1]
    }
  }
  x
}
# Example
# df_2018$PARAM <- get_standard_parametername(df_2018$NAME, "Milkys_2018/01b_synonyms.csv")

# New version: adding ENTERED_DATE and ENTERED_BY. Also not throwing away any columns from original data
add_sumparameter <- function(i, pars_list, data){
  # Add variable N_par, if it's not already there
  if (!"N_par" %in% colnames(data)){
    data$N_par <- 1
  }
  pars <- pars_list[[i]]
  cat("==================================================================\n", i, names(pars_list)[i], "\n")
  cat(pars, "\n")
  df_grouped <- data %>%
    filter(PARAM %in% pars & !is.na(SAMPLE_NO)) %>%                        # select records (only those with SAMPLE_NO2)
    group_by(STATION_CODE, STATION_NAME, SAMPLE_DATE, LATIN_NAME, TISSUE_NAME, MYEAR, SAMPLE_NO, BASIS, UNIT)  # not PARAM
  if (nrow(df_grouped) > 0){
    df1 <- df_grouped %>%
      summarise(VALUE = sum(VALUE, na.rm = TRUE),                        # sum of the measurements
                UNCERTAINTY = mean(UNCERTAINTY, na.rm = TRUE),           # mean of the uncertainty
                ENTERED_BY = paste(unique(ENTERED_BY), collapse = ","),  # list all ENTERED_BY
                ENTERED_DATE = max(ENTERED_DATE)) %>%                    # we use max date for ENTERED_DATE
      mutate(QUANTIFICATION_LIMIT = NA) %>%
      as.data.frame(stringsAsFactors = FALSE)
    df2 <- df_grouped %>%
      summarise(FLAG1 = ifelse(mean(!is.na(FLAG1))==1, "<", as.character(NA))) %>%       # If all FLAG1 are "<", FLAG1 = "<", otherwise FLAG1 = NA
      as.data.frame()
    df2$FLAG1[df2$FLAG1 %in% "NA"] <- NA
    df3 <- df_grouped %>%
      summarise(N_par = n()) %>%    # number of measurements
      as.data.frame()
    # Should be all 1
    check <- df1[,1:9] == df2[,1:9]
    cat("Test 1 (should be 1):", 
        apply(check, 2, mean) %>% mean(na.rm = TRUE), "\n")
    
    check <- df2[,1:9] == df3[,1:9]
    cat("Test 2 (should be 1):", 
        apply(check, 2, mean) %>% mean(na.rm = TRUE), "\n")
    
    # Change the parameter name
    df1$PARAM <- names(pars_list)[i]   
    
    df_to_add <- data.frame(df1, FLAG1 = df2[,"FLAG1"], N_par = df3[,"N_par"], stringsAsFactors = FALSE)  # Make data to add
    data <- bind_rows(data, df_to_add)   # Add data for this parameter
    cat("Number of rows added:", nrow(df_to_add), "; number of rows in data:", nrow(data), "\n")
  } else {
    data <- df_orig
    cat("No rows added (found no data for these parameters found)\n")
  }
  data
}

get_sumparameter_definitions <- function(synonymfile){
  synonyms <- read.csv2(synonymfile, stringsAsFactors = FALSE)
  pars_list <- vector("list", 8)
  for (i in 1:5){
    sumpar <- c("CB_S7", "BDE6S", "P_S", "PFAS", "HBCDD")[i]
    pars_list[[i]] <- synonyms$substances2[synonyms$Sums1 %in% sumpar]
  }
  pars_list[[6]] <- grep("^BDE", synonyms$substances2, value = TRUE)   
  pars_list[[7]] <- synonyms$substances2[synonyms$Sums1 %in% c("P_S","PAH16")]
  pars_list[[8]] <- synonyms$substances2[synonyms$IARC_class %in% c("1","2A","2B")]
  pars_list[[9]] <- c("DDEPP", "DDTPP")
  names(pars_list) <- c("CB_S7", "BDE6S", "P_S", "PFAS", "HBCDD", 
                        "BDESS", "PAH16", "KPAH", "DDTEP")
  pars_list
}


change_oldunits_to_new <- function(
  df,
  units_to_change = c("M", "P", "U"),
  varname_unit = "UNIT"){
  unit <- df[[varname_unit]]
  if ("M" %in% units_to_change){
    sel <- toupper(unit) %in% "M"
    unit[sel] <- "MG_P_KG"
    cat(sum(sel), "records changed from M to MG_P_KG\n")
  }    
  if ("U" %in% units_to_change){
    sel <- toupper(unit) %in% "U"
    unit[sel] <- "UG_P_KG"
    cat(sum(sel), "records changed from U to UG_P_KG\n")
  }    
  if ("P" %in% units_to_change){
    sel <- toupper(unit) %in% "P"
    unit[sel] <- "PG_P_KG"
    cat(sum(sel), "records changed from P to PG_P_KG\n")
  }    
  df[[varname_unit]] <- unit
  df
}

#
# Changes "NG_P_G", "PG_P_G", "PG_P_KG" to "UG_P_KG"
# Note that "NG_P_KG" is *not* included
#
change_unit_to_ug <- function(
  df,
  units_to_change = c("NG_P_G", "PG_P_G", "PG_P_KG"),
  varname_unit = "UNIT",
  varname_value = "VALUE"){
  unit <- df[[varname_unit]]
  value <- df[[varname_value]]          # One NG = 0.001 UG, and One 
  if ("NG_P_G" %in% units_to_change){
    sel <- unit %in% "NG_P_G"
    unit[sel] <- "UG_P_KG"
    cat(sum(sel), "records changed from NG_P_G to UG_P_KG\n")
  }    
  if ("PG_P_G" %in% units_to_change){
    sel <- unit %in% "PG_P_G"
    unit[sel] <- "UG_P_KG"
    value[sel] <- value[sel]/1000
    cat(sum(sel), "records converted from PG_P_G to UG_P_KG\n")
  }
  if ("PG_P_KG" %in% units_to_change){
    sel <- unit %in% "PG_P_KG"
    unit[sel] <- "UG_P_KG"
    value[sel] <- value[sel]/1000000
    cat(sum(sel), "records converted from p to UG_P_KG\n")
  }
  df[[varname_unit]] <- unit
  df[[varname_value]] <- value
  df
}
# df_2018 <- change_unit_to_ug(df_2018)

#
# Returns one line per PARAM  
#
check_paramunits1 <- function(data){
  data %>%
    filter(!is.na(VALUE)) %>%
    group_by(PARAM, UNIT) %>%
    summarize(n = n(), value_median = median(VALUE)) %>%
    mutate(Unit_n = paste0(UNIT, " (", n, ")")) %>%
    group_by(PARAM) %>%
    summarize(n_units = length(unique(UNIT)), 
              Units = paste(Unit_n, collapse = ", "),
              Common_unit = UNIT[which.max(n)])
}
# check1 <- check_paramunits1(df_2018) %>% filter(n_units > 1)

#
# Returns one line per PARAM, TISSUE_NME and UNIT; includes median, min and max values of VALUE
#
check_paramunits2 <- function(data){
  data %>%
    filter(!is.na(VALUE)) %>%
    group_by(PARAM, TISSUE_NAME, UNIT) %>%
    summarize(n = n(), Median = median(VALUE), Min = min(VALUE), Max = max(VALUE)) %>%
    group_by(PARAM) %>%
    mutate(n_units = length(unique(UNIT))) %>%
    arrange(PARAM, TISSUE_NAME, UNIT)
}
# check2 <- check_paramunits2(df_2018) %>% filter(n_units > 1)


#
# Ascheck_paramunits2 but also includes one line per year, i.e.:
# Returns one line per PARAM, TISSUE_NAME, UNIT and YEAR; includes median, min and max values of VALUE
#
check_paramunits3 <- function(data){
  data %>%
    filter(!is.na(VALUE)) %>%
    group_by(PARAM, TISSUE_NAME, UNIT, MYEAR) %>%
    summarize(n = n(), Median = median(VALUE), Min = min(VALUE), Max = max(VALUE)) %>%
    group_by(PARAM) %>%
    mutate(n_units = length(unique(UNIT))) %>%
    arrange(PARAM, TISSUE_NAME, UNIT, MYEAR)
}
# check2 <- check_paramunits2(df_2018) %>% filter(n_units > 1)


#
# convert_preferred_unit
#
# Adds the columns UNIT_preferred, VALUE_preferred and Multiplier to 'data'
#
# 

convert_preferred_unit <- function(
  data,
  filename = "Input_data/Lookup table - preferred units.xlsx",
  sheetnames = c("Preferred_units", "Unit_conversion")){
  
  check <- convert_preferred_unit_check(
    data = data,
    filename = filename,
    sheetnames = sheetnames)
  
  if (sum(is.na(check$UNIT_preferred))==0 & sum(is.na(check$VALUE_preferred))==0){
    result_data <- check %>%
      rename(VALUE_orig = VALUE, 
             UNIT_orig = UNIT,
             VALUE = VALUE_preferred, 
             UNIT = UNIT_preferred)
    cat(
      "Unit changed for", 
      with(result_data, sum(UNIT_orig != UNIT)),
      "records\n")
  } else {
    cat("One or more UNIT_preferred and/or Multiplier is lacking.\n")
    cat("Run 'convert_preferred_unit_check' and check the result.\n")
    cat("\n")
    cat("Returning the original data.\n")
    result_data <- data
  }
  
  invisible(result_data)
  
} 


convert_preferred_unit_check <- function(
  data,
  filename = "Input_data/Lookup table - preferred units.xlsx",
  sheetnames = c("Preferred_units", "Unit_conversion")){
  
  df_units_preferred <- readxl::read_excel(
    filename, 
    sheet = sheetnames[1]) %>%
    select(PARAM, UNIT_preferred)
  
  df_units_conversion <- readxl::read_excel(
    filename, 
    sheet = sheetnames[2])
  
  # df_units_preferred
  # df_units_conversion
  
  data %>%
    mutate(UNIT = ifelse(is.na(UNIT), "NONE", UNIT)) %>%
    left_join(df_units_preferred, by = "PARAM") %>% 
    left_join(df_units_conversion, by = c("UNIT", "UNIT_preferred")) %>%
    mutate(Multiplier = case_when(
      UNIT == UNIT_preferred ~ 1,
      TRUE ~ Multiplier
    )) %>%
    mutate(VALUE_preferred = VALUE*Multiplier)
}

