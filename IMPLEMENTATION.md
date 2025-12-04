# SEC Data Viewer - Implementation Guide

This document provides a detailed overview of the SEC Data Viewer application, explaining the architecture, key components, and data flow.

## Project Structure

```
Project_R/
├── app.R                  # Main Shiny Application (UI + Server)
├── api.R                  # Plumber JSON API
├── config.json            # Configuration (User-Agent, DB Path)
├── run_app.sh             # Script to launch the Shiny App
├── run_api.sh             # Script to launch the API
├── data/
│   ├── sec_data.sqlite    # SQLite Database (Cache)
│   └── Loughran-McDonald_MasterDictionary_1993-2024.csv
├── R/                     # Helper Scripts
│   ├── sec_api.R          # SEC API Interaction
│   ├── db_utils.R         # Database Management
│   ├── scrapper_sec.R     # HTML Scraping
│   ├── cleaning.R         # DOM-based Text Cleaning
│   ├── cleaning_toc.R     # Table of Contents Removal
│   └── sentiment.R        # Sentiment Analysis
└── tests/                 # Verification Scripts
    ├── test_api.R
    ├── test_cleaning.R
    ├── test_cleaning_multiple.R
    ├── test_scrapper.R
    ├── test_sentiment.R
    └── test_toc_removal.R
```

## Key Components

### 1. Data Acquisition (`R/sec_api.R`, `R/scrapper_sec.R`)
-   **SEC API**: We use the official SEC EDGAR API to fetch:
    -   **Company Tickers**: `fetch_company_tickers()`
    -   **Submissions (Filings)**: `fetch_company_submissions(cik)`
    -   **Company Facts (XBRL)**: `fetch_company_facts(cik)`
-   **Scraper**: For the actual text of 10-K filings, we construct the URL and download the raw HTML using `get_filing_text()`.
-   **Compliance**: All requests include a `User-Agent` header (email) as required by the SEC.

### 2. Data Storage (`R/db_utils.R`)
-   **SQLite**: We use a local SQLite database (`data/sec_data.sqlite`) to cache data.
-   **Tables**:
    -   `companies`: CIK, Ticker, Title.
    -   `filings`: Metadata about recent filings.
    -   `facts`: Financial data points (US-GAAP).
    -   `filing_texts`: Cached raw HTML content of filings.
-   **Caching Strategy**: We check the DB first. If data is missing, we fetch from the SEC and save it.

### 3. Text Cleaning (`R/cleaning.R`, `R/cleaning_toc.R`)
We employ a two-stage cleaning process to transform raw HTML into readable text:
-   **Stage 1 (DOM Cleaning)**: Uses `rvest` to parse the HTML and remove:
    -   `<table` nodes (financial tables).
    -   `<xbrl` and `<xml` nodes (machine-readable data).
    -   `<script>` and `<style>` tags.
-   **Stage 2 (TOC Removal)**: Uses a heuristic to identify the "Table of Contents" block (usually ending before "Item 1. Business") and removes it, allowing the user to jump straight to the narrative.

### 4. Sentiment Analysis (`R/sentiment.R`)
-   **Dictionary**: We use the **Loughran-McDonald Master Dictionary**, which is tailored for financial texts.
-   **Process**:
    1.  **Tokenization**: Split text into words, remove numbers and short words.
    2.  **Matching**: Match tokens against the dictionary.
    3.  **Scoring**: Count words in categories: *Negative, Positive, Uncertainty, Litigious, Strong Modal, Weak Modal, Constraining*.
    4.  **Result**: Returns counts and percentages (Count / Total Words).

### 5. User Interface (`app.R`)
-   **Shiny**: The frontend is built with R Shiny.
-   **Tabs**:
    -   **Filings**: Table of recent 10-Ks, 10-Qs, etc.
    -   **Financial Facts**: Interactive plot of financial metrics (e.g., Net Income) over time.
    -   **10-K Text**: Viewer for filings with a toggle between "Raw" and "Cleaned" text.
    -   **Sentiment Analysis**: Dashboard showing sentiment scores for the loaded filing.

## Setup and Usage

### 1. Prerequisites
Ensure you have the following installed on your system:
-   **R** (Version 4.0 or higher)
-   **System Libraries** (Required for R packages):
    -   `libxml2` (for `xml2`/`rvest`)
    -   `openssl` (for `httr`)
    -   `libcurl` (for `httr`)

### 2. Installation
1.  **Clone the Repository**:
    ```bash
    git clone <repository-url>
    cd Project_R
    ```
2.  **Install R Packages**:
    Open R or RStudio and run:
    ```r
    install.packages(c("shiny", "plumber", "httr", "jsonlite", "dplyr", "DBI", "RSQLite", "rvest", "xml2", "stringr", "tidytext", "readr", "ggplot2", "DT", "tidyr"))
    ```

### 3. Configuration
Create a `config.json` file in the project root. This is **critical** for SEC API access.
```json
{
  "user_agent": "Your Name <your.email@example.com>",
  "db_path": "data/sec_data.sqlite"
}
```
*Note: The SEC requires a valid User-Agent string identifying the requester.*

### 4. Running the Application
To launch the interactive Shiny dashboard:
```bash
./run_app.sh
```
-   This script automatically clears the `sec_data.sqlite` cache on startup to ensure you see fresh data.
-   The app will open in your default web browser (usually at `http://127.0.0.1:XXXX`).

### 5. Running the API
To launch the Plumber API backend:
```bash
./run_api.sh
```
-   The API documentation (Swagger UI) will be available at `http://127.0.0.1:8000/__docs__/`.
-   **Endpoints**:
    -   `GET /companies`: List all companies.
    -   `GET /filings?cik=...`: Get filings for a company.
    -   `GET /facts?cik=...`: Get financial facts.
    -   `GET /sentiment?cik=...`: Get sentiment analysis.
    -   `GET /analysis/financials?cik=...`: Get financial KPIs and YoY growth.

### 6. Verification
To verify that the system is working correctly, you can run the test suite:
```bash
Rscript tests/test_scrapper.R        # Test HTML fetching
Rscript tests/test_sentiment.R       # Test sentiment logic
Rscript tests/test_financial_analysis.R # Test KPI calculations
```
