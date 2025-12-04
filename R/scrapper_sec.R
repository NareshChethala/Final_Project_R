# ==============================================================================
# SEC Scraper
# ==============================================================================
# Functions to scrape the actual HTML content of 10-K filings.
# ==============================================================================

library(rvest)
library(httr)
library(stringr)

#' Get Filing Text (HTML)
#' @description Downloads the primary document (HTML) for a given filing.
#' @param cik Company CIK
#' @param accession Accession Number (e.g., "0000320193-23-000106")
#' @param primary_doc Primary Document Filename (e.g., "aapl-20230930.htm")
#' @param format "html" (returns raw HTML) or "text" (returns cleaned text - deprecated here, handled in app)
#' @return Raw HTML string or NULL if failed
get_filing_text <- function(cik, accession, primary_doc, format = "html") {
  
  # Construct the URL
  # URL format: https://www.sec.gov/Archives/edgar/data/{cik}/{accession_no_dashes}/{primary_doc}
  accession_no_dashes <- gsub("-", "", accession)
  cik_no_zeros <- as.numeric(cik) # SEC URLs often use unpadded CIKs, but let's stick to standard
  
  url <- paste0("https://www.sec.gov/Archives/edgar/data/", cik_no_zeros, "/", accession_no_dashes, "/", primary_doc)
  
  message(paste("Downloading filing from:", url))
  
  response <- GET(url, get_headers())
  
  if (status_code(response) == 200) {
    # Return raw HTML content
    return(content(response, "text", encoding = "UTF-8"))
  } else {
    warning(paste("Failed to download filing from:", url))
    return(NULL)
  }
}
