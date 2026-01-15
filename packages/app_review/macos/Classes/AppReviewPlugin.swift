import Cocoa
import FlutterMacOS
import StoreKit

import SwiftUI

public class AppReviewPlugin: NSObject, FlutterPlugin, AppReviewApi {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = AppReviewPlugin()
    AppReviewApiSetup.setUp(binaryMessenger: registrar.messenger, api: instance)
  }

  public func requestReview(testMode: Bool, completion: @escaping (Result<String?, Error>) -> Void) {
      if #available(macOS 14.0, *) {
          DispatchQueue.main.async {
               if let window = NSApplication.shared.windows.first {
                   let view = NSHostingView(rootView: ReviewRequestView())
                   view.frame = .zero
                   window.contentView?.addSubview(view)
                   // Cleanup? The view is zero frame and invisible, but triggers onAppear.
                   // Ideally we remove it later, but for now this triggers the action.
               }
          }
          completion(.success("Requested Review via SwiftUI"))
      } else if #available(macOS 10.14, *) {
        SKStoreReviewController.requestReview()
        completion(.success("Requested Review"))
      } else {
        completion(.success("Review not available"))
      }
  }

  public func isRequestReviewAvailable(completion: @escaping (Result<Bool, Error>) -> Void) {
    if #available(macOS 10.14, *) {
      completion(.success(true))
    } else {
      completion(.success(false))
    }
  }

  public func getBundleId(completion: @escaping (Result<String, Error>) -> Void) {
    completion(.success(Bundle.main.bundleIdentifier ?? ""))
  }

  public func openStoreListing(storeId: String?, completion: @escaping (Result<Void, Error>) -> Void) {
      guard let storeId = storeId, !storeId.isEmpty else {
          completion(.failure(NSError(domain: "AppReview", code: 404, userInfo: [NSLocalizedDescriptionKey: "Store ID is missing"])))
          return
      }
      let urlString = "https://apps.apple.com/app/id\(storeId)"
      if let url = URL(string: urlString) {
          if NSWorkspace.shared.open(url) {
              completion(.success(()))
          } else {
              completion(.failure(NSError(domain: "AppReview", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to open store listing"])))
          }
      } else {
          completion(.failure(NSError(domain: "AppReview", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Store URL"])))
      }
  }

  public func openAppStoreReview(storeId: String?, completion: @escaping (Result<Void, Error>) -> Void) {
      guard let storeId = storeId, !storeId.isEmpty else {
          completion(.failure(NSError(domain: "AppReview", code: 404, userInfo: [NSLocalizedDescriptionKey: "Store ID is missing"])))
          return
      }
      let urlString = "https://apps.apple.com/app/id\(storeId)?action=write-review"
      if let url = URL(string: urlString) {
          if NSWorkspace.shared.open(url) {
              completion(.success(()))
          } else {
              completion(.failure(NSError(domain: "AppReview", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to open App Store review"])))
          }
      } else {
          completion(.failure(NSError(domain: "AppReview", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Store URL"])))
      }
  }

  public func lookupAppId(bundleId: String, countryCode: String?, completion: @escaping (Result<String?, Error>) -> Void) {
      let country = countryCode ?? ""
      let urlString = "https://itunes.apple.com/\(country)/lookup?bundleId=\(bundleId)"
      guard let url = URL(string: urlString) else {
          completion(.failure(NSError(domain: "AppReview", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Lookup URL"])))
          return
      }

      let task = URLSession.shared.dataTask(with: url) { data, response, error in
          if let error = error {
              completion(.failure(error))
              return
          }
          guard let data = data else {
              completion(.success(nil))
              return
          }
           do {
              if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                 let results = json["results"] as? [[String: Any]],
                 let firstResult = results.first,
                 let trackId = firstResult["trackId"] as? Int {
                  completion(.success(String(trackId)))
              } else {
                  completion(.success(nil))
              }
          } catch {
              completion(.failure(error))
          }
      }
      task.resume()
  }
}

@available(macOS 14.0, *)
struct ReviewRequestView: View {
    @Environment(\.requestReview) var requestReview

    var body: some View {
        EmptyView()
            .onAppear {
                requestReview()
            }
    }
}
