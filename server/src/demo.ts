import { destination, haversine, bearing } from './geo.js';
import { publicMember } from './rooms.js';
import type { RoomStore } from './rooms.js';
import type { Location, Member, PublicMember, Room } from './types.js';

type Emit = (roomId: string, event: string, payload: unknown) => void;

const WALK_SPEED = 1.35; // m/s
const DRIVE_SPEED = 9.5; // m/s

/**
 * Spawns a friendly simulated traveller walking/driving toward the host.
 * Lets you demo the arrival experience on a TV or emulator without a second phone.
 */
export class DemoDirector {
  private readonly timers = new Map<string, NodeJS.Timeout>();

  constructor(
    private readonly store: RoomStore,
    private readonly emit: Emit,
  ) {}

  start(
    room: Room,
    host: Member,
    options: { name?: string; distanceM?: number; mode?: 'walk' | 'drive' } = {},
  ): PublicMember {
    if (!host.location) {
      throw new Error('Share your own location before inviting a demo traveller.');
    }
    this.stop(room.id);
    const mode = options.mode ?? 'walk';
    const distance = Math.min(50_000, Math.max(120, options.distanceM ?? 1_400));
    const target = { lat: host.location.lat, lng: host.location.lng };
    const start = destination(target, distance, Math.random() * 360);
    const speed = mode === 'drive' ? DRIVE_SPEED : WALK_SPEED;

    const now = Date.now();
    const demo: Member = {
      id: `demo-${now.toString(36)}-${Math.random().toString(36).slice(2, 6)}`,
      token: 'demo',
      name: options.name ?? (mode === 'drive' ? 'Maya (driving)' : 'Maya (walking)'),
      avatar: '🦊',
      color: '#BDB2FF',
      device: 'phone',
      isHost: false,
      demo: true,
      joinedAt: now,
      online: true,
      lastSeen: now,
      location: {
        lat: start.lat,
        lng: start.lng,
        accuracy: 12,
        heading: bearing(start, target),
        speed,
        battery: 86,
        ts: now,
      },
    };
    room.members.set(demo.id, demo);
    this.emit(room.id, 'member:joined', publicMember(room, demo));

    let travelled = 0;
    let tick = 0;
    const timer = setInterval(() => {
      const roomNow = this.store.get(room.id);
      const member = roomNow?.members.get(demo.id);
      if (!roomNow || !member) {
        this.stop(room.id);
        return;
      }
      const current: Location =
        member.location ?? {
          lat: start.lat,
          lng: start.lng,
          accuracy: 12,
          heading: null,
          speed: null,
          battery: null,
          ts: Date.now(),
        };
      const remaining = haversine(current, target);
      if (remaining <= 18) {
        member.location = {
          ...current,
          ...target,
          accuracy: 8,
          speed: 0,
          heading: null,
          ts: Date.now(),
        };
        member.lastSeen = Date.now();
        this.emit(room.id, 'member:location', {
          memberId: member.id,
          location: member.location,
          online: true,
        });
        this.emit(room.id, 'member:arrived', { memberId: member.id });
        this.stop(room.id);
        return;
      }

      tick += 1;
      const step = Math.min(remaining, speed * 1);
      travelled += step;
      // Gentle S-curve so the trail on the map feels human instead of laser-straight.
      const sway = Math.sin(travelled / 90) * 14;
      const curveBearing = bearing(current, target) + (sway / Math.max(60, remaining)) * 20;
      const next = destination(current, step, curveBearing);
      const jitter = () => (Math.random() - 0.5) * 1.6;
      member.location = {
        lat: next.lat + jitter() / 111_320,
        lng: next.lng + jitter() / (111_320 * Math.cos((next.lat * Math.PI) / 180)),
        accuracy: 8 + Math.random() * 6,
        heading: bearing(current, target),
        speed: speed + (Math.random() - 0.5) * 0.25,
        battery: Math.max(20, 86 - Math.floor(tick / 60)),
        ts: Date.now(),
      };
      member.lastSeen = Date.now();
      member.online = true;
      this.emit(room.id, 'member:location', {
        memberId: member.id,
        location: member.location,
        online: true,
      });
    }, 1_000);
    timer.unref?.();
    this.timers.set(room.id, timer);
    return publicMember(room, demo);
  }

  stop(roomId: string): void {
    const timer = this.timers.get(roomId);
    if (timer) clearInterval(timer);
    this.timers.delete(roomId);
  }
}
