# 1. Keep the Paymob SDK internal classes
-keep class com.paymob.** { *; }
-dontwarn com.paymob.**

# 2. Keep Retrofit/OkHttp (used for API calls)
-keep class retrofit2.** { *; }
-keep class okhttp3.** { *; }
-dontwarn retrofit2.**
-dontwarn okhttp3.**

# 3. Keep GSON (prevents renaming of JSON data models)
-keep class com.google.gson.** { *; }

# 4. Keep Koin (Paymob uses this for Dependency Injection)
-keep class io.insertkoin.** { *; }

# 5. Keep AndroidX Navigation (common crash point for SDK screens)
-keep class androidx.navigation.** { *; }