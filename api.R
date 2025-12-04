# ==============================================================================
# SEC Data Viewer - Plumber API
# ==============================================================================
# This API exposes SEC data via JSON endpoints.
# Endpoints:
# - /health: Check API status
# - /search: Search for companies
# - /facts: Get financial facts
# - /filings: Get filing history
# - /filing-text: Get raw or cleaned text of a filing
# - /sentiment: Analyze sentiment of a filing
# ==============================================================================

library(plumber)
library(dplyr)
library(jsonlite)

# Source helper scripts
source("R/sec_api.R")
source("R/db_utils.R")
source("R/scrapper_sec.R")
source("R/cleaning.R")
source("R/cleaning_toc.R")
source("R/cleaning_facts.R")
source("R/financial_analysis.R")

# Initialize DB
init_db()

#* @apiTitle SEC Data Viewer API
#* @apiDescription API for searching SEC filings and financial data.

#* Check API Health
#* @get /health
function() {
  list(status = "ok", time = Sys.time())
}

#* Search for a company by CIK or Name
#* @param q Query string (CIK or Company Name)
#* @get /search
function(q = "") {
  if (q == "") return(list(error = "Query parameter 'q' is required"))
  
  res <- get_company_cik(q)
  return(res)
}

#* Get Financial Facts for a Company
#* @param cik Company CIK
#* @param clean If TRUE, returns only latest value per FY (default: TRUE)
#* @get /facts
function(cik = "", clean = TRUE) {
  if (cik == "") return(list(error = "CIK is required"))
  
  # Try to get from DB first
  facts <- get_facts(cik)
  
  if (is.null(facts) || nrow(facts) == 0) {
    # Fetch from SEC if not in DB
    facts <- fetch_company_facts(cik)
    if (!is.null(facts)) {
      facts$cik <- cik
      save_facts(facts, cik)
    }
  }
  
  # Apply cleaning if requested (default TRUE per user request)
  if (isTRUE(as.logical(clean))) {
    facts <- clean_facts_latest(facts)
  }
  
  return(facts)
}

#* Get Financial Analysis (KPIs & YoY Change)
#* @param cik Company CIK
#* @get /analysis/financials
function(cik = "") {
  if (cik == "") return(list(error = "CIK is required"))
  
  analysis <- analyze_financials(cik)
  
  if (is.null(analysis)) {
    return(list(error = "No data available for analysis"))
  }
  
  return(analysis)
}

#* Get Filing History for a Company
#* @param cik Company CIK
#* @get /filings
function(cik = "") {
  if (cik == "") return(list(error = "CIK is required"))
  
  # Try to get from DB first
  filings <- get_filings(cik)
  
  if (is.null(filings) || nrow(filings) == 0) {
    # Fetch from SEC
    submissions <- fetch_company_submissions(cik)
    if (!is.null(submissions)) {
      save_filings(submissions, cik)
      filings <- get_filings(cik)
    }
  }
  
  return(filings)
}

#* Get Filing Text (Raw or Cleaned)
#* @param cik Company CIK
#* @param accession Accession Number
#* @param primary_doc Primary Document Name
#* @param format "text" (cleaned) or "html" (raw)
#* @get /filing-text
function(cik = "", accession = "", primary_doc = "", format = "text") {
  if (cik == "" || accession == "" || primary_doc == "") {
    return(list(error = "Missing required parameters: cik, accession, primary_doc"))
  }
  
  # 1. Check Cache (Raw HTML)
  html <- get_cached_filing_text(cik, accession)
  
  if (is.null(html)) {
    # 2. Scrape if not cached
    html <- get_filing_text(cik, accession, primary_doc, format = "html")
    if (!is.null(html)) {
      save_filing_text(cik, accession, html)
    } else {
      return(list(error = "Failed to fetch filing text"))
    }
  }
  
  # 3. Return requested format
  if (format == "html") {
    # Return raw HTML
    return(list(cik = cik, accession = accession, format = "html", content = html))
  } else {
    # Return Cleaned Text (DOM + TOC Removal)
    text <- clean_10k_text(html)
    text <- remove_10k_toc(text)
    return(list(cik = cik, accession = accession, format = "text", content = text))
  }
}

#* Analyze Sentiment of a Filing
#* @param cik Company CIK
#* @param accession Accession Number
#* @param primary_doc Primary Document Name
#* @get /sentiment
function(cik = "", accession = "", primary_doc = "") {
  if (cik == "" || accession == "" || primary_doc == "") {
    return(list(error = "Missing required parameters: cik, accession, primary_doc"))
  }
  
  # 1. Fetch/Load Text (Raw HTML)
  html <- get_cached_filing_text(cik, accession)
  
  if (is.null(html)) {
    html <- get_filing_text(cik, accession, primary_doc, format = "html")
    if (!is.null(html)) {
      save_filing_text(cik, accession, html)
    } else {
      return(list(error = "Failed to fetch filing text"))
    }
  }
  
  # 2. Clean Text (DOM + TOC Removal)
  text <- clean_10k_text(html)
  text <- remove_10k_toc(text)
  
  # 3. Calculate Sentiment
  scores <- calculate_sentiment(text)
  
  if (is.null(scores)) {
    return(list(error = "Failed to calculate sentiment (empty text or no dictionary matches)"))
  }
  
  # Add metadata
  scores$cik <- cik
  scores$accession <- accession
  
  return(scores)
}
