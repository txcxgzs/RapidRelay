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

app.listen(PORT, () => {
  console.log(`RapidRelay 服务已启动: http://localhost:${PORT}`);
  console.log(`监听端口: ${PORT}`);
});
