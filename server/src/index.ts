import { createServer, type IncomingMessage, type ServerResponse } from 'node:http';
import { Server } from 'socket.io';
import { dashboardHtml } from './dashboard.js';
import { DemoDirector } from './demo.js';
import { HttpError, RoomStore, publicMember, publicMembers, publicRoom } from './rooms.js';
import { serveWeb, wantsWeb } from './web_static.js';
import type { DeviceKind, Member, Room, Units, Precision } from './types.js';

const PORT = Number(process.env.PORT ?? 8787);
const HOST = process.env.HOST ?? '0.0.0.0';
const VERSION = process.env.COMEOVER_VERSION ?? '0.1.0';
const DIRECT_PORT = Number(process.env.COMEOVER_DIRECT_PORT ?? PORT);
const SWEEP_MS = 60_000;

const store = new RoomStore();

interface SocketCtx {
  roomId: string;
  memberId: string;
}

const server = createServer(handleHttp);
const io = new Server(server, {
  cors: { origin: '*', methods: ['GET', 'POST'] },
  pingInterval: 12_000,
  pingTimeout: 20_000,
  maxHttpBufferSize: 64 * 1024,
});

const demo = new DemoDirector(store, (roomId, event, payload) => {
  io.to(channel(roomId)).emit(event, payload);
});

/* ------------------------------------------------------------------ HTTP -- */

async function handleHttp(req: IncomingMessage, res: ServerResponse): Promise<void> {
  const url = new URL(req.url ?? '/', `http://${req.headers.host ?? 'localhost'}`);
  res.setHeader('access-control-allow-origin', '*');
  res.setHeader('access-control-allow-headers', 'content-type, authorization, x-member-token');
  res.setHeader('access-control-allow-methods', 'GET, POST, OPTIONS');
  res.setHeader('cache-control', 'no-store');

  if (req.method === 'OPTIONS') {
    res.writeHead(204).end();
    return;
  }

  // Bundled web client: everything that isn't the API, sockets, invite
  // pages, health probe or the relay dashboard is served from the Flutter
  // build (the relay root becomes the installable web app).
  if (
    (req.method === 'GET' || req.method === 'HEAD') &&
    wantsWeb(url.pathname) &&
    (await serveWeb(url.pathname, res))
  ) {
    return;
  }

  try {
    const path = url.pathname;

    if (req.method === 'GET' && (path === '/healthz' || path === '/api/health')) {
      return json(res, 200, { ok: true, rooms: store.size, uptime: process.uptime(), version: VERSION });
    }

    if (req.method === 'GET' && (path === '/' || path === '/status')) {
      const html = dashboardHtml({
        rooms: store.size,
        uptime: process.uptime(),
        version: VERSION,
        directPort: DIRECT_PORT,
      });
      res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' }).end(html);
      return;
    }

    if (req.method === 'POST' && path === '/api/rooms') {
      const body = await readJson(req);
      const result = store.create({
        name: body.name,
        avatar: body.avatar,
        device: parseDevice(body.device),
        location: parseLocation(body.location),
      });
      return json(res, 201, result);
    }

    const join = path.match(/^\/api\/rooms\/([A-Za-z0-9]{4,10})\/join$/);
    if (req.method === 'POST' && join) {
      const body = await readJson(req);
      const result = store.join(join[1] as string, {
        name: body.name,
        avatar: body.avatar,
        device: parseDevice(body.device),
      });
      io.to(channel(result.room.id)).emit(
        'member:joined',
        publicMember(store.require(result.room.id), findMember(store.require(result.room.id), result.member.id)),
      );
      return json(res, 200, result);
    }

    const peek = path.match(/^\/api\/rooms\/([A-Za-z0-9]{4,10})$/);
    if (req.method === 'GET' && peek) {
      const snapshot = store.peek(peek[1] as string);
      return json(res, 200, snapshot);
    }

    const demoRoute = path.match(/^\/api\/rooms\/([A-Za-z0-9]{4,10})\/demo$/);
    if (req.method === 'POST' && demoRoute) {
      const body = await readJson(req);
      const room = store.requireByCode(demoRoute[1] as string);
      const host = authorizeHost(req, body, room);
      const member = demo.start(room, host, {
        name: typeof body.name === 'string' ? body.name : undefined,
        distanceM: typeof body.distanceM === 'number' ? body.distanceM : undefined,
        mode: body.mode === 'drive' ? 'drive' : 'walk',
      });
      return json(res, 201, { ok: true, member });
    }

    const settingsRoute = path.match(/^\/api\/rooms\/([A-Za-z0-9]{4,10})\/settings$/);
    if (req.method === 'POST' && settingsRoute) {
      const body = await readJson(req);
      const room = store.requireByCode(settingsRoute[1] as string);
      const host = authorizeHost(req, body, room);
      const settings = store.updateSettings(room, {
        units: body.units as Units,
        precision: body.precision as Precision,
        arrivalRadius: typeof body.arrivalRadius === 'number' ? body.arrivalRadius : undefined,
      });
      io.to(channel(room.id)).emit('room:settings', settings);
      return json(res, 200, { ok: true, settings });
    }

    const removeRoute = path.match(/^\/api\/rooms\/([A-Za-z0-9]{4,10})\/members\/([\w-]+)$/);
    if (req.method === 'DELETE' && removeRoute) {
      const room = store.requireByCode(removeRoute[1] as string);
      const memberId = removeRoute[2] as string;
      const token = tokenFrom(req, {});
      const requester = [...room.members.values()].find((member) => member.token === token);
      if (!requester || (requester.id !== memberId && !requester.isHost)) {
        throw new HttpError(403, 'You can only remove yourself or a guest.', 'forbidden');
      }
      if (memberId === room.hostId) throw new HttpError(400, 'The host cannot be removed.', 'cannot_remove_host');
      store.removeMember(room, memberId);
      demo.stop(room.id);
      io.to(channel(room.id)).emit('member:left', { memberId });
      return json(res, 200, { ok: true });
    }

    const endRoute = path.match(/^\/api\/rooms\/([A-Za-z0-9]{4,10})\/end$/);
    if (req.method === 'POST' && endRoute) {
      const body = await readJson(req);
      const room = store.requireByCode(endRoute[1] as string);
      authorizeHost(req, body, room);
      store.end(room);
      demo.stop(room.id);
      io.to(channel(room.id)).emit('room:ended', { reason: 'host_ended' });
      return json(res, 200, { ok: true });
    }

    const invitePage = path.match(/^\/j\/([A-Za-z0-9]{4,10})$/);
    if (req.method === 'GET' && invitePage) {
      return inviteHtml(res, invitePage[1] as string);
    }

    json(res, 404, { error: 'Not found', code: 'not_found' });
  } catch (error) {
    if (error instanceof HttpError) {
      json(res, error.status, { error: error.message, code: error.code });
    } else {
      console.error('[http]', error);
      json(res, 500, { error: 'Something went wrong.', code: 'internal' });
    }
  }
}

