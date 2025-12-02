//
//  InAppPurchase.swift
//  CLibStoreKitBridge
//
//  Created by Nigel on 2025/4/28.
//

import Foundation
import StoreKit

@_cdecl("native_purchase")
public func native_purchase(accountToken: UnsafePointer<CChar>, productId: UnsafePointer<CChar>) {
    let appAccountToken = String(cString: accountToken)
    let productIdStr = String(cString: productId)
    Task {
        let result = await syncPurchase(appAccountToken: appAccountToken, productId: productIdStr)
        DispatchQueue.main.async {
            StoreManager.shared.send(event: "PURCHASE", data: result.data, error: result.error)
        }
    }
}

// MARK: - 用 continuation 进行 async → sync 转换
func syncPurchase(appAccountToken: String, productId: String) async -> CallbackData {
    return await withCheckedContinuation { continuation in
        Task {
            let result = await asyncPurchase(appAccountToken: appAccountToken, productId: productId)
            continuation.resume(returning: result)
        }
    }
}


// MARK: - 真正执行异步 IAP 的函数
func asyncPurchase(appAccountToken: String, productId: String) async -> CallbackData {
    var callback = CallbackData(event: "PURCHASE", data: #"{"productId":"\#(productId)"}"#, error: nil)
    do {
        // 1. 权限检查
        guard AppStore.canMakePayments else {
            callback.error = "In-app purchases are disabled"
            return callback
        }
        
        // 2. 拉取商品
        let products = try await Product.products(for: [productId])
        guard let product = products.first else {
            callback.error = "Product not found"
            return callback
        }
        
        // 3. 检查 UUID
        guard let uuid = UUID(uuidString: appAccountToken) else {
            callback.error = "Invalid UUID"
            return callback
        }
        
        let options: Set<Product.PurchaseOption> = [.appAccountToken(uuid)]
        
        // 4. 购买
        let purchaseResult = try await product.purchase(options: options)
        
        switch purchaseResult {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                let receiptData = await loadOrRefreshReceipt()
                let receiptString = receiptData?.base64EncodedString() ?? ""
                
                let resultJson = """
                {
                    "status": "success",
                    "receipt-data": "\(receiptString)",
                    "transaction-id": "\(transaction.id)",
                    "productId": "\(productId)"
                }
                """
                await transaction.finish()
                callback.data = resultJson
                
            case .unverified(_, let error):
                callback.error = "Verification failed: \(error.localizedDescription)"
                
            @unknown default:
                callback.error = "Verification failed"
            }
            
        case .userCancelled:
            callback.error = "User cancelled"
            
        case .pending:
            callback.error = "Pending approval"
            
        @unknown default:
            callback.error = "Unknown purchase result"
        }
        
    } catch {
        callback.error = "Error: \(error.localizedDescription)"
    }
    
    return callback
}


// MARK: - 收据加载与刷新
func loadOrRefreshReceipt() async -> Data? {
    if let receiptURL = Bundle.main.appStoreReceiptURL,
       let receiptData = try? Data(contentsOf: receiptURL),
       receiptData.count > 0 {
        return receiptData
    }
    
    do {
        try await refreshReceipt()
        if let refreshed = try? Data(contentsOf: Bundle.main.appStoreReceiptURL!) {
            return refreshed
        }
    } catch {
        print("Failed to refresh receipt: \(error.localizedDescription)")
    }
    
    return nil
}

func refreshReceipt() async throws {
    return try await withCheckedThrowingContinuation { continuation in
        let request = SKReceiptRefreshRequest()
        let delegate = ReceiptRefreshDelegate(continuation: continuation)
        request.delegate = delegate
        request.start()
    }
}

class ReceiptRefreshDelegate: NSObject, SKRequestDelegate {
    let continuation: CheckedContinuation<Void, Error>
    
    init(continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
    }
    
    func requestDidFinish(_ request: SKRequest) {
        continuation.resume()
    }
    
    func request(_ request: SKRequest, didFailWithError error: Error) {
        continuation.resume(throwing: error)
    }
}
