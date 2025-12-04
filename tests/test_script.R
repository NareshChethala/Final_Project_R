source("R/sec_api.R")
source("R/db_utils.R")

print("Initializing DB...")
init_db()

print("Fetching tickers...")
tickers <- fetch_company_tickers()
print(paste("Fetched", nrow(tickers), "tickers"))
save_companies(tickers)

print("Searching for Apple...")
res <- get_company_cik("Apple")
print(res)

if (nrow(res) > 0) {
  cik <- res$cik[1]
  print(paste("Fetching facts for CIK:", cik))
  facts <- fetch_company_facts(cik)
  if (!is.null(facts)) {
    print(paste("Fetched", nrow(facts), "facts"))
    save_facts(facts, cik)
    
    saved_facts <- get_facts(cik)
    print(paste("Retrieved", nrow(saved_facts), "facts from DB"))
    print(head(saved_facts))
  } else {
    print("Failed to fetch facts")
  }
  
  print("Fetching submissions...")
  subs <- fetch_company_submissions(cik)
  if (!is.null(subs)) {
    print(paste("Fetched", nrow(subs), "submissions"))
    save_filings(subs, cik)
    
    saved_filings <- get_filings(cik)
    print(paste("Retrieved", nrow(saved_filings), "filings from DB"))
    print(head(saved_filings))
  }
}
