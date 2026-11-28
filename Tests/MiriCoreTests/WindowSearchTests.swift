import Foundation
import Testing

@testable import MiriCore

struct WindowSearchTests {
    @Test func findsParkedWindowsByTitleAndAppWithoutRepeatingAWindow() throws {
        let json = """
            {"virtual_workspaces":[{"windows":[
              {"window_id":1,"bundle_id":"org.example.edit","app_name":"Editor","title":"Release Notes","focused":false,"floating":false,"column":2},
              {"window_id":2,"bundle_id":"org.example.term","app_name":"Terminal","title":"Release build","focused":true,"floating":false,"column":0},
              {"window_id":3,"bundle_id":"org.example.miri","app_name":"Miri","title":"Settings","focused":false,"floating":true},
              {"window_id":1,"bundle_id":"org.example.edit","app_name":"Editor","title":"Release Notes","focused":false,"floating":false,"column":2}
            ]}]}
            """
        let search = try WindowSearch(json: Data(json.utf8), excludingBundle: "org.example.miri")
        #expect(search.matching("").map(\.id) == [2, 1])
        #expect(search.matching("rln").first?.id == 1)
        #expect(search.matching("edit notes").map(\.id) == [1])
        #expect(search.matching("terminal").first?.id == 2)
        #expect(search.matching("zzzz").isEmpty)
    }
}
