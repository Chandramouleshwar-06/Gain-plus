# Release builds are shrunk with R8 (Flutter turns it on); keep what
# plugins look up by reflection.

# flutter_local_notifications stores scheduled notifications with Gson,
# which needs generic type information (rules from the Gson project).
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod, InnerClasses
-dontwarn sun.misc.**
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# Home-screen widget provider is created by the system from the manifest.
-keep class com.tracker1.gainplus.GainPlusWidgetProvider { *; }
