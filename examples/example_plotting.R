df <- recanaq::get_daily_all_stations(from_date = "01/01/2025", to_date = "01/01/2026")

df_temps <- df |>
  filter(name == "Temperature 2m (DegC)")

cutpoints <- df_temps  %>%
  mutate(
    outlier = between(
      value,
      quantile(value, 0.25, na.rm=T)-
        1.5*IQR(value, na.rm=T),
      quantile(value, 0.75, na.rm=T)+
        1.5*IQR(value, na.rm=T))) %>%
  filter(outlier)

ori <- sum(range(cutpoints$value))/2
sca <- seq(range(cutpoints$value)[1],
           range(cutpoints$value)[2],
           length.out = 7)[-4]

round(ori, 2) # The origin
#> [1] 6.58

round(sca, 2)



df_temps |>
  # filter(name == "Temperature2mDegC") |>
  ggplot() +
  geom_horizon(aes(DateTime, value)) +
  scale_fill_hcl(palette = 'RdBu', reverse = T) +
  facet_grid(StationName~.) +
  theme_few() +
  theme(
    panel.spacing.y=unit(0, "lines"),
    strip.text.y = element_text(size = 7, angle = 0, hjust = 0),
    axis.text.y = element_blank(),
    axis.title.y = element_blank(),
    axis.ticks.y = element_blank(),
    panel.border = element_blank()
  ) +
  scale_x_date(expand=c(0,0),
               date_breaks = "1 month",
               date_labels = "%b") +
  xlab('Date') +
  ggtitle('Average daily temperatures in Canterbury 2025')

