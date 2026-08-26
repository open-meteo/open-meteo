import Foundation
@testable import App
import Testing

@Suite struct MigrationTests {
    private func supplementalGridpointPolicy(for domain: MultiDomains) -> MultiDomains.SupplementalGridpointPolicy? {
        guard let mapping = domain.getDomainAndVariable(),
              case .singleWithSupplementalDomains(_, _, _, _, _, let policy) = mapping
        else {
            return nil
        }
        return policy
    }

    @Test func marineReaderMappings() {
        let singleDomainModels: [MultiDomains] = [
            .ecmwf_wam,
            .ewam,
            .dwd_ewam,
            .gwam,
            .dwd_gwam,
            .era5_ocean,
            .ecmwf_wam025,
            .ecmwf_wam025_ensemble,
            .meteofrance_wave,
            .ncep_gfswave025,
            .ncep_gfswave016,
            .ncep_gefswave025,
        ]
        for model in singleDomainModels {
            guard let mapping = model.getDomainAndVariable(), case .single = mapping else {
                Issue.record("Expected a single-domain mapping for \(model.rawValue)")
                continue
            }
        }

        #expect(supplementalGridpointPolicy(for: .meteofrance_currents) == .alignedSupplemental)
        #expect(supplementalGridpointPolicy(for: .jma_msm) == .primaryOnly)
        #expect(supplementalGridpointPolicy(for: .icon_d2) == .primaryOnly)
    }

    @Test func marineBestMatchFreshnessFallback() {
        let now = Timestamp(2026, 8, 26, 12)
        #expect(!MultiDomains.marineBestMatchUsesEcmwfFallback(lastRunAvailabilityTime: nil, now: now))
        #expect(!MultiDomains.marineBestMatchUsesEcmwfFallback(lastRunAvailabilityTime: now.subtract(hours: 25), now: now))
        #expect(MultiDomains.marineBestMatchUsesEcmwfFallback(lastRunAvailabilityTime: now.subtract(hours: 26), now: now))
        #expect(MultiDomains.marineBestMatchUsesEcmwfFallback(lastRunAvailabilityTime: now.subtract(hours: 27), now: now))
    }

    @Test func xml() {
        let str = "<Contents><Key>enkfgdas.20210212/00/mem001/gdas.t00z.sfcf003.nemsio</Key></Contents><Contents><Key>enkfgdas.20210212/00/mem001/gdas.t00z.sfcf006.nemsio</Key></Contents>"
        let contents = Array(str.xmlSection("Contents"))
        #expect(contents.count == 2)
        #expect(contents[0] == "<Key>enkfgdas.20210212/00/mem001/gdas.t00z.sfcf003.nemsio</Key>")
        #expect(contents[1] == "<Key>enkfgdas.20210212/00/mem001/gdas.t00z.sfcf006.nemsio</Key>")

        #expect(contents[0].xmlFirst("Key") == "enkfgdas.20210212/00/mem001/gdas.t00z.sfcf003.nemsio")
        #expect(contents[1].xmlFirst("Key") == "enkfgdas.20210212/00/mem001/gdas.t00z.sfcf006.nemsio")
    }
}
