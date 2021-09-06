//
//  Network.swift
//  iOSTemplate
//
//  Created by Trung Hoang on 04/09/2021.
//

import Foundation

public protocol NetworkDownloadDelegate: AnyObject {
    func onDownloading(_ progress: Float)
    func onFinishedDownloading(to tempLocation: URL)
    func onDownloadFailed(error: NetworkError, resumeData: Data?)
}

public protocol NetworkBackgroundDownloadDelegate: AnyObject {
    func onFailed(error: NetworkError)
    func onSuccess(tempLocation: URL)
}

public protocol NetworkUploadDelegate: AnyObject {
    func didUpload(_ result: Bool)
}

public class Network: NSObject {
    public static var shared = Network()
    
    private lazy var session: URLSession = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
    
    private lazy var backgroundSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "APOC_Background_Session")
        config.isDiscretionary = true
        config.sessionSendsLaunchEvents = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    struct Streams {
        let input: InputStream
        let output: OutputStream
    }
    
    private lazy var boundStreams: Streams = {
        var inputOrNil: InputStream? = nil
        var outputOrNil: OutputStream? = nil
        
        Stream.getBoundStreams(withBufferSize: 4096, inputStream: &inputOrNil, outputStream: &outputOrNil)
        
        guard let input = inputOrNil, let output = outputOrNil else {
            fatalError("On return of `getBoundStreams`, both `inputStream` and `outputStream` will contain non-nil streams.")
        }
        
        output.delegate = self
        output.schedule(in: .current, forMode: .default)
        output.open()
        return Streams(input: input, output: output)
    }()
    
    private var canWrite = false
    private var downloadTask: URLSessionDownloadTask? = nil
    
    public weak var uploadDelegate: NetworkUploadDelegate?
    public weak var downloadDelegate: NetworkDownloadDelegate?
    public weak var backgroundDownloadDelegate: NetworkBackgroundDownloadDelegate?
    
    public var backgroundCompletionHandler: (() -> Void)?
    
    private func performDataTaskWithRequest<T: Decodable>(_ request: URLRequest, keyDecoding: KeyDecoding, completion: @escaping (Result<T, NetworkError>) -> Void) {
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.unkownError(description: error.localizedDescription)))
            }
            
            guard let response = response as? HTTPURLResponse, let data = data else {
                completion(.failure(.unkownError(description: "Server didn't respond")))
                return
            }
            
            guard (200...299).contains(response.statusCode) else {
                completion(.failure(.serverError(code: response.statusCode, message: String(data: data, encoding: .utf8) ?? "")))
                return
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = keyDecoding.strategy
            do {
                let returnedObject = try decoder.decode(T.self, from: data)
                completion(.success(returnedObject))
            } catch {
                print(error.localizedDescription)
                completion(.failure(.decodeError))
            }
        }
        
        task.resume()
    }
}

// MARK: Handle fetching data
extension Network {
    public func fetch<T>(with networkRequest: NetworkRequest, completion: @escaping (Result<T, NetworkError>) -> Void) where T: Decodable {
        
        guard let url = url(with: networkRequest) else {
            completion(.failure(.unkownError(description: "URL invalid")))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = networkRequest.method.rawValue
        request.allHTTPHeaderFields = networkRequest.headers
        if let body = networkRequest.body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        
        performDataTaskWithRequest(request, keyDecoding: networkRequest.config.keyDecoding, completion: completion)
    }
}

// MARK: Handle uploading data
extension Network {
    public func upload<T: Decodable>(networkRequest: NetworkUploadRequest, timeout: TimeInterval, completion: @escaping (Result<T, NetworkError>) -> Void) {
        guard let url = url(with: networkRequest) else {
            completion(.failure(.unkownError(description: "URL invalid")))
            return
        }
        
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        request.httpMethod = networkRequest.method.rawValue
        let uploadTask = session.uploadTask(withStreamedRequest: request)
        uploadTask.resume()
        if canWrite {
            let messageCount = networkRequest.data.count
            let bytesWritten: Int = networkRequest.data.withUnsafeBytes { (buffer: UnsafePointer<UInt8>) in
                self.canWrite = false
                return self.boundStreams.output.write(buffer, maxLength: messageCount)
            }
            
            if bytesWritten < messageCount {
                // Handle writing less data than expected
            }
        }
    }
    