function findMember(room: Room, memberId: string): Member {
  const member = room.members.get(memberId);
  if (!member) throw new HttpError(404, 'Member not found.', 'member_not_found');
  return member;
}

function authorizeHost(req: IncomingMessage, body: Record<string, unknown>, room: Room): Member {
  const token = tokenFrom(req, body);
  const host = room.members.get(room.hostId);
  if (!host || !token || host.token !== token) {
    throw new HttpError(403, 'Only the host can do that.', 'host_only');
  }
  return host;
}

function tokenFrom(req: IncomingMessage, body: Record<string, unknown>): string {
  const header = req.headers['x-member-token'];
  const auth = req.headers.authorization;
  if (typeof header === 'string' && header) return header;
  if (auth?.startsWith('Bearer ')) return auth.slice(7);
  return typeof body.token === 'string' ? body.token : '';
}

function parseDevice(value: unknown): DeviceKind {
  return value === 'tv' || value === 'tablet' || value === 'phone' ? value : 'phone';
}

function parseLocation(value: unknown): { lat: number; lng: number; accuracy?: number } | null {
  if (!value || typeof value !== 'object') return null;
  const point = value as Record<string, unknown>;
  if (typeof point.lat !== 'number' || typeof point.lng !== 'number') return null;
  return {
    lat: point.lat,
    lng: point.lng,
    accuracy: typeof point.accuracy === 'number' ? point.accuracy : undefined,
  };
}

