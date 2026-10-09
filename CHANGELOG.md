# Changelog

## [1.7.0](https://github.com/open-meteo/open-meteo/compare/1.6.0...1.7.0) (2026-10-09)


### Features

* add environment variable to limit atomic block cache to pressure level files ([#2168](https://github.com/open-meteo/open-meteo/issues/2168)) ([f6e111e](https://github.com/open-meteo/open-meteo/commit/f6e111e5bad38910f36e86bc9abbe9f542a262a9))
* finish DMI migration ([#2150](https://github.com/open-meteo/open-meteo/issues/2150)) ([cc3f4e5](https://github.com/open-meteo/open-meteo/commit/cc3f4e5e956b39a56ab182faeccfd3d936ae6b4c))
* migrate cmc to generic structure ([#2147](https://github.com/open-meteo/open-meteo/issues/2147)) ([29c9a89](https://github.com/open-meteo/open-meteo/commit/29c9a892a3420e918d8cdc8975083130bb29ea4e))
* migrate kma to generic structure ([#2146](https://github.com/open-meteo/open-meteo/issues/2146)) ([7eb1aed](https://github.com/open-meteo/open-meteo/commit/7eb1aed7429167a4533eab57ff892e74f8140cf9))
* native icon grid domains ([#1993](https://github.com/open-meteo/open-meteo/issues/1993)) ([1cd0eaa](https://github.com/open-meteo/open-meteo/commit/1cd0eaa1ed97857772a6bd968bbe373bd23636f3))


### Bug Fixes

* bounding box requests need to know about model elevation ([#2188](https://github.com/open-meteo/open-meteo/issues/2188)) ([454d6ef](https://github.com/open-meteo/open-meteo/commit/454d6ef3ef683587afac067f31627088cd111637))
* build failure in Swift 6.4 release build ([#2144](https://github.com/open-meteo/open-meteo/issues/2144)) ([fb7e804](https://github.com/open-meteo/open-meteo/commit/fb7e8046633bafe1244e16abf1c1491bae48ecca))
* bump aws-actions/configure-aws-credentials from 6.2.4 to 6.3.0 ([#2142](https://github.com/open-meteo/open-meteo/issues/2142)) ([87063f8](https://github.com/open-meteo/open-meteo/commit/87063f8bba7ed741c7e6a3288aeee67683c5f4e1))
* bump github.com/apple/swift-log from 1.15.0 to 1.15.1 in the swift-dependencies group ([#2128](https://github.com/open-meteo/open-meteo/issues/2128)) ([e669e62](https://github.com/open-meteo/open-meteo/commit/e669e6293ce2f0c70646fd61af8fe0c529fc0c53))
* bump googleapis/release-please-action from 4 to 5 ([#2127](https://github.com/open-meteo/open-meteo/issues/2127)) ([c085b34](https://github.com/open-meteo/open-meteo/commit/c085b347f599ba7d0809b321c01b8aa9fcc90eec))
* bump the swift-dependencies group across 1 directory with 10 updates ([#2158](https://github.com/open-meteo/open-meteo/issues/2158)) ([96e07bc](https://github.com/open-meteo/open-meteo/commit/96e07bc647819557b1e7bf4990d07d7d6c7bb9ec))
* correct HRRR and NAM wind direction from grid relative to true north ([#2157](https://github.com/open-meteo/open-meteo/issues/2157)) ([b06f476](https://github.com/open-meteo/open-meteo/commit/b06f4760fd1f997e5559bb380f64c5e496b4a509))
* **Meteofrance HD 15min:** 15min precipitation and snow is not available anymore ([#2120](https://github.com/open-meteo/open-meteo/issues/2120)) ([9701689](https://github.com/open-meteo/open-meteo/commit/9701689dd81ebef2d478800366c586c8a02c0c19))
* send acceptRanges in S3DataController ([#2175](https://github.com/open-meteo/open-meteo/issues/2175)) ([39a0b8c](https://github.com/open-meteo/open-meteo/commit/39a0b8c44b2ec2c86b26e89acaa2a7bb9340776f))
* static file uploading ([#2145](https://github.com/open-meteo/open-meteo/issues/2145)) ([690aa0b](https://github.com/open-meteo/open-meteo/commit/690aa0b321e4950a0dbf70a8cdf93ecd64044e47))
* support bounding box requests for native grids ([#2169](https://github.com/open-meteo/open-meteo/issues/2169)) ([ad179c7](https://github.com/open-meteo/open-meteo/commit/ad179c7b39e443b579f391482c1aa41799aa9af0))
* sync exits non-zero when a model failed ([#2171](https://github.com/open-meteo/open-meteo/issues/2171)) ([f625df2](https://github.com/open-meteo/open-meteo/commit/f625df2c2b2d29d7837b1c71660fb226b1864f9b))
* throw 404 on fileNotFound in S3DataController ([#2181](https://github.com/open-meteo/open-meteo/issues/2181)) ([290493f](https://github.com/open-meteo/open-meteo/commit/290493ffb9b5ee66fb1336219487a346eb27d191))
* Use actual step length to scale GEM accumulated variables ([#2180](https://github.com/open-meteo/open-meteo/issues/2180)) ([a5aac75](https://github.com/open-meteo/open-meteo/commit/a5aac75ca4aed1e1a97dd7e09564f0e06a8359f0))

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
