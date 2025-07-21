import XCTest
@testable import Hume

final class DeserializationTests: XCTestCase {
    
    var client: HumeClient!
    
    override func setUp() {
    }
    
    func test_returnchat_page_parses() throws {
        let json = """
          {
            "pagination_direction" : "ASC",
            "page_number" : 0,
            "total_pages" : 156,
            "chats_page" : [
              {
                "status" : "USER_ENDED",
                "config" : null,
                "id" : "5be9799e-ae7f-4688-889d-ab53a2f2efb4",
                "chat_group_id" : "009939ed-1c61-4719-a689-11695314d08d",
                "end_timestamp" : 1726581654746,
                "tag" : null,
                "event_count" : 1,
                "start_timestamp" : 1726581632521,
                "metadata" : null
              },
              {
                "status" : "USER_ENDED",
                "config" : null,
                "id" : "c4f5f7f1-0704-4be4-9b7e-bc7343757c34",
                "chat_group_id" : "009939ed-1c61-4719-a689-11695314d08d",
                "end_timestamp" : 1726581682131,
                "tag" : null,
                "event_count" : 0,
                "start_timestamp" : 1726581660124,
                "metadata" : null
              },
            ],
            "page_size" : 2
          }
        """
        let decoded: ReturnPagedChats = try! Defaults.decoder.decode(ReturnPagedChats.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(decoded.chatsPage[0].id, "5be9799e-ae7f-4688-889d-ab53a2f2efb4")
    }
}
