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
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// printing (and similar plugins) set compileSdk 30, which breaks
// verifyReleaseResources on android:attr/lStar. Override after their
// build.gradle runs. Avoid evaluationDependsOn(":app") so afterEvaluate works.
subprojects {
    afterEvaluate {
        extensions.findByType<com.android.build.gradle.LibraryExtension>()?.apply {
            compileSdk = 34
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
