const express = require('express');
const http = require('http');
const https = require('https');
const url = require('url');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.static('public'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

const stats = {
  totalDownloads: 0,
  totalBytesTransferred: 0,
  activeDownloads: new Map()
};

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

function generateDownloadId() {
  return 'dl_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
}

app.get('/download', async (req, res) => {
  const { url: targetUrl } = req.query;
  
  if (!targetUrl) {
    return res.status(400).json({ error: '请提供文件链接' });
  }
  
  const downloadId = generateDownloadId();
  const downloadInfo = {
    id: downloadId,
    url: targetUrl,
    startTime: Date.now(),
    bytesTransferred: 0,
    speed: 0,
    status: 'connecting'
  };
  
  stats.activeDownloads.set(downloadId, downloadInfo);
  
  try {
    const directUrl = parseFileUrl(targetUrl);
    const client = getHttpClient(directUrl);
    
    const req = client.get(directUrl, (remoteRes) => {
      if (remoteRes.statusCode >= 300 && remoteRes.statusCode < 400 && remoteRes.headers.location) {
        const redirectUrl = new URL(remoteRes.headers.location, directUrl).toString();
        stats.activeDownloads.delete(downloadId);
        return res.redirect(`/download?url=${encodeURIComponent(redirectUrl)}`);
      }
      
      if (remoteRes.statusCode !== 200) {
        stats.activeDownloads.delete(downloadId);
        return res.status(remoteRes.statusCode).json({ error: '无法获取文件' });
      }
      
      const contentDisposition = remoteRes.headers['content-disposition'];
      const filename = getFilenameFromUrl(directUrl, contentDisposition);
      const contentLength = parseInt(remoteRes.headers['content-length']) || 0;
      
      downloadInfo.filename = filename;
      downloadInfo.totalSize = contentLength;
      downloadInfo.status = 'downloading';
      
      res.writeHead(200, {
          'Content-Type': remoteRes.headers['content-type'] || 'application/octet-stream',
          'Content-Disposition': `attachment; filename="${filename.replace(/"/g, '\\"')}"; filename*=UTF-8''${encodeURIComponent(filename)}`,
          'Content-Length': contentLength,
          'Access-Control-Allow-Origin': '*'
        });
        
        let lastUpdate = Date.now();
        let lastBytes = 0;
        
        remoteRes.on('data', (chunk) => {
          downloadInfo.bytesTransferred += chunk.length;
          
          const now = Date.now();
          const elapsed = (now - lastUpdate) / 1000;
          
          if (elapsed >= 1) {
            const bytesDiff = downloadInfo.bytesTransferred - lastBytes;
            downloadInfo.speed = bytesDiff / elapsed;
            lastUpdate = now;
            lastBytes = downloadInfo.bytesTransferred;
          }
        });
        
        remoteRes.pipe(res);
       
       remoteRes.on('end', () => {
         downloadInfo.status = 'completed';
         downloadInfo.endTime = Date.now();
         stats.totalDownloads++;
         stats.totalBytesTransferred += downloadInfo.bytesTransferred;
         
         setTimeout(() => {
           stats.activeDownloads.delete(downloadId);
         }, 5000);
       });
       
       remoteRes.on('error', (err) => {
         console.error('下载错误:', err);
         downloadInfo.status = 'error';
         stats.activeDownloads.delete(downloadId);
         if (!res.headersSent) {
           res.status(500).json({ error: '下载过程中发生错误' });
         }
       });
       
     }).on('error', (err) => {
       console.error('请求错误:', err);
       downloadInfo.status = 'error';
       stats.activeDownloads.delete(downloadId);
       res.status(500).json({ error: '无法连接到目标服务器' });
     });
    
   } catch (error) {
     console.error('处理错误:', error);
     downloadInfo.status = 'error';
     stats.activeDownloads.delete(downloadId);
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
  
  const protocol = req.get('X-Forwarded-Proto') || req.protocol;
  const host = req.get('X-Forwarded-Host') || req.get('host');
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

app.get('/api/stats', (req, res) => {
  const activeList = Array.from(stats.activeDownloads.values()).map(dl => ({
    filename: dl.filename || 'unknown',
    url: dl.url,
    status: dl.status,
    speed: Math.round(dl.speed),
    bytesTransferred: dl.bytesTransferred,
    totalSize: dl.totalSize || 0,
    progress: dl.totalSize ? Math.round((dl.bytesTransferred / dl.totalSize) * 100) : 0,
    startTime: dl.startTime
  }));
  
  const totalBandwidth = activeList.reduce((sum, dl) => sum + dl.speed, 0);
  
  res.json({
    success: true,
    data: {
      totalDownloads: stats.totalDownloads,
      totalBytesTransferred: stats.totalBytesTransferred,
      totalBandwidth: Math.round(totalBandwidth),
      activeDownloads: activeList.length,
      downloads: activeList
    }
  });
});

app.listen(PORT, () => {
  console.log(`RapidRelay 服务已启动: http://localhost:${PORT}`);
  console.log(`API 文档: http://localhost:${PORT}/api/info`);
  console.log(`统计面板: http://localhost:${PORT}/api/stats`);
  console.log(`监听端口: ${PORT}`);
});
