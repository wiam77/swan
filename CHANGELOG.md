# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- `swan.apply()`, which substitues `swan.create(Instance)`, for better DX (now, the properties table is correctly typed).
- Color3 to animatable data types.
- Usage example for `swan.tween()` in its documentation.
- Test suite (using [Lest](https://github.com/lest-luau/lest)).
- `swan.utils.is_computed()`.

### Changed
- Reworked tweening system to use Roblox's TweenService.
- Made `swan.tween()` accept an initial_value.
- Made `swan.tween()` accept a raw target value (as in, not a state), for "one-shot" tweens.
- `swan.derived()` -> `swan.computed()`.
- Made computed states a primitive construct (they were previously an effect wrapper)
- Made computed states pull-based.
- Make binary implicit computeds support both operands as states.
- `swan.state` now provides types (with some limitations) for implicit computeds.
- `swan.proxy_state()` -> `swan.proxy()`.
- `state.callbacks` -> `state.subscribers`.
- License from GPLv3 to MPL-2.0.
- Split the library across multiple files.

### Removed
- A bunch of internal types from the external API (now only `state` and `proxy_state` are available).
- `swan.wait()`.
- `utils.state_get_real()`.
- `utils.branch()`.

## [v1.1.0] - 2026-05-20
### Added
- Tweening capabilities through [`swan.tween()`](https://wiam.codeberg.page/swan/api/swan#tween),
with multiple default easing functions (with support for custom ones), directions (in, out, in-out),
data-types (numbers, vectors, UDims and CFrames) and options (bounces (yoyo), delay and on_complete callback).

### Changed
- Removed warnings for when an effect would yield and a block effect would not.
- Changed SWAN_PROXY_ID and SWAN_REAL_ID to be non-unique string identifiers, for persistence across sessions.

## [v1.0.0] - 2026-05-04
### Added
- Documentation website (through Moonwave): https://wiam.codeberg.page/swan
- [`swan.create()`](https://wiam.codeberg.page/swan/api/swan#create) and [`swan.component()`](https://wiam.codeberg.page/swan/api/swan#component) for [Roblox](http://wiam.codeberg.page/swan/api/swan#roblox).
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

[Unreleased]: https://codeberg.org/wiam/swan/compare/v1.1.0...HEAD
[v1.1.0]: https://codeberg.org/wiam/swan/compare/v1.0.0...v1.1.0
[v1.0.0]: https://codeberg.org/wiam/swan/compare/v0.1.2...v1.0.0
[v0.1.2]: https://codeberg.org/wiam/swan/compare/v0.1.1...v0.1.2
[v0.1.1]: https://codeberg.org/wiam/swan/compare/v0.1.0...v0.1.1
[v0.1.0]: https://codeberg.org/wiam/swan/releases/tag/v0.1.0
