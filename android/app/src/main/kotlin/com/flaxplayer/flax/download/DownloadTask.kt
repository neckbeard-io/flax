package com.flaxplayer.flax.download

data class DownloadTask(
    val songId: String,
    val serverId: String,
    val title: String,
    val artist: String? = null,
    val downloadUrl: String,
    val destinationPath: String,
    val expectedSizeBytes: Long? = null
)
