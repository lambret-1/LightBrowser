import Foundation
import CommonCrypto

// MARK: - 腾讯云翻译 API 封装
class TencentTranslateManager {
    static let shared = TencentTranslateManager()
    
    // 腾讯云密钥
    private let secretId = "AKIDGn7E7uVu78ykSzOj6JJ6fmgNtDLGxRjn"
    private let secretKey = "vcGixzc2FE0axBC2xkQxIROAjBRfhW9b"
    
    // API 配置
    private let service = "tmt"
    private let host = "tmt.tencentcloudapi.com"
    private let version = "2018-03-21"
    private let action = "TextTranslate"
    
    private init() {}
    
    // MARK: - TC3-HMAC-SHA256 签名
    private func hmacSHA256(data: Data, key: Data) -> Data {
        var result = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { dataPtr in
            key.withUnsafeBytes { keyPtr in
                CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256), keyPtr.baseAddress, key.count, dataPtr.baseAddress, data.count, result.withUnsafeMutableBytes { $0.baseAddress })
            }
        }
        return result
    }
    
    private func sha256Hex(_ data: Data) -> String {
        var hash = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { ptr in
            _ = CC_SHA256(ptr.baseAddress, CC_LONG(data.count), hash.withUnsafeMutableBytes { $0.baseAddress })
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    private func sha256Hex(_ string: String) -> String {
        guard let data = string.data(using: .utf8) else { return "" }
        return sha256Hex(data)
    }
    
    /// 翻译文本
    /// - Parameters:
    ///   - text: 待翻译文本
    ///   - source: 源语言（默认 auto 自动检测）
    ///   - target: 目标语言（默认 zh 中文）
    ///   - completion: 翻译结果回调
    func translate(_ text: String,
                   source: String = "auto",
                   target: String = "zh",
                   completion: @escaping (String?, Error?) -> Void) {
        let timestamp = Int(Date().timeIntervalSince1970)
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let date = dateFormatter.string(from: Date())
        
        // 1. 构建请求参数
        let payload: [String: Any] = [
            "SourceText": text,
            "Source": source,
            "Target": target,
            "ProjectId": 0
        ]
        guard let payloadData = try? JSONSerialization.data(withJSONObject: payload),
              let payloadString = String(data: payloadData, encoding: .utf8) else {
            completion(nil, NSError(domain: "TencentTranslate", code: -1, userInfo: [NSLocalizedDescriptionKey: "参数序列化失败"]))
            return
        }
        
        // 2. 拼接规范请求串
        let httpRequestMethod = "POST"
        let canonicalURI = "/"
        let canonicalQueryString = ""
        let canonicalHeaders = "content-type:application/json; charset=utf-8\nhost:\(host)\nx-tc-action:\(action.lowercased())\n"
        let signedHeaders = "content-type;host;x-tc-action"
        let hashedRequestPayload = sha256Hex(payloadData)
        let canonicalRequest = "\(httpRequestMethod)\n\(canonicalURI)\n\(canonicalQueryString)\n\(canonicalHeaders)\n\(signedHeaders)\n\(hashedRequestPayload)"
        
        // 3. 拼接待签名字符串
        let algorithm = "TC3-HMAC-SHA256"
        let credentialScope = "\(date)/\(service)/tc3_request"
        let hashedCanonicalRequest = sha256Hex(canonicalRequest)
        let stringToSign = "\(algorithm)\n\(timestamp)\n\(credentialScope)\n\(hashedCanonicalRequest)"
        
        // 4. 计算签名
        guard let secretDateData = hmacSHA256(data: date.data(using: .utf8)!, key: ("TC3" + secretKey).data(using: .utf8)!) as Data?,
              let secretServiceData = hmacSHA256(data: service.data(using: .utf8)!, key: secretDateData) as Data?,
              let secretSigningData = hmacSHA256(data: "tc3_request".data(using: .utf8)!, key: secretServiceData) as Data?,
              let signatureData = hmacSHA256(data: stringToSign.data(using: .utf8)!, key: secretSigningData) as Data? else {
            completion(nil, NSError(domain: "TencentTranslate", code: -2, userInfo: [NSLocalizedDescriptionKey: "签名计算失败"]))
            return
        }
        let signature = signatureData.map { String(format: "%02x", $0) }.joined()
        
        // 5. 拼接 Authorization
        let authorization = "TC3-HMAC-SHA256 Credential=\(secretId)/\(credentialScope), SignedHeaders=\(signedHeaders), Signature=\(signature)"
        
        // 6. 发送请求
        guard let url = URL(string: "https://\(host)/") else {
            completion(nil, NSError(domain: "TencentTranslate", code: -3, userInfo: [NSLocalizedDescriptionKey: "URL构建失败"]))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue(host, forHTTPHeaderField: "Host")
        request.setValue(action, forHTTPHeaderField: "X-TC-Action")
        request.setValue(version, forHTTPHeaderField: "X-TC-Version")
        request.setValue("\(timestamp)", forHTTPHeaderField: "X-TC-Timestamp")
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        request.httpBody = payloadData
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(nil, error) }
                return
            }
            guard let data = data,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                DispatchQueue.main.async { completion(nil, NSError(domain: "TencentTranslate", code: -4, userInfo: [NSLocalizedDescriptionKey: "网络请求失败"])) }
                return
            }
            
            // 7. 解析响应
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let responseData = json["Response"] as? [String: Any] {
                    if let targetText = responseData["TargetText"] as? String {
                        DispatchQueue.main.async { completion(targetText, nil) }
                    } else if let error = responseData["Error"] as? [String: Any],
                              let message = error["Message"] as? String {
                        DispatchQueue.main.async { completion(nil, NSError(domain: "TencentTranslate", code: -5, userInfo: [NSLocalizedDescriptionKey: message])) }
                    } else {
                        DispatchQueue.main.async { completion(nil, NSError(domain: "TencentTranslate", code: -6, userInfo: [NSLocalizedDescriptionKey: "响应解析失败"])) }
                    }
                } else {
                    DispatchQueue.main.async { completion(nil, NSError(domain: "TencentTranslate", code: -7, userInfo: [NSLocalizedDescriptionKey: "响应格式错误"])) }
                }
            } catch {
                DispatchQueue.main.async { completion(nil, error) }
            }
        }.resume()
    }
}
