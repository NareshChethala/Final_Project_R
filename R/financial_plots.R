# ==============================================================================
# Financial Analysis Plots
# ==============================================================================
# Functions to visualize financial KPIs using ggplot2.
# ==============================================================================

library(ggplot2)
library(dplyr)

#' Plot KPI Trends
#' @description Creates a faceted line chart of KPI values over time.
#' @param analysis_df Dataframe returned by analyze_financials()
#' @return ggplot object
plot_kpi_trends <- function(analysis_df) {
  if (is.null(analysis_df) || nrow(analysis_df) == 0) return(NULL)
  
  # Filter out rows with NA values for plotting
  df_plot <- analysis_df %>%
    filter(!is.na(Value))
  
  ggplot(df_plot, aes(x = FY, y = Value)) +
    geom_line(color = "#2c3e50", size = 1) +
    geom_point(color = "#2c3e50", size = 2) +
    facet_wrap(~Metric, scales = "free_y", ncol = 3) +
    labs(title = "Financial Trends (Last 5 Years)",
         x = "Fiscal Year",
         y = "Value") +
    theme_minimal() +
    theme(
      strip.text = element_text(face = "bold"),
      axis.text.x = element_text(angle = 45, hjust = 1)
    ) +
    scale_y_continuous(labels = scales::label_number(scale_cut = scales::cut_short_scale()))
}

#' Plot YoY Growth
#' @description Creates a faceted bar chart of Year-over-Year percentage changes.
#' @param analysis_df Dataframe returned by analyze_financials()
#' @return ggplot object
plot_yoy_growth <- function(analysis_df) {
  if (is.null(analysis_df) || nrow(analysis_df) == 0) return(NULL)
  
  # Filter out rows with NA YoY_Change
  df_plot <- analysis_df %>%
    filter(!is.na(YoY_Change)) %>%
    mutate(Growth_Type = ifelse(YoY_Change >= 0, "Positive", "Negative"))
  
  ggplot(df_plot, aes(x = FY, y = YoY_Change, fill = Growth_Type)) +
    geom_bar(stat = "identity", position = "dodge") +
    facet_wrap(~Metric, scales = "free_y", ncol = 3) +
    labs(title = "Year-over-Year Growth (%)",
         x = "Fiscal Year",
         y = "Growth %") +
    scale_fill_manual(values = c("Positive" = "#27ae60", "Negative" = "#c0392b")) +
    theme_minimal() +
    theme(
      legend.position = "none",
      strip.text = element_text(face = "bold"),
      axis.text.x = element_text(angle = 45, hjust = 1)
    )
}
