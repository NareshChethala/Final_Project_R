# ==============================================================================
# Database Utilities
# ==============================================================================
# Functions to manage the SQLite database cache.
# Stores: Companies, Filings, Facts, and Filing Texts.
# ==============================================================================

library(DBI)
library(RSQLite)
library(jsonlite)

#' Get Database Path
#' @return Path to the SQLite database file
get_db_path <- function() {
  config_path <- "config.json"
  if (file.exists(config_path)) {
    config <- fromJSON(config_path)
    if (!is.null(config$db_path)) {
      return(config$db_path)
    }
  }
  return("data/sec_data.sqlite")
}

#' Initialize Database
#' @description Creates tables if they do not exist.
init_db <- function() {
  db_path <- get_db_path()
  dir.create(dirname(db_path), showWarnings = FALSE, recursive = TRUE)
  
  con <- dbConnect(RSQLite::SQLite(), db_path)
  
  # 1. Companies Table
  dbExecute(con, "CREATE TABLE IF NOT EXISTS companies (
            cik INTEGER PRIMARY KEY,
            ticker TEXT,
            title TEXT
            )")
  
  # 2. Filings Table
  dbExecute(con, "CREATE TABLE IF NOT EXISTS filings (
            accessionNumber TEXT PRIMARY KEY,
            cik INTEGER,
            filingDate TEXT,
            reportDate TEXT,
            form TEXT,
            primaryDocument TEXT,
            size INTEGER
            )")
  
  # 3. Facts Table
  dbExecute(con, "CREATE TABLE IF NOT EXISTS facts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cik INTEGER,
            concept TEXT,
            unit TEXT,
            val REAL,
            fy INTEGER,
            fp TEXT,
            form TEXT,
            filed TEXT,
            frame TEXT
            )")
  
  # 4. Filing Texts Table (Cache for HTML)
  dbExecute(con, "CREATE TABLE IF NOT EXISTS filing_texts (
            accessionNumber TEXT PRIMARY KEY,
            cik INTEGER,
            html_content TEXT,
            last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )")
  
  dbDisconnect(con)
}

# ------------------------------------------------------------------------------
# Save Functions
# ------------------------------------------------------------------------------

#' Save Companies to DB
save_companies <- function(df) {
  con <- dbConnect(RSQLite::SQLite(), get_db_path())
  # Overwrite the companies table with the fresh list from SEC
  dbWriteTable(con, "companies", df, overwrite = TRUE)
  dbDisconnect(con)
}

#' Save Filings to DB
save_filings <- function(df, cik) {
  con <- dbConnect(RSQLite::SQLite(), get_db_path())
  
  # Select relevant columns
  cols <- c("accessionNumber", "filingDate", "reportDate", "form", "primaryDocument", "size")
  df_save <- df[, cols, drop = FALSE]
  df_save$cik <- cik
  
  # Reorder columns to match DB schema: accessionNumber, cik, filingDate, reportDate, form, primaryDocument, size
  df_save <- df_save[, c("accessionNumber", "cik", "filingDate", "reportDate", "form", "primaryDocument", "size")]
  
  # Use INSERT OR IGNORE to avoid duplicates
  dbWriteTable(con, "temp_filings", df_save, overwrite = TRUE, row.names = FALSE)
  
  # Use explicit column names to ensure correct mapping
  dbExecute(con, "INSERT OR IGNORE INTO filings (accessionNumber, cik, filingDate, reportDate, form, primaryDocument, size) 
                  SELECT accessionNumber, cik, filingDate, reportDate, form, primaryDocument, size FROM temp_filings")
  
  dbExecute(con, "DROP TABLE temp_filings")
  
  dbDisconnect(con)
}

#' Save Facts to DB
save_facts <- function(df, cik) {
  con <- dbConnect(RSQLite::SQLite(), get_db_path())
  
  # Ensure columns match schema
  cols <- c("cik", "concept", "unit", "val", "fy", "fp", "form", "filed", "frame")
  # Add missing columns with NA if needed
  for (col in cols) {
    if (!col %in% names(df)) df[[col]] <- NA
  }
  
  df_save <- df[, cols, drop = FALSE]
  
  # Clear old facts for this CIK to avoid duplicates/stale data
  dbExecute(con, "DELETE FROM facts WHERE cik = ?", params = list(cik))
  
  dbWriteTable(con, "facts", df_save, append = TRUE)
  dbDisconnect(con)
}

#' Save Filing Text (HTML) to DB
save_filing_text <- function(cik, accession, html) {
  con <- dbConnect(RSQLite::SQLite(), get_db_path())
  # Upsert logic (Replace)
  dbExecute(con, "INSERT OR REPLACE INTO filing_texts (accessionNumber, cik, html_content) VALUES (?, ?, ?)",
            params = list(accession, cik, html))
  dbDisconnect(con)
}

# ------------------------------------------------------------------------------
# Get Functions
# ------------------------------------------------------------------------------

#' Get CIK by Query
get_company_cik <- function(query) {
  con <- dbConnect(RSQLite::SQLite(), get_db_path())
  
  # Check if query is numeric (CIK) or string (Name/Ticker)
  if (grepl("^\\d+$", query)) {
    res <- dbGetQuery(con, "SELECT * FROM companies WHERE cik = ?", params = list(query))
  } else {
    # Case-insensitive search for Ticker or Title
    q_wild <- paste0("%", query, "%")
    res <- dbGetQuery(con, "SELECT * FROM companies WHERE ticker LIKE ? OR title LIKE ?", 
                      params = list(q_wild, q_wild))
  }
  
  dbDisconnect(con)
  return(res)
}

#' Get Filings for CIK
get_filings <- function(cik) {
  con <- dbConnect(RSQLite::SQLite(), get_db_path())
  res <- dbGetQuery(con, "SELECT * FROM filings WHERE cik = ? ORDER BY filingDate DESC", params = list(cik))
  dbDisconnect(con)
  return(res)
}

#' Get Facts for CIK
get_facts <- function(cik) {
  con <- dbConnect(RSQLite::SQLite(), get_db_path())
  res <- dbGetQuery(con, "SELECT * FROM facts WHERE cik = ?", params = list(cik))
  dbDisconnect(con)
  return(res)
}

#' Get Cached Filing Text
get_cached_filing_text <- function(cik, accession) {
  con <- dbConnect(RSQLite::SQLite(), get_db_path())
  res <- dbGetQuery(con, "SELECT html_content FROM filing_texts WHERE cik = ? AND accessionNumber = ?", 
                    params = list(cik, accession))
  dbDisconnect(con)
  
  if (nrow(res) > 0) {
    return(res$html_content[1])
  } else {
    return(NULL)
  }
}
