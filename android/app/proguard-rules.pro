# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# WorkManager and Room
-keep class androidx.work.** { *; }
-keep class androidx.work.impl.** { *; }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keepclassmembers class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class * extends androidx.work.Worker { *; }
-keep class * extends androidx.work.ListenableWorker { *; }
-keep class * extends androidx.room.RoomDatabase { *; }
-keepclassmembers class * extends androidx.room.RoomDatabase { *; }
-keep class com.flaxplayer.flax.sync.** { *; }
-dontwarn androidx.work.impl.**

# OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**

# Play Core deferred components
-dontwarn com.google.android.play.core.**

