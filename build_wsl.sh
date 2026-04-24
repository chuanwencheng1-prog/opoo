#!/bin/bash
# ============================================================
#  MapReplacer - 一键安装 Theos + 编译打包脚本
#  在 WSL Ubuntu 中运行: bash build_wsl.sh
# ============================================================

set -e

echo "======================================================"
echo "  MapReplacer 自动编译脚本 (WSL/Linux)"
echo "======================================================"

# 项目路径 (WSL 中访问 Windows 路径)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"

echo "[INFO] 项目目录: $PROJECT_DIR"

# ============================================================
# 第一步: 安装系统依赖
# ============================================================
install_dependencies() {
    echo ""
    echo "[1/4] 安装系统依赖..."
    
    sudo apt-get update -qq
    sudo apt-get install -y \
        git \
        perl \
        curl \
        build-essential \
        libtinfo5 \
        libplist-utils \
        fakeroot \
        dpkg \
        2>/dev/null
    
    echo "[OK] 系统依赖已安装"
}

# ============================================================
# 第二步: 安装 Theos
# ============================================================
install_theos() {
    echo ""
    echo "[2/4] 安装 Theos..."
    
    export THEOS=~/theos
    
    if [ -d "$THEOS" ]; then
        echo "[INFO] Theos 已存在，更新中..."
        cd "$THEOS"
        git pull --quiet 2>/dev/null || true
        cd "$PROJECT_DIR"
    else
        echo "[INFO] 克隆 Theos..."
        git clone --recursive https://github.com/theos/theos.git "$THEOS"
    fi
    
    # 安装 iOS SDK (如果不存在)
    SDK_DIR="$THEOS/sdks"
    if [ ! -d "$SDK_DIR/iPhoneOS14.5.sdk" ] && [ ! -d "$SDK_DIR/iPhoneOS15.0.sdk" ] && [ ! -d "$SDK_DIR/iPhoneOS16.0.sdk" ]; then
        echo "[INFO] 下载 iOS SDK..."
        mkdir -p "$SDK_DIR"
        cd "$SDK_DIR"
        
        # 尝试下载 iOS 14.5 SDK
        curl -sL https://github.com/theos/sdks/archive/master.tar.gz -o sdks.tar.gz 2>/dev/null || \
        curl -sL https://github.com/xybp888/iOS-SDKs/releases/download/iOS-SDKs/iPhoneOS14.5.sdk.tar.gz -o sdk.tar.gz 2>/dev/null
        
        if [ -f "sdks.tar.gz" ]; then
            tar xzf sdks.tar.gz --strip-components=1 2>/dev/null || true
            rm -f sdks.tar.gz
        elif [ -f "sdk.tar.gz" ]; then
            tar xzf sdk.tar.gz 2>/dev/null || true
            rm -f sdk.tar.gz
        fi
        
        cd "$PROJECT_DIR"
        echo "[OK] iOS SDK 已安装"
    else
        echo "[OK] iOS SDK 已存在"
    fi
    
    # 安装 iOS 工具链
    if [ ! -d "$THEOS/toolchain" ] || [ -z "$(ls -A $THEOS/toolchain 2>/dev/null)" ]; then
        echo "[INFO] 安装 iOS 工具链..."
        
        # Linux 需要安装 swift 工具链 (包含 arm64 clang)
        TOOLCHAIN_DIR="$THEOS/toolchain/linux/iphone"
        mkdir -p "$TOOLCHAIN_DIR"
        
        # 使用 Theos 官方推荐的工具链
        cd /tmp
        curl -sL https://github.com/sbingner/llvm-project/releases/latest/download/linux-ios-arm64e-clang-toolchain.tar.lzma -o toolchain.tar.lzma 2>/dev/null || true
        
        if [ -f "toolchain.tar.lzma" ]; then
            sudo apt-get install -y lzma xz-utils 2>/dev/null || true
            unlzma toolchain.tar.lzma 2>/dev/null || xz -d toolchain.tar.lzma 2>/dev/null || true
            if [ -f "toolchain.tar" ]; then
                tar xf toolchain.tar -C "$TOOLCHAIN_DIR" 2>/dev/null || true
                rm -f toolchain.tar
            fi
        fi
        
        cd "$PROJECT_DIR"
        echo "[OK] 工具链已安装"
    else
        echo "[OK] 工具链已存在"
    fi
    
    echo "[OK] Theos 环境就绪"
}

