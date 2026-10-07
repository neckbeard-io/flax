package com.flaxplayer.flax.sync

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.TimeUnit

private const val NIGHTLY_INBOX = "flaxArtInbox"

class FlaxSyncWorker(
    private val context: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(context, workerParams) {

    private val okHttpClient = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    override suspend fun doWork(): Result {
        try {
            val server = getActiveServer() ?: return Result.success()
            val url = server.optString("url").trimEnd('/')
            val user = server.optString("username")
            val token = server.optString("tokenHash")
            val salt = server.optString("salt")

            if (url.isEmpty() || user.isEmpty() || token.isEmpty() || salt.isEmpty()) {
                return Result.success()
            }

            // The app files these into its cover store on its next launch or
            // sync (CoverArtCache.importNightlyCovers). Written straight into
            // the store's folder they were never indexed, so no screen found
            // them.
            val cacheDir = File(context.filesDir, NIGHTLY_INBOX)
            if (!cacheDir.exists()) {
                cacheDir.mkdirs()
            }

            val metaConfig = server.optJSONObject("metadataCacheConfig")
            val fullMetadata = metaConfig?.optBoolean("backgroundSyncFullMetadata", false) ?: false
            val albumSize = requestSize(metaConfig?.optString("albumArtQuality"))
            val artistSize = requestSize(metaConfig?.optString("artistArtQuality"))
            stored = StoredCovers(context)

            if (fullMetadata) {
                // 1. Full Library Deep Scan: Paginate all albums and fill in missing covers
                var offset = 0
                val pageSize = 200
                while (!isStopped) {
                    val albumListUrl = "$url/rest/getAlbumList2.view?type=alphabeticalByName&size=$pageSize&offset=$offset&u=$user&t=$token&s=$salt&v=1.16.1&c=Flax&f=json"
                    val request = Request.Builder().url(albumListUrl).build()
                    val response = okHttpClient.newCall(request).execute()
                    if (!response.isSuccessful) break
                    val responseBody = response.body?.string() ?: break
                    val json = JSONObject(responseBody)
                    val subsonicResponse = json.optJSONObject("subsonic-response") ?: break
                    val albumList2 = subsonicResponse.optJSONObject("albumList2")
                    val albumArray = albumList2?.optJSONArray("album") ?: JSONArray()
                    if (albumArray.length() == 0) break

                    for (i in 0 until albumArray.length()) {
                        if (isStopped) return Result.retry()
                        val album = albumArray.optJSONObject(i) ?: continue
                        val coverId = album.optString("coverArt")
                        if (coverId.isNotEmpty()) {
                            precacheCover(url, user, token, salt, coverId, albumSize, cacheDir)
                        }
                    }

                    if (albumArray.length() < pageSize) break
                    offset += pageSize
                }

                // 2. Fetch all artists to precache missing artist avatars
                if (!isStopped) {
                    try {
                        val artistsUrl = "$url/rest/getArtists.view?u=$user&t=$token&s=$salt&v=1.16.1&c=Flax&f=json"
                        val artistsReq = Request.Builder().url(artistsUrl).build()
                        val artistsResp = okHttpClient.newCall(artistsReq).execute()
                        if (artistsResp.isSuccessful && artistsResp.body != null) {
                            val artistsBody = artistsResp.body!!.string()
                            val artistsSub = JSONObject(artistsBody).optJSONObject("subsonic-response")?.optJSONObject("artists")
                            val indexArray = artistsSub?.optJSONArray("index") ?: JSONArray()
                            for (i in 0 until indexArray.length()) {
                                if (isStopped) return Result.retry()
                                val indexObj = indexArray.optJSONObject(i) ?: continue
                                val artistArray = indexObj.optJSONArray("artist") ?: JSONArray()
                                for (j in 0 until artistArray.length()) {
                                    if (isStopped) return Result.retry()
                                    val artist = artistArray.optJSONObject(j) ?: continue
                                    val coverId = artist.optString("coverArt")
                                    if (coverId.isNotEmpty()) {
                                        precacheCover(url, user, token, salt, coverId, artistSize, cacheDir)
                                    }
                                }
                            }
                        }
                    } catch (_: Exception) {}
                }
            } else {
                // Light Scan: Fetch newest 50 albums from Subsonic / Navidrome API
                val albumListUrl = "$url/rest/getAlbumList2.view?type=newest&size=50&u=$user&t=$token&s=$salt&v=1.16.1&c=Flax&f=json"
                val request = Request.Builder().url(albumListUrl).build()
                val response = okHttpClient.newCall(request).execute()

                if (response.isSuccessful && response.body != null) {
                    val json = JSONObject(response.body!!.string())
                    val subsonicResponse = json.optJSONObject("subsonic-response")
                    val albumList2 = subsonicResponse?.optJSONObject("albumList2")
                    val albumArray = albumList2?.optJSONArray("album") ?: JSONArray()
                    for (i in 0 until albumArray.length()) {
                        if (isStopped) return Result.retry()
                        val album = albumArray.optJSONObject(i) ?: continue
                        val coverId = album.optString("coverArt")
                        if (coverId.isNotEmpty()) {
                            precacheCover(url, user, token, salt, coverId, albumSize, cacheDir)
                        }
                    }
                }
            }

            // 3. Fetch starred items to precache favorite album covers
            if (!isStopped) {
                try {
                    val starredUrl = "$url/rest/getStarred2.view?u=$user&t=$token&s=$salt&v=1.16.1&c=Flax&f=json"
                    val starredReq = Request.Builder().url(starredUrl).build()
                    val starredResp = okHttpClient.newCall(starredReq).execute()
                    if (starredResp.isSuccessful && starredResp.body != null) {
                        val starredJson = JSONObject(starredResp.body!!.string())
                        val starredSub = starredJson.optJSONObject("subsonic-response")?.optJSONObject("starred2")
                        val starredAlbums = starredSub?.optJSONArray("album") ?: JSONArray()
                        for (i in 0 until starredAlbums.length()) {
                            if (isStopped) return Result.retry()
                            val album = starredAlbums.optJSONObject(i) ?: continue
                            val coverId = album.optString("coverArt")
                            if (coverId.isNotEmpty()) {
                                precacheCover(url, user, token, salt, coverId, albumSize, cacheDir)
                            }
                        }
                    }
                } catch (_: Exception) {}
            }

            // Record successful background sync timestamp
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.edit().putLong("flutter.last_background_sync_timestamp", System.currentTimeMillis()).apply()

            return Result.success()
        } catch (e: Exception) {
            return Result.retry()
        } finally {
            stored?.close()
            stored = null
        }
    }

    private var stored: StoredCovers? = null

    /** The size the app's quality setting asks for: null for the original, 0 when disabled. */
    private fun requestSize(quality: String?): Int? = when (quality) {
        "low" -> 256
        "original" -> null
        "disabled" -> 0
        else -> 512
    }

    private fun precacheCover(
        url: String,
        user: String,
        token: String,
        salt: String,
        coverId: String,
        size: Int?,
        cacheDir: File
    ): Boolean {
        if (size == 0) return false
        // coverCacheKey in lib/shared/widgets/cover_art_cache.dart.
        val cacheKey = "cover-$coverId-${size ?: "orig"}"
        if (stored?.contains(cacheKey) == true) return false
        val targetFile = File(cacheDir, cacheKey)
        if (targetFile.exists() && targetFile.length() > 0L) {
            return false // Already cached! Fill-in-the-blanks skips immediately
        }
        val sizeParam = if (size != null) "&size=$size" else ""
        val coverUrl = "$url/rest/getCoverArt.view?id=$coverId$sizeParam&u=$user&t=$token&s=$salt&v=1.16.1&c=Flax"
        val coverReq = Request.Builder().url(coverUrl).build()
        return try {
            val coverResp = okHttpClient.newCall(coverReq).execute()
            if (coverResp.isSuccessful && coverResp.body != null) {
                val temp = File(cacheDir, "$cacheKey.tmp")
                FileOutputStream(temp).use { out ->
                    coverResp.body!!.byteStream().copyTo(out)
                }
                if (temp.exists() && temp.length() > 0L) {
                    temp.renameTo(targetFile)
                    true
                } else false
            } else false
        } catch (_: Exception) {
            false
        }
    }

    /**
     * Read-only view of the app's cover store index: flutter_cache_manager's
     * `flaxArtCache.db`, next to the store's folder in the application support
     * directory. Lets the worker skip covers the app already has instead of
     * downloading the whole library again every night.
     */
    private class StoredCovers(context: Context) : AutoCloseable {
        private val folder = File(context.filesDir, "flaxArtCache")
        private val db: SQLiteDatabase? = try {
            val file = File(context.filesDir, "flaxArtCache.db")
            if (file.exists()) {
                SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READONLY)
            } else {
                null
            }
        } catch (_: Exception) {
            null
        }

        fun contains(key: String): Boolean {
            val database = db ?: return false
            return try {
                database.rawQuery(
                    "SELECT relativePath FROM cacheObject WHERE key = ? LIMIT 1",
                    arrayOf(key),
                ).use { cursor ->
                    cursor.moveToFirst() && File(folder, cursor.getString(0)).isFile
                }
            } catch (_: Exception) {
                false
            }
        }

        override fun close() {
            try {
                db?.close()
            } catch (_: Exception) {}
        }
    }

    private fun getActiveServer(): JSONObject? {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val rawServers = prefs.getString("flutter.flax_servers", null) ?: return null
        return try {
            val array = JSONArray(rawServers)
            for (i in 0 until array.length()) {
                val s = array.getJSONObject(i)
                if (s.optBoolean("isActive", false)) {
                    return s
                }
            }
            if (array.length() > 0) array.getJSONObject(0) else null
        } catch (_: Exception) {
            null
        }
    }
}
