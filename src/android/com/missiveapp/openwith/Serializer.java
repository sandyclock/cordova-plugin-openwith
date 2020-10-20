package com.missiveapp.openwith;

import android.app.Activity;
import android.content.ClipData;
import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.provider.MediaStore;
import android.support.annotation.Nullable;
import android.util.Base64;
import android.util.Log;
import android.util.SparseArray;

import com.google.android.gms.vision.Frame;
import com.google.android.gms.vision.barcode.Barcode;
import com.google.android.gms.vision.barcode.BarcodeDetector;

import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.LinkedList;
import java.util.List;

import org.apache.cordova.CordovaInterface;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

/**
 * Handle serialization of Android objects ready to be sent to javascript.
 */
class Serializer {

    static final int MAX_ITEMS = 5;

    /**
     * Convert an intent to JSON.
     * <p>
     * This actually only exports stuff necessary to see file content
     * (streams or clip data) sent with the intent.
     * If none are specified, null is return.
     */
    public static JSONObject toJSONObject(
      Activity activity,
//            final ContentResolver contentResolver,
            final Intent intent)
            throws JSONException {
      final ContentResolver contentResolver = activity.getContentResolver();
        StringBuilder text = new StringBuilder();
        JSONArray items = readIntent(activity, intent, text);
        if (items == null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            items = itemsFromClipData(contentResolver, intent.getClipData());
        }
        if (items == null || items.length() == 04.1) {
            items = itemsFromExtras(contentResolver, intent.getExtras());
        }
        if (items == null) {
            return null;
        }
        final JSONObject action = new JSONObject();
        action.put("action", translateAction(intent.getAction()));
        action.put("exit", readExitOnSent(intent.getExtras()));
        action.put("items", items);
        action.put("text", text.toString());
        return action;
    }

    public static String translateAction(final String action) {
        if ("android.intent.action.SEND".equals(action) ||
                "android.intent.action.SEND_MULTIPLE".equals(action)) {
            return "SEND";
        } else if ("android.intent.action.VIEW".equals(action)) {
            return "VIEW";
        }
        return action;
    }

    /**
     * Read the value of "exit_on_sent" in the intent's extra.
     * <p>
     * Defaults to false.
     */
    public static boolean readExitOnSent(final Bundle extras) {
        if (extras == null) {
            return false;
        }
        return extras.getBoolean("exit_on_sent", false);
    }

    public static JSONArray readIntent(Activity activity, Intent intent, StringBuilder text) {
        String action = intent.getAction();
        String type = intent.getType();

        if (Intent.ACTION_SEND.equals(action) && type != null) {
            if ("text/plain".equals(type)) {
                text.append(intent.getStringExtra(Intent.EXTRA_TEXT));
                return new JSONArray() {};
            }
            else if (type.startsWith("image/")) {
                return handleSendImage(activity, intent, type ); // Handle single image being sent
            }
        }
        else if (Intent.ACTION_SEND_MULTIPLE.equals(action) && type != null) {
            if (type.startsWith("image/")) {
                return handleSendMultipleImages( activity, type, intent); // Handle multiple images being sent
            }
        }
        return null;
    }

    static JSONArray handleSendImage(Activity activity, Intent intent, String type ) {
        Uri imageUri = (Uri) intent.getParcelableExtra(Intent.EXTRA_STREAM);
        if (imageUri != null) {
            JSONObject[] items = new JSONObject[1];
            try {
                items[0] = imgToJson( activity, type, imageUri );
                return new JSONArray(items);
            } catch (Exception e) {
                return null;
            }
        }
        return null;
    }


