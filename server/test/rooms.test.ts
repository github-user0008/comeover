import assert from 'node:assert/strict';
import { test } from 'node:test';
import { coarsen, destination, haversine } from '../src/geo.js';
import { RoomStore, HttpError } from '../src/rooms.js';

test('haversine measures known distance', () => {
  const a = { lat: 12.9716, lng: 77.5946 };
  const b = { lat: 12.9806, lng: 77.5946 };
  const d = haversine(a, b);
  assert.ok(d > 990 && d < 1010, `expected ~1000m, got ${d}`);
});

test('destination walks a measured lap back to the origin', () => {
  const origin = { lat: 51.5072, lng: -0.1276 };
  const there = destination(origin, 250, 45);
  assert.ok(Math.abs(haversine(origin, there) - 250) < 1);
});

test('approximate sharing snaps to a coarse grid', () => {
  const p = coarsen({ lat: 12.97164, lng: 77.59461 });
  assert.deepEqual(p, { lat: 12.97, lng: 77.59 });
});

test('host creates a room, guest joins and both are visible', () => {
  const store = new RoomStore();
  const host = store.create({ name: '  Ada  ', device: 'tv', location: { lat: 12.97, lng: 77.59 } });
  assert.equal(host.room.code.length, 6);
  assert.equal(host.member.isHost, true);
  assert.equal(host.member.device, 'tv');
  assert.equal(host.member.name, 'Ada');
  assert.equal(host.member.location?.lat, 12.97);
  assert.equal(host.members.length, 1);

  const guest = store.join(host.room.code.toLowerCase(), { name: 'Grace', device: 'phone' });
  assert.equal(guest.members.length, 2);
  assert.equal(guest.room.id, host.room.id);
  assert.equal(guest.member.isHost, false);
  assert.equal(guest.token.length > 20, true);
});

test('join rejects unknown codes and ended rooms', () => {
  const store = new RoomStore();
  assert.throws(() => store.join('ZZZZZZ', { name: 'Ada' }), (error: unknown) => {
    return error instanceof HttpError && error.status === 404;
  });

  const host = store.create({ name: 'Ada' });
  store.end(store.require(host.room.id));
  assert.throws(() => store.join(host.room.code, { name: 'Grace' }), (error: unknown) => {
    return error instanceof HttpError && error.status === 410;
  });
});

test('only the right token authenticates as a member', () => {
  const store = new RoomStore();
  const host = store.create({ name: 'Ada' });
  const guest = store.join(host.room.code, { name: 'Grace' });

  assert.equal(store.authenticate(host.room.id, host.member.id, host.token).name, 'Ada');
  assert.throws(() => store.authenticate(host.room.id, guest.member.id, host.token), HttpError);
  assert.throws(() => store.authenticate(host.room.id, guest.member.id, 'nope'), HttpError);
});

test('location updates are clamped and validated', () => {
  const store = new RoomStore();
  const host = store.create({ name: 'Ada' });
  const room = store.require(host.room.id);
  const member = room.members.get(host.member.id)!;

  store.updateLocation(member, { lat: 12.9, lng: 77.5, accuracy: 999_999 });
  assert.equal(member.location?.accuracy, 5000);

  assert.throws(() => store.updateLocation(member, { lat: Number.NaN, lng: 0 }), HttpError);
  assert.throws(() => store.updateLocation(member, { lat: 120, lng: 0 }), HttpError);
});

test('approximate precision hides exact coordinates on the wire', () => {
  const store = new RoomStore();
  const host = store.create({ name: 'Ada', location: { lat: 12.9716, lng: 77.5946 } });
  const room = store.require(host.room.id);
  const guest = store.join(host.room.code, { name: 'Grace' });
  const guestMember = room.members.get(guest.member.id)!;
  store.updateLocation(guestMember, { lat: 12.9733, lng: 77.5966, accuracy: 5 });
  store.updateSettings(room, { precision: 'approximate' });

  const snapshot = store.peek(room.code);
  const guestPublic = snapshot.members.find((m) => m.id === guestMember.id)!;
  assert.equal(guestPublic.location?.lat, 12.97);
  assert.equal(guestPublic.location?.lng, 77.6);
  assert.ok((guestPublic.location?.accuracy ?? 0) >= 100);
  assert.equal('token' in guestPublic, false);
});

test('settings only accept sane values', () => {
  const store = new RoomStore();
  const host = store.create({ name: 'Ada' });
  const room = store.require(host.room.id);
  store.updateSettings(room, { units: 'imperial', precision: 'approximate', arrivalRadius: 9999 });
  assert.equal(room.settings.units, 'imperial');
  assert.equal(room.settings.precision, 'approximate');
  assert.equal(room.settings.arrivalRadius, 500);
});

test('host removal keeps the host and sweep expires old rooms', () => {
  const store = new RoomStore();
  const host = store.create({ name: 'Ada' });
  const guest = store.join(host.room.code, { name: 'Grace' });
  const room = store.require(host.room.id);
  store.removeMember(room, host.member.id);
  assert.equal(room.members.has(host.member.id), true);
  store.removeMember(room, guest.member.id);
  assert.equal(room.members.size, 1);

  const removed = store.sweep(Date.now() + 7 * 60 * 60 * 1000);
  assert.equal(removed.length, 1);
  assert.equal(store.size, 0);
});
