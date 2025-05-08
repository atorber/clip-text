# ClipText - 智能音频转文字应用

ClipText 是一款 Android 应用，可以录制系统音频并将其转换为文字。它支持实时转写、智能摘要生成、关键词提取等功能。

## 功能特点

- 系统音频录制：支持录制其他应用的音频
- 实时语音转写：支持在线/离线转写
- 智能文本处理：自动生成摘要和关键词
- 文本编辑：支持编辑转写结果
- 关键词搜索：快速检索历史记录
- 分享功能：支持分享音频和文本

## 系统要求

- Android 10.0 (API 29) 或更高版本
- 最小 SDK 版本：29
- 目标 SDK 版本：34
- Kotlin 版本：1.9.0 或更高
- Java 版本：17

## 开发环境设置

1. 安装必要工具：
   - Android Studio Hedgehog (2023.1.1) 或更高版本
   - Android SDK
   - Android NDK (如果需要原生开发)

2. 克隆项目：
```bash
git clone https://github.com/atorber/clip-text.git
cd clip-text
```

3. 配置开发者密钥：

### 创建开发者密钥

1. 使用 Android Studio 创建密钥：
   - 打开 Android Studio
   - 选择 "Build" > "Generate Signed Bundle / APK"
   - 点击 "Create new keystore"
   - 填写以下信息：
     ```
     Key store path: [项目目录]/keystore.jks
     Password: 设置密钥库密码
     Alias: 设置密钥别名
     Password: 设置密钥密码
     Validity (years): 25（或更长）
     Certificate: 
       First and Last Name: 您的姓名
       Organizational Unit: 部门名称
       Organization: 公司/组织名称
       City or Locality: 城市
       State or Province: 省份
       Country Code: CN
     ```
   - 点击 "OK" 生成密钥库文件

2. 使用命令行创建密钥：
```bash
keytool -genkey -v -keystore keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias your_key_alias
```

3. 查看密钥信息：
```bash
keytool -list -v -keystore keystore.jks
```

### 配置密钥

1. 将生成的 `keystore.jks` 文件复制到项目根目录或安全位置

2. 在项目根目录创建 `local.properties` 文件（注意：不要提交到版本控制）：
```properties
sdk.dir=/path/to/your/android/sdk
RELEASE_STORE_FILE=/path/to/your/keystore.jks
RELEASE_STORE_PASSWORD=your_store_password
RELEASE_KEY_ALIAS=your_key_alias
RELEASE_KEY_PASSWORD=your_key_password
```

3. 在 `app/build.gradle.kts` 中配置签名：
```kotlin
android {
    signingConfigs {
        create("release") {
            val localProperties = gradleLocalProperties(rootDir)
            storeFile = file(localProperties.getProperty("RELEASE_STORE_FILE"))
            storePassword = localProperties.getProperty("RELEASE_STORE_PASSWORD")
            keyAlias = localProperties.getProperty("RELEASE_KEY_ALIAS")
            keyPassword = localProperties.getProperty("RELEASE_KEY_PASSWORD")
        }
    }
    
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}
```

### 应用商店开发者账号申请

1. Google Play 开发者账号：
   - 访问 [Google Play Console](https://play.google.com/console)
   - 点击 "开始使用"
   - 支付 25 美元一次性注册费
   - 完善开发者信息
   - 等待审核通过（通常 2-3 个工作日）

2. 国内应用商店：

   a. 华为应用市场：
   - 访问 [华为开发者联盟](https://developer.huawei.com)
   - 注册华为开发者账号
   - 完成企业/个人认证
   - 缴纳 300 元保证金（可退）

   b. 小米应用商店：
   - 访问 [小米开放平台](https://dev.mi.com)
   - 注册开发者账号
   - 完成实名认证
   - 无需缴纳费用

   c. OPPO 软件商店：
   - 访问 [OPPO 开放平台](https://open.oppomobile.com)
   - 注册开发者账号
   - 完成身份认证
   - 无需缴纳费用

   d. vivo 应用商店：
   - 访问 [vivo 开发者平台](https://dev.vivo.com.cn)
   - 注册开发者账号
   - 完成实名认证
   - 无需缴纳费用

### 密钥安全建议

1. 备份密钥：
   - 将 keystore 文件备份到安全位置
   - 记录密钥信息（密码、别名等）
   - 建议使用密码管理器保存

2. 保护密钥：
   - 不要将 keystore 文件提交到版本控制
   - 在 `.gitignore` 中添加以下内容：
     ```
     *.jks
     *.keystore
     local.properties
     ```
   - 在团队内安全传递密钥信息

3. CI/CD 配置：
   - 使用环境变量存储密钥信息
   - 使用加密服务保存密钥文件
   - 设置访问权限控制

## 编译指南

### 开发版本编译

1. 在 Android Studio 中打开项目
2. 选择 "Build" > "Make Project" 或使用快捷键 Cmd+F9 (Mac) / Ctrl+F9 (Windows)
3. 等待 Gradle 同步和编译完成

命令行编译：
```bash
# 清理项目
./gradlew clean

# 编译调试版本
./gradlew assembleDebug

# 运行单元测试
./gradlew test

# 运行 UI 测试
./gradlew connectedAndroidTest
```

### 发布版本编译

1. 更新版本信息：
   - 在 `app/build.gradle.kts` 中修改版本号：
```kotlin
android {
    defaultConfig {
        versionCode = xxx  // 递增版本号
        versionName = "x.x.x"  // 版本名称
    }
}
```

2. 生成发布版本：
```bash
# 生成发布版 APK
./gradlew assembleRelease

# 生成发布版 Bundle
./gradlew bundleRelease
```

编译后的文件位置：
- APK: `app/build/outputs/apk/release/app-release.apk`
- Bundle: `app/build/outputs/bundle/release/app-release.aab`

## 发布流程

1. 测试准备：
   - 运行所有单元测试和 UI 测试
   - 在不同设备上进行功能测试
   - 检查 Proguard 混淆规则

2. 签名配置：
   - 确保 `keystore.jks` 文件配置正确
   - 验证签名配置在 `app/build.gradle.kts` 中正确设置

3. Google Play 发布：
   - 登录 [Google Play Console](https://play.google.com/console)
   - 创建新版本发布
   - 上传 AAB 或 APK 文件
   - 填写版本说明
   - 提交审核

4. 其他应用商店发布：
   - 小米应用商店
   - 华为应用市场
   - OPPO 软件商店
   - vivo 应用商店

## 常见问题

1. 编译错误：
   - 检查 Gradle 版本是否匹配
   - 确保所有依赖项都已正确配置
   - 验证 SDK 路径配置

2. 运行时崩溃：
   - 检查 AndroidManifest.xml 中的权限声明
   - 确保目标设备 API 级别符合要求
   - 查看 Logcat 日志定位具体原因

3. 签名问题：
   - 确保密钥库文件存在且配置正确
   - 验证密钥库密码和别名
   - 检查 Gradle 签名配置

## 贡献指南

1. Fork 项目
2. 创建特性分支：`git checkout -b feature/AmazingFeature`
3. 提交更改：`git commit -m 'Add some AmazingFeature'`
4. 推送分支：`git push origin feature/AmazingFeature`
5. 提交 Pull Request

## 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

## 联系方式

- 项目维护者：[LuChao]
- 邮箱：[atorber@163.com]
- 项目主页：[https://github.com/atorber/clip-text]

