library(tidyverse)
library(lubridate)
library(extRemes)

setwd("~/Desktop/R_WD")

ranger <- read.csv("rangerstation.csv")
airport <- read.csv("airport.csv")

ranger_only <- ranger %>%
  filter(NAME == "TRUCKEE RANGER STATION, CA US") %>%
  mutate(
    DATE = as.Date(DATE),
    SNOW = as.numeric(SNOW)
  ) %>%
  filter(!is.na(SNOW))

airport_only <- airport %>%
  mutate(
    DATE = as.Date(DATE),
    SNOW = as.numeric(SNOW)
  ) %>%
  filter(!is.na(SNOW))

combined <- bind_rows(ranger_only, airport_only) %>%
  arrange(DATE) %>%
  mutate(
    year = year(DATE),
    month = month(DATE),
    snow_season = ifelse(month >= 10, year + 1, year)
  )

seasonal_snow <- combined %>%
  group_by(snow_season) %>%
  summarise(
    total_snowfall = sum(SNOW),
    days_recorded = n(),
    .groups = "drop"
  ) %>%
  filter(days_recorded > 200)

gev_model <- fevd(seasonal_snow$total_snowfall, type = "GEV")

return_levels <- return.level(
  gev_model,
  return.period = c(10, 25, 50, 100)
)

snow_100yr <- as.numeric(return_levels[4])
max_observed <- max(seasonal_snow$total_snowfall)

prob_300 <- mean(seasonal_snow$total_snowfall > 300)
return_period_300 <- 1 / prob_300

top_winters <- seasonal_snow %>%
  arrange(desc(total_snowfall)) %>%
  head(10)

print(seasonal_snow)
print(return_levels)
summary(gev_model)

cat("Estimated snowfall threshold exceeded in about 1% of seasons:", 
    round(snow_100yr, 1), "inches\n")
cat("Maximum observed seasonal snowfall:", round(max_observed, 1), "inches\n")
cat("Probability of a season exceeding 300 inches:", round(prob_300 * 100, 2), "%\n")
cat("Approximate return period for 300+ inches:", round(return_period_300, 1), "years\n")

print(top_winters)

ggplot(seasonal_snow, aes(x = snow_season, y = total_snowfall)) +
  geom_line() +
  geom_point() +
  scale_x_continuous(breaks = seq(1900, 2025, by = 10)) +
  labs(
    title = "Truckee Snowfall Over Time",
    subtitle = "Winter season snowfall (October-May)",
    x = "Winter Season",
    y = "Total Snowfall (inches)"
  ) +
  theme_minimal()
ggsave("snowfall_over_time.png", width = 8, height = 5)
ggplot(seasonal_snow, aes(x = total_snowfall)) +
  geom_histogram(bins = 15, fill = "steelblue", color = "black") +
  geom_vline(xintercept = snow_100yr, linetype = "dashed", color = "red") +
  labs(
    title = "Distribution of Truckee Seasonal Snowfall",
    subtitle = paste("Dashed line shows snowfall levels above ~",
                     round(snow_100yr, 1),
                     "inches, occurring in about 1% of seasons"),
    x = "Seasonal Snowfall (inches)",
    y = "Number of Seasons"
  ) +
  theme_minimal()
ggsave("snowfall_distribution.png", width = 8, height = 5)
ggplot(top_winters, aes(x = reorder(as.factor(snow_season), total_snowfall), y = total_snowfall)) +
  geom_col(fill = "steelblue") +
  coord_flip() +
  labs(
    title = "Top 10 Snowiest Truckee Winters",
    x = "Season",
    y = "Total Snowfall (inches)"
  ) +
  theme_minimal()
ggsave("top_10_winters.png", width = 8, height = 5)
write.csv(seasonal_snow, "combined_seasonal_snowfall.csv", row.names = FALSE)
write.csv(top_winters, "top_10_snowfall_seasons.csv", row.names = FALSE)
write.csv(as.data.frame(return_levels), "gev_return_levels.csv", row.names = TRUE)