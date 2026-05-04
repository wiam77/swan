# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [v1.0.0] - 2026-05-04
### Added
- Documentation website (through Moonwave): https://wiam.codeberg.page/swan
- [`swan.create()`] and [`swan.component()`] for [Roblox](http://wiam.codeberg.page/swan/api/swan#roblox).
- [Implicit deriveds](http://wiam.codeberg.page/swan/docs/concepts#implicit-deriveds).
- [Proxy states for tables](https://wiam.codeberg.page/swan/docs/concepts#table-states).
- [`swan.block_effect()`](https://wiam.codeberg.page/swan/api/swan#block_effect).
- Effect cleanup functions.
- [`swan.utils`](https://wiam.codeberg.page/swan/api/utils).
- `keywords` and `homepage` fields to package.json.

### Changed
- Renamed `swan.derive()` to `swan.derived()`.
- Renamed `swan.cleanup()` to `swan.clear()`.
- [`swan.scope()`](https://wiam.codeberg.page/swan/api/swan#scope) now acts in a completely different way: you
pass a function to it, and `swan` will automatically collect the disconnecter of any effect created within it,
putting them into a single disconnecter.
- Moved `batch()`, `branch()`, `is_state()` and `clear()` into `swan.utils`.
- Replaced warnings(`warn` calls) with normal `print` calls for better portability.
- Updated README.md demo and documentation website on wally manifest.

### Removed
- `swan.mirror()`.

## [v0.1.2] - 2026-01-21
### Added
- This changelog

### Changed
- Improved build script.
- Include newline (\n) in base pesde manifest.
- rl -> swan in Rojo project file.

### Removed
- Rojo project file in pesde manifest.

## [v0.1.1] - 2026-01-19
### Changed
- Bumped the package version for an unpublished change which renamed the namespace in the TypeScript declaration file from `rl` (the project's previous name) to `swan`.

## [v0.1.0] - 2026-01-19
Initial release.

[Unreleased]: https://codeberg.org/wiam/swan/compare/v1.0.0...HEAD
[v1.0.0]: https://codeberg.org/wiam/swan/compare/v0.1.2...v1.0.0
[v0.1.2]: https://codeberg.org/wiam/swan/compare/v0.1.1...v0.1.2
[v0.1.1]: https://codeberg.org/wiam/swan/compare/v0.1.0...v0.1.1
[v0.1.0]: https://codeberg.org/wiam/swan/releases/tag/v0.1.0
