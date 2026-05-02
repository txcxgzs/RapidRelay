#!/bin/bash

echo "=========================================="
echo "  RapidRelay 一键部署脚本"
echo "=========================================="

# 检查 Node.js
if ! command -v node &> /dev/null; then
    echo "❌ 错误: 未安装 Node.js"
    echo "请先安装 Node.js: https://nodejs.org/"
    exit 1
fi

# 检查 npm
if ! command -v npm &> /dev/null; then
    echo "❌ 错误: 未安装 npm"
    exit 1
fi

echo "✅ Node.js 版本: $(node -v)"
echo "✅ npm 版本: $(npm -v)"
echo ""

# 安装依赖
echo "📦 正在安装依赖..."
npm install

if [ $? -ne 0 ]; then
    echo "❌ 依赖安装失败"
    exit 1
fi

echo "✅ 依赖安装完成"
echo ""

# 启动服务
echo "🚀 正在启动服务..."
echo ""
echo "=========================================="
echo "  服务已启动!"
echo "  访问地址: http://$(hostname -I | awk '{print $1}'):3000"
echo "=========================================="
echo ""

# 后台运行
nohup npm start > /dev/null 2>&1 &

echo "✅ 服务已在后台运行"
echo "使用 'pm2 logs' 查看日志"
