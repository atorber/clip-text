#!/bin/bash

# 获取版本号
VERSION=$(grep "version:" pubspec.yaml | sed 's/version: //' | sed 's/+.*//')

echo "正在构建 ClipText v${VERSION}..."

# 构建APK
flutter build apk --release

if [ $? -eq 0 ]; then
    # 构建成功，重命名APK文件
    SOURCE_APK="build/app/outputs/flutter-apk/app-release.apk"
    TARGET_APK="build/app/outputs/flutter-apk/clip-text-${VERSION}.apk"
    
    if [ -f "$SOURCE_APK" ]; then
        mv "$SOURCE_APK" "$TARGET_APK"
        echo "✅ 构建成功！"
        echo "📦 APK文件: $TARGET_APK"
        echo "📊 文件大小: $(du -h "$TARGET_APK" | cut -f1)"
    else
        echo "❌ 错误: 找不到构建的APK文件"
        exit 1
    fi
else
    echo "❌ 构建失败"
    exit 1
fi 