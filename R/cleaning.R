# ==============================================================================
# Text Cleaning (DOM-Based)
# ==============================================================================
# Functions to clean raw HTML 10-K filings.
# Uses 'rvest' to parse the DOM and remove unwanted elements like tables and XBRL.
# ==============================================================================

library(rvest)
library(xml2)
library(stringr)

#' Clean 10-K Text (Stage 1: DOM Cleaning)
#' @description Removes tables, XBRL, XML, scripts, and styles from the HTML.
#' @param raw_html The raw HTML content of the filing
#' @return Cleaned text string
clean_10k_text <- function(raw_html) {
  if (is.null(raw_html) || nchar(raw_html) == 0) return("")
  
  # Parse HTML
  page <- read_html(raw_html)
  
  # Remove unwanted nodes
  # 1. Tables: 10-Ks use tables for layout and financial data. We want narrative text.
  xml_remove(html_nodes(page, "table"))
  
  # 2. XBRL and XML: Machine-readable tags embedded in the document.
  xml_remove(html_nodes(page, "xbrl"))
  xml_remove(html_nodes(page, "xml"))
  
  # 3. Scripts and Styles: Standard web cleanup.
  xml_remove(html_nodes(page, "script"))
  xml_remove(html_nodes(page, "style"))
  
  # 4. Extract Text
  # html_text2() converts <br> and <p> to newlines and handles entities.
  text <- html_text2(page)
  
  # 5. Post-processing
  # Remove SEC Header if present (often at the top of raw text files)
  text <- str_remove(text, regex("^.*?</SEC-HEADER>", ignore_case = TRUE, dotall = TRUE))
  
  # Remove privacy footer
  text <- str_remove(text, "-----END PRIVACY-ENHANCED MESSAGE-----.*$")
  
  return(text)
}
