package com.flaxplayer.flax

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.webkit.MimeTypeMap
import java.io.File
import java.io.FileNotFoundException

/**
 * Serves stored cover art to Android Auto and Android Automotive.
 *
 * Their media UIs open the Now Playing art URI in their own process, where a
 * file:// path into flax's private storage cannot be read: the large view
 * (left) drew the cover from the bitmap in the session metadata, but the small
 * card (right) loads the URI and showed none. A content:// URI from an exported
 * provider is what they can open.
 *
 * Read-only, and only for files directly inside the art cache:
 * `content://<applicationId>.art/<file name>`.
 */
class FlaxArtProvider : ContentProvider() {
    override fun onCreate(): Boolean = true

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        if (mode != "r") throw SecurityException("Cover art is read-only")
        return ParcelFileDescriptor.open(resolve(uri), ParcelFileDescriptor.MODE_READ_ONLY)
    }

    // Must be an image type: ImageDecoder opens the URI only if it matches
    // image/*. The cache names a file `.file` when the server sent no type.
    override fun getType(uri: Uri): String {
        val extension = uri.lastPathSegment?.substringAfterLast('.', "")?.lowercase()
        val type = extension?.let { MimeTypeMap.getSingleton().getMimeTypeFromExtension(it) }
        return if (type != null && type.startsWith("image/")) type else "image/*"
    }

    /** The art cache file [uri] names, refusing anything outside the cache. */
    private fun resolve(uri: Uri): File {
        val root = File(requireNotNull(context).filesDir, ART_CACHE_DIR).canonicalFile
        val file = uri.pathSegments.singleOrNull()?.let { File(root, it).canonicalFile }
        if (file == null || file.parentFile != root || !file.isFile) {
            throw FileNotFoundException("No stored cover for $uri")
        }
        return file
    }

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor? = null

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int = 0

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0

    companion object {
        /**
         * `ArtCache.key` in lib/shared/widgets/art_cache.dart. The cache keeps its
         * files in the application support directory under that name, which on
         * Android is [android.content.Context.getFilesDir] — not the cache
         * directory, which Android empties when it wants the space.
         */
        private const val ART_CACHE_DIR = "flaxArtCache"
    }
}
