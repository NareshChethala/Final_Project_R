source("R/financial_analysis.R")
source("R/cleaning_facts.R")
source("R/db_utils.R")
source("R/sec_api.R")
library(dplyr)

init_db()

print("---------------------------------------------------")
print("Testing Financial Analysis...")

# 1. Mock Data Test
# Create mock facts with Revenue for 2 years
# 2023: 100
# 2024: 120 (20% growth)

mock_facts <- tibble(
  cik = 123,
  concept = "Revenues",
  fy = c(2023, 2024),
  val = c(100, 120),
  filed = c("2024-02-01", "2025-02-01"),
  form = "10-K"
)

# We need to mock get_facts or modify analyze_financials to accept data.
# analyze_financials calls get_facts internally.
# For unit testing, it's better if analyze_financials accepts data or we mock the DB.
# However, analyze_financials is designed for the app flow.
# Let's verify with real data (Apple) since we have it in DB.

print("Testing with Apple (CIK 320193)...")
cik <- 320193

# Ensure we have facts
facts <- get_facts(cik)
if (is.null(facts) || nrow(facts) == 0) {
  print("Fetching facts...")
  facts <- fetch_company_facts(cik)
  save_facts(facts, cik)
}

analysis <- analyze_financials(cik)

print("Analysis Result:")
print(head(analysis, 10))

# Check if we have Revenue and Net Income
has_revenue <- any(analysis$Metric == "Revenue")
has_net_income <- any(analysis$Metric == "Net Income")

if (has_revenue && has_net_income) {
  print("PASS: Analysis contains key metrics.")
  
  # Check YoY Calculation
  # Find a year with previous data
  rev_data <- analysis %>% filter(Metric == "Revenue") %>% arrange(FY)
  if (nrow(rev_data) >= 2) {
    val_curr <- rev_data$Value[2]
    val_prev <- rev_data$Value[1]
    yoy_calc <- ((val_curr - val_prev) / abs(val_prev)) * 100
    yoy_rep <- rev_data$YoY_Change[2]
    
    if (abs(yoy_calc - yoy_rep) < 0.1) {
      print(paste("PASS: YoY Calculation correct for Revenue (", round(yoy_calc, 2), "%)."))
    } else {
      print(paste("FAIL: YoY Calculation mismatch. Calc:", yoy_calc, "Rep:", yoy_rep))
    }
  } else {
    print("WARN: Not enough Revenue data for YoY check.")
  }
  
} else {
  print("FAIL: Missing key metrics.")
}
