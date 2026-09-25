import Foundation
#if canImport(Security)
import Security
#endif

public final class KeychainStore: @unchecked Sendable {
    public static let shared = KeychainStore()
    private let service = "com.efootballassistant.secrets"
    private let account = "groq-api-key"
    private init() {}
    public func readGroqKey() -> String? {
        #if canImport(Security)
        let query:[String:Any] = [kSecClass as String:kSecClassGenericPassword, kSecAttrService as String:service, kSecAttrAccount as String:account, kSecReturnData as String:true, kSecMatchLimit as String:kSecMatchLimitOne]
        var result:CFTypeRef?; guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data=result as? Data else{return nil}; return String(data:data,encoding:.utf8)
        #else
        return nil
        #endif
    }
    @discardableResult public func saveGroqKey(_ key:String) -> Bool {
        #if canImport(Security)
        let data=Data(key.utf8); let query:[String:Any] = [kSecClass as String:kSecClassGenericPassword, kSecAttrService as String:service, kSecAttrAccount as String:account]
        let update:[String:Any] = [kSecValueData as String:data, kSecAttrAccessible as String:kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        if SecItemUpdate(query as CFDictionary, update as CFDictionary) == errSecSuccess { return true }
        var add=query; add[kSecValueData as String]=data; add[kSecAttrAccessible as String]=kSecAttrAccessibleWhenUnlockedThisDeviceOnly; return SecItemAdd(add as CFDictionary,nil) == errSecSuccess
        #else
        return false
        #endif
    }
    @discardableResult public func deleteGroqKey() -> Bool {
        #if canImport(Security)
        let query:[String:Any] = [kSecClass as String:kSecClassGenericPassword, kSecAttrService as String:service, kSecAttrAccount as String:account]; return SecItemDelete(query as CFDictionary) == errSecSuccess
        #else
        return false
        #endif
    }
}
