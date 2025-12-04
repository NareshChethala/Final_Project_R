# Test Cleaning Logic for Multiple Companies
source("R/sec_api.R")
source("R/scrapper_sec.R")
source("R/cleaning.R")
source("R/db_utils.R")

init_db()

# Ensure companies are populated
con <- DBI::dbConnect(RSQLite::SQLite(), "data/sec_data.sqlite")
if (DBI::dbGetQuery(con, "SELECT count(*) FROM companies")[[1]] == 0) {
  print("Populating companies table...")
  tickers <- fetch_company_tickers()
  save_companies(tickers)
}
DBI::dbDisconnect(con)

companies <- list(
  "Apple" = "Apple",
  "Microsoft" = "Microsoft",
  "Tesla" = "Tesla"
)

for (name in names(companies)) {
  print(paste("---------------------------------------------------"))
  print(paste("Testing:", name))
  
  # 1. Get CIK
  res <- get_company_cik(companies[[name]])
  if (nrow(res) == 0) {
    print("  Failed to find CIK.")
    next
  }
  cik <- res$cik[1]
  print(paste("  CIK:", cik))
  
  # 2. Get Filings
  subs <- fetch_company_submissions(cik)
  if (is.null(subs)) {
    print("  Failed to fetch submissions.")
    next
  }
  
  # 3. Find latest 10-K
  latest_10k <- subs %>%
    filter(form == "10-K") %>%
    head(1)
  
  if (nrow(latest_10k) == 0) {
    print("  No 10-K found.")
    next
  }
  
  accession <- latest_10k$accessionNumber
  primary_doc <- latest_10k$primaryDocument
  print(paste("  Latest 10-K:", accession))
  
  # 4. Fetch Raw HTML
  print("  Fetching Raw HTML...")
  html <- get_filing_text(cik, accession, primary_doc, format = "html")
  
  if (is.null(html)) {
    print("  Failed to fetch HTML.")
    next
  }
  print(paste("  Raw HTML Length:", nchar(html)))
  
  # 5. Clean Text
  print("  Cleaning Text...")
  cleaned <- clean_10k_text(html)
  print(paste("  Cleaned Text Length:", nchar(cleaned)))
  
  # 6. Checks
  has_table <- grepl("<table", cleaned, ignore.case = TRUE)
  has_xbrl <- grepl("<xbrl", cleaned, ignore.case = TRUE)
  
  if (has_table) print("  FAIL: Table tags found.")
  else print("  PASS: No Table tags.")
  
  if (has_xbrl) print("  FAIL: XBRL tags found.")
  else print("  PASS: No XBRL tags.")
  
  print(paste("  First 100 chars:", substr(cleaned, 1, 100)))
}
