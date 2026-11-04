import { createReadStream } from 'node:fs';
import { stat } from 'node:fs/promises';
import path from 'node:path';
import type { ServerResponse } from 'node:http';

const MIME: Record<string, string> = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.wasm': 'application/wasm',
  '.wav': 'audio/wav',
  '.mp3': 'audio/mpeg',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.txt': 'text/plain; charset=utf-8',
};

/**
 * Serves the bundled Flutter web client (`COMEOVER_WEB_DIR`) so guests can
 * install the web app straight from the relay origin — no separate hosting,
 * no CORS configuration. Falls back to index.html for extension-less paths,
 * which is all the SPA routing the app needs (it uses hash routes).
 *
 * Returns false when no web directory is configured or nothing matched —
 * callers then fall through to the API/dashboard behaviour.
 */
export async function serveWeb(
  urlPath: string,
  res: ServerResponse,
): Promise<boolean> {
  const root = process.env.COMEOVER_WEB_DIR;
  if (!root) return false;
  const rootStat = await stat(root).catch(() => null);
  if (!rootStat?.isDirectory()) return false;
  const rootAbs = path.resolve(root);

  if (urlPath.includes('\0')) return false;
  const decoded = decodeURIComponent(urlPath);
  // Traversal guard *after* decoding: resolve inside the web root and refuse
  // anything that escapes it. Legit asset paths never contain '..' segments.
  if (decoded.includes('..') || decoded.includes('\0')) return false;
  let candidate = path.resolve(rootAbs, `.${decoded}`);
  if (candidate !== rootAbs && !candidate.startsWith(rootAbs + path.sep)) {
    return false;
  }

  let info = await stat(candidate).catch(() => null);
  if (info?.isDirectory()) {
    candidate = path.join(candidate, 'index.html');
    info = await stat(candidate).catch(() => null);
  }
  if (!info?.isFile()) {
    // Assets must exist as files; only pages fall back to the app shell.
    if (path.extname(decoded)) return false;
    candidate = path.join(rootAbs, 'index.html');
    info = await stat(candidate).catch(() => null);
    if (!info?.isFile()) return false;
  }

  const rel = path.relative(rootAbs, candidate);
  const ext = path.extname(candidate).toLowerCase();
  // Hashed Flutter asset paths are immutable; the shell and icons are not.
  const cacheable =
    rel.startsWith(`assets${path.sep}`) || rel === 'main.dart.js';
  res.setHeader('content-type', MIME[ext] ?? 'application/octet-stream');
  res.setHeader('content-length', String(info.size));
  res.setHeader('cache-control', cacheable ? 'public, max-age=86400' : 'no-cache');

  const stream = createReadStream(candidate);
  stream.on('error', () => {
    if (!res.headersSent) res.writeHead(404);
    res.end();
  });
  stream.pipe(res);
  return true;
}

export function wantsWeb(urlPath: string): boolean {
  return (
    !urlPath.startsWith('/api/') &&
    !urlPath.startsWith('/socket.io') &&
    !urlPath.startsWith('/j/') &&
    urlPath !== '/healthz' &&
    urlPath !== '/status'
  );
}
