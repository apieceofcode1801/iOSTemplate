//
//  ViewController.swift
//  iOSTemplate
//
//  Created by Trung Hoang on 04/09/2021.
//

import UIKit
import iOSTemplate

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Network.shared.fetch(with: AppAPI.getStoreConfig) { (result: Result<String, NetworkError>) in
            print(result)
        }
    }
}

enum AppAPI: NetworkRequest {
    case getStoreConfig
    
    var path: String {
        return "/rest/default/V1/integration/customer/token"
    }
    
    var method: HttpMethod {
        return HttpMethod.POST
    }
    
    var headers: [String : String] {
        return ["Authorization": "Bearer ***", "Content-Type": "application/json"]
    }
    
    var body: [String : Any]? {
        return [
            "username": "roni_cost@example.com",
            "password": "roni_cost3@example.com"
          ]
    }
}

extension NetworkRequest {
    var config: NetworkConfig {
        return AppConfig.development
    }
}

enum AppConfig: NetworkConfig {
    case development
    
    var scheme: URLScheme {
        return .https
    }
    
    var host: String {
        return "demo.fatherofapps.com"
    }
    
    var keyDecoding: KeyDecoding {
        return .snake
    }
}

struct StoreConfig: Decodable {
    let id: Int
    let code: String
    let baseCurrencyCode: String
}
