import http from 'node:http';
import { readFile } from 'node:fs/promises';
import path from 'node:path';

/**
 * content parts server（跨平台）
 *
 * 用途：把“按章拆分”的内容缓存目录暴露为本地 HTTP JSON 接口，供各平台分发自动化读取。
 *
 * 统一约定（无兼容兜底）：
 * - 端口环境变量：CONTENT_PARTS_PORT（默认 8765）
 * - 平台目录环境变量（可选）：DISTRIBUTION_PLATFORM_DIR（默认：小说正文）
 * - 缓存子路径（写死）：.cache/content_parts
 * - 目录分层约定（推荐）：
 *   - 无分部小说：no_part/v{卷号}/
 *   - 有分部小说：p{分部号}/v{卷号}/
 * - 文件命名：
 *   - {章号两位补零}_title.txt
 *   - {章号两位补零}_body.txt
 *   - {章号两位补零}_author.txt
 *
 * 推荐调用示例：
 * 1) 小说正文（默认）
 *    $env:CONTENT_PARTS_PORT='8765'
 *    node .\scripts\content_parts_server.mjs
 *
 * 2) 豆瓣
 *    $env:CONTENT_PARTS_PORT='8766'
 *    $env:DISTRIBUTION_PLATFORM_DIR='豆瓣'
 *    node .\scripts\content_parts_server.mjs
 *
 * 3) 番茄小说
 *    $env:CONTENT_PARTS_PORT='8767'
 *    $env:DISTRIBUTION_PLATFORM_DIR='番茄小说'
 *    node .\scripts\content_parts_server.mjs
 *
 * 读取示例（推荐）：
 * - 无分部小说第1卷第40章：/parts/v/1/40
 * - 有分部小说第2部分部第3卷第40章：/parts/p/2/v/3/40
 *
 * 读取示例（平铺，单批次可选）：
 * - /parts/40
 */

const port = Number(process.env.CONTENT_PARTS_PORT || 8765);
const repoRoot = process.cwd();
const platformDirName = process.env.DISTRIBUTION_PLATFORM_DIR || '小说正文';
const fixedPartsSubPath = path.join('.cache', 'content_parts');

function resolveBaseDir() {
  // 固定缓存子路径，仅平台目录可选切换
  return path.join(repoRoot, platformDirName, fixedPartsSubPath);
}

const baseDir = resolveBaseDir();

function parsePartRequest(pathname) {
  // 推荐：无分部小说（卷内章号）
  // /parts/v/{volume}/{chapter}
  const noPartMatch = pathname.match(/^\/parts\/v\/(\d+)\/(\d+)$/);
  if (noPartMatch) {
    return {
      chapterNo: noPartMatch[2],
      scopeDir: path.join('no_part', `v${Number(noPartMatch[1])}`),
      mode: 'no_part',
      volumeNo: Number(noPartMatch[1]),
    };
  }

  // 推荐：有分部小说（分部 + 卷内章号）
  // /parts/p/{part}/v/{volume}/{chapter}
  const withPartMatch = pathname.match(/^\/parts\/p\/(\d+)\/v\/(\d+)\/(\d+)$/);
  if (withPartMatch) {
    return {
      chapterNo: withPartMatch[3],
      scopeDir: path.join(`p${Number(withPartMatch[1])}`, `v${Number(withPartMatch[2])}`),
      mode: 'with_part',
      partNo: Number(withPartMatch[1]),
      volumeNo: Number(withPartMatch[2]),
    };
  }

  // 可选：平铺目录（仅适用于单批次/不跨卷）
  // /parts/{chapter}
  const flatMatch = pathname.match(/^\/parts\/(\d+)$/);
  if (flatMatch) {
    return {
      chapterNo: flatMatch[1],
      scopeDir: '',
      mode: 'flat',
    };
  }

  return null;
}

function sendJson(res, status, payload) {
  const body = JSON.stringify(payload, null, 2);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  });
  res.end(body);
}

function normalizeChapter(raw) {
  const chapter = Number(raw);
  if (!Number.isInteger(chapter) || chapter < 1 || chapter > 999) {
    return null;
  }
  return String(chapter).padStart(2, '0');
}

async function loadPart(requestInfo) {
  const chapterKey = normalizeChapter(requestInfo.chapterNo);
  if (!chapterKey) {
    return null;
  }

  const scopedBaseDir = requestInfo.scopeDir
    ? path.join(baseDir, requestInfo.scopeDir)
    : baseDir;

  const [title, body, author] = await Promise.all([
    readFile(path.join(scopedBaseDir, `${chapterKey}_title.txt`), 'utf8'),
    readFile(path.join(scopedBaseDir, `${chapterKey}_body.txt`), 'utf8'),
    readFile(path.join(scopedBaseDir, `${chapterKey}_author.txt`), 'utf8'),
  ]);

  return {
    chapterNo: Number(requestInfo.chapterNo),
    scopeMode: requestInfo.mode,
    scopeDir: requestInfo.scopeDir || '.',
    title: title.trimEnd(),
    body: body.trimEnd(),
    author: author.trimEnd(),
  };
}

const server = http.createServer(async (req, res) => {
  if (!req.url) {
    return sendJson(res, 400, { error: 'missing_url' });
  }

  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    });
    return res.end();
  }

  const url = new URL(req.url, `http://127.0.0.1:${port}`);
  if (url.pathname === '/health') {
    return sendJson(res, 200, {
      ok: true,
      baseDir,
      endpoints: [
        '/parts/v/{volume}/{chapter}',
        '/parts/p/{part}/v/{volume}/{chapter}',
        '/parts/{chapter} (flat, optional)',
        '/health',
      ],
      env: {
        CONTENT_PARTS_PORT: port,
        DISTRIBUTION_PLATFORM_DIR: process.env.DISTRIBUTION_PLATFORM_DIR || '小说正文',
      },
      note: 'Cache subpath is fixed to .cache/content_parts. Prefer scoped endpoints to avoid chapter collisions.',
    });
  }

  const requestInfo = parsePartRequest(url.pathname);
  if (!requestInfo) {
    return sendJson(res, 404, { error: 'not_found' });
  }

  try {
    const payload = await loadPart(requestInfo);
    if (!payload) {
      return sendJson(res, 400, { error: 'invalid_chapter' });
    }
    return sendJson(res, 200, payload);
  } catch (error) {
    return sendJson(res, 500, {
      error: 'read_failed',
      message: error instanceof Error ? error.message : String(error),
    });
  }
});

server.listen(port, '127.0.0.1', () => {
  console.log(`content-parts-server listening on http://127.0.0.1:${port}`);
  console.log(`baseDir: ${baseDir}`);
});
