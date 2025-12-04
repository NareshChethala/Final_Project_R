# library(plumber) # Skipped as it might not be installed
library(jsonlite)

# Source helper scripts
source("R/sec_api.R")
source("R/db_utils.R")

print("Testing config loading...")
headers <- get_headers()
print(headers)

print("Testing DB path...")
path <- get_db_path()
print(path)

print("Testing search logic...")
res <- get_company_cik("Apple")
print(res)

if (nrow(res) > 0) {
  cik <- res$cik[1]
  print(paste("Testing facts logic for CIK:", cik))
  facts <- get_facts(cik)
  print(paste("Retrieved", nrow(facts), "facts"))
}

print("Logic verification complete.")
