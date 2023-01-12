# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - [2023-1-11]
### Changed
- Made sure `repo` option is appended with '/' when concatenating w/ file path
- By default, run against a base branch. Base branch defaults to "origin/testflight"
- Updated logging logic. Logs by default with each log having log level.

### Added
- Return status code
- Running on committed changes between provided base branch or "origin/testflight" by default
- Option to silent logs. User will still see result of fix
- Support for single file fix.

## [1.0.1] - [2023-1-11]
### Changed
- Fix logging for unfixable offenses

## [1.0.0] - [2022-12-26]
### Changed
- Both staged and unstaged files are parsed by default now.
  Command `unstaged` is repurposed to running on unstaged files **only**
- Autofix will run, maximum two times, in the case where initial fix may result of rule
  break.

### Added
- Logging is improved with log levels. Updated CLI commands with addition of `log` & `log_level` and removal of `verbose`