# Test script for API Scraper Endpoint Logic
source("R/sec_api.R")
source("R/scrapper_sec.R")

# Simulate the API call
test_api_filing_text <- function(cik, accession_number, primary_document = NULL) {
  print(paste("API Call: /filing-text?cik=", cik, "&accession_number=", accession_number, sep=""))
  
  if (missing(cik) || missing(accession_number)) {
    return(list(error = "Parameters 'cik' and 'accession_number' are required"))
  }
  
  text <- get_filing_text(cik, accession_number, primary_document)
  
  if (is.null(text)) {
    return(list(error = "Failed to retrieve filing text"))
  }
  
  return(list(cik = cik, accession_number = accession_number, text_preview = substr(text, 1, 100)))
}

# Test with Apple's latest 10-K (known from previous test)
cik <- 320193
accession <- "0000320193-25-000079"
primary_doc <- "aapl-20250927.htm"

print("Testing API endpoint logic...")
result <- test_api_filing_text(cik, accession, primary_doc)

if (is.null(result$error)) {
  print("Success! API returned text.")
  print(result)
} else {
  print("API returned error:")
  print(result$error)
}
