const express = require('express');
const http = require('http');
const https = require('https');
const url = require('url');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.static('public'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

function parseFileUrl(originalUrl) {
  let directUrl = originalUrl;
  
  if (originalUrl.includes('github.com') && originalUrl.includes('/releases/download/')) {
    directUrl = originalUrl;
  } else if (originalUrl.includes('onedrive.live.com') || originalUrl.includes('1drv.ms')) {
    if (originalUrl.includes('1drv.ms')) {
      directUrl = originalUrl;
    } else {
      directUrl = originalUrl;
    }
  }
  
  return directUrl;
}

function getHttpClient(urlStr) {
  const parsedUrl = new URL(urlStr);
  return parsedUrl.protocol === 'https:' ? https : http;
}

function getFilenameFromUrl(urlStr, contentDisposition) {
  if (contentDisposition) {
    const filenameMatch = contentDisposition.match(/filename[^;=\n]*=((['"]).*?\2|[^;\n]*)/);
    if (filenameMatch && filenameMatch[1]) {
      let filename = filenameMatch[1].replace(/['"]/g, '');
      if (filename.toLowerCase().startsWith("utf-8''")) {
        filename = decodeURIComponent(filename.substring(7));
      }
      return filename;
    }
  }
  
  const parsedUrl = new URL(urlStr);
  const pathname = parsedUrl.pathname;
  const filename = pathname.split('/').pop();
  return filename || 'download';
}

app.get('/download', async (req, res) => {
  const { url: targetUrl } = req.query;
  
  if (!targetUrl) {
    return res.status(400).json({ error: '请提供文件链接' });
  }
  
  try {
    const directUrl = parseFileUrl(targetUrl);
    const client = getHttpClient(directUrl);
    
    client.get(directUrl, (remoteRes) => {
      if (remoteRes.statusCode >= 300 && remoteRes.statusCode < 400 && remoteRes.headers.location) {
        const redirectUrl = new URL(remoteRes.headers.location, directUrl).toString();
        return res.redirect(`/download?url=${encodeURIComponent(redirectUrl)}`);
      }
      
      if (remoteRes.statusCode !== 200) {
        return res.status(remoteRes.statusCode).json({ error: '无法获取文件' });
      }
      
      const contentDisposition = remoteRes.headers['content-disposition'];
      const filename = getFilenameFromUrl(directUrl, contentDisposition);
      
      res.writeHead(200, {
        'Content-Type': remoteRes.headers['content-type'] || 'application/octet-stream',
        'Content-Disposition': `attachment; filename="${encodeURIComponent(filename)}"`,
        'Content-Length': remoteRes.headers['content-length'],
        'Access-Control-Allow-Origin': '*'
      });
      
      remoteRes.pipe(res);
      
      remoteRes.on('error', (err) => {
        console.error('下载错误:', err);
        if (!res.headersSent) {
          res.status(500).json({ error: '下载过程中发生错误' });
        }
      });
      
    }).on('error', (err) => {
      console.error('请求错误:', err);
      res.status(500).json({ error: '无法连接到目标服务器' });
    });
    
  } catch (error) {
    console.error('处理错误:', error);
    res.status(500).json({ error: '处理请求时发生错误' });
  }
});

app.get('/api/accelerate', (req, res) => {
  const { url: targetUrl } = req.query;
  
  if (!targetUrl) {
    return res.status(400).json({ 
      success: false, 
      error: '请提供文件链接 (url 参数)' 
    });
  }
  
  try {
    new URL(targetUrl);
  } catch {
    return res.status(400).json({ 
      success: false, 
      error: '无效的 URL 格式' 
    });
  }
  
  const protocol = req.protocol;
  const host = req.get('host');
  const baseUrl = `${protocol}://${host}`;
  const downloadUrl = `${baseUrl}/download?url=${encodeURIComponent(targetUrl)}`;
  
  res.json({
    success: true,
    message: '加速链接生成成功',
    data: {
      original_url: targetUrl,
      accelerate_url: downloadUrl,
      usage: '直接访问 accelerate_url 即可进行加速下载'
    }
  });
});

app.get('/api/info', (req, res) => {
  res.json({
    service: 'RapidRelay',
    version: '1.0.0',
    endpoints: {
      accelerate: {
        method: 'GET',
        path: '/api/accelerate',
        params: { url: '原始文件链接 (必需)' },
        example: `/api/accelerate?url=${encodeURIComponent('https://example.com/file.zip')}`
      },
      download: {
        method: 'GET',
        path: '/download',
        params: { url: '原始文件链接 (必需)' },
        description: '直接下载文件 (内部使用)'
      }
    },
    supported_links: [
      'OneDrive 直链',
      '1drv.ms 链接', 
      'GitHub Releases',
      '其他 HTTP/HTTPS 直链'
    ]
  });
});

app.listen(PORT, () => {
  console.log(`RapidRelay 服务已启动: http://localhost:${PORT}`);
  console.log(`API 文档: http://localhost:${PORT}/api/info`);
  console.log(`监听端口: ${PORT}`);
});
