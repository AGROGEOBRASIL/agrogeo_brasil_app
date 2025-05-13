import org.gradle.api.tasks.Delete
import org.gradle.api.file.Directory

buildscript {
    dependencies {
        // ✅ Versão segura do plugin do Firebase compatível com FlutLab
        classpath("com.google.gms:google-services:4.3.15")
    }
    repositories {
        google()
        mavenCentral()
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// 🔧 Corrige problema de build path para Vercel/Flutter Web se necessário
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// 🔄 Garante que o app seja avaliado primeiro
subprojects {
    project.evaluationDependsOn(":app")
}

// 🧹 Tarefa de clean
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
