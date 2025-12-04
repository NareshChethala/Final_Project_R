# ==============================================================================
# Text Cleaning (TOC Removal)
# ==============================================================================
# Heuristic-based function to remove the Table of Contents from 10-K text.
# ==============================================================================

library(stringr)

#' Remove Table of Contents
#' @description Identifies the start of the "Business" section and removes preceding text (TOC).
#' @param text The cleaned text (from clean_10k_text)
#' @return Text with TOC removed
remove_10k_toc <- function(text) {
  if (is.null(text) || nchar(text) == 0) return("")
  
  # Heuristic: Find "Item 1. Business"
  # The TOC usually lists "Item 1. Business ...... [Page]".
  # The actual content starts with "Item 1. Business" followed by a paragraph.
  
  # We look for all occurrences of "Item 1. Business"
  matches <- str_locate_all(text, regex("Item\\s+1\\.\\s+Business", ignore_case = TRUE))[[1]]
  
  if (nrow(matches) == 0) return(text)
  
  best_start <- 1
  
  # Iterate through matches to find the one that looks like the content header
  for (i in 1:nrow(matches)) {
    start_pos <- matches[i, 1]
    end_pos <- matches[i, 2]
    
    # Look ahead 100 chars
    lookahead <- substr(text, end_pos, end_pos + 100)
    
    # 1. If followed by dots or numbers, it's likely a TOC entry
    if (str_detect(lookahead, "^[\\s\\.]+\\d+")) {
      next 
    }
    
    # 2. If followed closely by "Item 1A", it's likely a TOC block
    if (str_detect(lookahead, regex("Item\\s+1A", ignore_case = TRUE))) {
      next 
    }
    
    # If we pass these checks, it's likely the start of the content
    best_start <- start_pos
    break
  }
  
  # If we found a valid start, cut everything before it
  if (best_start > 1) {
    return(substr(text, best_start, nchar(text)))
  }
  
  return(text)
}
