# install.packages("here")
# install.packages("readr")
# install.packages("openxlsx")


if (rstudioapi::isAvailable()) {
  setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
}

library(mirr)
library(here)
library(bigrquery)
library(readr)
library(dplyr)
mir_useComponents(c("db", "file"))

sql <- mir_readSqlInDir()

# A. Basis data laden =========================================================================

source("./function/authenticate.R")

# read the first sql file
sql_file <- sort(list.files(
  here("sql"),
  pattern = "\\.sql$",
  full.names = TRUE
))[1]

# pull the data from mirdb as prepared earlier
tbDataBb <- mir_dbReadTable(dbTable = "predictie_bb_training", db = "mirdb")
l$pmaanw_bb <- tbDataBb

# pull the new data
data <- bq_get_table(
  project_id = "prj-uzl-gold-uzl-prd-806f",
  sql = read_file(sql_file),
  auth = FALSE
)
attr(data$datumUurEnum, "tzone")
attr(tbDataBb$datumUurEnum, "tzone")


# B. Basic checks =============

old <- tbDataBb |>
  filter(eenheid == 650, jaar == 2024) |>
  select(AC_CODE, eenheid, datumUurEnum, bb_dwh = bb)

new <- data |>
  transmute(AC_CODE, eenheid = as.integer(eenheid), datumUurEnum, bb_gbq = bb)


list(old = old, new = new) |>
  purrr::imap(~ .x |>
    count(AC_CODE) |>
    mutate(
      dataset = .y,
      total_rows = nrow(.x),
      min_date = min(.x$datumUurEnum, na.rm = TRUE),
      max_date = max(.x$datumUurEnum, na.rm = TRUE)
    ))


sum(duplicated(old[c("AC_CODE", "datumUurEnum")]))

sum(duplicated(new[c("AC_CODE", "datumUurEnum")]))


cmp <- full_join(old, new, by = c("AC_CODE", "eenheid", "datumUurEnum")) |>
  mutate(diff = bb_gbq - bb_dwh)

# unmatched keys, NA values
c(only_dwh = sum(is.na(cmp$bb_gbq)), only_gbq = sum(is.na(cmp$bb_dwh)))

# exact vs tolerance match
c(
  n = nrow(cmp),
  exact = sum(cmp$diff == 0, na.rm = TRUE),
  within_1e6 = sum(abs(cmp$diff) < 1e-6, na.rm = TRUE),
  differing = sum(abs(cmp$diff) >= 1e-6, na.rm = TRUE)
)

summary(cmp$diff)

cmp |>
  filter(abs(diff) >= 1e-6) |>
  arrange(desc(abs(diff)))

cmp |>
  mutate(cat = case_when(
    diff == 0 ~ "exact",
    abs(diff) < 1e-4 ~ "rounding (<1e-4)",
    diff < 0 ~ "gbq lower",
    TRUE ~ "gbq higher"
  )) |>
  count(cat)


big <- cmp |> filter(abs(diff) >= 1e-4)

summary(abs(big$diff * 60 - round(big$diff * 60)))


table(round(big$diff * 60))

summary(abs(big$bb_dwh * 60 - round(big$bb_dwh * 60)))

summary(abs(big$bb_gbq * 60 - round(big$bb_gbq * 60)))

big |> count(month = lubridate::month(datumUurEnum))