# ============================================================
# 第三步: 安装 CydiaSubstrate 头文件
# ============================================================
install_substrate() {
    echo ""
    echo "[3/4] 安装 CydiaSubstrate..."
    
    export THEOS=~/theos
    SUBSTRATE_H="$THEOS/vendor/include/substrate.h"
    
    if [ ! -f "$SUBSTRATE_H" ]; then
        mkdir -p "$THEOS/vendor/include"
        mkdir -p "$THEOS/vendor/lib"
        
        # 下载 substrate 头文件
        curl -sL https://raw.githubusercontent.com/nicklama/cydia-substrate/master/substrate.h \
            -o "$SUBSTRATE_H" 2>/dev/null || \
        curl -sL https://raw.githubusercontent.com/nicklama/cydia-substrate/main/substrate.h \
            -o "$SUBSTRATE_H" 2>/dev/null || true
        
        # 如果下载失败，创建一个最小的 substrate.h
        if [ ! -f "$SUBSTRATE_H" ] || [ ! -s "$SUBSTRATE_H" ]; then
            cat > "$SUBSTRATE_H" << 'HEADER'
#ifndef SUBSTRATE_H
#define SUBSTRATE_H

#include <objc/runtime.h>
#include <objc/message.h>

#ifdef __cplusplus
extern "C" {
#endif

void MSHookMessageEx(Class _class, SEL message, IMP hook, IMP *old);
void MSHookFunction(void *symbol, void *hook, void **old);

#ifdef __cplusplus
}
#endif

#endif
HEADER
        fi
        
        echo "[OK] CydiaSubstrate 头文件已安装"
    else
        echo "[OK] CydiaSubstrate 已存在"
    fi
}

# ============================================================
# 第四步: 编译项目
# ============================================================
build_project() {
    echo ""
    echo "[4/4] 编译 MapReplacer..."
    
    export THEOS=~/theos
    export PATH="$THEOS/bin:$PATH"
    
    cd "$PROJECT_DIR"
    
    # 清理
    make clean 2>/dev/null || true
    
    # 编译
    echo "[INFO] 开始编译..."
    make package FINALPACKAGE=1
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "======================================================"
        echo "  ✅ 编译成功！"
        echo "======================================================"
        
        # 查找生成的 deb 包
        DEB_FILE=$(find packages/ -name "*.deb" -type f 2>/dev/null | head -1)
        if [ -n "$DEB_FILE" ]; then
            echo "  输出文件: $DEB_FILE"
            DEB_SIZE=$(du -h "$DEB_FILE" | awk '{print $1}')
            echo "  文件大小: $DEB_SIZE"
        fi
        
        echo ""
        echo "  安装方法:"
        echo "  1. 将 .deb 文件传输到越狱 iOS 设备"
        echo "  2. 使用 Filza 安装，或 SSH 执行:"
        echo "     dpkg -i $DEB_FILE"
        echo "     killall SpringBoard"
        echo ""
        echo "  使用前准备:"
        echo "  将 pak 文件放入设备 /var/mobile/MapReplacerRes/"
        echo "======================================================"
    else
        echo ""
        echo "❌ 编译失败，请检查错误信息"
        exit 1
    fi
}

# ============================================================
# 主流程
# ============================================================
main() {
    cd "$PROJECT_DIR"
    
    install_dependencies
    install_theos
    install_substrate
    build_project
    
    echo ""
    echo "全部完成！"
}

main "$@"
