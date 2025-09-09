//
//  HTTPMethodTest.swift
//  Hume
//
//  Created by Chris on 9/9/25.
//

import Testing

@testable import Hume

struct HTTPMethodTest {

  @Test func testRawVAlues() async throws {
    for method in HTTPMethod.allCases {
      switch method {
      case .get:
        #expect(method.rawValue == "GET")
      case .post:
        #expect(method.rawValue == "POST")
      case .put:
        #expect(method.rawValue == "PUT")
      case .patch:
        #expect(method.rawValue == "PATCH")
      case .delete:
        #expect(method.rawValue == "DELETE")
      }
    }
  }

}
