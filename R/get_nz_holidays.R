#' Fetch NZ School Holiday Calendar URLs
#'
#' Scrapes the NZ Ministry of Education website for .ics file download links.
#'
#' @param url Base web address to scrape.
#' @return A character vector of absolute URLs.
#' @export
get_school_holiday_urls <- function(url = "https://www.education.govt.nz/school-terms-and-holidays-dates") {
  page <- rvest::read_html(url)

  all_links <- page |>
    rvest::html_elements("a") |>
    rvest::html_attr("href")

  ics_links <- unique(purrr::keep(all_links, ~ stringr::str_detect(.x, "(?i)\\.ics")))

  base_url <- "https://www.education.govt.nz"
  final_urls <- ifelse(
    stringr::str_starts(ics_links, "http"),
    ics_links,
    paste0(base_url, ics_links)
  )

  return(final_urls)
}

#' Download School Holiday .ics Files
#'
#' @param urls Character vector of `.ics` file URLs.
#' @param download_dir Directory where files should be saved.
#' @return A character vector of saved file paths (invisibly).
#' @export
download_school_holidays <- function(urls, download_dir = tempdir()) {
  if (!dir.exists(download_dir)) {
    dir.create(download_dir, recursive = TRUE)
  }

  downloaded_files <- character()

  for (file_url in urls) {
    file_name <- file_url |>
      basename() |>
      stringr::str_remove("\\?.*$") |>
      stringr::str_remove("#.*$")

    destination_path <- file.path(download_dir, file_name)

    tryCatch({
      utils::download.file(file_url, destfile = destination_path, mode = "wb", quiet = TRUE)
      downloaded_files <- c(downloaded_files, destination_path)
    }, error = function(e) {
      warning("Failed to download: ", file_url, call. = FALSE)
    })
  }

  invisible(downloaded_files)
}

#' Parse a Single Outlook .ics File
#'
#' Internal helper to extract event data from an `.ics` file.
#'
#' @param file_path Path to the `.ics` file.
#' @return A data frame containing raw event details, or NULL.
#' @keywords internal
parse_outlook_ics <- function(file_path) {
  lines <- readLines(file_path, warn = FALSE)

  # Unfold wrapped lines
  unfolded_lines <- character()
  for (line in lines) {
    if (stringr::str_detect(line, "^[ \t]")) {
      if (length(unfolded_lines) > 0) {
        idx <- length(unfolded_lines)
        unfolded_lines[idx] <- paste0(unfolded_lines[idx], stringr::str_remove(line, "^[ \t]"))
      }
    } else {
      unfolded_lines <- c(unfolded_lines, line)
    }
  }

  events <- list()
  current_event <- NULL
  in_event <- FALSE

  for (line in unfolded_lines) {
    if (line == "BEGIN:VEVENT") {
      in_event <- TRUE
      current_event <- list()
      next
    }
    if (line == "END:VEVENT") {
      if (in_event) {
        events[[length(events) + 1]] <- as.data.frame(current_event, stringsAsFactors = FALSE)
      }
      in_event <- FALSE
      current_event <- NULL
      next
    }

    if (in_event && stringr::str_detect(line, "^(DTSTART|DTEND|SUMMARY|DESCRIPTION)[:;]")) {
      key <- stringr::str_extract(line, "^[A-Z]+")
      value <- stringr::str_remove(line, "^[^:]*:")

      if (key == "SUMMARY") {
        value <- stringr::str_remove(value, "^LANGUAGE=[^:]*:")
      }

      current_event[[key]] <- value
    }
  }

  if (length(events) > 0) {
    dplyr::bind_rows(events) |>
      dplyr::mutate(Source = basename(file_path))
  } else {
    NULL
  }
}

