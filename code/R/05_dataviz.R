library(dplyr)
library(tidyr)
library(ggplot2)
library(stringr)
library(magrittr)
library(patchwork)
library(rgdal)
library(sf)
library(sp)

# Load data -----------------------------------------------------------------------

dahiti_water_level <- read.csv(here::here("data/processed/csv", "dahiti_water_level_r.csv"))

mdas_polys_pct_info_min <- read.csv(here::here("output/csv", "mdas_polys_area_pct_info_min.csv")) %>% 
set_colnames(sub("X", "", colnames(.), fixed = TRUE)) %>%
select(., -1)

mdas_polys_pct_info_max <- read.csv(here::here("output/csv", "mdas_polys_area_pct_info_max.csv")) %>% 
set_colnames(sub("X", "", colnames(.), fixed = TRUE)) %>%
select(., -1)


# Quantitative data (overall) -----------------------------------------------------------------------

poly_quant_data <- data.frame(
  "PolygonStatus" = factor(c("Always Submerged at h.w.l.", "Affected", "Always Exposed at l.w.l.", "Never Exposed", "Never Submerged"),
                           levels = c("Always Submerged at h.w.l.", "Affected", "Always Exposed at l.w.l.",  "Never Exposed", "Never Submerged"),
                           ordered = TRUE
  ),
  "MinWaterLevel" = colSums(mdas_polys_pct_info_min[, c("AlwaysSub", "Affected", "AlwaysEm","NeverEm", "NeverSub")]),
  "MaxWaterLevel" = colSums(mdas_polys_pct_info_max[, c("AlwaysSub", "Affected", "AlwaysEm","NeverEm", "NeverSub")]),
  row.names = NULL
)


poly_quant_data_l <- poly_quant_data %>% 
pivot_longer(cols = -PolygonStatus, names_to = "LakeStatus", values_to = "NumSites")

polygon_status_barplot <- ggplot(filter(poly_quant_data_l, NumSites > 0), mapping = aes(x = LakeStatus, y = NumSites, fill = PolygonStatus)) +
  geom_bar(stat = "identity", position = "dodge", colour = "black", width = .8) +
  geom_text(aes(label = NumSites),
            vjust = -0.25, color = "black",
            position = position_dodge(0.8), size = 3.5
  ) +
  scale_fill_manual(values = c("red", "yellow", "green", "black", "grey95")) +
  labs(
    title = "Status of Archaeological Sites in the Mosul Reservoir - 1993-2020",
    caption = "Data from two images per year, one for each water level period",
    y = "Number of Sites", fill = "Sites Status"
  ) +
  theme_light() +
  theme(
    plot.title = element_text(hjust = 0.5),
    axis.title.x = element_blank(),
    axis.text = element_text(size = 12),
    legend.text = element_text(size = 14),
    legend.position = "bottom",
    # legend.position = c(0.45, 0.93),
    # legend.direction = "horizontal",
    legend.title = element_blank()
)

polygon_status_barplot

ggsave(
  filename = "status_polygons_barplot.png", plot = polygon_status_barplot, device = "png",
  path = here::here("output/plots"),
  width = 30,
  height = 18,
  units = "cm", dpi = 300
)

# Quantitative data (per year) -----------------------------------------------------------------------

# IMPORTANT: REMOVE SITES NEVER EMERGED AND NEVER SUBMERGED for the next plots

sites_to_remove <- mdas_polys_pct_info_min[which(mdas_polys_pct_info_min$NeverSub == 1 | mdas_polys_pct_info_min$NeverEm == 1),] %>% 
  select(starts_with("name"))

mdas_polys_pct_info_max_filtered <- mdas_polys_pct_info_max[!(mdas_polys_pct_info_max$name %in% sites_to_remove$name),]
mdas_polys_pct_info_min_filtered <- mdas_polys_pct_info_min[!(mdas_polys_pct_info_min$name %in% sites_to_remove$name),]


dahiti_df <- data.frame(
    "Years" = c(dahiti_water_level$date_min, dahiti_water_level$date_max),
    "Period" = c(rep("MinWaterLevel", length(dahiti_water_level$date_min)), 
        rep("MaxWaterLevel", length(dahiti_water_level$date_max))),
    "WaterLevel" = c(dahiti_water_level$water_level_min, dahiti_water_level$water_level_max)
)

