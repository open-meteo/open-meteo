# Changelog

## [1.8.0](https://github.com/open-meteo/open-meteo/compare/1.7.0...1.8.0) (2026-10-24)


### Features

* aicon downloader ([#1769](https://github.com/open-meteo/open-meteo/issues/1769)) ([17f6624](https://github.com/open-meteo/open-meteo/commit/17f6624d97246e2c6bb6219241ee3e130c8ee3c8))
* integrate ICON-D2 RUC ([#2186](https://github.com/open-meteo/open-meteo/issues/2186)) ([a48a37e](https://github.com/open-meteo/open-meteo/commit/a48a37e47d39d02215eff3541fb56d1d437ff64b))
* NOAA NCEP RRFS model integration ([#2133](https://github.com/open-meteo/open-meteo/issues/2133)) ([f3cdf74](https://github.com/open-meteo/open-meteo/commit/f3cdf746bee49044a3ec9871237057eeb282b85d))


### Bug Fixes

* best match should not depend on EPS grid artifacts ([#2238](https://github.com/open-meteo/open-meteo/issues/2238)) ([c81f031](https://github.com/open-meteo/open-meteo/commit/c81f031499821299ffaf1a570bddf9008041000a))
* **cleanup:** obsolete reader mappings ([#2244](https://github.com/open-meteo/open-meteo/issues/2244)) ([9de207f](https://github.com/open-meteo/open-meteo/commit/9de207fa9d47240915d00b6384b009accef2477e))
* ecmwf ensemble downloader improvements ([#2210](https://github.com/open-meteo/open-meteo/issues/2210)) ([dcff54d](https://github.com/open-meteo/open-meteo/commit/dcff54d45b17649bd1485da8362667af1313cf45))
* ERA5 last day aggregation might be missing for precipitation and solar radiation ([#2252](https://github.com/open-meteo/open-meteo/issues/2252)) ([815e0d8](https://github.com/open-meteo/open-meteo/commit/815e0d8da98fff84091df6f41c82f4cca9dc83b3))
* Improve UKMO, NBM and HRRR solar radiation instant to backwards approximation ([#2240](https://github.com/open-meteo/open-meteo/issues/2240)) ([6922cb0](https://github.com/open-meteo/open-meteo/commit/6922cb0671bd9bf73a87d6472d8aac12be505b3e))
* metno use local files via curl.downloadNetCdf ([#2242](https://github.com/open-meteo/open-meteo/issues/2242)) ([8ccda52](https://github.com/open-meteo/open-meteo/commit/8ccda52e9c4e612c8ae521a749e17885aaaa0fcd))
* mfwave workaround for one of the files missing ([#2255](https://github.com/open-meteo/open-meteo/issues/2255)) ([ae5caa8](https://github.com/open-meteo/open-meteo/commit/ae5caa86c8b8b5e9c6d5f0b8b48f69dc36487bb4))
* **performance:** Use OmFileSystemManager directories to speed up chunk and yearly files discovery ([#2234](https://github.com/open-meteo/open-meteo/issues/2234)) ([7afe0fd](https://github.com/open-meteo/open-meteo/commit/7afe0fdbab87fe7948518a17346af9df907680b4))
* Prefetch can stop after the first valid prefetch ([#2232](https://github.com/open-meteo/open-meteo/issues/2232)) ([6d80d13](https://github.com/open-meteo/open-meteo/commit/6d80d13a1d4d37d0fc669701f9059812adf50509))
* reject api requests if over quota ([7e6d03e](https://github.com/open-meteo/open-meteo/commit/7e6d03ef249f8eb24b5b24fa04f5ee777c9e18cb))
* remove variable filtering in static/meta.json update ([#2241](https://github.com/open-meteo/open-meteo/issues/2241)) ([7a0724b](https://github.com/open-meteo/open-meteo/commit/7a0724bead7f7dffb601d7429f4a82f65932fd4f))
* report the requested value in the forecast_days range error ([#2228](https://github.com/open-meteo/open-meteo/issues/2228)) ([c817186](https://github.com/open-meteo/open-meteo/commit/c817186004a55a77d9134235c5bf6c09ac265ef8))
* reversed NAM wind components ([#2253](https://github.com/open-meteo/open-meteo/issues/2253)) ([e10b415](https://github.com/open-meteo/open-meteo/commit/e10b415a6f4a348bda75792733f1a3ee9c7cd413))
* update placeholder sdk values ([#2237](https://github.com/open-meteo/open-meteo/issues/2237)) ([5f11eaf](https://github.com/open-meteo/open-meteo/commit/5f11eafbf0e4917618870f562bd35f3a40fa240e))
* Update SDK for latest model identifier ([01ceed5](https://github.com/open-meteo/open-meteo/commit/01ceed5b028fb6ac19794c3310aed5a4f7aa6d4a))

## [1.7.0](https://github.com/open-meteo/open-meteo/compare/1.6.0...1.7.0) (2026-10-16)


### Features

* add environment variable to limit atomic block cache to pressure level files ([#2168](https://github.com/open-meteo/open-meteo/issues/2168)) ([f6e111e](https://github.com/open-meteo/open-meteo/commit/f6e111e5bad38910f36e86bc9abbe9f542a262a9))
* continued support for icon API domains ([#2176](https://github.com/open-meteo/open-meteo/issues/2176)) ([735f488](https://github.com/open-meteo/open-meteo/commit/735f488affdb3d8332df878ac7508d12bc51a42c))
* finish DMI migration ([#2150](https://github.com/open-meteo/open-meteo/issues/2150)) ([cc3f4e5](https://github.com/open-meteo/open-meteo/commit/cc3f4e5e956b39a56ab182faeccfd3d936ae6b4c))
* icon v1 url migration and EPS resolution switch ([#2160](https://github.com/open-meteo/open-meteo/issues/2160)) ([e758180](https://github.com/open-meteo/open-meteo/commit/e75818015239921b194b38ee147b2c1af639b15a))
* migrate cmc to generic structure ([#2147](https://github.com/open-meteo/open-meteo/issues/2147)) ([29c9a89](https://github.com/open-meteo/open-meteo/commit/29c9a892a3420e918d8cdc8975083130bb29ea4e))
* migrate ecmwf providers to generic structure ([#2149](https://github.com/open-meteo/open-meteo/issues/2149)) ([a0adc5a](https://github.com/open-meteo/open-meteo/commit/a0adc5a93aab2178aa598dc3b83f640473c862fc))
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
* Derive missing temperature extrema and align daily interval aggregations ([#2205](https://github.com/open-meteo/open-meteo/issues/2205)) ([4633aa1](https://github.com/open-meteo/open-meteo/commit/4633aa1250c8495539d7d988e1112281628339e5))
* DWD SIS downloader terminates too early ([001723f](https://github.com/open-meteo/open-meteo/commit/001723f21819cc51e46f94743ea355900c5705d9))
* ecmwf daily maximum/minimum temperatures ([#2202](https://github.com/open-meteo/open-meteo/issues/2202)) ([768e7a7](https://github.com/open-meteo/open-meteo/commit/768e7a74b0cd8eaa9712bcc9466d1d153c297dc8))
* ecmwf download support from azure ([#2198](https://github.com/open-meteo/open-meteo/issues/2198)) ([162976d](https://github.com/open-meteo/open-meteo/commit/162976d5ac174591d28425e417973d2308d6151b))
* icon convective snow lookups in downloader ([#2207](https://github.com/open-meteo/open-meteo/issues/2207)) ([b0ff3eb](https://github.com/open-meteo/open-meteo/commit/b0ff3ebbbafa890000ab8bc5f9598a2e4ef64dc4))
* **Meteofrance HD 15min:** 15min precipitation and snow is not available anymore ([#2120](https://github.com/open-meteo/open-meteo/issues/2120)) ([9701689](https://github.com/open-meteo/open-meteo/commit/9701689dd81ebef2d478800366c586c8a02c0c19))
* send acceptRanges in S3DataController ([#2175](https://github.com/open-meteo/open-meteo/issues/2175)) ([39a0b8c](https://github.com/open-meteo/open-meteo/commit/39a0b8c44b2ec2c86b26e89acaa2a7bb9340776f))
* separate icon model-level storage domains for native domains ([#2179](https://github.com/open-meteo/open-meteo/issues/2179)) ([082f1fb](https://github.com/open-meteo/open-meteo/commit/082f1fbcc182e2145df7e0cbd38981a146a27e64))
* static file uploading ([#2145](https://github.com/open-meteo/open-meteo/issues/2145)) ([690aa0b](https://github.com/open-meteo/open-meteo/commit/690aa0b321e4950a0dbf70a8cdf93ecd64044e47))
* static resource path for ensemble mean domains where missing ([#2212](https://github.com/open-meteo/open-meteo/issues/2212)) ([78f2209](https://github.com/open-meteo/open-meteo/commit/78f2209665998613bca32ae2709e1559bbd618eb))
* support bounding box requests for native grids ([#2169](https://github.com/open-meteo/open-meteo/issues/2169)) ([ad179c7](https://github.com/open-meteo/open-meteo/commit/ad179c7b39e443b579f391482c1aa41799aa9af0))
* sync exits non-zero when a model failed ([#2171](https://github.com/open-meteo/open-meteo/issues/2171)) ([f625df2](https://github.com/open-meteo/open-meteo/commit/f625df2c2b2d29d7837b1c71660fb226b1864f9b))
* syncing icon models synchronizes native icon models as well ([#2203](https://github.com/open-meteo/open-meteo/issues/2203)) ([b8793ea](https://github.com/open-meteo/open-meteo/commit/b8793ead9d38a7ddc3f5ff6a01440fde4c3b7b29))
* throw 404 on fileNotFound in S3DataController ([#2181](https://github.com/open-meteo/open-meteo/issues/2181)) ([290493f](https://github.com/open-meteo/open-meteo/commit/290493ffb9b5ee66fb1336219487a346eb27d191))
* Use actual step length to scale GEM accumulated variables ([#2180](https://github.com/open-meteo/open-meteo/issues/2180)) ([a5aac75](https://github.com/open-meteo/open-meteo/commit/a5aac75ca4aed1e1a97dd7e09564f0e06a8359f0))
* Use backwards averages for minTwo, maxTwo and sum cases ([#2204](https://github.com/open-meteo/open-meteo/issues/2204)) ([713bed5](https://github.com/open-meteo/open-meteo/commit/713bed562292d72d92bac6b0f6349359d286bcb5))

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
