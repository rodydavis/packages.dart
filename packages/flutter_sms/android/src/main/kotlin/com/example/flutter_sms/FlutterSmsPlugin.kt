package com.example.flutter_sms

import android.annotation.TargetApi
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger



class FlutterSmsPlugin: FlutterPlugin, SmsHostApi, ActivityAware {
  var activity: Activity? = null
  private val REQUEST_CODE_SEND_SMS = 205

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivity() {
    activity = null
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    Log.d("FlutterSmsPlugin", "onAttachedToEngine")
    SmsHostApi.setUp(flutterPluginBinding.binaryMessenger, this)
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    SmsHostApi.setUp(binding.binaryMessenger, null)
  }

  // V1 embedding entry point. This is deprecated and will be removed in a future Flutter
  // release but we leave it here in case someone's app does not utilize the V2 embedding yet.


  override fun sendSms(message: String, recipients: List<String>, callback: (Result<String>) -> Unit) {
    if (!checkCanSendSms()) {
      callback(Result.failure(FlutterError("device_not_capable", "The current device is not capable of sending text messages.", "A device may be unable to send messages if it does not support messaging or if it is not currently configured to send messages. This only applies to the ability to send text messages via iMessage, SMS, and MMS.")))
      return
    }
    
    val phones = recipients.joinToString(";")
    callback(Result.success(sendSMSDialog(phones, message)))
  }

  @TargetApi(Build.VERSION_CODES.ECLAIR)
  override fun canSendSms(callback: (Result<Boolean>) -> Unit) {
      callback(Result.success(checkCanSendSms()))
  }

  @TargetApi(Build.VERSION_CODES.ECLAIR)
  private fun checkCanSendSms(): Boolean {
    if (activity == null) {
        Log.d("FlutterSmsPlugin", "Activity is null")
        return false
    }
    if (!activity!!.packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY)) {
        Log.d("FlutterSmsPlugin", "No TELEPHONY feature")
        return false
    }
    val intent = Intent(Intent.ACTION_SENDTO)
    intent.data = Uri.parse("smsto:123456")
    val activityInfo = intent.resolveActivityInfo(activity!!.packageManager, 0)
    if (activityInfo == null || !activityInfo.exported) {
        Log.d("FlutterSmsPlugin", "No activity to handle smsto intent or not exported")
        return false
    }
    return true
  }

  private fun sendSMSDialog(phones: String, message: String): String {
    val intent = Intent(Intent.ACTION_SENDTO)
    intent.data = Uri.parse("smsto:$phones")
    intent.putExtra("sms_body", message)
    intent.putExtra(Intent.EXTRA_TEXT, message)
    activity?.startActivityForResult(intent, REQUEST_CODE_SEND_SMS)
    return "SMS Sent!"
  }
}

