
import Foundation

public class EmpathicVoiceClient {
  //  private let networkClient: NetworkClient
  private let options: HumeClient.Options

  init(networkClient: NetworkClient, options: HumeClient.Options) {
    // self.networkClient = networkClient
    self.options = options
  }

  public lazy var chat: Chat = { Chat(options: options) }()

  // public lazy var configs: Configs = { Configs(networkClient: networkClient) }()
}
