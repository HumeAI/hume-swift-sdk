//
//  NetworkErrorTest.swift
//  Hume
//
//  Created by AI on 9/9/25.
//

import Foundation
import Testing

@testable import Hume

struct NetworkErrorTest {

  @Test func error_descriptions_are_human_readable() async throws {
    // Map each case to an expected description substring
    let samples: [(NetworkError, String)] = [
      (.authenticationError, "authentication credentials were invalid"),
      (.unauthorized, "unauthorized"),
      (.forbidden, "forbidden"),
      (.invalidRequest, "could not be created"),
      (.invalidResponse, "invalid response"),
      (.errorResponse(code: 418, message: "teapot"), "Error 418: teapot"),
      (.noData, "No data"),
      (.requestDecodingFailed, "decode the request"),
      (.responseDecodingFailed, "decode the response"),
      (.unknownMessageType, "unknown message type"),
      (.unknown, "unknown error"),
    ]

    for (err, expectedSubstring) in samples {
      let desc = try #require(err.errorDescription)
      #expect(desc.localizedCaseInsensitiveContains(expectedSubstring))
    }
  }
}
