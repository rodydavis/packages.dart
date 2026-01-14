import Flutter
import UIKit
import MessageUI

public class SwiftFlutterSmsPlugin: NSObject, FlutterPlugin, SmsHostApi, UINavigationControllerDelegate, MFMessageComposeViewControllerDelegate {
    var result: ((Result<String, Error>) -> Void)?
    var _arguments = [String: Any]()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = SwiftFlutterSmsPlugin()
    SmsHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
  }

  public func sendSms(message: String, recipients: [String], completion: @escaping (Result<String, Error>) -> Void) {
    #if targetEnvironment(simulator)
      completion(.failure(FlutterError(
          code: "message_not_sent",
          message: "Cannot send message on this device!",
          details: "Cannot send SMS and MMS on a Simulator. Test on a real device."
        )))
    #else
      if (MFMessageComposeViewController.canSendText()) {
        self.result = completion
        let controller = MFMessageComposeViewController()
        controller.body = message
        controller.recipients = recipients
        controller.messageComposeDelegate = self
        UIApplication.shared.keyWindow?.rootViewController?.present(controller, animated: true, completion: nil)
      } else {
        completion(.failure(FlutterError(
            code: "device_not_capable",
            message: "The current device is not capable of sending text messages.",
            details: "A device may be unable to send messages if it does not support messaging or if it is not currently configured to send messages. This only applies to the ability to send text messages via iMessage, SMS, and MMS."
          )))
      }
    #endif
  }

  public func canSendSms() -> Bool {
    #if targetEnvironment(simulator)
      return false
    #else
      if (MFMessageComposeViewController.canSendText()) {
        return true
      } else {
        return false
      }
    #endif
  }

  public func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
    let map: [MessageComposeResult: String] = [
        MessageComposeResult.sent: "sent",
        MessageComposeResult.cancelled: "cancelled",
        MessageComposeResult.failed: "failed",
    ]
    if let callback = self.result {
        callback(.success(map[result] ?? "unknown"))
    }
    UIApplication.shared.keyWindow?.rootViewController?.dismiss(animated: true, completion: nil)
  }
}