#' Parse and Tidy School Holiday .ics Files
#'
#' @param ics_files Vector of file paths to `.ics` files.
#' @return A cleaned tibble of holiday names and dates.
#' @export
parse_school_holidays <- function(ics_files) {
  if (length(ics_files) == 0) {
    stop("No .ics files provided to parse.", call. = FALSE)
  }

  master_holiday_dates <- purrr::map_dfr(ics_files, parse_outlook_ics)

  if (nrow(master_holiday_dates) == 0) {
    return(tibble::tibble(
      Event = character(),
      Start_Date = as.Date(character()),
      End_Date = as.Date(character()),
      Source = character()
    ))
  }

  master_holiday_dates |>
    dplyr::bind_rows(tibble::tibble(SUMMARY = character(), DTSTART = character(), DTEND = character())) |>
    dplyr::select(
      Event = SUMMARY,
      Start_Raw = DTSTART,
      End_Raw = DTEND,
      Source
    ) |>
    dplyr::mutate(
      Start_Date = lubridate::ymd(stringr::str_extract(Start_Raw, "\\d{8}"), quiet = TRUE),
      End_Date   = lubridate::ymd(stringr::str_extract(End_Raw, "\\d{8}"), quiet = TRUE),

      # Clean and standardise event names across years
      Event = dplyr::case_when(
        stringr::str_detect(Event, "(?i)start.*term\\s*1") ~ "Start of Term 1",
        stringr::str_detect(Event, "(?i)end.*term\\s*1")   ~ "End of Term 1",
        stringr::str_detect(Event, "(?i)start.*term\\s*2") ~ "Start of Term 2",
        stringr::str_detect(Event, "(?i)end.*term\\s*2")   ~ "End of Term 2",
        stringr::str_detect(Event, "(?i)start.*term\\s*3") ~ "Start of Term 3",
        stringr::str_detect(Event, "(?i)end.*term\\s*3")   ~ "End of Term 3",
        stringr::str_detect(Event, "(?i)start.*term\\s*4") ~ "Start of Term 4",
        stringr::str_detect(Event, "(?i)end.*term\\s*4")   ~ "End of Term 4",
        stringr::str_detect(Event, "(?i)king")             ~ "King's Birthday",
        TRUE ~ stringr::str_to_title(stringr::str_squish(Event))
      )
    ) |>
    dplyr::select(Event, Start_Date, End_Date, Source) |>
    dplyr::distinct(Event, Start_Date, End_Date, .keep_all = TRUE) |>
    dplyr::arrange(Start_Date)
}

#' Get NZ School Holiday Dates
#'
#' Wraps the fetching, downloading, and parsing steps into a single call.
#'
#' @param download_dir Target folder for file downloads. Defaults to a temporary directory.
#' @return A tidy tibble of school holiday dates.
#' @export
get_school_holidays <- function(download_dir = tempdir()) {
  urls <- get_school_holiday_urls()
  files <- download_school_holidays(urls, download_dir = download_dir)
  parse_school_holidays(files)
}

#' Get New Zealand Public Holidays Data Frame
#'
#' This function fetches New Zealand public holiday data for a specified year
#' from a remote CSV repository, maps them alongside weekends and weekdays,
#' and returns a structured data frame.
#'
#' @param target_year An integer or character specifying the calendar year (e.g., 2026).
#' @param holidays_only A logical value. If \code{TRUE} (default), the function returns only
#'   the official holiday rows. If \code{FALSE}, it returns a continuous
#'   365/366-day calendar grid.
#'
#' @return A data frame containing two columns: \code{Date} (Date class) and
#'   \code{Category} (character class).
#' @export
#'
#' @importFrom utils read.csv
#' @importFrom dplyr mutate filter select
#'
get_nz_holidays <- function(target_year, holidays_only = TRUE) {

  if (length(target_year) != 1 || is.na(target_year) ||
      !grepl("^\\d{4}$", as.character(target_year))) {
    stop("`target_year` must be a single four-digit year.", call. = FALSE)
  }

  target_year <- as.integer(target_year)

  if (target_year < 2022 || target_year > 2032) {
    stop("`target_year` must be between 2022 and 2032.", call. = FALSE)
  }

  if (length(holidays_only) != 1 || is.na(holidays_only) ||
      !is.logical(holidays_only)) {
    stop("`holidays_only` must be a single TRUE or FALSE value.", call. = FALSE)
  }

  # 1. Fetch the raw CSV directly from the GitHub repository link
  csv_url <- "https://raw.githubusercontent.com/sohnemann/New-Zealand-Public-Holidays/main/data/2022-2032-public-holidays-all.csv"

  # Safeguard against download errors
  nz_raw_data <- tryCatch({
    utils::read.csv(csv_url)
  }, error = function(e) {
    stop("Failed to download holiday data from GitHub repository.")
  })

  # Parse dates and filter by year using standard base/dplyr tools
  nz_raw_data <- nz_raw_data |>
    dplyr::mutate(Date = as.Date(Date, format = "%d/%m/%Y")) |>
    dplyr::filter(format(Date, "%Y") == as.character(target_year))

  # 2. Build full year calendar baseline grid rows
  all_dates <- seq(as.Date(paste0(target_year, "-01-01")), as.Date(paste0(target_year, "-12-31")), by = "day")

  calendar_df <- data.frame(
    Date = all_dates,
    Day_OfWeek = as.POSIXlt(all_dates)$wday # 0 = Sunday, 6 = Saturday
  ) |>
    dplyr::mutate(Category = ifelse(Day_OfWeek %in% c(0, 6), "Weekend", "Regular Weekday"))

  # 3. Inject unique labels directly from the CSV text fields
  if (nrow(nz_raw_data) > 0) {
    for (i in 1:nrow(nz_raw_data)) {
      h_date <- nz_raw_data$Date[i]
      h_name <- nz_raw_data$Holiday.Name[i]

      if (grepl("Canterbury Anniversary", h_name)) {
        h_cat <- "Canterbury Anniversary"
      } else if (grepl("Mondayised|Tuesdayised", h_name)) {
        h_cat <- "Observed Holiday"
      } else if (grepl("Anniversary", h_name)) {
        next # Skip other regional anniversary matches to avoid grid clutter
      } else {
        h_cat <- "Standard Holiday"
      }

      calendar_df$Category[calendar_df$Date == h_date] <- h_cat
    }
  } else {
    warning(paste("No holiday data found in the CSV for year", target_year))
  }

  # 4. Clean up the final dataframe output
  output_df <- calendar_df |>
    dplyr::select(Date, Category)

  # 5. Conditional filter for only the actual holidays
  if (holidays_only) {
    output_df <- output_df |>
      dplyr::filter(!Category %in% c("Weekend", "Regular Weekday"))
  }

  return(output_df)
}

