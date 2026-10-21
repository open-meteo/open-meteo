import Testing
@testable import App

@Suite struct DwdSisDownloaderTests {
    @Test func includesPreviousExistingRunBeforeGap() {
        let previous = Timestamp(2026, 9, 4, 10, 0)
        let next = previous.add(30 * 60)
        #expect(DwdSisDownloader.runsToDownload(availableRuns: [previous, next], lastDownloadedTimeStep: previous, dtSeconds: 600) == [previous, next])
        // The checkpoint itself might no longer be present in both listings.
        #expect(DwdSisDownloader.runsToDownload(availableRuns: [previous, next], lastDownloadedTimeStep: previous.add(600), dtSeconds: 600) == [previous, next])
    }

    @Test func doesNotRedownloadPreviousRunWithoutGap() {
        let previous = Timestamp(2026, 9, 4, 10, 0)
        let next = previous.add(600)
        #expect(DwdSisDownloader.runsToDownload(availableRuns: [previous, next], lastDownloadedTimeStep: previous, dtSeconds: 600) == [next])
    }

    @Test func keepsPrecedingRunForGapsWithinNewBatch() {
        let previous = Timestamp(2026, 9, 4, 10, 0)
        let first = previous.add(600)
        let next = previous.add(30 * 60)
        #expect(DwdSisDownloader.runsToDownload(availableRuns: [previous, first, next], lastDownloadedTimeStep: previous, dtSeconds: 600) == [first, next])
    }

    @Test func handlesInitialDownloadAndMissingHistory() {
        let first = Timestamp(2026, 9, 4, 10, 0)
        let next = first.add(30 * 60)
        #expect(DwdSisDownloader.runsToDownload(availableRuns: [first, next], lastDownloadedTimeStep: nil, dtSeconds: 600) == [first, next])
        #expect(DwdSisDownloader.runsToDownload(availableRuns: [next], lastDownloadedTimeStep: first, dtSeconds: 600) == [next])
    }

    @Test func skipsWhenNoNewRunsExist() {
        let last = Timestamp(2026, 9, 4, 10, 0)
        #expect(DwdSisDownloader.runsToDownload(availableRuns: [last], lastDownloadedTimeStep: last, dtSeconds: 600).isEmpty)
        #expect(DwdSisDownloader.runsToDownload(availableRuns: [], lastDownloadedTimeStep: nil, dtSeconds: 600).isEmpty)
    }

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
