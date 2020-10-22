package com.missiveapp.openwith;

import android.app.Activity;
import android.app.NotificationManager;
import android.content.ClipData;
import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Bundle;
import android.support.annotation.RequiresApi;
import android.util.Log;
import android.util.SparseArray;

import com.adobe.phonegap.push.FCMService;
import com.adobe.phonegap.push.PushPlugin;
import com.google.android.gms.vision.Frame;
import com.google.android.gms.vision.barcode.Barcode;
import com.google.android.gms.vision.barcode.BarcodeDetector;

import org.json.JSONException;
import org.json.JSONObject;

import static java.lang.System.*;

public class IntentActivity extends Activity {
  private static String LOG_TAG = "Shared_IntentActivity";

  /*
   * this activity will be started if the user touches a notification that we own.
   * We send it's data off to the push plugin for processing.
   * If needed, we boot up the main activity to kickstart the application.
   * @see android.app.Activity#onCreate(android.os.Bundle)
   */
  @RequiresApi(api = Build.VERSION_CODES.N)
  @Override
  public void onCreate(Bundle savedInstanceState) {

    Intent intent = getIntent();

    super.onCreate(savedInstanceState);
    Log.v(LOG_TAG, "onCreate");

    String callback = getIntent().getExtras().getString("callback");
    Log.d(LOG_TAG, "callback = " + callback);
    boolean foreground = getIntent().getExtras().getBoolean("foreground", true);
//    boolean startOnBackground = getIntent().getExtras().getBoolean(START_IN_BACKGROUND, false);
//    boolean dismissed = getIntent().getExtras().getBoolean(DISMISSED, false);
//    Log.d(LOG_TAG, "dismissed = " + dismissed);

//    if(!startOnBackground){
//      NotificationManager notificationManager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
//      notificationManager.cancel(FCMService.getAppName(this), notId);
//    }
//
    boolean isPushPluginActive = PushPlugin.isActive();
//    boolean inline = processPushBundle(isPushPluginActive, intent);

//    if(inline && android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.N && !startOnBackground){
//      foreground = true;
//    }
//
//    Log.d(LOG_TAG, "bringToForeground = " + foreground);

    finish();


//    if (isPushPluginActive) {
    forceMainActivityReload(false);
//      if (intent.getAction().equals(Intent.ACTION_SEND)){
//        //this is an sending activity. We need to process this.
////        ContentResolver resolver = this.getApplicationContext().getContentResolver();
//        try {
//          JSONObject obj = Serializer.toJSONObject(this, intent);
////          Log.d(LOG_TAG, "obj:");
////          Log.d(LOG_TAG, obj.toString());
//
//        } catch (JSONException e) {
//          e.printStackTrace();
//        }
////        startActivity(intent);
//      }


//    };
//      if (!isPushPluginActive && foreground && inline) {
//        Log.d(LOG_TAG, "forceMainActivityReload");
//        forceMainActivityReload(false);
//      } else if(startOnBackground) {
//        Log.d(LOG_TAG, "startOnBackgroundTrue");
//        forceMainActivityReload(true);
//      } else {
//        Log.d(LOG_TAG, "don't want main activity");
//      }
  }

//  /**
//   * Takes the pushBundle extras from the intent,
//   * and sends it through to the PushPlugin for processing.
//   */
//  private boolean processPushBundle(boolean isPushPluginActive, Intent intent) {
//    Bundle extras = getIntent().getExtras();
//    Bundle remoteInput = null;
//
//    if (extras != null) {
//      Bundle originalExtras = extras.getBundle(PUSH_BUNDLE);
//
//      originalExtras.putBoolean(FOREGROUND, false);
//      originalExtras.putBoolean(COLDSTART, !isPushPluginActive);
//      originalExtras.putBoolean(DISMISSED, extras.getBoolean(DISMISSED));
//      originalExtras.putString(ACTION_CALLBACK, extras.getString(CALLBACK));
//      originalExtras.remove(NO_CACHE);
//
//      remoteInput = RemoteInput.getResultsFromIntent(intent);
//      if (remoteInput != null) {
//        String inputString = remoteInput.getCharSequence(INLINE_REPLY).toString();
//        Log.d(LOG_TAG, "response: " + inputString);
//        originalExtras.putString(INLINE_REPLY, inputString);
//      }
//
//      PushPlugin.sendExtras(originalExtras);
//    }
//    return remoteInput == null;
//  }

  public interface StartActivityFun {
    void start(JSONObject extraObj);
  }

  /**
   * Forces the main activity to re-launch if it's unloaded.
   */
  @RequiresApi(api = Build.VERSION_CODES.N)
  private void forceMainActivityReload(boolean startOnBackground) {

//    Intent originalIntent = getIntent();
    Bundle extras = getIntent().getExtras();
    if (extras != null) {

//      launchIntent.putExtras(extras);
//       ClipData data = getIntent().getClipData();
//       launchIntent.setClipData(data);

//       String type = getIntent().getType();
//       if (type!=null) {
//         launchIntent.putExtra("internalType", type);
////         launchIntent.setType(type);
//       }
//      JSONObject obj = null;
      StartActivityFun sendIntent = (JSONObject json) -> {
        PackageManager pm = getPackageManager();
        Intent launchIntent = pm.getLaunchIntentForPackage(getApplicationContext().getPackageName());

        if (json != null) {
          launchIntent.putExtra("json", json.toString());
        }

        launchIntent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP);

//        launchIntent.addFlags(Intent.FLAG_FROM_BACKGROUND);

        launchIntent.putExtra("cdvStartInBackground", false);
        this.startActivity(launchIntent);
      };

      try {
//        obj = Serializer.toJSONObject(getApplicationContext().getContentResolver(), getIntent());
        Serializer.populateAndSendIntent(this, getIntent(), sendIntent);
//        sendIntent.start(obj);

//        launchIntent.putExtra("json", obj.toString());
      } catch (JSONException e) {
        e.printStackTrace();
      }

    }
  }

  @Override
  protected void onResume() {
    super.onResume();
//    final NotificationManager notificationManager = (NotificationManager) this.getSystemService(Context.NOTIFICATION_SERVICE);
//    notificationManager.cancelAll();
  }
}
