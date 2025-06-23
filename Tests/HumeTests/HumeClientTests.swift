import XCTest
@testable import Hume

final class HumeClientTests: XCTestCase {
    
    var client: HumeClient!
    
    override func setUp() {
        self.client = HumeClient(options: .accessToken(token: "test_token"))
    }
    
    
    func test_empathicVoice_returnsLazily() throws {
        let voice1 = self.client.empathicVoice
        let voice2 = self.client.empathicVoice
        
        XCTAssertTrue(voice1 === voice2)
    }
}
