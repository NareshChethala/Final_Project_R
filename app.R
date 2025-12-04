# ==============================================================================
# SEC Data Viewer - Shiny Application
# ==============================================================================
# This application allows users to:
# 1. Search for companies by CIK or Name.
# 2. View recent filings (10-K, 10-Q, etc.).
# 3. Visualize financial facts (e.g., Net Income, Assets) over time.
# 4. Read 10-K filings with options for Raw or Cleaned text.
# 5. Analyze sentiment of 10-K filings using the Loughran-McDonald dictionary.
# ==============================================================================

library(shiny)
library(DT)
library(ggplot2)
library(dplyr)
library(rvest)
library(tidyr)

# ------------------------------------------------------------------------------
# Source Helper Scripts
# ------------------------------------------------------------------------------
source("R/sec_api.R")       # SEC API interaction functions
source("R/db_utils.R")      # Database management (SQLite)
source("R/scrapper_sec.R")  # Scraping logic for 10-K HTML
source("R/cleaning.R")      # Text cleaning (DOM-based)
source("R/cleaning_toc.R")  # Table of Contents removal
source("R/cleaning_facts.R") # Fact cleaning (deduplication)
source("R/financial_analysis.R") # Financial KPI analysis
source("R/financial_plots.R")    # Financial plots
source("R/sentiment.R")     # Sentiment analysis logic

# ------------------------------------------------------------------------------
# Initialization
# ------------------------------------------------------------------------------
# Initialize the SQLite database and tables if they don't exist
init_db()

# Check if the companies table needs population (first run)
con <- DBI::dbConnect(RSQLite::SQLite(), "data/sec_data.sqlite")
if (DBI::dbGetQuery(con, "SELECT count(*) FROM companies")[[1]] == 0) {
  message("Initializing companies table from SEC tickers...")
  tickers <- fetch_company_tickers()
  save_companies(tickers)
}
DBI::dbDisconnect(con)

# ------------------------------------------------------------------------------
# UI Definition
# ------------------------------------------------------------------------------
ui <- fluidPage(
  titlePanel("SEC Data Viewer"),
  
  sidebarLayout(
    sidebarPanel(
      # Search Input
      textInput("search_query", "Enter CIK or Company Name:", placeholder = "e.g., Apple or 320193"),
      actionButton("search_btn", "Search", class = "btn-primary"),
      hr(),
      helpText("Data is cached locally in 'data/sec_data.sqlite' for performance.")
    ),
    
    mainPanel(
      # Company Title Header
      h3(textOutput("company_title")),
      
      # Tabs for different features
      tabsetPanel(
        
        # Tab 1: Filings List
        tabPanel("Filings (Last 5 Years)", 
                 br(),
                 DTOutput("filings_table")
        ),
        
        # Tab 2: Financial Facts Visualization
        tabPanel("Financial Facts",
                 br(),
                 selectInput("concept_select", "Select Metric:", choices = NULL),
                 plotOutput("facts_plot"),
                 br(),
                 DTOutput("facts_table")
        ),
        
        # Tab 3: Financial Analysis (New)
        tabPanel("Financial Analysis",
                 br(),
                 h4("Key Performance Indicators (KPIs)"),
                 tabsetPanel(
                   tabPanel("Data Table", 
                            br(),
                            p("Year-over-Year (YoY) percentage change for key financial metrics."),
                            DTOutput("analysis_table")
                   ),
                   tabPanel("Trend Charts",
                            br(),
                            plotOutput("analysis_trend_plot", height = "600px")
                   ),
                   tabPanel("Growth Charts",
                            br(),
                            plotOutput("analysis_growth_plot", height = "600px")
                   )
                 )
        ),
        
        # Tab 4: 10-K Text Viewer
        tabPanel("10-K Text",
                 br(),
                 selectInput("filing_select", "Select 10-K Filing:", choices = NULL),
                 
                 # Toggle for Text Mode
                 radioButtons("text_mode", "View Mode:", 
                              choices = c("Raw Text" = "raw", "Cleaned Text" = "clean"),
                              inline = TRUE),
                 
                 actionButton("load_text_btn", "Load Text"),
                 hr(),
                 verbatimTextOutput("filing_text_display")
        ),
        
        # Tab 4: Sentiment Analysis
        tabPanel("Sentiment Analysis",
                 br(),
                 h4("Loughran-McDonald Sentiment Analysis"),
                 p("Analyze the tone of the currently loaded 10-K text."),
                 
                 # Comparison Selection
                 selectInput("comparison_select", "Compare with (Optional):", choices = NULL),
                 
                 actionButton("analyze_btn", "Analyze Sentiment", class = "btn-success"),
                 hr(),
                 plotOutput("sentiment_plot"),
                 br(),
                 DTOutput("sentiment_table")
        )
      )
    )
  )
)

