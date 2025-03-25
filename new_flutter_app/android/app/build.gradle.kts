plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.new_flutter_app"
    compileSdk = 35  // ★ ここを固定
    ndkVersion = "27.0.12077973"  // ★ ここを修正

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.new_flutter_app"
        minSdk = 21  // ★ `flutter.minSdkVersion` を 21 に固定
        targetSdk = 33  // ★ `flutter.targetSdkVersion` を 33 に固定
        versionCode = 1
        versionName = "1.0.0"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    packagingOptions {
        exclude("META-INF/DEPENDENCIES")
        exclude("META-INF/LICENSE")
        exclude("META-INF/LICENSE.txt")
        exclude("META-INF/NOTICE")
        exclude("META-INF/NOTICE.txt")
    }

    lint {
        // lintエラーを無視する設定
        abortOnError = false
        checkReleaseBuilds = false
        // 必要に応じて個別のエラーを無視する設定も可能
        disable += "DuplicatePlatformClasses"  // 重複クラスエラーを無視
    }
}

dependencies {
    // Google API関連ライブラリ
    implementation("com.google.api-client:google-api-client:1.34.0")
    implementation("com.google.http-client:google-http-client-jackson2:1.41.0")
    implementation("com.google.auth:google-auth-library-oauth2-http:1.16.0")
    implementation("com.google.apis:google-api-services-drive:v3-rev136-1.25.0")
    // 既存のWorkManager依存関係
    implementation("androidx.work:work-runtime:2.10.0")
    implementation("androidx.work:work-runtime-ktx:2.10.0")
}

flutter {
    source = "../.."
}
