import Foundation
import KeychainSwift
import Models
import SwiftUI

@MainActor
public enum DeepLUserAPIHandler {
  private static let key = "DeepL"
  private static let fallbackDefaultsKey = "deepl_user_api_key_fallback"

  private static var keychain: KeychainSwift {
    let keychain = KeychainSwift()
    #if !DEBUG && !targetEnvironment(simulator)
      keychain.accessGroup = AppInfo.keychainGroup
    #endif
    return keychain
  }

  private static var localKeychain: KeychainSwift {
    KeychainSwift()
  }

  public static func write(value: String) {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let kc = keychain
    kc.synchronizable = true
    let localKc = localKeychain
    if !trimmed.isEmpty {
      kc.set(trimmed, forKey: key)
      localKc.set(trimmed, forKey: key)
      UserPreferences.sharedDefault?.set(trimmed, forKey: fallbackDefaultsKey)
    } else {
      kc.delete(key)
      localKc.delete(key)
      UserPreferences.sharedDefault?.removeObject(forKey: fallbackDefaultsKey)
    }
  }

  public static func readKeyIfAllowed() -> String? {
    guard UserPreferences.shared.preferredTranslationType == .useDeepl else { return nil }

    return readKeyInternal()
  }

  public static func readKey() -> String {
    return readKeyInternal() ?? ""
  }

  private static func readKeyInternal() -> String? {
    let kc = keychain
    kc.synchronizable = true
    if let val = kc.get(key)?.trimmingCharacters(in: .whitespacesAndNewlines), !val.isEmpty {
      return val
    }
    if let localVal = localKeychain.get(key)?.trimmingCharacters(in: .whitespacesAndNewlines), !localVal.isEmpty {
      return localVal
    }
    if let fallbackVal = UserPreferences.sharedDefault?.string(forKey: fallbackDefaultsKey)?.trimmingCharacters(in: .whitespacesAndNewlines), !fallbackVal.isEmpty {
      return fallbackVal
    }
    return nil
  }

  public static func deactivateToggleIfNoKey() {
    if UserPreferences.shared.preferredTranslationType == .useDeepl {
      if readKeyInternal() == nil {
        UserPreferences.shared.preferredTranslationType = .useServerIfPossible
      }
    }
  }

  public static var shouldAlwaysUseDeepl: Bool {
    readKeyIfAllowed() != nil
  }
}
