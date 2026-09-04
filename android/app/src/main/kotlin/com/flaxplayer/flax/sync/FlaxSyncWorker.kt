package com.flaxplayer.flax.sync

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.TimeUnit

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

            val cacheDir = File(context.cacheDir, "flaxArtCache")
            if (!cacheDir.exists()) {
                cacheDir.mkdirs()
            }

            // 1. Fetch newest albums from Subsonic / Navidrome API
            val albumListUrl = "$url/rest/getAlbumList2.view?type=newest&size=50&u=$user&t=$token&s=$salt&v=1.16.1&c=Flax&f=json"
            val request = Request.Builder().url(albumListUrl).build()
            val response = okHttpClient.newCall(request).execute()

            if (!response.isSuccessful) {
                return Result.retry()
            }

            val responseBody = response.body?.string() ?: return Result.success()
            val json = JSONObject(responseBody)
            val subsonicResponse = json.optJSONObject("subsonic-response") ?: return Result.success()
            val albumList2 = subsonicResponse.optJSONObject("albumList2")
            val albumArray = albumList2?.optJSONArray("album") ?: JSONArray()

            // 2. Precache missing album covers directly into ArtCache directory
            var coversCached = 0
            for (i in 0 until albumArray.length()) {
                if (isStopped) return Result.retry()

                val album = albumArray.optJSONObject(i) ?: continue
                val coverId = album.optString("coverArt")
                if (coverId.isNotEmpty()) {
                    val cacheKey = "cover-$coverId-512"
                    val targetFile = File(cacheDir, cacheKey)
                    if (!targetFile.exists() || targetFile.length() == 0L) {
                        val coverUrl = "$url/rest/getCoverArt.view?id=$coverId&size=512&u=$user&t=$token&s=$salt&v=1.16.1&c=Flax"
                        val coverReq = Request.Builder().url(coverUrl).build()
                        try {
                            val coverResp = okHttpClient.newCall(coverReq).execute()
                            if (coverResp.isSuccessful && coverResp.body != null) {
                                val temp = File(cacheDir, "$cacheKey.tmp")
                                FileOutputStream(temp).use { out ->
                                    coverResp.body!!.byteStream().copyTo(out)
                                }
                                if (temp.exists() && temp.length() > 0L) {
                                    temp.renameTo(targetFile)
                                    coversCached++
                                }
                            }
                        } catch (_: Exception) {}
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
                                val cacheKey = "cover-$coverId-512"
                                val targetFile = File(cacheDir, cacheKey)
                                if (!targetFile.exists() || targetFile.length() == 0L) {
                                    val coverUrl = "$url/rest/getCoverArt.view?id=$coverId&size=512&u=$user&t=$token&s=$salt&v=1.16.1&c=Flax"
                                    val coverReq = Request.Builder().url(coverUrl).build()
                                    try {
                                        val coverRes = okHttpClient.newCall(coverReq).execute()
                                        if (coverRes.isSuccessful && coverRes.body != null) {
                                            val temp = File(cacheDir, "$cacheKey.tmp")
                                            FileOutputStream(temp).use { out ->
                                                coverRes.body!!.byteStream().copyTo(out)
                                            }
                                            if (temp.exists() && temp.length() > 0L) {
                                                temp.renameTo(targetFile)
                                                coversCached++
                                            }
                                        }
                                    } catch (_: Exception) {}
                                }
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