# ------------------------------------------------------------------------------
# Server Logic
# ------------------------------------------------------------------------------
server <- function(input, output, session) {
  
  # Reactive Values
  selected_cik <- reactiveVal(NULL)       # Stores current company info
  filing_html_content <- reactiveVal(NULL) # Stores raw HTML of loaded filing
  sentiment_results <- reactiveVal(NULL)   # Stores sentiment analysis results (list with current and comparison)
  
  # ----------------------------------------------------------------------------
  # Search Functionality
  # ----------------------------------------------------------------------------
  observeEvent(input$search_btn, {
    req(input$search_query)
    
    withProgress(message = 'Searching...', value = 0, {
      
      # 1. Find CIK based on query
      res <- get_company_cik(input$search_query)
      
      if (nrow(res) == 0) {
        showNotification("Company not found.", type = "error")
        return()
      } else if (nrow(res) > 1) {
        showNotification(paste("Multiple matches found. Showing:", res$title[1]), type = "warning")
        cik <- res$cik[1]
        title <- res$title[1]
      } else {
        cik <- res$cik[1]
        title <- res$title[1]
      }
      
      # Update state
      selected_cik(list(cik = cik, title = title))
      
      # Reset text and sentiment when switching companies
      filing_html_content(NULL)
      sentiment_results(NULL)
      
      incProgress(0.3, detail = "Fetching data from SEC...")
      
      # 2. Fetch and Cache Data (Facts and Submissions)
      facts <- fetch_company_facts(cik)
      if (!is.null(facts)) {
        facts$cik <- cik
        save_facts(facts, cik)
      }
      
      submissions <- fetch_company_submissions(cik)
      if (!is.null(submissions)) {
        save_filings(submissions, cik)
      }
      
      incProgress(1, detail = "Done")
    })
  })
  
  # Display Company Title
  output$company_title <- renderText({
    req(selected_cik())
    paste("Company:", selected_cik()$title, "(CIK:", selected_cik()$cik, ")")
  })
  
  # ----------------------------------------------------------------------------
  # Tab 1: Filings Table
  # ----------------------------------------------------------------------------
  output$filings_table <- renderDT({
    req(selected_cik())
    df <- get_filings(selected_cik()$cik)
    datatable(df, options = list(pageLength = 10, scrollX = TRUE))
  })
  
  # ----------------------------------------------------------------------------
  # Tab 2: Financial Facts
  # ----------------------------------------------------------------------------
  facts_data <- reactive({
    req(selected_cik())
    raw_facts <- get_facts(selected_cik()$cik)
    # Apply cleaning to keep only latest value per FY
    clean_facts_latest(raw_facts)
  })
  
  # Update Concept Dropdown based on available data
  observe({
    df <- facts_data()
    if (!is.null(df) && nrow(df) > 0) {
      concepts <- sort(unique(df$concept))
      
      # Default selection logic
      selected <- concepts[1]
      if ("NetIncomeLoss" %in% concepts) selected <- "NetIncomeLoss"
      else if ("Assets" %in% concepts) selected <- "Assets"
      
      updateSelectInput(session, "concept_select", choices = concepts, selected = selected)
    }
  })
  
  # Plot Financial Data
  output$facts_plot <- renderPlot({
    req(facts_data(), input$concept_select)
    
    df <- facts_data() %>%
      filter(concept == input$concept_select) %>%
      filter(!is.na(val)) %>%
      arrange(filed)
    
    if (nrow(df) == 0) return(NULL)
    
    ggplot(df, aes(x = as.Date(filed), y = val / 1e6)) +
      geom_line(color = "#2c3e50") +
      geom_point(color = "#e74c3c") +
      labs(title = paste(input$concept_select, "Over Time"),
           x = "Filing Date", y = "Value (Millions)") +
      theme_minimal()
  })
  
  # Table of Financial Data
  output$facts_table <- renderDT({
    req(facts_data(), input$concept_select)
    
    df <- facts_data() %>%
      filter(concept == input$concept_select) %>%
      arrange(desc(filed)) %>%
      select(Date = filed, FY = fy, Form = form, Value = val, Unit = unit)
    
    datatable(df, options = list(pageLength = 10))
  })
  
  # ----------------------------------------------------------------------------
  # Tab 3: Financial Analysis
  # ----------------------------------------------------------------------------
  output$analysis_table <- renderDT({
    req(selected_cik())
    
    df <- analyze_financials(selected_cik()$cik)
    
    if (is.null(df) || nrow(df) == 0) return(NULL)
    
    # Format for display
    datatable(df, options = list(pageLength = 15)) %>%
      formatCurrency("Value", currency = "", interval = 3, mark = ",") %>%
      formatRound("YoY_Change", digits = 2) %>%
      formatStyle(
        'YoY_Change',
        color = styleInterval(0, c('red', 'green')),
        fontWeight = 'bold'
      )
  })
  
  output$analysis_trend_plot <- renderPlot({
    req(selected_cik())
    df <- analyze_financials(selected_cik()$cik)
    plot_kpi_trends(df)
  })
  
  output$analysis_growth_plot <- renderPlot({
    req(selected_cik())
    df <- analyze_financials(selected_cik()$cik)
    plot_yoy_growth(df)
  })
  
  # ----------------------------------------------------------------------------
  # Tab 4: 10-K Text Viewer & Tab 4: Comparison Dropdown Update
  # ----------------------------------------------------------------------------
  
  # Update Filing Dropdowns (Only 10-Ks)
  observe({
    req(selected_cik())
    df <- get_filings(selected_cik()$cik)
    
    if (!is.null(df) && nrow(df) > 0) {
      ten_ks <- df %>% 
        filter(form == "10-K") %>%
        arrange(desc(filingDate))
      
      if (nrow(ten_ks) > 0) {
        choices <- setNames(ten_ks$accessionNumber, paste(ten_ks$filingDate, "-", ten_ks$accessionNumber))
        
        # Update Text Viewer Dropdown
        updateSelectInput(session, "filing_select", choices = choices)
        
        # Update Comparison Dropdown (Include "None")
        comp_choices <- c("None" = "none", choices)
        updateSelectInput(session, "comparison_select", choices = comp_choices)
        
      } else {
        updateSelectInput(session, "filing_select", choices = list("No 10-Ks found" = ""))
        updateSelectInput(session, "comparison_select", choices = list("None" = "none"))
      }
    }
  })
  
  # Load Text Button Logic
  observeEvent(input$load_text_btn, {
    req(selected_cik(), input$filing_select)
    if (input$filing_select == "") return()
    
    cik <- selected_cik()$cik
    accession <- input$filing_select
    
    withProgress(message = 'Loading text...', value = 0, {
      
      # 1. Check Cache
      cached_html <- get_cached_filing_text(cik, accession)
      
      if (!is.null(cached_html)) {
        filing_html_content(cached_html)
      } else {
        # 2. Scrape if not cached
        filings <- get_filings(cik)
        primary_doc <- filings %>% 
          filter(accessionNumber == accession) %>% 
          pull(primaryDocument) %>% 
          head(1)
        
        incProgress(0.5, detail = "Scraping from SEC...")
        html <- get_filing_text(cik, accession, primary_doc, format = "html")
        
        if (!is.null(html)) {
          save_filing_text(cik, accession, html)
          filing_html_content(html)
        } else {
          filing_html_content(NULL)
          showNotification("Failed to load text.", type = "error")
        }
      }
      incProgress(1, detail = "Done")
    })
  })
  
  # Helper to process text based on selected mode
  get_current_text <- reactive({
    req(filing_html_content())
    html <- filing_html_content()
    
    if (input$text_mode == "clean") {
      # Mode: Cleaned Text
      # 1. DOM Cleaning (remove tables, XBRL)
      text <- clean_10k_text(html)
      # 2. TOC Removal (remove Table of Contents)
      text <- remove_10k_toc(text)
    } else {
      # Mode: Raw Text
      # Convert HTML to readable text, preserving structure but removing tags
      text <- rvest::html_text2(read_html(html))
    }
    return(text)
  })
  
  # Render Text Output
  output$filing_text_display <- renderText({
    get_current_text()
  })
  
  # ----------------------------------------------------------------------------
  # Tab 4: Sentiment Analysis
  # ----------------------------------------------------------------------------
  observeEvent(input$analyze_btn, {
    req(filing_html_content())
    
    withProgress(message = 'Analyzing Sentiment...', value = 0, {
      
      # 1. Analyze Current Filing
      incProgress(0.1, detail = "Processing current filing...")
      html_curr <- filing_html_content()
      text_curr <- clean_10k_text(html_curr)
      text_curr <- remove_10k_toc(text_curr)
      scores_curr <- calculate_sentiment(text_curr)
      scores_curr$Type <- "Current"
      
      # 2. Analyze Comparison Filing (if selected)
      scores_comp <- NULL
      if (input$comparison_select != "none" && input$comparison_select != "") {
        incProgress(0.4, detail = "Processing comparison filing...")
        
        cik <- selected_cik()$cik
        accession_comp <- input$comparison_select
        
        # Fetch comparison text
        html_comp <- get_cached_filing_text(cik, accession_comp)
        if (is.null(html_comp)) {
          filings <- get_filings(cik)
          primary_doc_comp <- filings %>% 
            filter(accessionNumber == accession_comp) %>% 
            pull(primaryDocument) %>% 
            head(1)
          
          html_comp <- get_filing_text(cik, accession_comp, primary_doc_comp, format = "html")
          if (!is.null(html_comp)) {
            save_filing_text(cik, accession_comp, html_comp)
          }
        }
        
        if (!is.null(html_comp)) {
          text_comp <- clean_10k_text(html_comp)
          text_comp <- remove_10k_toc(text_comp)
          scores_comp <- calculate_sentiment(text_comp)
          scores_comp$Type <- "Comparison"
        }
      }
      
      # Combine Results
      if (!is.null(scores_comp)) {
        combined_scores <- bind_rows(scores_curr, scores_comp)
      } else {
        combined_scores <- scores_curr
      }
      
      sentiment_results(combined_scores)
      incProgress(1, detail = "Done")
    })
  })
  
  # Sentiment Table
  output$sentiment_table <- renderDT({
    req(sentiment_results())
    
    df <- sentiment_results()
    
    # If comparison exists, pivot for better view
    if (nrow(df) > 1) {
      # Select percentage columns and Type
      df_pct <- df %>%
        select(Type, Sentiment_Score, ends_with("_Pct")) %>%
        tidyr::pivot_longer(cols = c(Sentiment_Score, ends_with("_Pct")), names_to = "Category", values_to = "Percentage") %>%
        mutate(Category = gsub("_Pct", "", Category)) %>%
        tidyr::pivot_wider(names_from = Type, values_from = Percentage) %>%
        mutate(Change = Current - Comparison)
      
      datatable(df_pct, options = list(dom = 't')) %>%
        formatRound(columns = c("Current", "Comparison", "Change"), digits = 2)
    } else {
      # Single filing view
      df_simple <- df %>%
        select(Total_Words, Sentiment_Score, Negative, Positive, Uncertainty, Litigious, Constraining)
      datatable(df_simple, options = list(dom = 't')) %>%
        formatRound(columns = c("Sentiment_Score"), digits = 2)
    }
  })
  
  # Sentiment Plot
  output$sentiment_plot <- renderPlot({
    req(sentiment_results())
    
    df <- sentiment_results() %>%
      select(Type, Sentiment_Score, ends_with("_Pct")) %>%
      tidyr::pivot_longer(cols = c(Sentiment_Score, ends_with("_Pct")), names_to = "Category", values_to = "Percentage") %>%
      mutate(Category = gsub("_Pct", "", Category))
    
    ggplot(df, aes(x = Category, y = Percentage, fill = Type)) +
      geom_bar(stat = "identity", position = "dodge") +
      labs(title = "Sentiment Scores & Distribution", y = "Score / Percentage", x = "") +
      theme_minimal() +
      scale_fill_brewer(palette = "Set1")
  })
}

# Run the Application
shinyApp(ui, server)
