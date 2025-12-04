# Test Sentiment Comparison Logic
source("R/sec_api.R")
source("R/scrapper_sec.R")
source("R/cleaning.R")
source("R/cleaning_toc.R")
source("R/sentiment.R")
source("R/db_utils.R")
library(dplyr)

init_db()

print("---------------------------------------------------")
print("Testing Sentiment Comparison...")

# 1. Setup: Ensure we have filings for Apple
cik <- 320193
filings <- get_filings(cik)

if (nrow(filings) < 2) {
  print("Fetching filings...")
  subs <- fetch_company_submissions(cik)
  save_filings(subs, cik)
  filings <- get_filings(cik)
}

# Select two 10-Ks
ten_ks <- filings %>% filter(form == "10-K") %>% head(2)

if (nrow(ten_ks) < 2) {
  print("FAIL: Need at least two 10-Ks for comparison test.")
} else {
  acc_curr <- ten_ks$accessionNumber[1]
  doc_curr <- ten_ks$primaryDocument[1]
  
  acc_comp <- ten_ks$accessionNumber[2]
  doc_comp <- ten_ks$primaryDocument[2]
  
  print(paste("Comparing:", acc_curr, "vs", acc_comp))
  
  # 2. Analyze Current
  print("Analyzing Current...")
  html_curr <- get_cached_filing_text(cik, acc_curr)
  if (is.null(html_curr)) {
    html_curr <- get_filing_text(cik, acc_curr, doc_curr, format = "html")
    save_filing_text(cik, acc_curr, html_curr)
  }
  text_curr <- clean_10k_text(html_curr)
  text_curr <- remove_10k_toc(text_curr)
  scores_curr <- calculate_sentiment(text_curr)
  scores_curr$Type <- "Current"
  
  # 3. Analyze Comparison
  print("Analyzing Comparison...")
  html_comp <- get_cached_filing_text(cik, acc_comp)
  if (is.null(html_comp)) {
    html_comp <- get_filing_text(cik, acc_comp, doc_comp, format = "html")
    save_filing_text(cik, acc_comp, html_comp)
  }
  text_comp <- clean_10k_text(html_comp)
  text_comp <- remove_10k_toc(text_comp)
  scores_comp <- calculate_sentiment(text_comp)
  scores_comp$Type <- "Comparison"
  
  # 4. Combine
  combined <- bind_rows(scores_curr, scores_comp)
  print("Combined Results:")
  print(combined)
  
  if (nrow(combined) == 2 && "Type" %in% names(combined)) {
    print("PASS: Comparison logic works.")
  } else {
    print("FAIL: Combined results incorrect.")
  }
}
