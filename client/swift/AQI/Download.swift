// Copyright 2020 Bret Taylor

import Foundation
import GameKit

private let aqiDataURL = URL(string: "https://dfddnmlutocpt.cloudfront.net/sensors.pb")!
private let particulateMatterDataURL = URL(string: "https://dfddnmlutocpt.cloudfront.net/sensors.raw.pb")!
private let compactDataURL = URL(string: "https://dfddnmlutocpt.cloudfront.net/sensors.compact.pb")!
private let compactParticulateMatterDataURL = URL(string: "https://dfddnmlutocpt.cloudfront.net/sensors.raw.compact.pb")!

/// The type of air quality measurement
public enum ReadingType {
    /// Calculated EPA AQI
    case epaCorrected
    
    /// Raw PurpleAir PM2.5 AQI
    case rawPurpleAir
}

/// Downloads the most recent AQI readings from the server.
///
/// Readings are delivered as an `GKRTree` to enable efficient querying of which readings are visible in a map view.
/// - Parameters:
///   - onProgess: The callback to which we report download progress as a percentage in the range `[0.0, 1.0]`
///   - onResponse: The callback to which we report the parsed download response
@available(iOS 13.0, *)
@available(macOS 10.12, *)
public func downloadReadings(type: ReadingType, onProgess: @escaping (Float) -> Void, onResponse: @escaping (GKRTree<Reading>?, Error?) -> Void) {
    let client = DownloadClient(onProgess: onProgess, onResponse: onResponse)
    let session = URLSession(configuration: URLSessionConfiguration.default, delegate: client, delegateQueue: OperationQueue.main)
    session.downloadTask(with: type == .epaCorrected ? aqiDataURL : particulateMatterDataURL).resume()
}

/// Downloads the compact AQI readings from the server, which only includes one AQI reading in addition to the latitude and longitude.
///
/// Readings are delivered as an `GKRTree` to enable efficient querying of which readings are visible in a map view.
/// - Parameters:
///   - onResponse: The callback to which we report the parsed download response
@available(iOS 13.0, *)
@available(macOS 10.12, *)
public func downloadCompactReadings(type: ReadingType, onResponse: @escaping (GKRTree<Reading>?, Error?) -> Void) {
    let client = DownloadClient(onProgess: { (percentage) in
    }, onResponse: onResponse)
    let session = URLSession(configuration: URLSessionConfiguration.default, delegate: client, delegateQueue: OperationQueue.main)
    session.downloadTask(with: type == .epaCorrected ? compactDataURL : compactParticulateMatterDataURL).resume()
}

@available(iOS 13.0, *)
@available(macOS 10.12, *)
private class DownloadClient: NSObject, URLSessionDelegate, URLSessionDownloadDelegate {
    let _onProgess: (Float) -> Void
    let _onResponse: (GKRTree<Reading>?, Error?) -> Void
    let _downloadStartTime: CFAbsoluteTime
    var _downloadCompleted: Bool = false
    let _maximumProgress: Float = 0.9

    init(onProgess: @escaping (Float) -> Void, onResponse: @escaping (GKRTree<Reading>?, Error?) -> Void) {
        self._onProgess = onProgess
        self._onResponse = onResponse
        self._downloadStartTime = CFAbsoluteTimeGetCurrent()
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite == NSURLSessionTransferSizeUnknown {
            self._onProgess(0.5 * self._maximumProgress)
        } else {
            self._onProgess(Float(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)) * self._maximumProgress)
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let data = try? Data(contentsOf: location) else {
            return
        }
        self._downloadCompleted = true
        self._onProgess(self._maximumProgress)
        DispatchQueue.global(qos: .background).async {
            if let httpResponse = downloadTask.response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                 let sensorsResponse = try? Sensors(serializedData: data) {
                 let sensors = GKRTree<Reading>(maxNumberOfChildren: 6000)
                for data in sensorsResponse.sensors {
                    let sensor = Reading(data)
                    let point = vector_float2(data.latitude, data.longitude)
                    sensors.addElement(sensor, boundingRectMin: point, boundingRectMax: point, splitStrategy: .reduceOverlap)
                }
                DispatchQueue.main.async {
                    self._onProgess(1.0)
                    self._onResponse(sensors, nil)
                }
            } else {
                DispatchQueue.main.async {
                    self._onResponse(nil, DownloadError.invalidServerResponse)
                }
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error,
           !self._downloadCompleted {
            self._onResponse(nil, error)
        } else if !self._downloadCompleted {
            self._onResponse(nil, DownloadError.serverError)
        }
    }
}

/// Represents an error in the AQI download process.
public enum DownloadError: Error {
    /// The server returned an HTTP error status code.
    case serverError
    
    /// The server returned a response we could not recognize.
    case invalidServerResponse
}
