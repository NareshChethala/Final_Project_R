# Test Cleaning Logic
source("R/sec_api.R")
source("R/scrapper_sec.R")
source("R/cleaning.R")

# 1. Fetch Apple's 10-K HTML
cik <- 320193
accession <- "0000320193-25-000079"
primary_doc <- "aapl-20250927.htm"

print("Fetching raw HTML...")
html <- get_filing_text(cik, accession, primary_doc, format = "html")

if (!is.null(html)) {
  print(paste("Raw HTML length:", nchar(html)))
  
  # 2. Apply Cleaning
  print("Cleaning text...")
  cleaned_text <- clean_10k_text(html)
  
  print(paste("Cleaned Text length:", nchar(cleaned_text)))
  
  # 3. Verify
  # Check for XBRL tags
  if (grepl("<XBRL", cleaned_text, ignore.case = TRUE)) {
    print("FAIL: XBRL tags found.")
  } else {
    print("PASS: No XBRL tags found.")
  }
  
  # Check for Table tags
  if (grepl("<TABLE", cleaned_text, ignore.case = TRUE)) {
    print("FAIL: TABLE tags found.")
  } else {
    print("PASS: No TABLE tags found.")
  }
  
  # Check for SEC Header
  if (grepl("<SEC-HEADER>", cleaned_text, ignore.case = TRUE)) {
    print("FAIL: SEC-HEADER found.")
  } else {
    print("PASS: No SEC-HEADER found.")
  }
  
  print("First 500 chars of cleaned text:")
  print(substr(cleaned_text, 1, 500))
  
} else {
  print("Failed to fetch HTML.")
}
