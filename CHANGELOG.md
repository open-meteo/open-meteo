# Changelog

## [1.6.1](https://github.com/open-meteo/open-meteo/compare/1.6.0...1.6.1) (2026-09-11)


### Bug Fixes

* **Meteofrance HD 15min:** 15min precipitation and snow is not available anymore ([#2120](https://github.com/open-meteo/open-meteo/issues/2120)) ([9701689](https://github.com/open-meteo/open-meteo/commit/9701689dd81ebef2d478800366c586c8a02c0c19))

## [1.6.0](https://github.com/open-meteo/open-meteo/compare/1.5.7...1.6.0) (2026-09-10)


### Features

* migrate marine API to generic readers ([#2080](https://github.com/open-meteo/open-meteo/issues/2080)) ([5242c2b](https://github.com/open-meteo/open-meteo/commit/5242c2ba02dd7d7aba715ee059049ddd98133a63))


### Bug Fixes

* accept Unix timestamps in OpenAPI response schemas ([#2107](https://github.com/open-meteo/open-meteo/issues/2107)) ([930063f](https://github.com/open-meteo/open-meteo/commit/930063f12047363861f775c685c16a98b52dbfe4))
* avoid nan encoding in json output writer ([#2115](https://github.com/open-meteo/open-meteo/issues/2115)) ([8730249](https://github.com/open-meteo/open-meteo/commit/8730249ffbb41af4ec11b9ac6f7ba66393aae6b7))
* avoid nonfinite values in ProjectionGrid before integer conversion ([#2118](https://github.com/open-meteo/open-meteo/issues/2118)) ([0b462a4](https://github.com/open-meteo/open-meteo/commit/0b462a4e1a2005d6cb6b767c049fdee5400dbc6f))
* bump aws-actions/configure-aws-credentials from 6.2.3 to 6.2.4 ([#2105](https://github.com/open-meteo/open-meteo/issues/2105)) ([175a30a](https://github.com/open-meteo/open-meteo/commit/175a30a1825ac1747e47b637a9d212f76ffb2e07))
* bump the swift-dependencies group with 9 updates ([#2106](https://github.com/open-meteo/open-meteo/issues/2106)) ([fb4b569](https://github.com/open-meteo/open-meteo/commit/fb4b569ebf6d20db8eb1097587d187317546cfbf))
* check whether OmFileSystemManager is initialized before spawning background tasks ([#2103](https://github.com/open-meteo/open-meteo/issues/2103)) ([a787d56](https://github.com/open-meteo/open-meteo/commit/a787d567e7e08852f4e0b05ac64731e926938040))
* DWD SIS downloader allow gap filling if single timesteps are missing ([#2111](https://github.com/open-meteo/open-meteo/issues/2111)) ([8e46661](https://github.com/open-meteo/open-meteo/commit/8e4666118978ad9e7219d98c3ab17de873a547ab))
* Large numbers could fail in the number to string formatter ([#2109](https://github.com/open-meteo/open-meteo/issues/2109)) ([56781e9](https://github.com/open-meteo/open-meteo/commit/56781e9cd9a4e8e9a9a7bb995ece9d40f94abc31))
* nan coordinates resulting from inverse projection at origin in laea ([#2114](https://github.com/open-meteo/open-meteo/issues/2114)) ([2f58838](https://github.com/open-meteo/open-meteo/commit/2f588383295fa2b8b80dbd9a886c7f2bd78b2585))
* print api key usage before upload ([4455deb](https://github.com/open-meteo/open-meteo/commit/4455debbb5244c469a39ddf612aa16393b624a42))
* reuse cache keys across 8MB boundary in OmReaderBlockCache ([#2117](https://github.com/open-meteo/open-meteo/issues/2117)) ([d957fcd](https://github.com/open-meteo/open-meteo/commit/d957fcd50782eb98d45c86e39a3bbecc678afb83))
* throw noDataAvailableForThisLocation error for single locations ([#2101](https://github.com/open-meteo/open-meteo/issues/2101)) ([aab9843](https://github.com/open-meteo/open-meteo/commit/aab9843bd50d58e5edff749334c63a3395b94ea8))
* track number of calls for each model ([2286452](https://github.com/open-meteo/open-meteo/commit/2286452907fca985d76b99fb69fd606ae3644eff))
* US AQI thresholds ([#2100](https://github.com/open-meteo/open-meteo/issues/2100)) ([4958504](https://github.com/open-meteo/open-meteo/commit/495850487c4411f0f3c4ac66202a3c854ad0dd87))
