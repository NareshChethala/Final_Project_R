# Demo Script to simulate App usage
source("R/sec_api.R")
source("R/db_utils.R")

# Helper to print section headers
print_header <- function(title) {
  cat("\n==================================================\n")
  cat(paste("  ", title, "\n"))
  cat("==================================================\n")
}

# Initialize DB
init_db()

# Example: Apple
print_header("Requested Test: Searching for 'Apple'")
res <- get_company_cik("Apple")
print(res)

if (nrow(res) > 0) {
  # Pick the first one (Apple Inc.)
  cik <- res$cik[1]
  cat(paste("\nSelected:", res$title[1], "(CIK:", cik, ")\n"))
  
  cat("Fetching Facts...\n")
  facts <- fetch_company_facts(cik)
  if (!is.null(facts)) {
    save_facts(facts, cik)
    saved_facts <- get_facts(cik)
    cat(paste("Success! Retrieved", nrow(saved_facts), "facts.\n"))
    
    # Show some key metrics
    metrics <- saved_facts %>% 
      filter(concept %in% c("NetIncomeLoss", "Assets", "Revenues", "SalesRevenueNet")) %>%
      arrange(desc(filed)) %>%
      head(5) %>%
      select(concept, fy, val, form, filed)
    print(metrics)
  }
  
  cat("\nFetching Filings...\n")
  subs <- fetch_company_submissions(cik)
  if (!is.null(subs)) {
    save_filings(subs, cik)
    saved_filings <- get_filings(cik)
    cat(paste("Success! Retrieved", nrow(saved_filings), "filings.\n"))
    print(head(saved_filings %>% select(filingDate, form, description), 5))
  }
}
print_header("Example 1: Searching for 'Microsoft'")
res <- get_company_cik("Microsoft")
print(res)

if (nrow(res) > 0) {
  cik <- res$cik[1]
  cat(paste("\nSelected:", res$title[1], "(CIK:", cik, ")\n"))
  
  cat("Fetching Facts...\n")
  facts <- fetch_company_facts(cik)
  if (!is.null(facts)) {
    save_facts(facts, cik)
    saved_facts <- get_facts(cik)
    cat(paste("Success! Retrieved", nrow(saved_facts), "facts.\n"))
    
    # Show some key metrics
    metrics <- saved_facts %>% 
      filter(concept %in% c("NetIncomeLoss", "Assets", "Revenues")) %>%
      arrange(desc(filed)) %>%
      head(5) %>%
      select(concept, fy, val, form, filed)
    print(metrics)
  }
  
  cat("\nFetching Filings...\n")
  subs <- fetch_company_submissions(cik)
  if (!is.null(subs)) {
    save_filings(subs, cik)
    saved_filings <- get_filings(cik)
    cat(paste("Success! Retrieved", nrow(saved_filings), "filings.\n"))
    print(head(saved_filings %>% select(filingDate, form, description), 5))
  }
}

# Example 2: Tesla
print_header("Example 2: Searching for 'Tesla'")
res <- get_company_cik("Tesla")
print(res)

if (nrow(res) > 0) {
  cik <- res$cik[1]
  cat(paste("\nSelected:", res$title[1], "(CIK:", cik, ")\n"))
  
  cat("Fetching Facts...\n")
  facts <- fetch_company_facts(cik)
  if (!is.null(facts)) {
    save_facts(facts, cik)
    saved_facts <- get_facts(cik)
    cat(paste("Success! Retrieved", nrow(saved_facts), "facts.\n"))
  }
}

# Example 3: Invalid Company
print_header("Example 3: Searching for 'NonExistentCompanyXYZ'")
res <- get_company_cik("NonExistentCompanyXYZ")
if (nrow(res) == 0) {
  cat("Correctly returned no results.\n")
} else {
  print(res)
}
