#devtools::install_github("IDEMSInternational/postgresr")
#devtools::install_github("IDEMSInternational/plhR")


data_l <- import_list("EFM_shiny (1).xlsx")

# Functions
# function to fix up namings to make it a bit prettier!
naming_conventions <- function(x, replace, replace_after) {
  if (!missing(replace)){
    x <- gsub(paste("^.*?", replace, ".*", sep = ""), "", x)
  }
  if (!missing(replace_after)){
    x <- gsub(paste(replace_after, "$", sep = ""), "", x)
  }
  substr(x, 1, 1) <- toupper(substr(x, 1, 1))
  x <- gsub("_", " ", x)
  x
}

# so we can use "add_na_variable" to add into the data variables which are not in the data
# but will be at some point
# this function checks if the variable is in the data.
# If it is not in the data, then it adds it as a new variable with all NAs.
add_na_variable <- function(data = contacts_unflat, variable){
  for (names in variable) {
    if (!names %in% colnames(data)) {
      data[, names] <- NA
      warning(paste(names, "does not exist. Adding NAs"))
    }
  }
  return(data)
}

# Download data ----------------------------------------------------------------
#  download EFM app data from Metabase as an RDS file?

plhdata_org <- postgresr::get_user_data(site = plh_con, filter = FALSE)

# plhdata_org <- get_user_data(filter_variable = "app_deployment_name",
#                              filter_variable_value = "early_family_math",
#                              site = plh_con, merge_check = FALSE, filter = TRUE)
#names(plhdata_org) <- gsub(x = names(plhdata_org), pattern = "\\-", replacement = ".")  
#View(plhdata_org)

mydate <- "2023-12-15"
plhdata_org <- plhdata_org %>% filter(as.Date(createdAt) > as.Date(mydate))


# COUNTING the number of clicks --------------------------------------------------------------------
### Creating counts 
#x <- c("2023-11-24T09:28:59 ; 2023-11-24T09:30:22", NA, "2023-11-27T14:45:52")

# Function to count dates in each element of the vector
count_dates <- function(x) {
  if (is.na(x)) {
    return(0)
  } else {
    dates <- unlist(strsplit(x, ";"))
    return(length(dates))
  }
}

# Apply the function to each element of the vector

# METHOD 1: sapply
# plhdata_org1 <- plhdata_org %>%
#   mutate(count_activities_button_click_history = 
#            sapply(`rp-contact-field.activities_button_click_history`, count_dates))
# plhdata_org1 %>% dplyr::select(count_activities_button_click_history, `rp-contact-field.activities_button_click_history`)

# METHOD 2: purrr
# plhdata_org2 <- plhdata_org %>%
#   mutate(count_activities_button_click_history_purrr = 
#            purrr::map_dbl(.x = `rp-contact-field.activities_button_click_history`,
#                           .f = ~ count_dates(.x)))
# 
# plhdata_org2 %>% dplyr::select(count_activities_button_click_history, count_activities_button_click_history_purrr, rp.contact.field.activities_button_click_history) %>% View()
# 

# METHOD 3: multiple columns
plhdata_org <- plhdata_org %>%
  mutate(across(ends_with("_click_history"), # put in here a set of variables.
                .names = "{.col}_count",     # rename the new variables
                ~ sapply(.x, count_dates)))  # apply count_dates to them.
#plhdata_org_3 %>% View()



######################################### Hello - fixes and comments #######################################

# we got an error in shiny:
# Caused by error in `.data[["rp-contact-field.efm_sb_Cat_And_Dog_And_The_Ball_book_click_history"]]`:
#   ! Column `rp-contact-field.efm_sb_Cat_And_Dog_And_The_Ball_book_click_history` not found in `.data`.

# lets check if these variables exist

vars_to_check <- data_l$storybooks$variable
plhdata_org <- add_na_variable(data = plhdata_org, variable = vars_to_check)

# WARNING: Please please check when you do this - this code creates the variable and fills with NAs if it
# is not in the data set.
# However, it may be that this variable is a typo, and so therefore you need to check the typo and fix it that way.
# Please make sure of this. I've noticed some typos already - e.g. you said
# app_last_launch, not rp-contact-field.app_last_launch. I've fixed this on run_plhr_shiny.R

#### Fix namings for rp-contact-field.current_book
# We just want to remove "data.efm_storybooks.efm_sb_" from our names
plhdata_org$`rp-contact-field.current_book` <- naming_conventions(plhdata_org$`rp-contact-field.current_book`,
                                                                  "data.efm_storybooks.efm_sb_")


#TODO: remove data column in spreadsheet
plhdata_org$`rp-contact-field._server_sync_latest` <- lubridate::as_date(plhdata_org$`rp-contact-field._server_sync_latest`)
plhdata_org$`app_last_launch` <- plhdata_org$`rp-contact-field.app_last_launch`
plhdata_org$`app_launch_count` <- plhdata_org$`rp-contact-field.app_launch_count`

#App last sync
plhdata_org <- plhdata_org %>%
  mutate(synced_7_days = ifelse(`rp-contact-field._server_sync_latest` >= as.Date(lubridate::now(tzone = "UTC")) - 7,
                                1,0))

plhdata_org <- plhdata_org %>%
  mutate(synced_7_14_days = ifelse(`rp-contact-field._server_sync_latest` >= as.Date(lubridate::now(tzone = "UTC")) - 14 &
                                     `rp-contact-field._server_sync_latest` < as.Date(lubridate::now(tzone = "UTC")) - 7,
                                   1,0))

plhdata_org <- plhdata_org %>%
  mutate(synced_14_30_days = ifelse(`rp-contact-field._server_sync_latest` >= as.Date(lubridate::now(tzone = "UTC")) - 30 &
                                     `rp-contact-field._server_sync_latest` < as.Date(lubridate::now(tzone = "UTC")) - 14,
                                   1,0))

plhdata_org <- plhdata_org %>%
  mutate(synced_more_than_30_days = ifelse(`rp-contact-field._server_sync_latest` < as.Date(lubridate::now(tzone = "UTC")) - 30,
                                           1,0))

plhdata_org$app_last_launch <- as.Date(plhdata_org$app_last_launch)

# # App last launch - line graph
# plhdata_org$app_last_launch <- as.Date(plhdata_org$app_last_launch)
# 
# # Creating a data frame of the last lauched dates
# app_last_launch_data <- plhdata_org %>%
#   filter(!is.na(app_last_launch)) %>% 
#   group_by(app_last_launch) %>% 
#   summarise(frequency = n())

# Creating the line graph
# ggplot(app_last_launch_data) + 
#   geom_line(aes(x = app_last_launch, y = frequency)) +
#   geom_point(aes(x = app_last_launch, y = frequency)) + 
#   labs(x = "Date", y = "Frequency", title = "Frequency of Values by Date")
# 








