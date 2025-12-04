source("R/sec_api.R")
source("R/scrapper_sec.R")

# 1. Get Apple CIK
print("Fetching Apple CIK...")
cik <- 320193 # Apple

# 2. Get Submissions
print("Fetching Submissions...")
subs <- fetch_company_submissions(cik)

if (!is.null(subs)) {
  # 3. Find latest 10-K
  latest_10k <- subs %>%
    filter(form == "10-K") %>%
    head(1)
  
  if (nrow(latest_10k) > 0) {
    print(paste("Found 10-K from:", latest_10k$filingDate))
    print(paste("Accession:", latest_10k$accessionNumber))
    print(paste("Primary Doc:", latest_10k$primaryDocument))
    
    # 4. Scrape Text
    print("Scraping text...")
    text <- get_filing_text(cik, latest_10k$accessionNumber, latest_10k$primaryDocument)
    
    if (!is.null(text)) {
      print("Success! Text length:")
      print(nchar(text))
      print("First 500 characters:")
      print(substr(text, 1, 500))
      
      # Verify content
      if (grepl("UNITED STATES", text) || grepl("SECURITIES AND EXCHANGE COMMISSION", text)) {
        print("Verification PASSED: Found SEC header.")
      } else {
        print("Verification WARNING: SEC header not found.")
      }
      
    } else {
      print("Failed to scrape text.")
    }
    
  } else {
    print("No 10-K found.")
  }
} else {
  print("Failed to fetch submissions.")
}
