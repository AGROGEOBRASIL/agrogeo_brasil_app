import java.util.Properties
import java.io.FileInputStream
import org.gradle.api.GradleException
import java.io.File // Importar a classe File

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") // Necessário para Firebase
}

// Função auxiliar para obter propriedade com verificação de nulo e mensagem clara
fun getKeystoreProperty(properties: Properties, key: String, propertyFilePath: String): String {
    val value = properties.getProperty(key)
    if (value.isNullOrBlank()) {
        throw GradleException("Propriedade '$key' ausente ou vazia no arquivo $propertyFilePath. Verifique se está configurada corretamente.")
    }
    return value
}

val keystoreProperties = Properties()
// O arquivo key.properties DEVE estar em android/app/key.properties
// Usar project.file() resolve o caminho relativo ao diretório do build.gradle.kts atual (android/app)
val keystorePropertiesFile = project.file("key.properties")

if (keystorePropertiesFile.exists()) {
    try {
        FileInputStream(keystorePropertiesFile).use { fis ->
            keystoreProperties.load(fis)
        }
    } catch (e: Exception) {
        throw GradleException("Falha ao carregar o arquivo key.properties de ${keystorePropertiesFile.absolutePath}. Erro: ${e.message}")
    }
} else {
    // Este aviso é importante. Se o arquivo não for encontrado, a build de release falhará.
    println("AVISO: Arquivo key.properties não encontrado em ${keystorePropertiesFile.absolutePath}. A configuração de assinatura para 'release' falhará se este arquivo for necessário.")
}

android {
    signingConfigs {
        create("release") {
            // Tentar carregar as propriedades apenas se o arquivo key.properties existir e foi carregado
            if (keystorePropertiesFile.exists() && !keystoreProperties.isEmpty) {
                try {
                    keyAlias = getKeystoreProperty(keystoreProperties, "keyAlias", keystorePropertiesFile.name)
                    storePassword = getKeystoreProperty(keystoreProperties, "storePassword", keystorePropertiesFile.name)
                    val storeFileValue = getKeystoreProperty(keystoreProperties, "storeFile", keystorePropertiesFile.name)
                    keyPassword = getKeystoreProperty(keystoreProperties, "keyPassword", keystorePropertiesFile.name)

                    // O valor de 'storeFile' (ex: ../../agrogeo_keystore.jks) é relativo ao local do key.properties (android/app/)
                    // project.file() resolve o caminho relativo ao diretório do build.gradle.kts (android/app)
                    val resolvedStoreFile: File = project.file(storeFileValue)
                    this.storeFile = resolvedStoreFile // Atribui à propriedade da DSL do Gradle

                    if (!resolvedStoreFile.exists()) {
                        throw GradleException("Arquivo Keystore (storeFile) não encontrado. Caminho especificado em key.properties (storeFile='$storeFileValue') resolvido para '${resolvedStoreFile.absolutePath}'. Verifique se o caminho está correto e o arquivo existe.")
                    }
                } catch (e: GradleException) {
                    println("ERRO CRÍTICO: Falha ao configurar a assinatura para o build 'release': ${e.message}")
                    println("Verifique o arquivo '${keystorePropertiesFile.absolutePath}' e o caminho para o arquivo keystore.")
                    throw e
                }
            } else {
                // Se o arquivo key.properties não existe ou está vazio, e não estamos em CI, lançar um erro para builds de release.
                // Em CI, pode ser que a assinatura seja gerenciada de outra forma.
                val isCiEnvironment = System.getenv("CI") != null
                if (!isCiEnvironment) {
                    val errorMessage = if (!keystorePropertiesFile.exists()) {
                        "Arquivo key.properties não encontrado em ${keystorePropertiesFile.absolutePath}."
                    } else {
                        "Arquivo key.properties (${keystorePropertiesFile.absolutePath}) está vazio."
                    }
                    throw GradleException("$errorMessage Não é possível configurar a assinatura de release.")
                } else {
                     println("AVISO: key.properties não encontrado ou vazio em ambiente CI. Assumindo que a assinatura será gerenciada externamente.")
                }
            }
        }
    }

    namespace = "br.com.agrogeo.agrogeo_brasil_app"
    compileSdk = 35
    ndkVersion = "27.0.12077973" // ATUALIZADO conforme sugestão do build

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "br.com.agrogeo.agrogeo_brasil_app"
        multiDexEnabled = true
        minSdk = 23 // ATUALIZADO conforme sugestão do build e requisitos do firebase_auth
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
