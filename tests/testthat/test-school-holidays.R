test_that("parse_school_holidays parses and standardizes ICS events", {
  ics_file <- tempfile(fileext = ".ics")
  writeLines(
    c(
      "BEGIN:VCALENDAR",
      "BEGIN:VEVENT",
      "DTSTART;VALUE=DATE:20260127",
      "DTEND;VALUE=DATE:20260128",
      "SUMMARY:Start of Term 1",
      "END:VEVENT",
      "BEGIN:VEVENT",
      "DTSTART;VALUE=DATE:20260403",
      "DTEND;VALUE=DATE:20260404",
      "SUMMARY:King's Birthday",
      "END:VEVENT",
      "END:VCALENDAR"
    ),
    ics_file
  )

  result <- parse_school_holidays(ics_file)

  expect_named(result, c("Event", "Start_Date", "End_Date", "Source"))
  expect_equal(result$Event, c("Start of Term 1", "King's Birthday"))
  expect_equal(result$Start_Date, as.Date(c("2026-01-27", "2026-04-03")))
  expect_equal(result$Source, rep(basename(ics_file), 2))
})

test_that("parse_school_holidays handles empty ICS files", {
  ics_file <- tempfile(fileext = ".ics")
  writeLines(c("BEGIN:VCALENDAR", "END:VCALENDAR"), ics_file)

  result <- parse_school_holidays(ics_file)

  expect_equal(nrow(result), 0)
  expect_s3_class(result$Start_Date, "Date")
  expect_s3_class(result$End_Date, "Date")
})

test_that("parse_school_holidays requires at least one file", {
  expect_error(parse_school_holidays(character()), "No .ics files provided")
})

test_that("download_school_holidays creates its destination for empty input", {
  download_dir <- tempfile()

  result <- download_school_holidays(character(), download_dir)

  expect_true(dir.exists(download_dir))
  expect_length(result, 0)
})

test_that("get_nz_holidays validates supported years and flags", {
  expect_error(get_nz_holidays(2033), "between 2022 and 2032")
  expect_error(get_nz_holidays(2026, holidays_only = NA), "single TRUE or FALSE")
  expect_error(get_nz_holidays(c(2026, 2027)), "single four-digit")
  expect_error(get_nz_holidays("2026x"), "single four-digit")
})
