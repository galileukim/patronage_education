# ==============================================================================
# workflow functions
# ==============================================================================
`%<>%` <- magrittr::`%<>%`

between <- data.table::between

build_repo <- function(module){
  repo <- here("data", "clean", module)

  if(!dir.exists(repo)){
    dir.create(repo)
  }else{
    unlink(repo, recursive = T)
    dir.create(repo)
  }
}

list_data <- function(dir){
  path <- here("data", "clean", dir)
  files <- list.files(path)

  return(files)
}

here_data <- function(type, dir, file) {
  path <- here("data", type, dir, file)
  
  return(path)
}

read_data <- function(type, dir, file) {
  file_path <- here_data(type, dir, file)

  if (str_detect(file, ".rds$")) {
    data <- read_rds(file_path)
  } else {
    data <- fread(file_path)
  }
  
  print_obj_size(data)

  return(data)
}

print_obj_size <- function(obj) {
  obj_size <- object.size(obj)
  print(obj_size, units = "MB")
}

ls_data <- function(env = .GlobalEnv) {
  obj <- ls(env)

  is_data <- map_lgl(
    obj,
    ~is.data.frame(get(.))
  )

  data_obj <- obj[is_data]

  return(data_obj)
}

read_model <- function(file){
  fit <- read_rds(
    here("figures", "models", file)
  )

  print_obj_size(fit)

  return(fit)
}

write_model <- function(model, file) {
  print_obj_size(model)
  
  write_rds(
    model,
    here("figures", "models", file)
  )
}

run_module <- function(domain, module) {
  print(
    paste0("running module ", module, "...")
  )

  if(domain == "data"){
    build_repo(module)
  }
  
  module_script <- paste0(module, ".R")

  path <- here("source", domain, "modules", module_script)

  init_env <- ls(.GlobalEnv)
  source(path)
  reset_env(init_env)

  print(
    paste("module", module, "complete!")
  )
}

reset_env <- function(init_env){
  final_env <- ls(.GlobalEnv)

  rm(
    envir = .GlobalEnv,
    list = setdiff(final_env, init_env)
  )

  gc()
}

save_fig <- function(pl, file, width = 5, height = 3, ...){
  ggplot2::ggsave(
    filename = here("figures", "plots", file),
    pl,
    width = width,
    height = height,
    ...
  )
}

# data io -----------------------------------------------------------------
fread <- partial(
  data.table::fread,
  nThread = parallel::detectCores(),
  integer64 = c("character")
)

list_files <- function(path, pattern){
  files <- map2(
    path,
    pattern,
    list.files
  ) %>% 
    flatten_chr
  
  return(files)
}

# ==============================================================================
# data cleaning
# ==============================================================================
scale_z <- function(col){
  as.vector(scale(col))
}

fix_na <- function(data){
  data_na_fix <- data %>%
    mutate_all(
      ~ na_if(., "")
    )

  return(data_na_fix)
}

# tidy and GGally::ggcoef
tidyfit <- function(fit, vars = '.'){
  broom::tidy(fit) %>%
    filter(
      !str_detect(term, "Intercept|as.factor|Observation.Residual"),
      str_detect(term, vars)
    ) %>%
    mutate(
      conf.low = estimate - 1.96*std.error,
      conf.high = estimate + 1.96*std.error
    )
}

# table of results
mstar <- function(..., font.size = "small", float = F, no.space = T, keep.stat = c("n", "rsq")){
  stargazer::stargazer(
    ...,
    font.size = font.size, 
    float = float, 
    no.space = no.space, 
    keep.stat = keep.stat
  )
}

# summarize props with c.i.
summarise_prop <- function(data, var){
  summarise(
    .data = data,
    prop = mean(get(var), na.rm = T),
    n = n(),
    se = sqrt(prop*(1 - prop)/n),
    upper = prop + 1.96*se,
    lower = prop - 1.96*se
  )
}

# create group summary
group_summarise <- function(data, group_vars, summarise_vars, ...){
  out <- data %>%
    group_by(
      across({{group_vars}})
    ) %>%
    summarise(
      across({{summarise_vars}},
      ...
      ),
      .groups = 'drop'
    )

    return(out)
}

summarise_stats <- function(data, ...){
  vars <- enquos(...)
  
  data_count <- data %>% 
    count
  
  data %<>% 
    summarise_at(
      .vars = vars(!!!vars),
      .funs = list(
        mean = mean,
        sum = sum, 
        med = median, 
        sd = sd
      ),
      na.rm = T
    ) %>% 
    ungroup()
  
  data %<>%
    left_join(
      data_count
    )
  
  return(data)
}

count_freq <- function(data, ...){
  vars <- enquos(...)
  
  data <- data %>% 
    group_by(!!! vars) %>% 
    summarise(n = n()) %>% 
    mutate(freq = n/sum(n))
  
  return(data)
}

# visualization -----------------------------------------------------------
theme_clean <- theme(
  panel.background = element_blank(),
  # panel.border = element_blank(),
  panel.grid.major = element_blank(),
  panel.grid.minor = element_blank(),
  axis.line = element_line(colour = "grey35"),
  legend.position = "bottom",
  text = element_text(
    # family = "Inconsolata",
    color = "grey30",
    size = 10
  ),
  axis.text = element_text(color = "grey30", size = 8),
  axis.title = element_text(size = 10),
  plot.margin = unit(rep(0.25, 4), "cm")
)


