#!/bin/bash
# ============================================================
#  MapReplacer 编译与安装脚本
#  需要在已安装 Theos 的环境中运行
# ============================================================

# 设置 Theos 环境变量 (按实际路径修改)
export THEOS=~/theos
export THEOS_DEVICE_IP=YOUR_DEVICE_IP
export THEOS_DEVICE_PORT=22

echo "======================================"
echo "  MapReplacer 编译脚本"
echo "======================================"

# 清理旧编译文件
echo "[1/3] 清理旧文件..."
make clean

# 编译
echo "[2/3] 编译中..."
make package

if [ $? -ne 0 ]; then
    echo "❌ 编译失败！请检查错误信息。"
    exit 1
fi

echo "✅ 编译成功！"

# 安装 (需要设备 IP)
echo "[3/3] 安装到设备..."
read -p "是否安装到设备? (y/n): " confirm
if [ "$confirm" = "y" ]; then
    make install
    echo "✅ 安装完成！"
else
    echo "已跳过安装。deb包位于 packages/ 目录。"
fi

echo ""
echo "======================================"
echo "  使用说明："
echo "  1. 将 pak 文件放入 /var/mobile/MapReplacerRes/"
echo "  2. 打开游戏，点击 MAP 悬浮按钮"
echo "  3. 选择要替换的地图并确认"
echo "======================================"
