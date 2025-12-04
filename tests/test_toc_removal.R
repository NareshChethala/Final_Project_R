# Test TOC Removal Logic
source("R/sec_api.R")
source("R/scrapper_sec.R")
source("R/cleaning.R")
source("R/cleaning_toc.R")
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
  
  res <- get_company_cik(companies[[name]])
  if (nrow(res) == 0) next
  cik <- res$cik[1]
  
  subs <- fetch_company_submissions(cik)
  if (is.null(subs)) next
  
  latest_10k <- subs %>% filter(form == "10-K") %>% head(1)
  if (nrow(latest_10k) == 0) next
  
  accession <- latest_10k$accessionNumber
  primary_doc <- latest_10k$primaryDocument
  
  print("  Fetching Raw HTML...")
  html <- get_filing_text(cik, accession, primary_doc, format = "html")
  if (is.null(html)) next
  
  print("  Cleaning Text (DOM)...")
  cleaned <- clean_10k_text(html)
  print(paste("  Length before TOC removal:", nchar(cleaned)))
  
  print("  Removing TOC...")
  final_text <- remove_10k_toc(cleaned)
  print(paste("  Length after TOC removal:", nchar(final_text)))
  
  diff <- nchar(cleaned) - nchar(final_text)
  print(paste("  Removed chars:", diff))
  
  if (diff > 0) {
    print("  PASS: TOC removed (text is shorter).")
  } else {
    print("  WARNING: No TOC removed (text length unchanged).")
  }
  
  print(paste("  First 200 chars of final text:"))
  print(substr(final_text, 1, 200))
}