tidycoef <- function(fit, vars = ".", ...){
  tidyfit(fit, vars) %>%
    GGally::ggcoef(
      mapping = aes_string(
        y = "term", 
        x = "estimate",
        ...
      ),
      vline_color = "grey85",
      vline_linetype = "dotted",
      color = "steelblue3",
      sort = "ascending",
      errorbar_color = "steelblue3"
    ) +
    xlab("") +
    theme_clean
}

# add mandate year vertical lines
mandate_year <- function(years = seq(2005, 2013, 4)){
  geom_vline(
    xintercept = years,
    linetype = "dotted",
    color = "grey65"
  )
}

# summarize by mun
summarise_fun <- function(data, var){
  data %>%
    group_by(
      region,
      state,
      mun_id,
      year
    ) %>%
    mutate(
      private_var = ifelse(
        public == 0,
        get(var),
        NA
      )
    ) %>%
    summarise(
      public = mean(
        ifelse(
          public == 1,
          get(var),
          NA
        ),
        na.rm = T
      ),
      private = mean(
        private_var,
        na.rm = T
      )
    )
}

# ==============================================================================
# estimation aux. functions
# ==============================================================================
ivreg <- AER::ivreg

formulate_models <- function(response, predictor, fe, controls) {
  formulae <- c(
    reformulate(
      c(predictor, fe), response
    ),
    reformulate(
      c(predictor, controls, fe), response
    )
  )

  return(formulae)
}

# logit
logit <- function(f, data, ...){
  fit <- glm(
    formula = f,
    data = data,
    family = 'binomial',
    ...
  )
}

# election years
add_election <- function(data){
  data %>% 
    mutate(
      election_year = case_when(
        between(year, 2001, 2004) ~ 2000,
        between(year, 2005, 2008) ~ 2004,
        between(year, 2009, 2012) ~ 2008,
        between(year, 2013, 2016) ~ 2012
      )
    )
}

# covariates
join_covariate <- function(data){
  data %>% 
    left_join(
      read_rds(
        here("data/clean/finbra/finbra.rds")
      ),
      by = c("cod_ibge_6", "year")
    ) %>% 
    left_join(
      read_rds(
        here("data/clean/censo_br/censo_2000.rds")
      ),
      by = c("cod_ibge_6")
    ) %>% 
    add_election() %>% 
    left_join(
      read_rds(
        here("data/clean/tse/election.rds")
      ),
      by = c("cod_ibge_6", "election_year")
    )
}

## ggplot aux
gg_point_smooth <- function(data, mapping = aes(),...){
  ggplot(
    data = data,
    mapping
  ) +
    geom_point(
      alpha = 0.25
    ) +
    geom_smooth(
      method = "lm",
      col = "coral3"
    ) 
}

gg_point_line <- function(data, mapping = aes(), ...) {
  ggplot(
    data = data,
    mapping
  ) +
    geom_point(
      ...
    ) +
    geom_line(
      ...
    )
}

geom_errorbar_tidy <- geom_errorbarh(
    aes(
      xmin = conf.low,
      xmax = conf.high
    ),
    height = 0,
    linetype = "solid",
    position = ggstance::position_dodgev(height=0.3)
  )

# missingness
gg_miss_var <- partial(
  naniar::gg_miss_var,
  show_pct = T
)

# hex
gg_hex <- function(data, mapping = aes(), n_bin = 30, ...){
  ggplot(
    data = data,
    mapping
  ) +
    geom_hex(
      bins = n_bin,
      ...
    ) +
    scale_fill_distiller(
      palette = "RdYlBu",
      direction = -1
    )
}
  
# histogram
gg_histogram <- function(data, mapping = aes(), ...){
  ggplot(
    data = data,
    mapping
  ) +
    geom_histogram(
      ...,
      col = "#375b7c",
      fill = "steelblue3",
      aes(y = stat(width*density))
    )
}

gg_point <- function(data, mapping = aes(), ...){
  ggplot(
    data = data,
    mapping
  ) +
    geom_point(...)
}

gg_summary <- function(data, x, y, fun = 'mean', size = 2, geom = 'point', color = matte_indigo, smooth = T, ...){
  plot <- data %>% 
    ggplot(
      aes(
        !!enquo(x),
        !!enquo(y)
      )
    ) +
    stat_summary_bin(
      fun = fun,
      size = size,
      geom = geom,
      color = color,
      ...
    )
  
  if(smooth == T){
    plot <- plot +
      geom_smooth(
        method = 'gam',
        formula = y ~ splines::bs(x, 3)
      ) 
  }
  
  return(plot)
}

# change default ggplot settings
scale_colour_discrete <- function(...) scale_color_brewer(palette = "OrRd", direction = -1, ...)
scale_fill_discrete <- function(...) scale_fill_brewer(palette = "OrRd", direction = -1, ...)

matte_indigo <- "#375b7c"
tulip_red <- "#E64538"

update_geom_defaults(
  "point",
  list(color = matte_indigo, size = 1.5)
)

update_geom_defaults(
  "vline",
  list(linetype = "dashed", color = "grey65")
)

update_geom_defaults(
  "line",
  list(color = matte_indigo, size = 1)
)

update_geom_defaults(
  "smooth",
  list(color = tulip_red)
)

group_split <- function(data, ...) {
  vars <- enquos(...)
  
  data <- data %>% 
    group_by(!!!vars)
  
  group_names <- group_keys(data) %>% 
    pull()
  
  data %>% 
    dplyr::group_split() %>% 
    set_names(
      group_names
    )
}

# reset
# rm(
#   list = setdiff(ls(), c(lsf.str(),"theme_clean"))
# )