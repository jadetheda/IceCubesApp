import Foundation
import SwiftUI

public struct AppAccount: Codable, Identifiable, Hashable {
  public let server: String
  public var accountName: String?
  public let oauthToken: OauthToken?
  public var isIceShrimp: Bool?
  public var serverSoftware: String?

  public var key: String {
    if let oauthToken {
      "\(server):\(oauthToken.createdAt)"
    } else {
      "\(server):anonymous"
    }
  }

  public var id: String {
    key
  }

  public init(
    server: String,
    accountName: String?,
    oauthToken: OauthToken? = nil,
    isIceShrimp: Bool? = nil,
    serverSoftware: String? = nil
  ) {
    self.server = server
    self.accountName = accountName
    self.oauthToken = oauthToken
    self.isIceShrimp = isIceShrimp
    self.serverSoftware = serverSoftware
  }
}

extension AppAccount: Sendable {}
