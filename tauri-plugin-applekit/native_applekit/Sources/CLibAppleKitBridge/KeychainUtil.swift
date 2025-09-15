import Foundation
import Security

@_cdecl("save_keychain")
public func save_keychain(keyPtr: UnsafePointer<CChar>, valuePtr: UnsafePointer<CChar>) -> Int32 {
    let key = String(cString: keyPtr)
    let value = String(cString: valuePtr)

    let data = value.data(using: .utf8)!

    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: key,
        kSecValueData as String: data
    ]

    SecItemDelete(query as CFDictionary)
    let status = SecItemAdd(query as CFDictionary, nil)

    return Int32(status)
}

@_cdecl("load_keychain")
public func load_keychain(keyPtr: UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>? {
    let key = String(cString: keyPtr)

    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: key,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne
    ]

    var dataTypeRef: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

    if status == errSecSuccess, let data = dataTypeRef as? Data,
       let value = String(data: data, encoding: .utf8) {
        return strdup(value)
    }
    return nil
}
