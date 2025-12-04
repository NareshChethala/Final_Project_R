# ==============================================================================
# Fact Cleaning
# ==============================================================================
# Functions to clean and deduplicate financial facts.
# ==============================================================================

library(dplyr)

#' Clean Facts (Latest per FY)
#' @description Deduplicates facts by keeping only the latest filing for each Fiscal Year (FY).
#' @param df Dataframe of facts (must contain cik, concept, fy, val, filed)
#' @return Cleaned dataframe with one row per FY per Concept
clean_facts_latest <- function(df) {
  if (is.null(df) || nrow(df) == 0) return(df)
  
  # Ensure required columns exist
  req_cols <- c("cik", "concept", "fy", "val", "filed")
  if (!all(req_cols %in% colnames(df))) {
    warning("Dataframe missing required columns for cleaning: ", paste(setdiff(req_cols, colnames(df)), collapse = ", "))
    return(df)
  }
  
  df_clean <- df %>%
    # Remove rows with missing key data
    filter(!is.na(fy), !is.na(val), !is.na(filed)) %>%
    # Group by Company, Concept, and Fiscal Year
    group_by(cik, concept, fy) %>%
    # Arrange by Filing Date (descending) to get the latest first
    # If filing dates are same, we could use other tie-breakers, but usually date is enough
    arrange(desc(filed)) %>%
    # Select the first row (latest)
    slice(1) %>%
    ungroup() %>%
    arrange(fy)
  
  return(df_clean)
}
