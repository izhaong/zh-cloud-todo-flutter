allprojects {
    repositories {
        // dl.google.com 在部分网络下 TLS 握手失败（curl 直连 000），
        // 阿里云 google 镜像兜底；google() 保留在前，命中顺序不变。
        maven("https://maven.aliyun.com/repository/google")
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
    project.evaluationDependsOn(":app")
    // 子模块插件（home_widget 0.8.x 等）在各自 build.gradle 里写死 jvmTarget 1.8，
    // 其 Kotlin 字节码里的内联函数会让 app 侧（JVM 17）在依赖编译期炸
    // 「Cannot inline bytecode built with JVM target 11」⇒ 子项目 Kotlin/Java
    // 编译统一提到 17。plugins.withId 保证在插件应用后才注册配置。
    plugins.withId("org.jetbrains.kotlin.android") {
        project.tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>()
            .configureEach {
                compilerOptions.jvmTarget.set(
                    org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17,
                )
            }
    }
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.gradle.LibraryExtension>("android") {
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
        // AGP 校验读的是 compileReleaseJavaWithJavac 任务实例上的 compat；
        // LibraryExtension.configure 回填不覆盖已创建任务，任务级再钉一次。
        tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = JavaVersion.VERSION_17.toString()
            targetCompatibility = JavaVersion.VERSION_17.toString()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
