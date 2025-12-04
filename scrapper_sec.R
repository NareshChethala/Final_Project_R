# Install if needed:
# install.packages(c("httr", "rvest", "stringr"))

library(httr)
library(rvest)
library(stringr)

extract_filing_html_directly <- function(row, user_agent_email) {
  #' Extract the actual 10-K filing HTML content from a row in .idx
  #' using the real HTML URL (R version of your Python function).
  #'
  #' Args:
  #'   row: one row of a data.frame (or a named list) with a "Filename" field
  #'   user_agent_email: character, your email for SEC-compliant User-Agent
  #'
  #' Returns:
  #'   A list: list(filing_url = <character or NULL>, html = <character or NULL>)
  #'   - filing_url: the URL attempted (or NULL if early failure)
  #'   - html: the HTML text of the main filing document, or NULL on failure
  
  filing_url <- NULL
  
  tryCatch({
    # 1. Clean and parse the filename
    filename <- row[["Filename"]]
    if (is.null(filename) || is.na(filename)) {
      message("Filename is missing in row.")
      return(list(filing_url = NULL, html = NULL))
    }
    
    filename <- gsub(" ", "", filename)        # remove spaces
    path_parts <- strsplit(filename, "/")[[1]]
    
    if (length(path_parts) < 4) {
      message(sprintf("Invalid path in Filename: %s", filename))
      return(list(filing_url = NULL, html = NULL))
    }
    
    cik <- path_parts[3]
    accession_with_dashes <- path_parts[4]
    accession_nodashes <- gsub("-", "", accession_with_dashes)
    index_filename <- paste0(accession_with_dashes, "-index.htm")
    
    index_url <- sprintf(
      "https://www.sec.gov/Archives/edgar/data/%s/%s/%s",
      cik, accession_nodashes, index_filename
    )
    
    # 2. Request the index page
    resp <- GET(
      index_url,
      add_headers(`User-Agent` = user_agent_email),
      timeout(10)
    )
    
    if (status_code(resp) != 200) {
      message(sprintf("Failed to load index page: %s (status %s)",
                      index_url, status_code(resp)))
      return(list(filing_url = NULL, html = NULL))
    }
    
    # 3. Parse the index HTML and find the table with document links
    index_html_text <- content(resp, as = "text", encoding = "UTF-8")
    index_doc <- read_html(index_html_text)
    
    doc_table <- html_element(index_doc, "table.tableFile")
    if (is.na(doc_table)) {
      message(sprintf("Could not find document table at: %s", index_url))
      return(list(filing_url = NULL, html = NULL))
    }
    
    # 4. Find the first <a> whose href ends with ".htm" but not "-index.htm"
    links <- html_elements(doc_table, "a")
    hrefs <- html_attr(links, "href")
    
    # keep non-NA hrefs only
    hrefs <- hrefs[!is.na(hrefs)]
    
    if (length(hrefs) == 0) {
      message(sprintf("No links found in document table at: %s", index_url))
      return(list(filing_url = NULL, html = NULL))
    }
    
    # Equivalent of: href.endswith(".htm") and not href.endswith("-index.htm")
    is_htm <- grepl("\\.htm$", hrefs, ignore.case = TRUE)
    is_index <- grepl("-index\\.htm$", hrefs, ignore.case = TRUE)
    
    candidate_idx <- which(is_htm & !is_index)
    
    if (length(candidate_idx) == 0) {
      message(sprintf("No .htm filing document found in index page: %s", index_url))
      return(list(filing_url = NULL, html = NULL))
    }
    
    primary_doc <- hrefs[candidate_idx[1]]
    primary_doc <- sub("^/", "", primary_doc)   # remove leading slash
    
    # FIXED — no double /Archives
    filing_url <- paste0("https://www.sec.gov/", primary_doc)
    
    # 5. Download the main filing HTML
    filing_resp <- GET(
      filing_url,
      add_headers(`User-Agent` = user_agent_email),
      timeout(15)
    )
    
    if (status_code(filing_resp) == 200) {
      message(sprintf("Downloaded: %s", filing_url))
      filing_html <- content(filing_resp, as = "text", encoding = "UTF-8")
      return(list(filing_url = filing_url, html = filing_html))
    } else {
      message(sprintf("Failed to download filing from: %s (status %s)",
                      filing_url, status_code(filing_resp)))
      return(list(filing_url = filing_url, html = NULL))
    }
    
  }, error = function(e) {
    message(sprintf("Exception occurred: %s", e$message))
    return(list(filing_url = filing_url, html = NULL))
  })
}