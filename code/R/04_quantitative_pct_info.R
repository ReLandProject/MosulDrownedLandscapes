library(dplyr)
library(magrittr)
library(here)
library(sf)

source("./code/R/functions/get_emerged_area.R")

# Get quantitative info about emerged area --------------------------------

# Function to use with `across` in place of `filter_at + any_vars``
# Find all rows where ANY numeric variable is greater than zero
# taken from vignette("colwise")
rowAny <- function(x) rowSums(x, na.rm = TRUE) > 0

mdas_polys_pct_min <- st_read(here::here("output/shp", "MDAS_polys_area_pct_min.shp"),
                              stringsAsFactors = FALSE
)

mdas_polys_pct_max <- st_read(here::here("output/shp", "MDAS_polys_area_pct_max.shp"),
                              stringsAsFactors = FALSE
)

# Load also the points to export a point layer later
mdas_sites <- st_read(here::here("data/raw/shp", "MDAS_points.shp"),
                      stringsAsFactors = FALSE
)

# Select which field you want to keep in the new spatial object

fields_to_select <- c("name", "area", "site_typ", "topo_set", "certainty", "area_cert")

# Define a field where the numeric area is stored
# it will be rounded inside the function
area_field <- c("area")

# Calculate the starting column for the calculations
# The first percentage field will start after (+1) the fields we selected before
starting_col <- length(fields_to_select) + 1

# Min water level -----------------------------------------------------------------------

# Apply the function after converting to simple feature, then convert it back to spatial object
mdas_polys_pct_info_min <- mdas_polys_pct_min %>%
  get_emersion_data(column_index = starting_col) %>%
  mutate(across(c(where(is.numeric), -all_of(area_field)), as.integer))

mdas_polys_pct_info_min <- mdas_polys_pct_info_min[order(mdas_polys_pct_info_min$name),]


mdas_polys_pct_info_min <- mdas_polys_pct_info_min %>%
  set_colnames(sub("X", "", colnames(.), fixed = TRUE))


# Max water level -----------------------------------------------------------------------

mdas_polys_pct_info_max <- mdas_polys_pct_max %>%
  get_emersion_data(column_index = starting_col) %>%
  mutate(across(c(where(is.numeric), -all_of(area_field)), as.integer))

mdas_polys_pct_info_max <- mdas_polys_pct_info_max[order(mdas_polys_pct_info_max$name),]

mdas_polys_pct_info_max <- mdas_polys_pct_info_max %>%
  set_colnames(sub("X", "", colnames(.), fixed = TRUE))


# Get info on never aff and always sub sites
# Isolate sites which are not touched by the lake in periods of min water
# and those that are not outside the water in periods of max water

names_sites <- mdas_polys_pct_info_max[which(mdas_polys_pct_info_max$AlwaysEm == 1),] %>% 
  bind_rows(mdas_polys_pct_info_min[which(mdas_polys_pct_info_min$AlwaysSub == 1),]) %>% 
  select(starts_with("name"))

mdas_polys_pct_info_min  <- mdas_polys_pct_info_min %>% 
  mutate(NeverSub = ifelse(AlwaysEm == 1 & mdas_polys_pct_info_min$name %in% names_sites$name, 1, 0)) %>% 
  mutate(NeverEm = ifelse(AlwaysSub == 1 & mdas_polys_pct_info_min$name %in% names_sites$name, 1, 0))

mdas_polys_pct_info_max  <- mdas_polys_pct_info_max %>% 
  mutate(NeverSub = ifelse(AlwaysEm == 1 & mdas_polys_pct_info_max$name %in% names_sites$name, 1, 0)) %>% 
  mutate(NeverEm = ifelse(AlwaysSub == 1 & mdas_polys_pct_info_max$name %in% names_sites$name, 1, 0))

# Update the AlwaysSub and AlwaysEm fields using the NeverSub and NeverEm just created
# This ensure there are no duplicated counts in the fields and makes them truly relative to the water level period
# I.e. count as Always sub only those sites that are not part of the NeverSub/Em categories

mdas_polys_pct_info_max  <- mdas_polys_pct_info_max %>% mutate(AlwaysSub = ifelse(NeverEm == 1 & AlwaysSub == 1, 0, AlwaysSub)) %>% 
mutate(AlwaysEm = ifelse(NeverSub == 1 & AlwaysEm == 1, 0, AlwaysEm))

mdas_polys_pct_info_min <- mdas_polys_pct_info_min %>% mutate(AlwaysSub = ifelse(NeverEm == 1 & AlwaysSub == 1, 0, AlwaysSub)) %>% 
mutate(AlwaysEm = ifelse(NeverSub == 1 & AlwaysEm == 1, 0, AlwaysEm))



# Get some insights into the data just created
# Note: Fields AlwaysEm and AlwaysSub are relative to the water level period
# Fields NeverSub and NeverEm are independent of the water level
# This means that NeverSub and NeverEm should be the same in both layers
# For the same reason, AlwaysEm and NeverSub will be the same in max water level
# And AlwaysSub and NeverEm will be the same in min water level

# First let's check if NeverSub and NeverEm are  the same in min and max water level
length(which(mdas_polys_pct_info_min$NeverSub == 1)) == length(which(mdas_polys_pct_info_max$NeverSub == 1))
length(which(mdas_polys_pct_info_min$NeverEm == 1)) == length(which(mdas_polys_pct_info_max$NeverEm == 1))

# Print a table in the console
knitr::kable(data.frame(
  "Always Submerged at h.w.l." = length(which(mdas_polys_pct_info_max$AlwaysSub == 1)),
  "Always Emerged at h.w.l." = length(which(mdas_polys_pct_info_max$AlwaysEm == 1)),
  "Always Submerged at l.w.l." = length(which(mdas_polys_pct_info_min$AlwaysSub == 1)),
  "Always Emerged at l.w.l." = length(which(mdas_polys_pct_info_min$AlwaysEm == 1)),
  "Never Emerged" = length(which(mdas_polys_pct_info_min$NeverEm == 1)),
  "Never Submerged" = length(which(mdas_polys_pct_info_min$NeverSub == 1)),
  "Affected in h.w.l." = length(which(mdas_polys_pct_info_max$Affected == 1)),
  "Affected in l.w.l." = length(which(mdas_polys_pct_info_min$Affected == 1))
))


# Export data

st_write(
  obj = mdas_polys_pct_info_min,
  dsn = here::here("output/shp", "MDAS_polys_area_pct_info_min.shp"),
  layer = "MDAS_polys_area_pct_info_min",
  driver = "ESRI Shapefile", 
  append = FALSE
)

write.csv(mdas_polys_pct_info_min@data, here::here("output/csv", "MDAS_polys_area_pct_info_min.csv"))

st_write(
  obj = mdas_polys_pct_info_max,
  dsn = here::here("output/shp", "MDAS_polys_area_pct_info_max.shp"),
  layer = "MDAS_polys_area_pct_info_max",
  driver = "ESRI Shapefile", 
  append = FALSE
)

write.csv(mdas_polys_pct_info_max@data, here::here("output/csv", "MDAS_polys_area_pct_info_max.csv"))
