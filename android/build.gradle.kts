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
    // 子模块插件（home_widget 0.9.x 等）在各自 build.gradle 里写死
    // jvmTarget 1.8 / Java 1.8：其内联字节码会让 app 侧（JVM 17）在依赖
    // 编译期炸「Cannot inline bytecode built with JVM target 11」；而只把
    // Kotlin 提到 17 又会因 Java/Kotlin 不一致被 AGP 拒编 ⇒ 两边都在
    // 子项目级统一钉到 17。plugins.withId 保证在插件应用后才注册。
    plugins.withId("org.jetbrains.kotlin.android") {
        project.tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>()
            .configureEach {
                compilerOptions.jvmTarget.set(
                    org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17,
                )
            }
    }
    // AGP 的 Java/Kotlin 一致性校验读 javac 任务的 compat；插件自带的
    // Java 1.8 配置会让校验失败，故 library 子项目 Java 也同步 17。
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.gradle.LibraryExtension>("android") {
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
    }
    // JavaCompile 兼容性在项目评估完成后（projectsEvaluated）才能稳定覆盖
    // 全部插件子项目任务，此处直接按名字匹配钉 17。
    project.tasks.whenTaskAdded {
        if (this is JavaCompile) {
            sourceCompatibility = JavaVersion.VERSION_17.toString()
            targetCompatibility = JavaVersion.VERSION_17.toString()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
