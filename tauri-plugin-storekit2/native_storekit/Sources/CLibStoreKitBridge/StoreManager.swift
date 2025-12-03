import StoreKit
import os

public typealias IapCallback = @convention(c) @Sendable (UnsafePointer<CChar>) -> Void

struct CallbackData: Codable {
    var event: String
    var data: String?
    var error: String?
}

@_cdecl("native_register_iap_callback")
public func native_register_iap_callback(callback: IapCallback) {
    DispatchQueue.main.async {
        StoreManager.shared.updateCallback(callback: callback);
    }
}

@_cdecl("native_restore_purchase")
public func native_restore_purchase() {
    Task {
        await StoreManager.shared.restorePurchases()
    }
}

@MainActor
class StoreManager: NSObject {
    static let shared = StoreManager()
    private var globalCallback: IapCallback?

    private override init() {
        super.init()
    }

    func updateCallback(callback: IapCallback) {
        globalCallback = callback
    }

    // MARK: - Restore Purchase
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            // result 无法直接获取 restored IDs，只能依赖 transaction listener 或读取收据
            
            if let receipt = loadReceipt()?.base64EncodedString() {
                send(event: "LOAD_RECEIPT", data: receipt, error: nil)
            } else {
                send(event: "LOAD_RECEIPT", data: nil, error: "Receipt not found")
            }

        } catch {
            send(event: "LOAD_RECEIPT", data: nil, error: error.localizedDescription)
        }
    }

    // MARK: - Transaction Handler
    func handleTransaction(_ transaction: Transaction) async {
        let productId = transaction.productID
        let transactionId = transaction.appTransactionID;
        let json = """
        {
            "productId": "\(productId)",
            "appAccountToken": "\(transaction.appAccountToken?.uuidString ?? "")",
            "transactionId": "\(transactionId)"
        }
        """
        send(event: "UNLOCK_PRODUCT", data: json, error: nil)

        await transaction.finish()
    }

    // MARK: - Receipt
    func loadReceipt() -> Data? {
        guard let url = Bundle.main.appStoreReceiptURL else { return nil }
        return try? Data(contentsOf: url)
    }

    // MARK: - Callback helper
    func send(event: String, data: String?, error: String?) {
        guard let callback = globalCallback else { return }
        let payload = CallbackData(event: event, data: data, error: error)

        do {
            let jsonData = try JSONEncoder().encode(payload)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                let cString = strdup(jsonString)
                callback(cString!)
                free(UnsafeMutablePointer(mutating: cString))
            }
        } catch {
            print("JSON encode error:", error.localizedDescription)
        }
    }
}
