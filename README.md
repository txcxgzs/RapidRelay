# RapidRelay

一个极简的文件中转加速服务。部署在带宽充裕的 VPS 上，将远端文件实时以流式拉取并返回给客户端，有效绕过本地网络瓶颈。原生支持 OneDrive 直链、GitHub Releases 等场景。

## 功能特点

- 🚀 流式实时转发，无需等待完整下载
- 💾 占用内存极低，不占用服务器存储
- 🔗 提供 API 接口，可获取加速链接
- 📋 一键复制加速链接，方便分享
- 📊 实时统计面板
- 🔒 支持 HTTP/HTTPS 协议
- 📦 支持 GitHub Releases、OneDrive 等链接

## 一键部署

```bash
# 克隆项目
git clone https://github.com/txcxgzs/RapidRelay.git
cd RapidRelay

# 一键部署
chmod +x deploy.sh && ./deploy.sh
```

服务默认监听 3000 端口，可通过环境变量 `PORT` 修改。

## API 接口

### 获取加速链接

```
GET /api/accelerate?url=<文件链接>
```

### 获取实时统计

```
GET /api/stats
```

### 直接下载

```
GET /download?url=<文件链接>
```

## 支持的链接类型

- GitHub Releases
- OneDrive / 1drv.ms
- 其他 HTTP/HTTPS 直链
