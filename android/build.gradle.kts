
import org.gradle.api.tasks.compile.JavaCompile
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile
import com.android.build.api.variant.LibraryAndroidComponentsExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()

rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory =
        newBuildDir.dir(project.name)

    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

// Keep Java and Kotlin JVM targets consistent for volume_controller.
subprojects {
    if (project.name == "volume_controller") {
        tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = "11"
            targetCompatibility = "11"
        }

        tasks.withType<KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(
                    org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
                )
            }
        }
    }
}

// Apply Android API 36 to every Android library plugin.
// This also covers plugins that are added later.
subprojects {
    plugins.withId("com.android.library") {
        extensions.configure<LibraryAndroidComponentsExtension> {
            finalizeDsl { androidDsl ->
                androidDsl.compileSdk = 36
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
