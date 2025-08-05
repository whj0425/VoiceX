#!/bin/bash

# VoiceX Release 构建脚本
# 每次构建后复制到固定位置，确保总是最新版本

echo "🚀 开始构建 VoiceX Release 版本..."

# 设置目录
RELEASE_DIR="./release"
APP_NAME="VoiceX.app"

# 清理旧版本
echo "🧹 清理旧版本..."
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

# 构建Release版本
echo "🔨 构建应用..."
xcodebuild -project VoiceX.xcodeproj -scheme VoiceX -configuration Release build

if [ $? -eq 0 ]; then
    # 查找构建产物
    BUILT_APP=$(find ~/Library/Developer/Xcode/DerivedData -name "VoiceX.app" -path "*/Build/Products/Release/VoiceX.app" | head -1)
    
    if [ -n "$BUILT_APP" ]; then
        echo "📦 复制应用到release目录..."
        cp -R "$BUILT_APP" "$RELEASE_DIR/"
        
        echo "✅ 构建成功！"
        echo "📦 应用位置: $PWD/$RELEASE_DIR/$APP_NAME"
        echo ""
        echo "🔧 使用方法:"
        echo "1. 双击打开: open '$PWD/$RELEASE_DIR/$APP_NAME'"
        echo "2. 复制到应用程序: cp -R '$PWD/$RELEASE_DIR/$APP_NAME' /Applications/"
        echo ""
        
        # 验证Info.plist中的LSUIElement
        if grep -q "<key>LSUIElement</key>" "$RELEASE_DIR/$APP_NAME/Contents/Info.plist"; then
            echo "✅ LSUIElement 配置正确（无Dock图标）"
        else
            echo "⚠️ LSUIElement 配置可能有问题"
        fi
    else
        echo "❌ 找不到构建产物！"
        exit 1
    fi
else
    echo "❌ 构建失败！"
    exit 1
fi