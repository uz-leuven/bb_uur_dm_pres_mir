# authenticate
bq_auth(path = "~/.config/gcloud/application_default_credentials.json") # maakt connectie (met cumulus account; hier eerste maal credentials voorzien)

# function to pull data from gbq
bq_get_table <- function(project_id, sql, auth = TRUE) {
  if (auth) {
    try(bq_auth(refresh = TRUE), silent = TRUE)
  }
  tb <- bq_project_query(project_id, sql)
  df <- bq_table_download(tb)
  return(df)
}