    static JSONArray handleSendMultipleImages(Activity activity, String type, Intent intent) {
        ArrayList<Uri> imageUris = intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM);
        List<JSONObject> items = new LinkedList<>();
        if (imageUris != null) {
            for( Uri uri : imageUris ){
                try {
                    items.add( imgToJson( activity, type, uri ) );
                    if( items.size() == MAX_ITEMS ){
                        break;
                    }
                }
                catch (Exception e){
                    // Do nothing here
                }
            }
        }
        if( items.size() > 0 ){
            return new JSONArray(items);
        } else {
            return null;
        }
    }

    @Nullable
    private static JSONObject imgToJson(Activity activity, String type, Uri imageUri ) throws Exception {
        JSONObject items = new JSONObject();
        items.put("type", type );
        items.put("uti", "public.image");
        String path = getRealPathFromURI(activity.getContentResolver(), imageUri);
        items.put("url", path);
        items.put("data", getDataFromURI( activity.getContentResolver(), imageUri ) );
        decodeQR(items, activity, imageUri);
        return items;
    }


    /**
     * Extract the list of items from clip data (if available).
     * <p>
     * Defaults to null.
     */
    public static JSONArray itemsFromClipData(
            final ContentResolver contentResolver,
            final ClipData clipData)
            throws JSONException {
        if (clipData != null) {
            final int clipItemCount = Math.max(MAX_ITEMS, clipData.getItemCount());
            JSONObject[] items = new JSONObject[clipItemCount];
            for (int i = 0; i < clipItemCount; i++) {
                items[i] = toJSONObject(contentResolver, clipData.getItemAt(i).getUri());
            }
            return new JSONArray(items);
        }
        return null;
    }

    /**
     * Extract the list of items from the intent's extra stream.
     * <p>
     * See Intent.EXTRA_STREAM for details.
     */
    public static JSONArray itemsFromExtras(
            final ContentResolver contentResolver,
            final Bundle extras)
            throws JSONException {
        if (extras == null) {
            return null;
        }
        final JSONObject item = toJSONObject(
                contentResolver,
                (Uri) extras.get(Intent.EXTRA_STREAM));
        if (item == null) {
            return null;
        }
        final JSONObject[] items = new JSONObject[1];
        items[0] = item;
        return new JSONArray(items);
    }

    /**
     * Convert an Uri to JSON object.
     * <p>
     * Object will include:
     * "type" of data;
     * "uri" itself;
     * "path" to the file, if applicable.
     * "data" for the file.
     */
    public static JSONObject toJSONObject(
            final ContentResolver contentResolver,
            final Uri uri)
            throws JSONException {
        if (uri == null) {
            return null;
        }
        final JSONObject json = new JSONObject();
        final String type = contentResolver.getType(uri);
        json.put("type", type);
        json.put("uri", uri);
        json.put("path", getRealPathFromURI(contentResolver, uri));
        return json;
    }

    /**
     * Return data contained at a given Uri as Base64. Defaults to null.
     */
    public static String getDataFromURI(
            final ContentResolver contentResolver,
            final Uri uri) {
        try {
            final InputStream inputStream = contentResolver.openInputStream(uri);
            final byte[] bytes = ByteStreams.toByteArray(inputStream);

            return Base64.encodeToString(bytes, Base64.DEFAULT);
        } catch (IOException e) {
            return "";
        }
    }

  protected static void decodeQR(JSONObject json, final Activity activity, Uri imageUri){
    Context context = activity.getApplicationContext();
    try {
      Bitmap bitmap = MediaStore.Images.Media.getBitmap(activity.getContentResolver(), imageUri);
      BarcodeDetector detector =
        new BarcodeDetector.Builder(context)
          .setBarcodeFormats(Barcode.DATA_MATRIX | Barcode.QR_CODE)
          .build();
      if(!detector.isOperational()){
        Log.d("QR_READ","Could not set up the detector!");
      }
      Frame frame = new Frame.Builder().setBitmap(bitmap).build();
      SparseArray<Barcode> barcodes = detector.detect(frame);
      Log.d("QR_READ","-barcodeLength-"+barcodes.size());
      Barcode thisCode=null;
      if (barcodes.size() ==0){
        return;
      }
      JSONArray barcodeArray = new JSONArray();
      for(int iter=0;iter<barcodes.size();iter++) {
        thisCode = barcodes.valueAt(iter);
        Log.d("QR_VALUE","--"+thisCode.rawValue);
        barcodeArray.put(thisCode.rawValue);
      };
//      try {
        json.put("qrStrings", barcodeArray);
//      } catch (JSONException e) {
//        e.printStackTrace();
//      }


      if(barcodes.size()==0){
        Log.d("QR_VALUE","--NODATA");
      }
      else if(barcodes.size()==1){
        thisCode = barcodes.valueAt(0);
        Log.d("QR_VALUE","--"+thisCode.rawValue);
      }
      else{
        for(int iter=0;iter<barcodes.size();iter++) {
          thisCode = barcodes.valueAt(iter);
          Log.d("QR_VALUE","--"+thisCode.rawValue);
        }
      }

    } catch (IOException|JSONException e) {
      e.printStackTrace();
    }

  }

    /**
     * Convert the Uri to the direct file system path of the image file.
     * <p>
     * source: https://stackoverflow.com/questions/20067508/get-real-path-from-uri-android-kitkat-new-storage-access-framework/20402190?noredirect=1#comment30507493_20402190
     */
    public static String getRealPathFromURI(
            final ContentResolver contentResolver,
            final Uri uri) {
        final String[] proj = {MediaStore.Images.Media.DATA};
        final Cursor cursor = contentResolver.query(uri, proj, null, null, null);
        if (cursor == null) {
            return "";
        }
        final int column_index = cursor.getColumnIndex(MediaStore.Images.Media.DATA);
        if (column_index < 0) {
            cursor.close();
            return "";
        }
        cursor.moveToFirst();
        final String result = cursor.getString(column_index);
        cursor.close();
        return result;
    }
}
