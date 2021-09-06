//
//  APIError.swift
//  iOSTemplate
//
//  Created by Trung Hoang on 04/09/2021.
//

import Foundation

public enum NetworkError: Error {
    case unkownError(description: String)
    case serverError(code: Int, message: String)
    case decodeError
}

public enum HttpMethod: String {
    case POST
    case GET
    case PUT
    case DELETE
}

public enum URLScheme {
    case http
    case https
    
    var value: String {
        switch self {
        case .http:
            return "http"
        case .https:
            return "https"
        }
    }
}

public enum KeyDecoding {
    case snake
    case `default`
    
    var strategy: JSONDecoder.KeyDecodingStrategy {
        switch self {
        case .snake:
            return .convertFromSnakeCase
        case .default:
            return .useDefaultKeys
        }
    }
}
