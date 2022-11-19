
# LOAD LIBARIES -----------------------------------------------------------

pacman::p_load(targets,tidymodels,modeltime,tidyverse,janitor)

# REFERENCE DATA ----------------------------------------------------------

#https://www.eia.gov/electricity/data/browser/#/topic/0?agg=2,0,1&fuel=vtvv&geo=g&sec=g&linechart=ELEC.GEN.ALL-US-99.M~ELEC.GEN.COW-US-99.M~ELEC.GEN.NG-US-99.M~ELEC.GEN.NUC-US-99.M~ELEC.GEN.HYC-US-99.M~ELEC.GEN.WND-US-99.M~ELEC.GEN.TSN-US-99.M&columnchart=ELEC.GEN.ALL-US-99.M~ELEC.GEN.COW-US-99.M~ELEC.GEN.NG-US-99.M~ELEC.GEN.NUC-US-99.M~ELEC.GEN.HYC-US-99.M~ELEC.GEN.WND-US-99.M&map=ELEC.GEN.ALL-US-99.M&freq=M&start=200101&end=202208&ctype=columnchart&ltype=pin&rtype=s&maptype=0&rse=0&pin=


tar_make()
tar_visnetwork(targets_only = TRUE, label = "branches")

tar_manifest()


# PROCESSING --------------------------------------------------------------

tar_read("energy_data")
tar_read("extend_energy_data")
tar_read("prepared_energy_data")
tar_read("future_energy_data")


# GROUPING ----------------------------------------------------------------

tar_read("group_prepared_energy_data") %>% filter(str_detect(fuel, "utility-scale"))
tar_read("grouped_future_energy_data") %>% filter(str_detect(fuel, "utility-scale"))


# MAPPING SPLITS ----------------------------------------------------------

tar_read("splits_grouped_energy_data")
tar_read("splits_grouped_energy_data", branches = 1)
tar_read("splits_grouped_energy_data", branches = 1) %>% 
  pull(splits) %>% 
  pluck(1) %>%
  training()


# MAPPING ARIMA -----------------------------------------------------------

tar_read("wflw_fit_arima")
tar_read("wflw_fit_arima", branches = 1)
tar_read("wflw_fit_arima", branches = 1) %>% 
  pull(wflw_fit) %>% 
  pluck(1)


# MAPPING PROPHET ---------------------------------------------------------

tar_read("wflw_fit_prophet")
tar_read("wflw_fit_prophet", branches = 1)
tar_read("wflw_fit_prophet", branches = 1) %>% 
  pull(wflw_fit) %>% 
  pluck(1)


# MAPPING ACCURACY --------------------------------------------------------

tar_read("test_accuracy_arima")
tar_read("test_accuracy_prophet")


# COMBINE ACCURACY --------------------------------------------------------

tar_read("best_test_accuracy")
tar_read("best_test_accuracy", branches = 1)

# GET BEST MODELS ---------------------------------------------------------

tar_read("best_models", branches = 1)

# REFIT MODELS ------------------------------------------------------------

tar_read("refitted_models")
tar_read("refitted_models", branches = 2)

# PRODUCE FINAL FORECAST --------------------------------------------------

tar_read("final_forecast") %>% 
  group_by(tar_group, fuel) %>% 
  plot_modeltime_forecast(
    .conf_interval_show = FALSE,
    .facet_ncol = 3
  )

tar_read("final_forecast", branches = 1) %>% 
  group_by(tar_group, fuel) %>% 
  plot_modeltime_forecast(
    .conf_interval_show = FALSE,
    .facet_ncol = 3
  )


# FORECAST AUDIT ----------------------------------------------------------

tar_read("accuracy_check")


# AUTOMATED REPORT --------------------------------------------------------

tar_read("report")
