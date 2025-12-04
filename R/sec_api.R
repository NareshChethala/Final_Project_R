# ==============================================================================
# SEC API Helper Functions
# ==============================================================================
# Functions to interact with the SEC EDGAR API.
# Handles User-Agent compliance and JSON parsing.
# ==============================================================================

library(httr)
library(jsonlite)
library(dplyr)

#' Get SEC Request Headers
#' @description Returns headers required by SEC (User-Agent).
#' Reads email from config.json.
#' @return Named list of headers
get_headers <- function() {
  config_path <- "config.json"
  if (!file.exists(config_path)) {
    stop("config.json not found. Please create it with your email address.")
  }
  config <- fromJSON(config_path)
  user_agent <- config$user_agent
  
  if (is.null(user_agent) || user_agent == "") {
    stop("User-Agent email not found in config.json")
  }
  
  return(add_headers(`User-Agent` = user_agent, `Accept-Encoding` = "gzip, deflate"))
}

#' Fetch Company Tickers
#' @description Downloads the full list of company tickers from SEC.
#' @return Data frame with cik, ticker, and title
fetch_company_tickers <- function() {
  url <- "https://www.sec.gov/files/company_tickers.json"
  response <- GET(url, get_headers())
  
  if (status_code(response) == 200) {
    data <- fromJSON(content(response, "text", encoding = "UTF-8"))
    df <- bind_rows(data)
    # Rename cik_str to cik to match DB schema
    df <- df %>% rename(cik = cik_str)
    return(df)
  } else {
    warning("Failed to fetch company tickers")
    return(NULL)
  }
}

#' Fetch Company Submissions (Filings)
#' @description Gets the filing history for a specific CIK.
#' @param cik Company CIK (number or string)
#' @return Data frame of recent filings
fetch_company_submissions <- function(cik) {
  # Pad CIK to 10 digits
  cik_padded <- sprintf("%010d", as.numeric(cik))
  url <- paste0("https://data.sec.gov/submissions/CIK", cik_padded, ".json")
  
  response <- GET(url, get_headers())
  
  if (status_code(response) == 200) {
    data <- fromJSON(content(response, "text", encoding = "UTF-8"))
    filings <- data$filings$recent
    df <- as.data.frame(filings)
    return(df)
  } else {
    warning(paste("Failed to fetch submissions for CIK:", cik))
    return(NULL)
  }
}

#' Fetch Company Facts (Financial Data)
#' @description Gets all XBRL facts for a specific CIK.
#' @param cik Company CIK
#' @return Data frame of financial facts (US-GAAP)
fetch_company_facts <- function(cik) {
  cik_padded <- sprintf("%010d", as.numeric(cik))
  url <- paste0("https://data.sec.gov/api/xbrl/companyfacts/CIK", cik_padded, ".json")
  
  response <- GET(url, get_headers())
  
  if (status_code(response) == 200) {
    data <- fromJSON(content(response, "text", encoding = "UTF-8"))
    
    # Extract US-GAAP facts
    if (!is.null(data$facts$`us-gaap`)) {
      facts_list <- data$facts$`us-gaap`
      
      # Convert list of dataframes to a single dataframe
      all_facts <- list()
      
      for (concept in names(facts_list)) {
        units <- facts_list[[concept]]$units
        for (unit in names(units)) {
          df <- units[[unit]]
          df$concept <- concept
          df$unit <- unit
          all_facts[[length(all_facts) + 1]] <- df
        }
      }
      
      final_df <- bind_rows(all_facts)
      return(final_df)
    }
  }
  
  warning(paste("Failed to fetch facts for CIK:", cik))
  return(NULL)
}
