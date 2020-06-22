# table of results
sink(p_file_here('results', 'turnover_result.tex'))
mstar(
  list(
    fit_turnover[[2]],
    fit_hired,
    fit_fired,
    fit_hired_mun,
    fit_fired_mun
  ),
  keep = c('coalition_share', 'rais_category'),
  add.lines = list(c("Controls", rep("\\checkmark", 5))),
  covariate.labels = c('Executive share of seats', 'School principal', 'Executive share of seats X School principal'),
  dep.var.labels.include = F,
  column.labels = c('Turnover index', 'Hired (Logit)', 'Fired (Logit)', 'Hired (FE)', 'Fired (FE)'),
  column.separate = rep(1, 5),
  model.names = FALSE
)
sink()

plot_mun <- fit_hired_mun%>% 
  tidycoef(
    vars = "coalition|mayor_reelected|censo_log_pop|censo_median_wage"
  ) +
  # scale_y_discrete(
  #   labels = rev(c("Share of legislative seats", "Population size (logged)", "Median wage", "Size of coalition", "Reelected", "Share of legislative seats (sq.)"))
  # ) +
  theme(
    axis.title = element_blank()
  )

ggsave(
  plot_mun,
  filename = p_file_here('figs', "fit_mun.pdf")
)

plot_hired <- plot_grid(
  plot_logit,
  plot_mun,
  nrow = 2,
  labels = c("Logit", "OLS"),
  label_size = 7.5
)

ggsave(
  plot_hired,
  filename = p_file_here('figs', "hired_fit.pdf")
)

# predicted vals
model_fit_hired_mun <- model.frame(
  fit_hired_mun
) 

plot_hired <- model_fit_hired_mun %>% 
  mutate(
    predict = fit_hired_mun$fitted.values
  ) %>% 
  group_by(coalition_share) %>% 
  mutate(predict_mean = mean(rais_hired, na.rm = T)) %>% 
  ggplot(
    aes(x = coalition_share)
  ) +
  geom_count(
    aes(y = predict_mean),
    alpha = 0.1
  ) +
  geom_smooth(
    aes(y = predict),
    method = lm,
    formula = y ~ x,
    col = "coral3"
  ) +
  coord_cartesian(
    ylim = c(0.05, 0.125)
  ) +
  labs(
    x = "Share of legislative seats",
    y = "Proportion of new hires"
  ) +
  theme(legend.position = 'none')

model_fit_fired_mun <- model.frame(
  fit_fired_mun
) 

plot_fired <- model_fit_fired_mun %>% 
  mutate(
    predict = fit_fired_mun$fitted.values
  ) %>% 
  group_by(coalition_share) %>% 
  mutate(predict_mean = mean(rais_fired, na.rm = T)) %>% 
  ggplot(
    aes(x = coalition_share)
  ) +
  geom_count(
    aes(y = predict_mean),
    alpha = 0.1
  ) +
  geom_smooth(
    aes(y = predict),
    method = lm,
    formula = y ~ x,
    col = "coral3"
  ) +
  coord_cartesian(
    ylim = c(0, 0.075)
  ) +
  labs(
    x = "Share of legislative seats",
    y = "Proportion of dismissals"
  ) +
  theme(legend.position = 'none')

plot_turnover <- grid.arrange(
  grobs = list(
    plot_hired,
    plot_fired
  ),
  ncol = 2
)

ggsave(
  plot_turnover,
  filename = p_file_here('figs', "plot_pred.pdf")
)