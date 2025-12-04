# Test Sentiment Analysis
source("R/sentiment.R")
source("R/sec_api.R")
source("R/scrapper_sec.R")
source("R/cleaning.R")
source("R/cleaning_toc.R")
source("R/db_utils.R")

init_db()

# Test Sentiment Analysis Logic
source("R/sentiment.R")
library(dplyr)
library(tidytext)

print("---------------------------------------------------")
print("Testing Sentiment Logic (New Formula)...")

# 1. Simple Text Test
# "Good" is positive, "Bad" is negative, "the" is a stop word.
# Text: "The good bad."
# Tokens (after stop words): "good", "bad"
# Total Tokens: 2
# Positive: 1 (good)
# Negative: 1 (bad)
# Score: ((1 - 1) / 2) * 100 = 0

text_neutral <- "The good bad."
scores_neutral <- calculate_sentiment(text_neutral)
print("Neutral Text ('The good bad.'):")
print(scores_neutral)

if (!is.null(scores_neutral) && scores_neutral$Sentiment_Score == 0) {
  print("PASS: Neutral score correct.")
} else {
  print("FAIL: Neutral score incorrect.")
}

# 2. Positive Text Test
# "Excellent performance."
# Tokens: "excellent", "performance"
# "excellent" -> Positive (2009)
# "performance" -> Neutral (0)
# Score: ((1 - 0) / 2) * 100 = 50

text_pos <- "Excellent performance."
scores_pos <- calculate_sentiment(text_pos)
print("Positive Text ('Excellent performance.'):")
print(scores_pos)

if (!is.null(scores_pos) && scores_pos$Sentiment_Score == 50) {
  print("PASS: Positive score correct.")
} else {
  print("FAIL: Positive score incorrect.")
}

# 3. Stop Word Test
# "The and of a excellent."
# Tokens: "excellent" (others are stop words)
# Total: 1
# Pos: 1
# Score: 100

text_stop <- "The and of a excellent."
scores_stop <- calculate_sentiment(text_stop)
print("Stop Word Text ('The and of a excellent.'):")
print(scores_stop)

if (!is.null(scores_stop) && scores_stop$Sentiment_Score == 100) {
  print("PASS: Stop word removal correct.")
} else {
  print("FAIL: Stop word removal incorrect.")
}

# 2. Test with Real 10-K (Apple)
print("---------------------------------------------------")
print("Testing with Apple 10-K...")

# Ensure companies are populated
con <- DBI::dbConnect(RSQLite::SQLite(), "data/sec_data.sqlite")
if (DBI::dbGetQuery(con, "SELECT count(*) FROM companies")[[1]] == 0) {
  tickers <- fetch_company_tickers()
  save_companies(tickers)
}
DBI::dbDisconnect(con)

res <- get_company_cik("Apple")
if (nrow(res) > 0) {
  cik <- res$cik[1]
  subs <- fetch_company_submissions(cik)
  latest_10k <- subs %>% filter(form == "10-K") %>% head(1)
  
  if (nrow(latest_10k) > 0) {
    accession <- latest_10k$accessionNumber
    primary_doc <- latest_10k$primaryDocument
    
    print("Fetching HTML...")
    html <- get_filing_text(cik, accession, primary_doc, format = "html")
    
    if (!is.null(html)) {
      print("Cleaning Text...")
      text <- clean_10k_text(html)
      text <- remove_10k_toc(text)
      
      print("Calculating Sentiment...")
      start_time <- Sys.time()
      scores <- calculate_sentiment(text)
      end_time <- Sys.time()
      
      print(paste("Time taken:", round(end_time - start_time, 2), "seconds"))
      print("Scores:")
      print(scores)
      
      if (scores$Total_Words > 0) {
        print("PASS: Sentiment calculated.")
      } else {
        print("FAIL: No words counted.")
      }
    }
  }
}