#' Update Historical Public Holiday Record
#'
#' Appends newly fetched New Zealand public holiday records for a specific year
#' to a persistent historical CSV file. It checks for duplicates before writing
#' to ensure historical rows are only added once.
#'
#' @param target_year An integer or character specifying the calendar year (e.g., 2026).
#' @param dev_mode A logical value. If \code{TRUE}, it attempts to write directly
#'   to the \code{inst/extdata/} directory of your active package development source.
#'   If \code{FALSE} (default), it reads/writes to a safe, persistent user directory
#'   allocated for the installed package.
#'
#' @return A data frame containing the updated, complete historical holiday record (invisibly).
#' @export
#'
#' @importFrom utils read.csv write.csv
#' @importFrom dplyr bind_rows distinct arrange
#' @importFrom tools R_user_dir
#'
update_holiday_history <- function(target_year, dev_mode = FALSE) {

  # 1. Determine the correct file path layout
  file_name <- "nz_holiday_history.csv"

  if (dev_mode) {
    # Path for when you are actively building/developing the source code package
    dir_path <- file.path("inst", "extdata")
    if (!dir.exists(dir_path)) {
      dir.create(dir_path, recursive = TRUE)
    }
    csv_path <- file.path(dir_path, file_name)
  } else {
    # Standard CRAN-compliant production path for an installed package environment
    dir_path <- tools::R_user_dir("recanaq", which = "data")
    if (!dir.exists(dir_path)) {
      dir.create(dir_path, recursive = TRUE)
    }
    csv_path <- file.path(dir_path, file_name)
  }

  # 2. Fetch the incoming data for the target year using your package function
  # Force holidays_only = TRUE to keep the history file lightweight and clean
  new_data <- get_nz_holidays(target_year = target_year, holidays_only = TRUE)

  if (nrow(new_data) == 0) {
    message("No new data found to append for year ", target_year)
    return(invisible(NULL))
  }

  # 3. Read the existing historical file if it exists, or create an empty layout
  if (file.exists(csv_path)) {
    history_df <- utils::read.csv(csv_path, stringsAsFactors = FALSE)
    # Ensure Date column stays formatted as Date class type for proper downstream operations
    history_df$Date <- as.Date(history_df$Date)
  } else {
    history_df <- data.frame(
      Date = as.Date(character()),
      Category = character(),
      stringsAsFactors = FALSE
    )
  }

  # 4. Combine the data frames and cleanly deduplicate rows
  # distinct() ensures we don't duplicate old years if this function runs multiple times
  updated_history <- dplyr::bind_rows(history_df, new_data) |>
    dplyr::distinct(Date, Category, .keep_all = TRUE) |>
    dplyr::arrange(Date)

  # 5. Save the updated historical dataset back to disk
  utils::write.csv(updated_history, file = csv_path, row.names = FALSE)

  message("Success: Historical log updated at: ", csv_path)
  return(invisible(updated_history))
}

