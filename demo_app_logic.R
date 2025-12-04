# Demo App Logic Verification
source("R/sec_api.R")
source("R/db_utils.R")
source("R/scrapper_sec.R")

# Initialize DB (updates schema if needed)
init_db()

print("1. Searching for Apple...")
res <- get_company_cik("Apple")
cik <- res$cik[1]
print(paste("CIK:", cik))

print("2. Fetching Filings...")
# Ensure we have filings
subs <- fetch_company_submissions(cik)
save_filings(subs, cik)
filings <- get_filings(cik)

# Find latest 10-K
latest_10k <- filings %>% filter(form == "10-K") %>% head(1)
accession <- latest_10k$accessionNumber
primary_doc <- latest_10k$primaryDocument

print(paste("Selected 10-K:", accession))

print("3. Simulating 'Load Text'...")
# Check cache first
cached <- get_cached_filing_text(cik, accession)
if (!is.null(cached)) {
  print("Text found in cache (from previous tests).")
  print(paste("Length:", nchar(cached)))
} else {
  print("Text not in cache. Scraping...")
  text <- get_filing_text(cik, accession, primary_doc)
  if (!is.null(text)) {
    print("Scraping successful.")
    save_filing_text(cik, accession, text)
    print("Saved to DB.")
    
    # Verify cache retrieval
    cached_new <- get_cached_filing_text(cik, accession)
    print(paste("Retrieved from cache. Length:", nchar(cached_new)))
  } else {
    print("Scraping failed.")
  }
}
