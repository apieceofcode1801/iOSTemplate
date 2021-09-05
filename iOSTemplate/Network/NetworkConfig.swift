//
//  NetworkConfig.swift
//  iOSTemplate
//
//  Created by Trung Hoang on 04/09/2021.
//

import Foundation

protocol NetworkConfig {
    var host: String { get }
    var scheme: URLScheme { get }
    var keyDecoding: KeyDecoding { get }
}

extension NetworkConfig {
    var keyDecoding: KeyDecoding {
        return .default
    }
}
