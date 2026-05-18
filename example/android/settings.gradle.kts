pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
        maven { url = uri("https://jitpack.io") }
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)

    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
        maven { url = uri("https://jitpack.io") }

        // Inject the bundled Paymob SDK local Maven repo from the plugin.
        // .flutter-plugins-dependencies always lives one level above android/ in any
        // Flutter project, so this path is stable for both path: and pub.dev installs.
        val flutterPluginsDeps = file("../.flutter-plugins-dependencies")
        if (flutterPluginsDeps.exists()) {
            @Suppress("UNCHECKED_CAST")
            val json = groovy.json.JsonSlurper().parse(flutterPluginsDeps) as Map<String, Any>
            @Suppress("UNCHECKED_CAST")
            val androidPlugins = ((json["plugins"] as? Map<String, Any>)?.get("android") as? List<Map<String, Any>>) ?: emptyList()
            androidPlugins.find { it["name"] == "flutter_paymob_sdk" }
                ?.get("path")
                ?.let { maven { url = uri("${it}android/libs") } }
        }
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.0" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")
