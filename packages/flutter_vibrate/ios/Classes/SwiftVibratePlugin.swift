import Flutter
import UIKit
import AudioToolbox

public class SwiftVibratePlugin: NSObject, FlutterPlugin, VibrateApi {
  private let isDevice = TARGET_OS_SIMULATOR == 0

  public static func register(with registrar: FlutterPluginRegistrar) {
    let messenger : FlutterBinaryMessenger = registrar.messenger()
    let api : VibrateApi & NSObjectProtocol = SwiftVibratePlugin()
    VibrateApiSetup.setUp(binaryMessenger: messenger, api: api)
  }

  func canVibrate() throws -> Bool {
      return isDevice
  }

  func vibrate(duration: Int64) throws {
      AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
  }

  func impact() throws {
      if #available(iOS 10.0, *) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
      }
  }

  func selection() throws {
      if #available(iOS 10.0, *) {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
      }
  }

  func success() throws {
      if #available(iOS 10.0, *) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
      }
  }

  func warning() throws {
      if #available(iOS 10.0, *) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
      }
  }

  func error() throws {
      if #available(iOS 10.0, *) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
      }
  }

  func heavy() throws {
      if #available(iOS 10.0, *) {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
      }
  }

  func medium() throws {
      if #available(iOS 10.0, *) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
      }
  }

  func light() throws {
      if #available(iOS 10.0, *) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
      }
  }
}
