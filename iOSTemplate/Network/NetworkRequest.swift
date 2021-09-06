//
//  NetworkRequest.swift
//  iOSTemplate
//
//  Created by Trung Hoang on 04/09/2021.
//

import Foundation

public protocol NetworkRequest {
    var path: String { get }
    var method: HttpMethod { get }
    var queries: [String: String]? { get }
    var body: [String: Any]? { get }
    var headers: [String: String]  { get }
    var config: NetworkConfig { get }
}

public extension NetworkRequest {
    var body: [String: Any]? { return nil }
    
    var queries: [String: String]? {return nil }
}

public protocol NetworkUploadRequest: NetworkRequest {
    var data: Data { get }
}

public extension NetworkUploadRequest {
    var method: HttpMethod {
        return .POST
    }
}

public protocol NetworkMultipartRequest: NetworkRequest {
    var boundary: String { get }
    var textFields: [MultipartTextField] { get }
    var dataField: MultipartDataField { get }
}

public extension NetworkMultipartRequest {
    var method: HttpMethod {
        return .POST
    }
    
    var boundary: String {
        return UUID().uuidString
    }
    
    var httpBody: Data {
        let httpBodyData = NSMutableData()
        
        textFields.compactMap { $0.toDataField(boundary: boundary) }.forEach { data in
            httpBodyData.append(data)
        }
        
        httpBodyData.append(dataField.toDataField(boundary: boundary))
        
        httpBodyData.append("--\(boundary)--")
        
        return httpBodyData as Data
    }
}

public struct MultipartTextField {
    let name: String
    let value: String
    
    func toDataField(boundary: String) -> Data? {
        var fieldString = "--\(boundary)\r\n"
        fieldString += "Content-Disposition: form-data; name=\"\(name)\"\r\n"
        fieldString += "Content-Type: text/plain; charset=ISO-8859-1\r\n"
        fieldString += "Content-Transfer-Encoding: 8bit\r\n"
        fieldString += "\r\n"
        fieldString += "\(value)\r\n"
        
        return fieldString.data(using: .utf8)
    }
}

public struct MultipartDataField {
    let name: String
    let data: Data
    let mimeType: String
    
    func toDataField(boundary: String) -> Data {
        let fieldData = NSMutableData()
        
        fieldData.append("--\(boundary)\r\n")
        fieldData.append("Content-Disposition: form-data; name=\"\(name)\"\r\n")
        fieldData.append("Content-Type: \(mimeType)\r\n")
        fieldData.append("\r\n")
        fieldData.append(data)
        fieldData.append("\r\n")
        
        return fieldData as Data
    }
}

extension NSMutableData {
    func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            self.append(data)
        }
    }
}
