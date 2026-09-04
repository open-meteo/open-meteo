import Testing
@testable import App

@Suite struct DwdSisDownloaderTests {
    @Test func parsesOnlyCompressedEaV4Files() {
        let html = """
        <a href="SISin202609041030EAv4.nc.bz2">SISin202609041030EAv4.nc.bz2</a>
        <a href="SISin202609041040EAv4.nc">SISin202609041040EAv4.nc</a>
        <a href="SISin202609041050EUv4.nc.bz2">SISin202609041050EUv4.nc.bz2</a>
        <a href="SISin202609041100EAv4.nc.bz2">SISin202609041100EAv4.nc.bz2</a>
        """

        #expect(DwdSisDownloader.availableRuns(in: html, filePrefix: "SISin") == [
            Timestamp(2026, 9, 4, 10, 30),
            Timestamp(2026, 9, 4, 11, 0)
        ])
    }

    @Test func selectsOnlyRunsAvailableForBothProducts() {
        let sis = DwdSisDownloader.availableRuns(in: "SISin202609041030EAv4.nc.bz2 SISin202609041040EAv4.nc.bz2", filePrefix: "SISin")
        let sid = DwdSisDownloader.availableRuns(in: "SIDin202609041030EAv4.nc.bz2", filePrefix: "SIDin")

        #expect(sis.intersection(sid) == [Timestamp(2026, 9, 4, 10, 30)])
    }
}