get_timeseries_pct_numsites_all <- function(y, Period, WaterLevel) {
  a <- y %>%
    summarise(across(ends_with("_em"), list(sum = ~ sum(.x > 0, na.rm = T)))) %>%
    pivot_longer(everything(), names_to = "Years", values_to = "NumPolys") %>%
    mutate(Years = str_remove(Years, "_em_sum")) %>%
    mutate(Years = str_replace(Years, "_", "-")) %>% 
    mutate(Period = Period) %>% 
    cbind(., WaterLevel = WaterLevel) -> a

  print(a)
}

polys_pct_area_numsites_all <- get_timeseries_pct_numsites_all(
  y = mdas_polys_pct_info_min_filtered,
  Period = "MinWaterLevel",
  WaterLevel = dahiti_water_level$water_level_min
) %>%
  bind_rows(get_timeseries_pct_numsites_all(
    y = mdas_polys_pct_info_max_filtered,
    Period = "MaxWaterLevel",
    WaterLevel = dahiti_water_level$water_level_max
  )) %>%
  mutate(Period = factor(Period)) %>%
  mutate(Years = factor(Years, ordered = TRUE))


polys_pct_area_numsites_all <- polys_pct_area_numsites_all %>%
  add_row(Years = "2003-01", NumPolys = NA, Period = "MinWaterLevel", .before = 11) %>%
  add_row(Years = "2003-06", NumPolys = NA, Period = "MinWaterLevel", .before = 37) %>%
  add_row(Years = "2012-01", NumPolys = NA, Period = "MaxWaterLevel", .before = 20) %>%
  add_row(Years = "2012-06", NumPolys = NA, Period = "MaxWaterLevel", .before = 47) %>% 
  add_row(Years = "2013-01", NumPolys = NA, Period = "MinWaterLevel", .before = 21) %>%
  add_row(Years = "2013-06", NumPolys = NA, Period = "MaxWaterLevel", .before = 49)

polys_pct_time_series_plot_min_all <- ggplot(data = polys_pct_area_numsites_all,
                                             aes(Years, NumPolys, fill = Period)) +
  geom_bar(width = 0.5, stat = "identity", alpha = .8, colour = "#737373") +
  # facet_rep_grid(~ Period, scales = "free") +
  scale_y_continuous(expand = c(0.01, 1)) +
  labs(y = "Number of Emerged Polygons") +
  theme_light() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, size = 8.3), axis.title.x = element_blank(),
    strip.text.x = element_text(size = 10, colour = "black"),
    text = element_text(size = 10),
    legend.position = "bottom",
    legend.text = element_text(size = 11),
    legend.title = element_text(size = 11)
  )

polys_pct_time_series_plot_min_all

# split dataframe for water level plot
split_df <- split(polys_pct_area_numsites_all, polys_pct_area_numsites_all$Period)

# First add missing years in dahiti df
dahiti_df <- dahiti_df %>%
  add_row(Years = "2003-01", Period = "MinWaterLevel", .before = 11) %>%
  add_row(Years = "2003-06", Period = "MaxWaterLevel", .before = 37) %>%
  add_row(Years = "2012-01", Period = "MinWaterLevel", .before = 20) %>%
  add_row(Years = "2012-06", Period = "MaxWaterLevel", .before = 47) %>% 
  add_row(Years = "2013-01", Period = "MinWaterLevel", .before = 21) %>%
  add_row(Years = "2013-06", Period = "MaxWaterLevel", .before = 49)

split_dahiti_df <- split(dahiti_df, dahiti_df$Period)