async function readJson(req: IncomingMessage): Promise<Record<string, unknown>> {
  const chunks: Buffer[] = [];
  let size = 0;
  for await (const chunk of req) {
    size += (chunk as Buffer).length;
    if (size > 32 * 1024) throw new HttpError(413, 'Payload too large.', 'too_large');
    chunks.push(chunk as Buffer);
  }
  if (size === 0) return {};
  try {
    const parsed = JSON.parse(Buffer.concat(chunks).toString('utf8'));
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
      throw new HttpError(400, 'Expected a JSON object.', 'bad_json');
    }
    return parsed as Record<string, unknown>;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError(400, 'Invalid JSON.', 'bad_json');
  }
}

function json(res: ServerResponse, status: number, body: unknown): void {
  res.writeHead(status, { 'content-type': 'application/json; charset=utf-8' }).end(JSON.stringify(body));
}

/* ---------------------------------------------------------------- Socket -- */

const socketsByMember = new Map<string, Set<string>>();

io.on('connection', (socket) => {
  const auth = socket.handshake.auth as Record<string, string | undefined>;
  let ctx: SocketCtx;

  try {
    const room = store.require(auth.roomId ?? '');
    const member = store.authenticate(auth.roomId ?? '', auth.memberId ?? '', auth.token ?? '');
    ctx = { roomId: room.id, memberId: member.id };
    socket.join(channel(room.id));
    store.setOnline(member, true);
    member.lastSeen = Date.now();

    const key = memberKey(ctx);
    const set = socketsByMember.get(key) ?? new Set<string>();
    set.add(socket.id);
    socketsByMember.set(key, set);

    socket.emit('room:snapshot', {
      room: publicRoom(room),
      members: publicMembers(room),
      you: publicMember(room, member),
    });
    io.to(channel(room.id)).emit('member:online', { memberId: member.id, online: true });

    socket.on('room:sync', () => {
      const current = store.require(ctx.roomId);
      const you = current.members.get(ctx.memberId);
      socket.emit('room:snapshot', {
        room: publicRoom(current),
        members: publicMembers(current),
        you: you ? publicMember(current, you) : null,
      });
    });

    let lastLocationAt = 0;
    socket.on('location:update', (payload: Record<string, unknown>) => {
      const now = Date.now();
      if (now - lastLocationAt < 350) return;
      lastLocationAt = now;
      try {
        const current = store.require(ctx.roomId);
        const member = current.members.get(ctx.memberId);
        if (!member) return;
        store.updateLocation(member, {
          lat: Number(payload.lat),
          lng: Number(payload.lng),
          accuracy: Number(payload.accuracy),
          heading: typeof payload.heading === 'number' ? payload.heading : null,
          speed: typeof payload.speed === 'number' ? payload.speed : null,
          battery: typeof payload.battery === 'number' ? payload.battery : null,
        });
        store.setOnline(member, true);
        io.to(channel(ctx.roomId)).emit('member:location', {
          memberId: member.id,
          location: publicMember(current, member).location,
          online: true,
        });
      } catch (error) {
        if (!(error instanceof HttpError)) console.error('[socket:location]', error);
      }
    });

    socket.on('ping:probe', (sentAt: number, ack?: (payload: { sentAt: number; serverAt: number }) => void) => {
      if (typeof ack === 'function') ack({ sentAt, serverAt: Date.now() });
    });

    socket.on('disconnect', () => {
      const current = store.get(ctx.roomId);
      if (!current) return;
      const setForMember = socketsByMember.get(key);
      setForMember?.delete(socket.id);
      if (!setForMember || setForMember.size === 0) {
        socketsByMember.delete(key);
        const member = current.members.get(ctx.memberId);
        if (member) {
          store.setOnline(member, false);
          io.to(channel(ctx.roomId)).emit('member:online', { memberId: member.id, online: false });
        }
      }
    });
  } catch {
    socket.emit('room:error', {
      error: 'This invite is no longer available.',
      code: 'unauthorized',
    });
    socket.disconnect(true);
  }
});

function channel(roomId: string): string {
  return `room:${roomId}`;
}

function memberKey(ctx: SocketCtx): string {
  return `${ctx.roomId}:${ctx.memberId}`;
}

/* -------------------------------------------------------------- Invite page */

