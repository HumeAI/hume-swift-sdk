//
//  SubscribeEventTest.swift
//
//
//  Created by Daniel Rees on 5/22/24.
//

import XCTest
@testable import Hume

final class SubscribeEventTest: XCTestCase {
    
    let decoder = Defaults.decoder
    
    
    func test_decodesUserMessage() throws {
        let json = """
        {
           "type": "user_message",
           "message": {
              "role": "user",
              "content": "Hello, what are you up to today?"
           },
           "models": {},
           "time": {
              "begin": 278,
              "end": 278
           },
           "from_text": true,
           "interim": false
        }
        """
        
        let message = try! decoder.decode(SubscribeEvent.self, from: json.data(using: .utf8)!)
        XCTAssertNotNil(message)
    }
    
}
