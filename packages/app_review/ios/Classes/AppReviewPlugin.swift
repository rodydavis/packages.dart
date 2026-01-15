import Flutter
import StoreKit
import SwiftUI

public class AppReviewPlugin: NSObject, FlutterPlugin, AppReviewApi {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = AppReviewPlugin()
    AppReviewApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
  }

  public func requestReview(testMode: Bool, completion: @escaping (Result<String?, Error>) -> Void) {
      if #available(iOS 16.0, *) {
           DispatchQueue.main.async {
               if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                  let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
                   let controller = UIHostingController(rootView: ReviewRequestView())
                   controller.view.isHidden = true
                   controller.view.frame = .zero
                   keyWindow.addSubview(controller.view)
                   // Triggering onAppear by adding to hierarchy.
               }
           }
           completion(.success("Requested Review via SwiftUI"))
      } else if #available(iOS 14.0, *) {
          if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
              SKStoreReviewController.requestReview(in: scene)
              completion(.success("Requested Review"))
          } else {
               SKStoreReviewController.requestReview()
               completion(.success("Requested Review"))
          }
      } else if #available(iOS 10.3, *) {
          SKStoreReviewController.requestReview()
          completion(.success("Requested Review"))
      } else {
          completion(.success("Review not available"))
      }
  }

  public func isRequestReviewAvailable(completion: @escaping (Result<Bool, Error>) -> Void) {
      if #available(iOS 10.3, *) {
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
          UIApplication.shared.open(url, options: [:]) { success in
              if success {
                   completion(.success(()))
              } else {
                   completion(.failure(NSError(domain: "AppReview", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to open store listing"])))
              }
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
           UIApplication.shared.open(url, options: [:]) { success in
              if success {
                   completion(.success(()))
              } else {
                   completion(.failure(NSError(domain: "AppReview", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to open App Store review"])))
              }
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

@available(iOS 16.0, *)
struct ReviewRequestView: View {
    @Environment(\.requestReview) var requestReview

    var body: some View {
        EmptyView()
            .onAppear {
                requestReview()
            }
    }
}
