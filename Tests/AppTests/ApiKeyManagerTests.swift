import Foundation
@testable import App
import Testing
import Vapor

@Suite struct ApiKeyManagerTests {
    @Test func quotaThreshold() throws {
        for usage in [1499.0, 1499.99] {
            let key = ApiKeyManager.KeyAndLimit(key: "key", limit: 100, id: nil, usageLast30Days: usage)
            try key.checkQuota(quotaMultiplier: 15)
        }
        for usage in [1500.0, 1501, 2000] {
            let key = ApiKeyManager.KeyAndLimit(key: "key", limit: 100, id: nil, usageLast30Days: usage)
            #expect(throws: ApiKeyManagerError.apiKeyOverQuota) {
                try key.checkQuota(quotaMultiplier: 15)
            }
        }
        #expect(ApiKeyManagerError.apiKeyOverQuota.status == .forbidden)
        #expect(ApiKeyManagerError.apiKeyOverQuota.reason == "Your API key is over quota.")
    }

    @Test func quotaBlockingIsOptional() throws {
        let key = ApiKeyManager.KeyAndLimit(key: "key", limit: 100, id: nil, usageLast30Days: 2000)
        for multiplier: Double? in [nil, 0, -1, .nan, .infinity] {
            try key.checkQuota(quotaMultiplier: multiplier)
        }
        for usage: Double in [0, -1, .nan, .infinity] {
            let key = ApiKeyManager.KeyAndLimit(key: "key", limit: 100, id: nil, usageLast30Days: usage)
            try key.checkQuota(quotaMultiplier: 15)
        }
        let unlimited = ApiKeyManager.KeyAndLimit(key: "key", limit: 0, id: nil, usageLast30Days: 2000)
        try unlimited.checkQuota(quotaMultiplier: 15)
    }

    @Test func forgivingCsvParsing() {
        let keys = ApiKeyManager.KeyAndLimit.parseApiKeys(" legacy , old;100;customer, new;100;customer;115.5, empty;100;;120, missing;100;customer;, invalid;100;customer;unknown, ;;;, , whitespace; 100 ; customer ; 120 \n")
        #expect(keys.count == 7)
        #expect(keys.first(where: { $0.key == "legacy" })?.limit == 0)
        #expect(keys.first(where: { $0.key == "old" })?.usageLast30Days == 0)
        #expect(keys.first(where: { $0.key == "new" })?.usageLast30Days == 115.5)
        #expect(keys.first(where: { $0.key == "empty" })?.id == nil)
        #expect(keys.first(where: { $0.key == "empty" })?.usageLast30Days == 120)
        #expect(keys.first(where: { $0.key == "missing" })?.usageLast30Days == 0)
        #expect(keys.first(where: { $0.key == "invalid" })?.usageLast30Days == 0)
        #expect(keys.first(where: { $0.key == "whitespace" })?.limit == 100)
        #expect(keys.first(where: { $0.key == "whitespace" })?.id == "customer")
        #expect(keys.first(where: { $0.key == "whitespace" })?.usageLast30Days == 120)
        #expect(ApiKeyManager.KeyAndLimit.parseApiKeys(";;;,, \n").isEmpty)
    }
}
