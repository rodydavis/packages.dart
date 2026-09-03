import Flutter
import UIKit
import MessageUI

public class SwiftFlutterSmsPlugin: NSObject, FlutterPlugin, SmsHostApi, MFMessageComposeViewControllerDelegate {
  private var result: ((Result<String, Error>) -> Void)?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = SwiftFlutterSmsPlugin()
    SmsHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
  }

  public func sendSms(message: String, recipients: [String], completion: @escaping (Result<String, Error>) -> Void) {
    #if targetEnvironment(simulator)
      completion(.failure(PigeonError(
          code: "message_not_sent",
          message: "Cannot send message on this device!",
          details: "Cannot send SMS and MMS on a Simulator. Test on a real device."
        )))
    #else
      DispatchQueue.main.async { [weak self] in
        guard let self = self else {
          completion(.failure(PigeonError(
            code: "plugin_unavailable",
            message: "The SMS plugin is unavailable.",
            details: nil
          )))
          return
        }
        guard self.result == nil else {
          completion(.failure(PigeonError(
            code: "composer_busy",
            message: "An SMS composer is already open.",
            details: nil
          )))
          return
        }
        guard MFMessageComposeViewController.canSendText() else {
          completion(.failure(PigeonError(
            code: "device_not_capable",
            message: "The current device is not capable of sending text messages.",
            details: "A device may be unable to send messages if it does not support messaging or if it is not currently configured to send messages."
          )))
          return
        }
        guard let presenter = Self.activeViewController() else {
          completion(.failure(PigeonError(
            code: "view_controller_unavailable",
            message: "Unable to present the SMS composer.",
            details: nil
          )))
          return
        }

        self.result = completion
        let controller = MFMessageComposeViewController()
        controller.body = message
        controller.recipients = recipients
        controller.messageComposeDelegate = self
        presenter.present(controller, animated: true) { [weak self, weak controller] in
          guard controller?.presentingViewController != nil else {
            let callback = self?.result
            self?.result = nil
            callback?(.failure(PigeonError(
              code: "view_controller_unavailable",
              message: "Unable to present the SMS composer.",
              details: nil
            )))
            return
          }
        }
      }
    #endif
  }

  public func canSendSms(completion: @escaping (Result<Bool, Error>) -> Void) {
    #if targetEnvironment(simulator)
      completion(.success(false))
    #else
      if (MFMessageComposeViewController.canSendText()) {
        completion(.success(true))
      } else {
        completion(.success(false))
      }
    #endif
  }

  public func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
    let map: [MessageComposeResult: String] = [
        MessageComposeResult.sent: "sent",
        MessageComposeResult.cancelled: "cancelled",
        MessageComposeResult.failed: "failed",
    ]
    let callback = self.result
    self.result = nil
    controller.dismiss(animated: true) {
      callback?(.success(map[result] ?? "unknown"))
    }
  }

  private static func activeViewController() -> UIViewController? {
    let rootViewController: UIViewController?
    if #available(iOS 13.0, *) {
      rootViewController = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first { $0.activationState == .foregroundActive }?
        .windows
        .first { $0.isKeyWindow }?
        .rootViewController
    } else {
      rootViewController = UIApplication.shared.keyWindow?.rootViewController
    }
    return topViewController(from: rootViewController)
  }

  private static func topViewController(from controller: UIViewController?) -> UIViewController? {
    if let navigationController = controller as? UINavigationController {
      return topViewController(from: navigationController.visibleViewController)
    }
    if let tabBarController = controller as? UITabBarController {
      return topViewController(from: tabBarController.selectedViewController)
    }
    if let presentedViewController = controller?.presentedViewController {
      return topViewController(from: presentedViewController)
    }
    return controller
  }
}
