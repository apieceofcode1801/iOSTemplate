//
//  NetworkConfig.swift
//  iOSTemplate
//
//  Created by Trung Hoang on 04/09/2021.
//

import Foundation

public protocol NetworkConfig {
    var host: String { get }
    var scheme: URLScheme { get }
    var keyDecoding: KeyDecoding { get }
}

public extension NetworkConfig {
    var keyDecoding: KeyDecoding {
        return .default
    }
}
