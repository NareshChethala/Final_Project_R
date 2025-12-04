# ==============================================================================
# Financial Analysis
# ==============================================================================
# Functions to analyze financial statements and calculate KPIs.
# ==============================================================================

library(dplyr)
library(tidyr)

#' Analyze Financials
#' @description Extracts key KPIs and calculates Year-over-Year (YoY) percentage changes.
#' @param cik Company CIK
#' @return Dataframe with FY, Metric, Value, and YoY_Change
analyze_financials <- function(cik) {
  if (is.null(cik) || cik == "") return(NULL)
  
  # 1. Fetch Facts
  # We need to ensure we have the data. If not in DB, fetch it.
  facts <- get_facts(cik)
  if (is.null(facts) || nrow(facts) == 0) {
    facts <- fetch_company_facts(cik)
    if (!is.null(facts)) {
      facts$cik <- cik
      save_facts(facts, cik)
    }
  }
  
  if (is.null(facts) || nrow(facts) == 0) return(NULL)
  
  # 2. Clean Data (Latest per FY)
  facts_clean <- clean_facts_latest(facts)
  
  # 3. Define Key Concepts to Track
  # Map common US-GAAP tags to readable names
  # Note: This is a simplified mapping. Real-world mapping is complex.
  target_concepts <- c(
    "NetIncomeLoss" = "Net Income",
    "ProfitLoss" = "Net Income", # Alternative
    "Revenues" = "Revenue",
    "SalesRevenueNet" = "Revenue", # Alternative
    "RevenueFromContractWithCustomerExcludingAssessedTax" = "Revenue", # Alternative
    "Assets" = "Total Assets",
    "Liabilities" = "Total Liabilities",
    "StockholdersEquity" = "Stockholders' Equity",
    "EarningsPerShareBasic" = "EPS (Basic)",
    "OperatingIncomeLoss" = "Operating Income"
  )
  
  # Filter for target concepts
  df_analysis <- facts_clean %>%
    filter(concept %in% names(target_concepts)) %>%
    mutate(Metric = target_concepts[concept]) %>%
    # If multiple concepts map to same Metric (e.g. Revenue), prioritize or take max?
    # For simplicity, we'll group by FY and Metric and take the one with largest value (heuristic)
    # or just take the first one found if we trust the order.
    group_by(fy, Metric) %>%
    arrange(desc(val)) %>% # Heuristic: larger value usually main aggregate
    slice(1) %>%
    ungroup() %>%
    select(FY = fy, Metric, Value = val) %>%
    arrange(FY)
  
  # 4. Calculate YoY Change
  df_final <- df_analysis %>%
    group_by(Metric) %>%
    arrange(FY) %>%
    mutate(
      Prev_Value = lag(Value),
      YoY_Change = ifelse(!is.na(Prev_Value) & Prev_Value != 0, 
                          ((Value - Prev_Value) / abs(Prev_Value)) * 100, 
                          NA)
    ) %>%
    ungroup() %>%
    select(FY, Metric, Value, YoY_Change) %>%
    arrange(desc(FY), Metric)
  
  return(df_final)
}
