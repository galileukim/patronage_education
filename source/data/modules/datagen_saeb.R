# generate municipal table
saeb_exam_mun <- read_data(
  "raw",
  "saeb",
  "saeb_exam_mun.csv"
) %>%
  add_election_year()

saeb_exam_mun %>%
  write_data(
    "saeb",
    "saeb_exam_mun.rds"
  )

# saeb_sample
saeb_student <- read_data(
  "raw",
  "saeb",
  "saeb_student.csv.gz"
)

# breakdown by administrative department
saeb_school <- saeb_student %>%
  filter(year >= 2007) %>%
  mutate(
    grade_level = as.factor(grade),
    brown_black_student = if_else(race_student %in% c("brown", "black"), 1, 0)
  ) %>%
  group_by(
    cod_ibge_6,
    year,
    dep,
    cod_school,
    grade_level
  ) %>%
  summarise(
    across(
      c(
        failed_school_year_student,
        fridge_student,
        housekeeper_student,
        father_home_student,
        mother_home_student,
        pc_student,
        age_student,
        brown_black_student,
      grade_exam
      ),
      ~ mean(as.numeric(.x), na.rm = T)
    ),
    .groups = "drop"
  )

saeb_student %>%
  sample_frac(0.25) %>%
  write_data(
    "saeb",
    "saeb_student_sample.rds"
  )

saeb_school %>%
  write_data(
    "saeb",
    "saeb_school.rds"
  )

# hierarchical model
saeb_hierarchical <- read_data(
  "raw",
  "saeb",
  "saeb_hierarchical.csv.gz"
)

saeb_hierarchical <- saeb_hierarchical %>%
  rename(
    school_id = cod_school,
    grade_level = grade
  ) %>%
  mutate(
    grade_level = case_when(
      grade_level <= 5 ~ 5L,
      T ~ 9L
    )
  )
  
saeb_hierarchical %>%
  write_data(
    "saeb",
    "saeb_hierarchical.rds"
  )