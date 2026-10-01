plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    ndkVersion = "29.0.13846066"
    namespace = "com.lhg.notes"
    compileSdk = 36
    buildFeatures {
        buildConfig = true
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.lhg.notes"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            // 设置支持的SO库架构
            abiFilters.add("arm64-v8a")
            //abiFilters.add("armeabi-v7a")
        }
    }

    flavorDimensions.add("device")
    productFlavors {
        create("phone") {
            dimension = "device"
            applicationIdSuffix = ".phone"
            buildConfigField("String", "DEVICE_TYPE", "\"phone\"")
            resValue("string", "app_name", "Note123")
            isDefault = true  // 设置为默认flavor
        }
        create("pad") {
            dimension = "device"
            applicationIdSuffix = ".pad"
            buildConfigField("String", "DEVICE_TYPE", "\"pad\"")
            resValue("string", "app_name", "Note123Pad")
        }
    }

    signingConfigs {
        create("release") {
            storeFile = file("keystore.jks")
            storePassword = "123456"
            keyAlias = "all"
            keyPassword = "123456"
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("release")
        }
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }

}

flutter {
    source = "../.."
}
