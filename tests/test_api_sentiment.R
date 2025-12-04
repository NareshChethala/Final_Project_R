# Test API Sentiment Endpoint
source("api.R") # Source the API definition to access functions

# We can test the function directly without running the server
# The function is defined anonymously in api.R, so we can't call it by name easily 
# unless we extract it or modify api.R to name functions.
# However, for this verification, we can just replicate the logic or use the helper functions directly 
# to ensure the flow works, OR we can source api.R and if the functions were named, call them.

# Since api.R uses #* annotations, the functions are not assigned to global variables by default in a way that's easy to test without plumber.
# BUT, we can just verify the logic flow using the helpers, which is what the API does.

print("---------------------------------------------------")
print("Testing API Logic for Sentiment...")

source("R/sec_api.R")
source("R/scrapper_sec.R")
source("R/cleaning.R")
source("R/cleaning_toc.R")
source("R/sentiment.R")
source("R/db_utils.R")

init_db()

# Mock parameters for Apple
cik <- 320193
accession <- "0000320193-25-000079"
primary_doc <- "aapl-20250927.htm"

print("1. Fetching/Loading Text...")
html <- get_cached_filing_text(cik, accession)
if (is.null(html)) {
  html <- get_filing_text(cik, accession, primary_doc, format = "html")
}

if (!is.null(html)) {
  print("2. Cleaning Text...")
  text <- clean_10k_text(html)
  text <- remove_10k_toc(text)
  
  print("3. Calculating Sentiment...")
  scores <- calculate_sentiment(text)
  
  print("Scores:")
  print(scores)
  
  if (!is.null(scores) && scores$Total_Words > 0) {
    print("PASS: API logic for sentiment works.")
  } else {
    print("FAIL: No scores returned.")
  }
} else {
  print("FAIL: Could not fetch text.")
}