water_level_plot <- ggplot() +
  geom_line(data =  split_df$MaxWaterLevel, aes(Years, WaterLevel, colour = "#F8776D", group = 1)) +
  geom_line(data =  split_df$MinWaterLevel, aes(Years, WaterLevel, colour = "#00C0B8", group = 1)) +
  scale_y_continuous(expand = c(0.01, 1)) +
  scale_x_discrete(breaks = sort(polys_pct_area_numsites_all$Years) [seq(1,56,1)], guide = guide_axis(check.overlap = TRUE))+
  scale_colour_identity(name = 'Period', guide = 'legend', labels = c("MinWaterLevel","MaxWaterLevel"))+
  labs(y = "Reservoir Water Level (m - s.l.m. Approx.)") +
  theme_light() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, size = 8.3), axis.title.x = element_blank(),
    strip.text.x = element_text(size = 10, colour = "black"),
    text = element_text(size = 10),
    legend.position = "NONE",
  )
water_level_plot

# No need for an intermediate patch, it will break the "collect" option in plot_layout()
patch <- water_level_plot / polys_pct_time_series_plot_min_all +
  plot_annotation(
    tag_levels = "A",
    title = "Tishreen Dam Water Surface and Number of Emerged Sites Polygons (1993-2020)",
    caption = "Water Level Data: Database for Hydrological Time Series of Inland Waters (DAHITI)"
  ) &
  theme(
    plot.title = element_text(size = 14),
    plot.caption = element_text(size = 8),
    plot.tag = element_text(size = 11)
)

patch

ggsave(
  "number_of_polygons_per_year_water_level_comb.png", plot = patch, device = "png",
  path = here::here("output/plots"), width = 240, height = 160, units = "mm", dpi = 300
)

# Selected sites plot -----------------------------------------------------------------------

sites_to_plot <- data.frame("name" = c("Cam Pashayi",
                                       "Terbaspi", "Gir Matbakh", "Kemune",
                                       "T. Sheikh Homsi", "EHS_B221", "Jubaniyeh"))

# Min Water Level -----------------------------------------------------------------------

sites_pct_area_min_filtered <- mdas_polys_pct_info_min %>% 
select(name, area, ends_with("_em")) %>% # Select only the columns with emerged percentage
    filter(mdas_polys_pct_info_min_filtered$name %in% sites_to_plot$name) %>% 
    set_colnames(gsub(colnames(.), pattern = "*_em", replacement = "")) %>%
    set_colnames(gsub(colnames(.), pattern = "*_", replacement = "-")) # replace separators for dates

# Add dummy values for missing years to show them in the plots
sites_pct_area_min_filtered <- sites_pct_area_min_filtered %>%
  mutate("2003-01" = NA, .before = "2004-03") %>% 
  mutate("2013-01" = NA, .before = "2014-09") %>% 
  mutate("2012-01" = NA, .before = "2013-01")


sites_pct_area_min_long <- sites_pct_area_min_filtered %>% 
  pivot_longer(-starts_with(c("name","area")), names_to = "Years", values_to = "PctEmergedArea") %>%
  mutate(name = factor(.$name, levels = unique(.$name), ordered = TRUE)) %>% 
  mutate(label = paste(.$name, " - Area: ", .$area, " ha", sep = ""))


# Max Water Level -----------------------------------------------------------------------


sites_pct_area_max_filtered <- mdas_polys_pct_info_max %>% 
select(name, area, ends_with("_em")) %>% # Select only the columns with emerged percentage
    filter(mdas_polys_pct_info_max$name %in% sites_to_plot$name) %>% 
    set_colnames(gsub(colnames(.), pattern = "*_em", replacement = "")) %>%
    set_colnames(gsub(colnames(.), pattern = "*_", replacement = "-")) # replace separators for dates

# Add dummy values for missing years to show them in the plots
sites_pct_area_max_filtered <- sites_pct_area_max_filtered %>%
  mutate("2003-06" = NA, .before = "2004-06") %>% 
  mutate("2013-06" = NA, .before = "2014-06") %>% 
  mutate("2012-06" = NA, .before = "2013-06")


sites_pct_area_max_long <- sites_pct_area_max_filtered %>% 
  pivot_longer(-starts_with(c("name","area")), names_to = "Years", values_to = "PctEmergedArea") %>%
  mutate(name = factor(.$name, levels = unique(.$name), ordered = TRUE)) %>% 
  mutate(label = paste(.$name, " - Area: ", .$area, " ha", sep = ""))


