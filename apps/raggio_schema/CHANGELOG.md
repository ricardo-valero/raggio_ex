# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-01-13

### Added

- Initial release
- Composable schema definition API with `struct/1`, `string/0`, `integer/0`, `float/0`, `boolean/0`
- Type validation with `positive/0`, `negative/0`, `min/1`, `max/1`, `range/2`
- Collection types with `array/1`, `map/2`
- Union types with `union/1` and enum validation with `enum/1`
- Optional fields with `optional/1` and default values with `default/2`
- Nested schema support
- Custom validator composition with `custom/1`
- BigQuery schema export adapter
- Sheet schema import adapter
- Comprehensive validation error reporting
