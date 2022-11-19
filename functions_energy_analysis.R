clean_data <- function(data) {
  
  data_description_tbl <- data %>% 
    janitor::clean_names() %>% 
    select(description:source_key) %>% 
    slice(-(1:2)) %>% 
    separate(description, into = c("location","fuel"), sep = " : ")
  
  data_pivoted_tbl <- data %>% 
    select(-description, -units) %>% 
    mutate(across(.cols = -(`source key`), as.numeric)) %>% 
    pivot_longer(cols = -`source key`, names_to = "date") %>% 
    drop_na() %>% 
    mutate(date = lubridate::my(date)) %>% 
    clean_names() %>% 
    distinct()
  
  data_joined_tbl <- data_pivoted_tbl %>% 
    left_join(data_description_tbl, by = "source_key")
  
  return(data_joined_tbl)
}

extend_data <- function(data, horizon = 24) {
  data %>% 
    distinct() %>% 
    group_by(source_key, location, fuel, units) %>% 
    future_frame(date, .length_out = horizon, .bind_data = TRUE) %>% 
    ungroup() %>% 
    distinct()
}


# TRAIN TEST SPLITTING ----------------------------------------------------


split_grouped_ts_data <- function(data, horizon = 24) {
  
  data <- ungroup(data)
  
  splits <- timetk::time_series_split(
    data,
    date_var = date,
    cumulative = TRUE,
    assess = horizon
  )
  
  tibble(
    tar_group = data$tar_group %>% unique(),
    splits = list(splits)
  )
}


# MODELLING WORKFLOWS -----------------------------------------------------


arima_workflow <- function(splits_tbl) {
  
  tar_group <- splits_tbl %>% pull(tar_group) %>% unique()
  
  train_tbl <- splits_tbl %>% 
    pull(splits) %>% 
    pluck(1) %>% 
    training()
  
  wflw_fit <- workflow() %>% 
    add_model(
      spec = arima_reg() %>% 
        set_engine("auto_arima")
    ) %>% 
    add_recipe(
      recipe = recipe(value ~ date, train_tbl)
    ) %>% 
    fit(train_tbl)
  
  ret <- tibble(
    tar_group = tar_group,
    wflw_fit = list(wflw_fit)
  )
  
  ret <- splits_tbl %>% 
    mutate(wflw_fit = list(wflw_fit))
  
  return(ret)
}

prophet_workflow <- function(splits_tbl) {
  tar_group <- splits_tbl %>% pull(tar_group) %>% unique()
  
  train_tbl <- splits_tbl %>% 
    pull(splits) %>% 
    pluck(1) %>% 
    training()
  
  wflw_fit <- workflow() %>% 
    add_model(
      spec = prophet_reg() %>% 
        set_engine("prophet")
    ) %>% 
    add_recipe(
      recipe = recipe(value ~ date, train_tbl)
    ) %>% 
    fit(train_tbl)
  
  ret <- splits_tbl %>% 
    mutate(wflw_fit = list(wflw_fit))
  
  return(ret)
}


# MODEL COMPARISON --------------------------------------------------------

test_accuracy <- function(model_tbl) {
  
  tar_group <- model_tbl %>% pull(tar_group) %>% unique()
  
  test_tbl <- model_tbl %>% 
    pull(splits) %>% 
    pluck(1) %>% 
    testing()
  
  wflw_fit <- model_tbl %>% 
    pull(wflw_fit) %>% 
    pluck(1)
  
  modeltime_table(
    wflw_fit
  ) %>% 
    modeltime_accuracy(test_tbl) %>% 
    add_column(tar_group = tar_group, .before = 1)
}

compare_best_test_accuracy <- function(...) {
  
  bind_rows(...) %>% 
    group_by(tar_group) %>% 
    slice_min(rmse, n = 1) %>% 
    ungroup()
}

select_model <- function(accuracy_tbl, ...) {
  bind_rows(...) %>% 
    mutate(.model_desc = map_chr(wflw_fit, modeltime::get_model_description)) %>% 
    filter(.model_desc %in% accuracy_tbl$.model_desc)
}


# REFITTING & FINAL FORECAST ----------------------------------------------

refit_model <- function(model_tbl, data_prepared) {
  
  tar_group <- model_tbl %>% pull(tar_group) %>% unique()
  
  modeltime_table(
    model_tbl$wflw_fit[[1]]
    ) %>% 
    modeltime_refit(data_prepared) %>% 
    mutate(tar_group = tar_group)
}

forecast_future <- function(refit_tbl, future_data, data_prepared = NULL) {
  
  refit_tbl %>% 
    select(-tar_group) %>% 
    modeltime_forecast(
      new_data = future_data,
      actual_data = data_prepared,
      keep_data = TRUE
    )
}


# DETECT ERRORS -----------------------------------------------------------

check_accuracy <- function(accuracy_tbl) {
  
  ret_acc_check <- accuracy_tbl %>% 
    filter(rsq < 0.15) %>% 
    select(tar_group) %>% 
    mutate(
      error_desc = "R-squared Less Than 0.15 - Prediction has low variance."
    )
  
  return(ret_acc_check)
}