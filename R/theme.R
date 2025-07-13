# R/theme.R

library(bslib)
library(yaml)

# Function to create the theme from a config file
create_app_theme <- function(config_path) {

  # Read the theme settings from the YAML file
  theme_settings <- yaml::read_yaml(config_path)

  # Start with the base "lux" theme. This is the foundation.
  base_theme <- bs_theme(bootswatch = "lux")

  # Prepare a list of fonts to apply, if they are specified in the config
  font_args <- list()
  if (!is.null(theme_settings$base_font)) {
    font_args$base <- font_google(theme_settings$base_font)
  }
  if (!is.null(theme_settings$heading_font)) {
    font_args$heading <- font_google(theme_settings$heading_font)
  }
  if (!is.null(theme_settings$code_font)) {
    font_args$code <- font_google(theme_settings$code_font)
  }

  # Add any specified fonts to the theme
  if (length(font_args) > 0) {
    base_theme <- bs_theme_add_variables(base_theme, !!!font_args)
  }

  # Remove font settings from the list so we can pass the rest as overrides
  theme_settings$base_font <- NULL
  theme_settings$heading_font <- NULL
  theme_settings$code_font <- NULL
  
  # Update the base theme with all the custom values from the config file.
  # The `!!!` (bang-bang-bang) operator unpacks the list of settings
  # so they are passed as individual arguments to the function.
  custom_theme <- bs_theme_update(base_theme, !!!theme_settings)
  
  return(custom_theme)
}

# Create the theme object that will be used in the app
chill_atc_theme <- create_app_theme("resources/theme_config.yml")
