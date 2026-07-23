# flutter_local_notifications persists scheduled notifications via Gson and
# reconstructs them in ScheduledNotificationReceiver using
# `new TypeToken<NotificationDetails>() {}` — R8 strips the generic
# signature off that anonymous subclass by default, which makes Gson's
# TypeToken constructor throw "Missing type parameter." at runtime the
# first time a scheduled notification actually fires. Keeping signatures
# and the plugin's/Gson's classes avoids that.
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class com.dexterous.flutterlocalnotifications.** { *; }
