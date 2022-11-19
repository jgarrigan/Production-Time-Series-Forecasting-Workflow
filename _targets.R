pacman::p_load(targets, tarchetypes, tidyverse)

source("functions/functions_energy_analysis.R")

tar_option_set(
  packages = c(
    "tidymodels", "modeltime", "tidyverse",
    "timetk", "lubridate", "janitor", "forecast",
    "prophet"
  )
)

list(
  # DATA ----
  # * IDENTIFY FILE LOCATION ----
  tar_target(
    name = energy_file,
    command = "data/Net_generation_for_all_sectors.csv",
    format = "file"
  )
  ,
  # READ DATA ----
  tar_target(
    name = energy_data,
    command = read_csv(energy_file)
  )
  ,
  # DATA CLEANING & PREP ----
  tar_target(
    name = clean_energy_data,
    command = clean_data(energy_data)
  )
  ,
  # EXTENDING DATA ----
  tar_target(
    name = extend_energy_data,
    command = extend_data(clean_energy_data, horizon = 24)
  )
  ,
  tar_target(
    name = prepared_energy_data,
    command = extend_energy_data %>% drop_na()
  )
  ,
  tar_target(
    name = future_energy_data,
    command = extend_energy_data %>% filter(is.na(value))
  )
  ,
  # GROUPING ----
  # * GROUPED DATA PREPARED ----
  tar_group_by(
    name = grouped_prepared_energy_data,
    command = prepared_energy_data,
    source_key, location, fuel, units
  )
  ,
  # * GROUPED FUTURE DATA ----
  tar_group_by(
    name = grouped_future_energy_data,
    command = future_energy_data,
    source_key, location, fuel, units
  )
  ,

  tar_target(
    name = prepared_data_branched,
    command = grouped_prepared_energy_data,
    pattern = map(grouped_prepared_energy_data)
  )
  ,
  # * FUTURE DATA BRANCHED ----
  tar_target(
    name = future_data_branched,
    command = grouped_future_energy_data,
    pattern = map(grouped_future_energy_data)
  )
  ,
  # SPLITS ----
  # * SPLIT DATA PREPARED ----
  tar_target(
    name = splits_grouped_energy_data,
    command = split_grouped_ts_data(
      data = prepared_data_branched,
      horizon = 24
    ),
    pattern = map(prepared_data_branched)
  )
  ,
  # MODELS ----
  # * MODEL 1: ARIMA ----
  tar_target(
    name = wflw_fit_arima,
    pattern = map(splits_grouped_energy_data),
    command = arima_workflow(splits_grouped_energy_data)
  )
  ,
  # * MODEL 2: PROPHET ----
  tar_target(
    name = wflw_fit_prophet,
    pattern = map(splits_grouped_energy_data),
    command = prophet_workflow(splits_grouped_energy_data)
  )
  ,
  # TEST SET ACCURACY ----
  # * MODEL 1: ARIMA ACCURACY ----
  tar_target(
    name = test_accuracy_arima,
    pattern = map(wflw_fit_arima),
    command = test_accuracy(wflw_fit_arima)
  )
  ,
  # * MODEL 2: PROPHET ACCURACY ----
  tar_target(
    name = test_accuracy_prophet,
    pattern = map(wflw_fit_prophet),
    command = test_accuracy(wflw_fit_prophet)
  )
  ,
  # COMPARE MODELS ----
  # * BEST TEST ACCURACY ----
  tar_target(
    name = best_test_accuracy,
    pattern = map(
      test_accuracy_arima,
      test_accuracy_prophet
    ),
    command = compare_best_test_accuracy(
      test_accuracy_arima,
      test_accuracy_prophet
    )
  )
  ,
  tar_target(
    name = best_models,
    pattern = map(
      best_test_accuracy,
      wflw_fit_arima,
      wflw_fit_prophet
    ),
    command = select_model(
      accuracy_tbl = best_test_accuracy,
      wflw_fit_arima,
      wflw_fit_prophet
    )
  )
  ,
  # REFIT ----
  # * REFIT MODELS ----
  tar_target(
    name = refitted_models,
    pattern = map(
      best_models,
      prepared_data_branched
    ),
    command = refit_model(
      best_models,
      prepared_data_branched
    )
  )
  ,
  # * FORECAST FUTURE DATA ----
  tar_target(
    name = final_forecast,
    pattern = map(
      refitted_models,
      future_data_branched,
      prepared_data_branched
    ),
    command = forecast_future(
      refitted_models,
      future_data_branched,
      prepared_data_branched
    )
  )
  ,
  tar_target(
    name = accuracy_check,
    pattern = map(
      best_test_accuracy
    ),
    command = check_accuracy(
      best_test_accuracy
    )
  )
  ,
  # RENDER REPORT ----
  # * PUBLISH REPORT ----
  tar_render(
    name = report,
    path = "reports/forecast_report.Rmd",
    params = list(
      test_accuracy = best_test_accuracy,
      forecast_data = final_forecast,
      accuracy_check = accuracy_check
    )
  )
)
