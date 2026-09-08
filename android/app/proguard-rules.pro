# Flutter's own rules come from the engine AAR; these cover the plugins we ship.
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**

# url_launcher / share_plus resolve activities reflectively.
-keep class androidx.core.content.FileProvider { *; }

# Keep annotations used by the Play Core split-install stubs Flutter references.
-dontwarn com.google.android.play.core.**
