package org.cagnulen.qdomyoszwift;

import android.app.Activity;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.MediaStore;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;

// The share card of a ride into the phone's Photos (Pictures/Bikemodo), and from there to the
// Android share sheet. A picture in MediaStore shows in Google Photos and the Gallery at once,
// and its content:// address can be handed to any app without a FileProvider.
public class BikemodoShare {
    private static final String FOLDER = "Bikemodo";

    // copies the PNG at path into Pictures/Bikemodo as name, and removes the file at path once it
    // is there; the content:// address, or "" when it could not be saved
    public static String saveToPictures(Context context, String path, String name) {
        try {
            String uri = Build.VERSION.SDK_INT >= 29 ? saveToMediaStore(context, path, name) : saveToFolder(context, path, name);
            if (!uri.isEmpty())
                new File(path).delete();
            return uri;
        } catch (Exception e) {
            QLog.e("BikemodoShare", "Cannot save the picture to Photos", e);
            return "";
        }
    }

    // Android 10 and later: no permission is needed to add a picture of the app's own
    private static String saveToMediaStore(Context context, String path, String name) throws Exception {
        ContentResolver resolver = context.getContentResolver();
        ContentValues values = new ContentValues();
        values.put(MediaStore.Images.Media.DISPLAY_NAME, name);
        values.put(MediaStore.Images.Media.MIME_TYPE, "image/png");
        values.put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/" + FOLDER);
        values.put(MediaStore.Images.Media.IS_PENDING, 1);
        Uri uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values);
        if (uri == null)
            return "";
        try (InputStream in = new FileInputStream(path); OutputStream out = resolver.openOutputStream(uri)) {
            if (out == null)
                throw new Exception("no output stream");
            copy(in, out);
        } catch (Exception e) {
            resolver.delete(uri, null, null);
            throw e;
        }
        values.clear();
        values.put(MediaStore.Images.Media.IS_PENDING, 0);
        resolver.update(uri, values, null, null);
        return uri.toString();
    }

    // Android 9 and older: the shared Pictures folder, which needs storage permission granted
    private static String saveToFolder(Context context, String path, String name) throws Exception {
        File folder = new File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), FOLDER);
        if (!folder.exists() && !folder.mkdirs())
            return "";
        File target = new File(folder, name);
        try (InputStream in = new FileInputStream(path); OutputStream out = new FileOutputStream(target)) {
            copy(in, out);
        }
        // in MediaStore it shows in the Gallery, and its content:// address can be shared
        ContentValues values = new ContentValues();
        values.put(MediaStore.Images.Media.DATA, target.getAbsolutePath());
        values.put(MediaStore.Images.Media.DISPLAY_NAME, name);
        values.put(MediaStore.Images.Media.MIME_TYPE, "image/png");
        Uri uri = context.getContentResolver().insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values);
        return uri != null ? uri.toString() : "";
    }

    private static void copy(InputStream in, OutputStream out) throws Exception {
        byte[] buffer = new byte[64 * 1024];
        int read;
        while ((read = in.read(buffer)) > 0)
            out.write(buffer, 0, read);
    }

    // the Android share sheet with the picture at uri (from saveToPictures)
    public static boolean share(Activity activity, String uri, String title) {
        try {
            Intent send = new Intent(Intent.ACTION_SEND);
            send.setType("image/png");
            send.putExtra(Intent.EXTRA_STREAM, Uri.parse(uri));
            send.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            Intent chooser = Intent.createChooser(send, title);
            chooser.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            activity.startActivity(chooser);
            return true;
        } catch (Exception e) {
            QLog.e("BikemodoShare", "Cannot open the share sheet", e);
            return false;
        }
    }
}
