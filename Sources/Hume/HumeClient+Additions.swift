//
//  HumeClient+Additions.swift
//  Hume
//
//  Created by Chris on 8/22/25.
//

import Foundation

#if !HUME_SERVER
  public extension HumeClient {
    static var isRunningOnServer: Bool {
      false
    }
  }
#endif
