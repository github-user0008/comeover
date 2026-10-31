import assert from 'node:assert/strict';
import { spawn, type ChildProcess } from 'node:child_process';
import { after, before, test } from 'node:test';
import { io, type Socket } from 'socket.io-client';

const PORT = 8799;
const BASE = `http://127.0.0.1:${PORT}`;

async function post<T>(path: string, body: unknown, token?: string): Promise<T> {
  const response = await fetch(BASE + path, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      ...(token ? { 'x-member-token': token } : {}),
    },
    body: JSON.stringify(body),
  });
  const json = (await response.json()) as T;
  assert.ok(response.ok, `POST ${path} -> ${response.status} ${JSON.stringify(json)}`);
  return json;
}

function waitFor<T>(socket: Socket, event: string, predicate?: (payload: T) => boolean, timeout = 6_000): Promise<T> {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      socket.off(event, handler);
      reject(new Error(`Timed out waiting for ${event}`));
    }, timeout);
    const handler = (payload: T) => {
      if (predicate && !predicate(payload)) return;
      clearTimeout(timer);
      socket.off(event, handler);
      resolve(payload);
    };
    socket.on(event, handler);
  });
}

let server: ChildProcess;

async function startServer(): Promise<ChildProcess> {
  const child = spawn(process.execPath, ['--import', 'tsx', 'src/index.ts'], {
    env: { ...process.env, PORT: String(PORT) },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  child.stderr?.on('data', (chunk) => process.stderr.write(`[server] ${chunk}`));
  for (let i = 0; i < 50; i += 1) {
    try {
      const res = await fetch(`${BASE}/healthz`);
      if (res.ok) return child;
    } catch {
      /* not up yet */
    }
    await new Promise((r) => setTimeout(r, 200));
  }
  child.kill();
  throw new Error('Server did not start');
}

before(async () => {
  server = await startServer();
});
after(() => {
  server?.kill('SIGTERM');
});

test('invite, live location and demo traveller flow end to end', async (t) => {

  const hostRoom = await post<{
    room: { id: string; code: string };
    member: { id: string };
    token: string;
  }>('/api/rooms', {
    name: 'Ada',
    device: 'tv',
    location: { lat: 12.9716, lng: 77.5946, accuracy: 18 },
  });

  const hostSocket = io(BASE, {
    auth: { roomId: hostRoom.room.id, memberId: hostRoom.member.id, token: hostRoom.token },
    transports: ['websocket'],
  });
  t.after(() => hostSocket.disconnect());

  const snapshot = await waitFor<{ members: unknown[]; you: { name: string } }>(hostSocket, 'room:snapshot');
  assert.equal(snapshot.you.name, 'Ada');
  assert.equal(snapshot.members.length, 1);

  const joinedPromise = waitFor<{ id: string }>(hostSocket, 'member:joined');
  const guestRoom = await post<{
    room: { id: string };
    member: { id: string; name: string };
    token: string;
  }>(`/api/rooms/${hostRoom.room.code}/join`, { name: 'Grace', device: 'phone' });

  const joined = await joinedPromise;
  assert.equal(joined.id, guestRoom.member.id);

  const guestSocket = io(BASE, {
    auth: {
      roomId: guestRoom.room.id,
      memberId: guestRoom.member.id,
      token: guestRoom.token,
    },
    transports: ['websocket'],
  });
  t.after(() => guestSocket.disconnect());

  guestSocket.emit('location:update', { lat: 12.9806, lng: 77.5946, accuracy: 9, speed: 1.4 });
  const location = await waitFor<{ memberId: string; location: { lat: number } }>(
    hostSocket,
    'member:location',
    (payload) => payload.memberId === guestRoom.member.id,
  );
  assert.ok(Math.abs(location.location.lat - 12.9806) < 0.00001);

  const demo = await post<{ member: { id: string } }>(
    `/api/rooms/${hostRoom.room.code}/demo`,
    { distanceM: 400, mode: 'walk' },
    hostRoom.token,
  );
  assert.ok(demo.member.id.startsWith('demo-'));

  const trail = await new Promise<number[]>((resolve) => {
    const distances: number[] = [];
    const handler = (payload: { memberId: string; location: { lat: number; lng: number } }) => {
      if (payload.memberId !== demo.member.id) return;
      distances.push(Math.abs(payload.location.lat - 12.9716) + Math.abs(payload.location.lng - 77.5946));
      if (distances.length >= 2) {
        hostSocket.off('member:location', handler);
        resolve(distances);
      }
    };
    hostSocket.on('member:location', handler);
  });
  assert.ok(trail[1]! < trail[0]!, 'demo traveller should get closer to the host');

  const settingsEventPromise = waitFor<{ units: string; precision: string }>(
    hostSocket,
    'room:settings',
  );
  const settings = await post<{ settings: { precision: string; units: string } }>(
    `/api/rooms/${hostRoom.room.code}/settings`,
    { precision: 'approximate', units: 'imperial' },
    hostRoom.token,
  );
  assert.equal(settings.settings.precision, 'approximate');
  const settingsEvent = await settingsEventPromise;
  assert.equal(settingsEvent.units, 'imperial');

  const endedPromise = waitFor<{ reason: string }>(guestSocket, 'room:ended');
  await post(`/api/rooms/${hostRoom.room.code}/end`, {}, hostRoom.token);
  const ended = await endedPromise;
  assert.equal(ended.reason, 'host_ended');

  const afterwards = await fetch(`${BASE}/api/rooms/${hostRoom.room.code}`);
  const endedPayload = (await afterwards.json()) as { room: { ended: boolean } };
  assert.equal(endedPayload.room.ended, true);
});

test('host-only actions reject guests', async () => {
  const host = await post<{ room: { code: string }; token: string }>('/api/rooms', {
    name: 'Ada',
    location: { lat: 1, lng: 2 },
  });
  const guest = await post<{ token: string }>(`/api/rooms/${host.room.code}/join`, { name: 'Grace' });

  const response = await fetch(`${BASE}/api/rooms/${host.room.code}/settings`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'x-member-token': guest.token },
    body: JSON.stringify({ units: 'imperial' }),
  });
  assert.equal(response.status, 403);

  const page = await fetch(`${BASE}/j/${host.room.code}`);
  const html = await page.text();
  assert.match(html, /Open ComeOver/);
  assert.match(html, new RegExp(host.room.code));
});

test('relay dashboard is a useful Umbrel landing page', async () => {
  const response = await fetch(`${BASE}/`);
  assert.ok(response.ok);
  assert.match(response.headers.get('content-type') ?? '', /text\/html/);
  const html = await response.text();
  assert.match(html, /ComeOver/);
  assert.match(html, /Relay online/);
  assert.match(html, /Connect the app/);
  assert.match(html, /Settings → Relay/);
  assert.match(html, /healthz/);
});
