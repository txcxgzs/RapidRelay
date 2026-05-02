# RapidRelay

一个极简的文件中转加速服务。部署在带宽充裕的 VPS 上，将远端文件实时以流式拉取并返回给客户端，有效绕过本地网络瓶颈。原生支持 OneDrive 直链、GitHub Releases 等场景。

## 功能特点

- 🚀 流式实时转发，无需等待完整下载
- 💾 占用内存极低，不占用服务器存储
- 🔗 提供 API 接口，可获取加速下载链接
- 📋 一键复制加速链接，方便分享
- 🔒 支持 HTTP/HTTPS 协议
- 📦 支持 GitHub Releases、OneDrive 等链接
- 🐳 提供 Docker 部署方式

## 快速开始

### 方法一：Node.js 直接部署

```bash
# 安装依赖
npm install

# 启动服务
npm start
```

服务默认监听 3000 端口，可通过环境变量 `PORT` 修改。

### 方法二：Docker 部署

```bash
# 构建镜像
docker build -t rapidrelay .

# 运行容器
docker run -d -p 3000:3000 --name rapidrelay rapidrelay
```

## 使用方法

1. 打开浏览器访问 `http://<your-server-ip>:3000`
2. 在输入框中粘贴文件链接
3. 点击「获取加速链接」生成并复制加速链接，或点击「直接下载」直接下载文件

## API 接口

### GET /api/accelerate

获取加速下载链接：

```
GET http://<your-server-ip>:3000/api/accelerate?url=<原始文件链接>
```

**响应示例：**
```json
{
  "success": true,
  "message": "加速链接生成成功",
  "data": {
    "original_url": "https://github.com/user/repo/releases/download/v1.0.0/file.zip",
    "accelerate_url": "http://<your-server-ip>:3000/download?url=https://github.com/...",
    "usage": "直接访问 accelerate_url 即可进行加速下载"
  }
}
```

### GET /api/info

查看 API 文档和使用说明：

```
GET http://<your-server-ip>:3000/api/info
```

### GET /download

直接下载文件（内部使用）：

```
GET http://<your-server-ip>:3000/download?url=<文件链接>
```

## 支持的链接类型

- GitHub Releases 下载链接
- OneDrive 直链 (onedrive.live.com, 1drv.ms)
- 其他任意 HTTP/HTTPS 直接下载链接

## 技术栈

- Node.js 18+
- Express 4.x
- 原生 HTTP/HTTPS 模块（流式处理）

