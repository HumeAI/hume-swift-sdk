import Foundation

public class EmpathicVoiceClient {
  //  private let networkClient: NetworkClient
  private let auth: HumeAuth

  init(networkClient: NetworkClient, auth: HumeAuth) {
    // self.networkClient = networkClient
    self.auth = auth
  }

  public lazy var chat: Chat = { Chat(auth: auth) }()

  // public lazy var configs: Configs = { Configs(networkClient: networkClient) }()
}