function inviteHtml(res: ServerResponse, code: string): void {
  let roomLine = 'You have been invited to share locations.';
  try {
    const { room, members } = store.peek(code);
    roomLine = `${members.length} ${members.length === 1 ? 'person is' : 'people are'} already in this room.`;
    if (room.ended) roomLine = 'This invite has ended.';
  } catch {
    roomLine = "This invite code doesn't exist (or has expired).";
  }
  const safeCode = code.replace(/[^A-Za-z0-9]/g, '').slice(0, 10);
  const html = `<!doctype html>
<html lang="en"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Join ${safeCode} · ComeOver</title>
<style>
  :root { color-scheme: dark; --ink:#f6f2ff; --muted:#b9b3c9; }
  * { box-sizing: border-box; }
  body { margin:0; min-height:100dvh; display:grid; place-items:center; padding:24px;
    font-family: ui-rounded, "SF Pro Rounded", "Segoe UI Variable", system-ui, sans-serif;
    background: radial-gradient(120% 90% at 15% 0%, #3b2a6f 0%, #16121f 55%, #0b0910 100%); color:var(--ink); }
  .halo { position:fixed; width:60vmax; height:60vmax; border-radius:50%; filter:blur(90px); opacity:.55; pointer-events:none; }
  .halo.a { background:#8b5cf6; top:-25vmax; right:-15vmax; animation:drift 18s ease-in-out infinite alternate; }
  .halo.b { background:#22d3ee; bottom:-30vmax; left:-20vmax; animation:drift 24s ease-in-out infinite alternate-reverse; }
  @keyframes drift { to { transform: translate3d(6vmax, 4vmax, 0) scale(1.12); } }
  .card { position:relative; width:min(430px, 100%); padding:34px 28px 28px; border-radius:36px; text-align:center;
    background: linear-gradient(150deg, rgba(255,255,255,.18), rgba(255,255,255,.06));
    border:1px solid rgba(255,255,255,.28);
    box-shadow: 0 30px 80px rgba(0,0,0,.5), inset 0 1px 0 rgba(255,255,255,.55);
    backdrop-filter: blur(28px) saturate(1.6); -webkit-backdrop-filter: blur(28px) saturate(1.6); }
  .mark { font-size:34px; }
  .eyebrow { text-transform:uppercase; letter-spacing:.18em; font-size:11px; color:var(--muted); margin:14px 0 6px; }
  h1 { font-size:28px; margin:0 0 6px; letter-spacing:-.02em; }
  p { color:var(--muted); margin:0 0 22px; font-size:15px; line-height:1.45; }
  .code { display:flex; gap:6px; justify-content:center; margin:0 0 24px; }
  .code span { width:48px; height:60px; display:grid; place-items:center; font-size:26px; font-weight:700;
    border-radius:16px; background:rgba(255,255,255,.1); border:1px solid rgba(255,255,255,.22);
    box-shadow: inset 0 1px 0 rgba(255,255,255,.35); }
  a.btn { display:block; padding:16px 22px; border-radius:999px; text-decoration:none; font-weight:700; font-size:16px;
    color:#211436; background:linear-gradient(120deg,#d9c8ff,#a5f3fc);
    box-shadow: 0 12px 30px rgba(165,243,252,.25), inset 0 1px 0 #fff; }
  .hint { margin-top:16px; font-size:12px; color:var(--muted); }
  .hint b { color:var(--ink); font-weight:600; }
</style></head>
<body>
  <div class="halo a"></div><div class="halo b"></div>
  <main class="card">
    <div class="mark">🫂</div>
    <div class="eyebrow">ComeOver invite</div>
    <h1>See you in a moment</h1>
    <p>${roomLine} Open the app to share live location, distance and ETA.</p>
    <div class="code">${safeCode.split('').map((c) => `<span>${c}</span>`).join('')}</div>
    <a class="btn" href="comeover://join/${safeCode}">Open ComeOver</a>
    <p class="hint">No app yet? Enter code <b>${safeCode}</b> after installing. Location is only shared while the room is open.</p>
  </main>
</body></html>`;
  res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' }).end(html);
}

/* ------------------------------------------------------------------ Boot -- */

setInterval(() => {
  for (const room of store.sweep()) {
    demo.stop(room.id);
    io.to(channel(room.id)).emit('room:ended', { reason: 'expired' });
  }
}, SWEEP_MS).unref();

server.listen(PORT, HOST, () => {
  console.log(`ComeOver relay listening on http://${HOST}:${PORT}`);
});

function shutdown(): void {
  io.close();
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(0), 2_000).unref();
}
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