# Plot data together
sites_pct_area_min_max_long <- sites_pct_area_min_long %>% 
  mutate(Period = "MinWaterLevel") %>% 
  bind_rows(mutate(sites_pct_area_max_long, Period = "MaxWaterLevel")) %>% 
  mutate(Period = as.factor(Period))

# Remove Jubaniyeh (save the original for later)
sites_pct_area_min_max_long_a <- sites_pct_area_min_max_long[!grepl("Jubaniyeh", sites_pct_area_min_max_long$name),]

custom_levels <- c("Terbaspi - Area: 6.06 ha",
                   "EHS_B221 - Area: 11.11 ha",
                   "Cam Pashayi - Area: 5.23 ha" ,
                   "T. Sheikh Homsi - Area: 5.69 ha",
                   "Gir Matbakh - Area: 6.02 ha",
                   "Kemune - Area: 6.72 ha")

 sites_pct_area_min_max_long_a <- sites_pct_area_min_max_long_a %>% 
 mutate(label = factor(label, levels = custom_levels, ordered = TRUE))


pct_area_min_max_plot <- ggplot(sites_pct_area_min_max_long_a, aes(x = Years, y = PctEmergedArea, fill = Period)) +
  geom_bar(width = 0.8, stat = "identity", position = "dodge", alpha = .8) +
  geom_hline(yintercept = c(25, 50, 75), linetype = "dashed", linewidth = 0.5, color = "#4040401e") +
  scale_colour_identity(name = 'Period', guide = 'legend', labels = c("MinWaterLevel","MaxWaterLevel"))+
  # scale_fill_manual(values = c("grey26", "grey65"))+
  facet_wrap(~ label, scales = "fixed", ncol = 2) +
  theme_light() +
  labs(
    y = "Percentage of Site Area Resurfaced",
    title = "Percentage of Site Area Resurfaced During Periods of Minimum and Maximum Water Level (2000-2023)"
  ) +
  theme(
    legend.position = "bottom",
    axis.text.x = element_text(angle = 45, hjust = 1, size = 5), axis.title.x = element_blank(),
    strip.text.x = element_text(size = 8, colour = "black"),
    # text = element_text(size = 12),
    axis.text.y = element_text(size = 12),legend.text = element_text(size = 12), 
    plot.title = element_text(size = 12)
  ) +
  guides(x = guide_axis(angle = 60))

pct_area_min_max_plot


ggsave(
  plot = pct_area_min_max_plot, filename = "percentage_emerged_area_selected_sites.png",
  path = here::here("output/plots"),
  device = "png", width = 240, height = 160, units = "mm", dpi = 300
)

# Single Site viz - Jubaniyeh -----------------------------------------------------------------------

# Grepl Jubaniyeh
sites_pct_area_min_max_long_j <- sites_pct_area_min_max_long[grepl("Jubaniyeh", sites_pct_area_min_max_long$name),]


pct_area_min_max_plot_j <- ggplot(sites_pct_area_min_max_long_j, aes(x = Years, y = PctEmergedArea, fill = Period)) +
  geom_bar(width = 0.8, stat = "identity", position = "dodge", alpha = .8) +
  geom_hline(yintercept = c(25, 50, 75), linetype = "dashed", size = 0.5, color = "gray25") +
  scale_fill_manual(values = c("grey26", "grey65"))+
  theme_light() +
  labs(
    y = "Percentage of Site Area Resurfaced",
    title = "Percentage of Area Resurfaced for the site of Jubaniyeh (1993-2020)"
  ) +
  theme(
    legend.position = "bottom",
    axis.text.x = element_text(angle = 45, hjust = 1, size = 10), axis.title.x = element_blank(),
    strip.text.x = element_text(size = 8, colour = "black"),
    axis.text.y = element_text(size = 12),legend.text = element_text(size = 12), 
    plot.title = element_text(size = 12)
  ) +
  guides(x = guide_axis(angle = 60))
pct_area_min_max_plot_j

ggsave(
  plot = pct_area_min_max_plot_j, filename = "percentage_emerged_area_jubaniyeh.png",
  path = here::here("output/plots"),
  device = "png", width = 230, height = 160, units = "mm", dpi = 300
)
