# ==============================================================================
# Sentiment Analysis
# ==============================================================================
# Functions to perform sentiment analysis using the Loughran-McDonald dictionary.
# ==============================================================================

library(dplyr)
library(readr)
library(stringr)
library(tidytext)

# Global cache for the dictionary to avoid reloading it every time
lm_dictionary <- NULL

#' Load LM Dictionary
#' @description Loads the dictionary from CSV if not already cached.
#' @return Data frame with words and sentiment categories
load_lm_dictionary <- function() {
  if (!is.null(lm_dictionary)) return(lm_dictionary)
  
  dict_path <- "data/Loughran-McDonald_MasterDictionary_1993-2024.csv"
  if (!file.exists(dict_path)) {
    stop("LM Dictionary not found at ", dict_path)
  }
  
  # Read only necessary columns
  cols_to_keep <- c("Word", "Negative", "Positive", "Uncertainty", 
                    "Litigious", "Strong_Modal", "Weak_Modal", "Constraining")
  
  df <- read_csv(dict_path, col_select = all_of(cols_to_keep), show_col_types = FALSE)
  
  # Filter for words that have at least one sentiment flag
  df <- df %>%
    filter(Negative > 0 | Positive > 0 | Uncertainty > 0 | 
             Litigious > 0 | Strong_Modal > 0 | Weak_Modal > 0 | Constraining > 0)
  
  lm_dictionary <<- df
  return(df)
}

#' Preprocess Text
#' @description Tokenizes text, removes stop words, and keeps only alphabetic tokens.
#' @param text Raw text string
#' @return Dataframe of tokens
preprocess_text <- function(text) {
  if (is.null(text) || nchar(text) == 0) return(tibble(word = character()))
  
  # Ensure stop_words are available
  if (!exists("stop_words")) {
    data("stop_words", package = "tidytext", envir = environment())
  }
  
  text_df <- tibble(text = text)
  
  tokens <- text_df %>%
    unnest_tokens(word, text)
  
  # Remove stop words (unnest_tokens converts to lowercase by default)
  tokens <- tokens %>%
    anti_join(stop_words, by = "word")
    
  tokens <- tokens %>%
    # Keep only alphabetic tokens (no numbers or punctuation leftovers)
    filter(str_detect(word, "^[a-z]+$")) %>%
    # Convert to uppercase to match LM dictionary
    mutate(word = toupper(word))
  
  return(tokens)
}

#' Calculate Sentiment Scores
#' @description Calculates sentiment scores using Loughran-McDonald dictionary.
#' Formula: ((Positive - Negative) / Total_Tokens) * 100
#' @param text Cleaned text string
#' @return Dataframe with counts, percentages, and Net Sentiment Score
calculate_sentiment <- function(text) {
  if (is.null(text) || nchar(text) == 0) return(NULL)
  
  dict <- load_lm_dictionary()
  tokens <- preprocess_text(text)
  total_words <- nrow(tokens)
  
  if (total_words == 0) return(NULL)
  
  # Count sentiment words
  sentiment_counts <- tokens %>%
    inner_join(dict, by = c("word" = "Word")) %>%
    summarise(
      Negative = sum(Negative > 0),
      Positive = sum(Positive > 0),
      Uncertainty = sum(Uncertainty > 0),
      Litigious = sum(Litigious > 0),
      Strong_Modal = sum(Strong_Modal > 0),
      Weak_Modal = sum(Weak_Modal > 0),
      Constraining = sum(Constraining > 0)
    )
  
  # Handle case where no sentiment words are found
  if (nrow(sentiment_counts) == 0) {
    sentiment_counts <- tibble(
      Negative = 0, Positive = 0, Uncertainty = 0, Litigious = 0,
      Strong_Modal = 0, Weak_Modal = 0, Constraining = 0
    )
  }
  
  # Add Total Words
  sentiment_counts$Total_Words <- total_words
  
  # Calculate Net Sentiment Score
  # ((Positive - Negative) / Total) * 100
  sentiment_counts$Sentiment_Score <- ((sentiment_counts$Positive - sentiment_counts$Negative) / total_words) * 100
  
  # Calculate Percentages for other categories (for context)
  sentiment_counts <- sentiment_counts %>%
    mutate(
      Negative_Pct = (Negative / Total_Words) * 100,
      Positive_Pct = (Positive / Total_Words) * 100,
      Uncertainty_Pct = (Uncertainty / Total_Words) * 100,
      Litigious_Pct = (Litigious / Total_Words) * 100,
      Strong_Modal_Pct = (Strong_Modal / Total_Words) * 100,
      Weak_Modal_Pct = (Weak_Modal / Total_Words) * 100,
      Constraining_Pct = (Constraining / Total_Words) * 100
    )
  
  return(sentiment_counts)
}
