package com.appleeducate.appreview;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.google.android.play.core.review.ReviewInfo;
import com.google.android.play.core.review.ReviewManager;
import com.google.android.play.core.review.ReviewManagerFactory;
import com.google.android.play.core.review.testing.FakeReviewManager;
import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.Task;

import java.lang.ref.WeakReference;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;

/** AppReviewPlugin */
public class AppReviewPlugin implements FlutterPlugin, Messages.AppReviewApi, ActivityAware {
  private WeakReference<Activity> currentActivity;
  private ReviewManager manager;
  @Nullable
  private ReviewInfo reviewInfo;

  public AppReviewPlugin() {
  }

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    Messages.AppReviewApi.setUp(binding.getBinaryMessenger(), this);
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    Messages.AppReviewApi.setUp(binding.getBinaryMessenger(), null);
  }

  @Override
  public void isRequestReviewAvailable(Messages.Result<Boolean> result) {
    if (manager == null) {
      result.error(new Exception("ReviewManager not initialized"));
      return;
    }
    Task<ReviewInfo> request = manager.requestReviewFlow();
    request.addOnCompleteListener(new OnCompleteListener<ReviewInfo>() {
      @Override
      public void onComplete(@NonNull Task<ReviewInfo> task) {
        if (task.isSuccessful()) {
          reviewInfo = task.getResult();
          result.success(true);
        } else {
          result.success(false);
        }
      }
    });
  }

  @Override
  public void openStoreListing(@Nullable String storeId, Messages.VoidResult result) {
    if (currentActivity == null || currentActivity.get() == null) {
      result.error(new Exception("Android activity not available"));
      return;
    }
    try {
      Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=" + storeId));
      intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
      currentActivity.get().startActivity(intent);
      result.success();
    } catch (android.content.ActivityNotFoundException anfe) {
      try {
        Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=" + storeId));
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        currentActivity.get().startActivity(intent);
        result.success();
      } catch (Exception e) {
        result.error(e);
      }
    }
  }

  @Override
  public void openAppStoreReview(@Nullable String storeId, Messages.VoidResult result) {
    openStoreListing(storeId, result);
  }

  @Override
  public void lookupAppId(@NonNull String bundleId, @Nullable String countryCode, Messages.NullableResult<String> result) {
    new Thread(() -> {
      try {
        String country = countryCode != null ? countryCode : "";
        java.net.URL url = new java.net.URL("https://itunes.apple.com/" + country + "/lookup?bundleId=" + bundleId);
        java.net.HttpURLConnection connection = (java.net.HttpURLConnection) url.openConnection();
        connection.setRequestMethod("GET");
        connection.setConnectTimeout(5000);
        connection.setReadTimeout(5000);

        if (connection.getResponseCode() == 200) {
          java.io.InputStream inputStream = connection.getInputStream();
          java.io.BufferedReader reader = new java.io.BufferedReader(new java.io.InputStreamReader(inputStream));
          StringBuilder response = new StringBuilder();
          String line;
          while ((line = reader.readLine()) != null) {
            response.append(line);
          }
          reader.close();

          org.json.JSONObject json = new org.json.JSONObject(response.toString());
          org.json.JSONArray results = json.getJSONArray("results");
          if (results.length() > 0) {
            org.json.JSONObject firstResult = results.getJSONObject(0);
            if (firstResult.has("trackId")) {
              String trackId = String.valueOf(firstResult.getInt("trackId"));
              new android.os.Handler(android.os.Looper.getMainLooper()).post(() -> result.success(trackId));
              return;
            }
          }
        }
        new android.os.Handler(android.os.Looper.getMainLooper()).post(() -> result.success(null));
      } catch (Exception e) {
        new android.os.Handler(android.os.Looper.getMainLooper()).post(() -> result.error(e));
      }
    }).start();
  }

  @Override
  public void getBundleId(Messages.Result<String> result) {
    if (currentActivity == null || currentActivity.get() == null) {
      result.error(new Exception("Android activity not available"));
      return;
    }
    result.success(currentActivity.get().getPackageName());
  }

  @Override
  public void requestReview(@NonNull Boolean testMode, Messages.NullableResult<String> result) {
    if (currentActivity == null || currentActivity.get() == null) {
      result.error(new Exception("Android activity not available"));
      return;
    }

    if (testMode) {
      manager = new FakeReviewManager(currentActivity.get());
    } else {
      if (manager == null || manager instanceof FakeReviewManager) {
        manager = ReviewManagerFactory.create(currentActivity.get());
      }
    }

    if (reviewInfo == null) {
      getReviewInfoAndRequestReview(testMode, result);
      return;
    }
    Task<Void> task = manager.launchReviewFlow(currentActivity.get(), reviewInfo);
    task.addOnCompleteListener(new OnCompleteListener<Void>() {
      @Override
      public void onComplete(@NonNull Task<Void> task) {
        reviewInfo = null;
        result.success("Success: " + task.isSuccessful());
      }
    });
  }

  private void getReviewInfoAndRequestReview(Boolean testMode, final Messages.NullableResult<String> result) {
    if (manager == null) {
      result.error(new Exception("ReviewManager not initialized"));
      return;
    }
    Task<ReviewInfo> request = manager.requestReviewFlow();
    request.addOnCompleteListener(new OnCompleteListener<ReviewInfo>() {
      @Override
      public void onComplete(@NonNull Task<ReviewInfo> task) {
        if (task.isSuccessful()) {
          reviewInfo = task.getResult();
          requestReview(testMode, result);
        } else {
          result.error(new Exception("Requesting review not possible"));
        }
      }
    });
  }

  @Override
  public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
    currentActivity = new WeakReference<>(binding.getActivity());
    manager = ReviewManagerFactory.create(binding.getActivity());
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() {
    onDetachedFromActivity();
  }

  @Override
  public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
    onAttachedToActivity(binding);
  }

  @Override
  public void onDetachedFromActivity() {
    currentActivity = null;
    manager = null;
  }
}
