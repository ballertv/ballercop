# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [1.0.0] - [2022-12-26]
### Changed
- Both staged and unstaged files are parsed by default now.
  Command `unstaged` is repurposed to running on unstaged files **only**
- Autofix will run, maximum two times, in the case where initial fix may result of rule
  break.

### Added
- Logging is improved with log levels. Updated CLI commands with addition of `log` & `log_level` and removal of `verbose`