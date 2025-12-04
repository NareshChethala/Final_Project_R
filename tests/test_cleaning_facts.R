# Test Fact Cleaning Logic
source("R/cleaning_facts.R")
library(dplyr)

print("---------------------------------------------------")
print("Testing Fact Cleaning (Latest per FY)...")

# Create mock data with duplicates for FY 2023
# Scenario: 
# - 2023 data filed on 2024-02-01 (Older)
# - 2023 data filed on 2024-03-01 (Newer/Correction)
# - 2022 data (Single entry)

mock_facts <- tibble(
  cik = 123,
  concept = "NetIncomeLoss",
  fy = c(2023, 2023, 2022),
  val = c(100, 150, 80),
  filed = c("2024-02-01", "2024-03-01", "2023-02-01"),
  form = "10-K"
)

print("Mock Data:")
print(mock_facts)

cleaned_facts <- clean_facts_latest(mock_facts)

print("Cleaned Data:")
print(cleaned_facts)

# Verification
# Should have 2 rows (2022 and 2023)
# 2023 value should be 150 (from 2024-03-01)

if (nrow(cleaned_facts) == 2 && 
    cleaned_facts$val[cleaned_facts$fy == 2023] == 150) {
  print("PASS: Fact cleaning logic works (kept latest 2023 value).")
} else {
  print("FAIL: Fact cleaning logic failed.")
}