    public func multipartUpload<T: Decodable>(multipartRequest: NetworkMultipartRequest, completion: @escaping (Result<T, NetworkError>) -> Void) {
        guard let url = url(with: multipartRequest) else {
            completion(.failure(.unkownError(description: "URL invalid")))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = multipartRequest.method.rawValue
        request.allHTTPHeaderFields = multipartRequest.headers
        request.setValue("multipart/form-data; boundary=\(multipartRequest.boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = multipartRequest.httpBody
        
        performDataTaskWithRequest(request, keyDecoding: multipartRequest.config.keyDecoding, completion: completion)
    }
}

// MARK: Handle downloading task
extension Network {
    public func download(networkRequest: NetworkRequest) {
        guard let url = url(with: networkRequest) else {
            downloadDelegate?.onDownloadFailed(error: .unkownError(description: "URL invalid"), resumeData: nil)
            return
        }
        
        downloadTask = session.downloadTask(with: url)
        downloadTask?.resume()
    }
    
    public func resumeDownload(_ resumeData: Data) {
        downloadTask = session.downloadTask(withResumeData: resumeData)
        downloadTask?.resume()
    }
    
    public func backgroundDownload(networkRequest: NetworkRequest) {
        guard let url = url(with: networkRequest) else {
            backgroundDownloadDelegate?.onFailed(error: .unkownError(description: "URL invalid"))
            return
        }
        
        let backgroundTask = backgroundSession.downloadTask(with: url)
        //        backgroundTask.earliestBeginDate = Date().addingTimeInterval(60 * 60)
        //        backgroundTask.countOfBytesClientExpectsToSend = 200
        //        backgroundTask.countOfBytesClientExpectsToReceive = 500 * 1024
        backgroundTask.resume()
    }
}

extension Network {
    private func url(with networkRequest: NetworkRequest) -> URL? {
        var urlComponents = URLComponents()
        urlComponents.scheme = networkRequest.config.scheme.value
        urlComponents.host = networkRequest.config.host
        urlComponents.path = networkRequest.path
        if networkRequest.method == HttpMethod.GET, let queries = networkRequest.queries {
            urlComponents.queryItems = queries.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        
        return urlComponents.url
    }
}

extension Network: URLSessionTaskDelegate {
    public func urlSession(_ session: URLSession, task: URLSessionTask, needNewBodyStream completionHandler: @escaping (InputStream?) -> Void) {
        completionHandler(boundStreams.input)
    }
    
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        guard let completionHandler = backgroundCompletionHandler else {
            return
        }
        
        completionHandler()
    }
}

extension Network: URLSessionDownloadDelegate {
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        if let error = downloadTask.error {
            downloadDelegate?.onDownloadFailed(error: .unkownError(description: error.localizedDescription), resumeData: nil)
        }
        
        guard let response = downloadTask.response as? HTTPURLResponse else {
            downloadDelegate?.onDownloadFailed(error: .unkownError(description: "Server didn't respond"), resumeData: nil)
            return
        }
        
        guard (200...299).contains(response.statusCode) else {
            downloadDelegate?.onDownloadFailed(error: .serverError(code: response.statusCode, message: "Download failed"), resumeData: nil)
            return
        }
        
        downloadDelegate?.onFinishedDownloading(to: location)
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if downloadTask == self.downloadTask {
            let calculatedProgress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
            DispatchQueue.main.async {
                self.downloadDelegate?.onDownloading(calculatedProgress)
            }
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if task == downloadTask, let error = error {
            let userInfo = (error as NSError).userInfo
            let resumeData = userInfo[NSURLSessionDownloadTaskResumeData] as? Data
            downloadDelegate?.onDownloadFailed(error: .unkownError(description: error.localizedDescription), resumeData: resumeData)
        }
    }
}

extension Network: StreamDelegate {
    public func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        guard aStream == boundStreams.output else {
            return
        }
        
        if eventCode.contains(.hasSpaceAvailable) {
            canWrite = true
        }
        
        if eventCode.contains(.errorOccurred) {
            // Close the stream
            aStream.close()
            uploadDelegate?.didUpload(false)
        }
    }
}
