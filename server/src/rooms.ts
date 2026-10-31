import { randomBytes, randomUUID } from 'node:crypto';
import { AVATARS, COLORS } from './types.js';
import type {
  DeviceKind,
  JoinResult,
  Member,
  Precision,
  PublicMember,
  PublicRoom,
  Room,
  RoomSettings,
  Units,
} from './types.js';
import { coarsen } from './geo.js';

const CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const ROOM_TTL_MS = 6 * 60 * 60 * 1000;
const MAX_MEMBERS = 8;
const MEMBER_OFFLINE_AFTER_MS = 45_000;

export class HttpError extends Error {
  constructor(
    readonly status: number,
    message: string,
    readonly code = 'error',
  ) {
    super(message);
  }
}

export interface CreateRoomInput {
  name: unknown;
  avatar?: unknown;
  device?: DeviceKind;
  location?: { lat: number; lng: number; accuracy?: number } | null;
}

function newCode(): string {
  let code = '';
  for (let i = 0; i < 6; i += 1) {
    code += CODE_ALPHABET[Math.floor(Math.random() * CODE_ALPHABET.length)];
  }
  return code;
}

function cleanName(value: unknown): string {
  if (typeof value !== 'string') throw new HttpError(400, 'A display name is required.', 'name_required');
  const name = value.trim().replace(/\s+/g, ' ').slice(0, 24);
  if (!name) throw new HttpError(400, 'A display name is required.', 'name_required');
  return name;
}

function pick<T>(list: readonly T[], seed: string): T {
  let hash = 0;
  for (let i = 0; i < seed.length; i += 1) hash = (hash * 31 + seed.charCodeAt(i)) | 0;
  return list[Math.abs(hash) % list.length] as T;
}

export class RoomStore {
  private readonly rooms = new Map<string, Room>();
  private readonly byCode = new Map<string, string>();

  create(input: CreateRoomInput): JoinResult {
    const name = cleanName(input.name);
    const device = input.device ?? 'phone';
    const id = randomUUID();
    let code = newCode();
    while (this.byCode.has(code)) code = newCode();
    const now = Date.now();
    const member = this.newMember({
      name,
      avatar: input.avatar,
      device,
      isHost: true,
      seed: id,
    });
    if (input.location) {
      member.location = {
        lat: input.location.lat,
        lng: input.location.lng,
        accuracy: input.location.accuracy ?? 25,
        heading: null,
        speed: null,
        battery: null,
        ts: now,
      };
    }
    const room: Room = {
      id,
      code,
      hostId: member.id,
      createdAt: now,
      expiresAt: now + ROOM_TTL_MS,
      ended: false,
      settings: { units: 'metric', precision: 'exact', arrivalRadius: 40 },
      members: new Map([[member.id, member]]),
    };
    this.rooms.set(id, room);
    this.byCode.set(code, id);
    return { room: publicRoom(room), member: publicMember(room, member), token: member.token, members: publicMembers(room) };
  }

  join(code: string, input: Omit<CreateRoomInput, 'location'>): JoinResult {
    const room = this.requireByCode(code);
    if (room.ended) throw new HttpError(410, 'This invite has already ended.', 'room_ended');
    if (this.activeMemberCount(room) >= MAX_MEMBERS) {
      throw new HttpError(429, 'This room is full.', 'room_full');
    }
    const name = cleanName(input.name);
    const member = this.newMember({
      name,
      avatar: typeof input.avatar === 'string' ? input.avatar : undefined,
      device: input.device ?? 'phone',
      isHost: false,
      seed: randomUUID(),
    });
    room.members.set(member.id, member);
    return { room: publicRoom(room), member: publicMember(room, member), token: member.token, members: publicMembers(room) };
  }

  peek(code: string): { room: PublicRoom; members: PublicMember[] } {
    const id = this.byCode.get(code.trim().toUpperCase());
    const room = id ? this.rooms.get(id) : undefined;
    if (!room) throw new HttpError(404, "That code doesn't match an invite.", 'invite_not_found');
    return { room: publicRoom(room), members: publicMembers(room) };
  }

  get(id: string): Room | undefined {
    return this.rooms.get(id);
  }

  require(id: string): Room {
    const room = this.rooms.get(id);
    if (!room) throw new HttpError(404, 'Room not found.', 'room_not_found');
    if (room.ended) throw new HttpError(410, 'This invite has already ended.', 'room_ended');
    return room;
  }

  requireByCode(code: string): Room {
    const id = this.byCode.get(code.trim().toUpperCase());
    if (!id) throw new HttpError(404, "That code doesn't match an invite.", 'invite_not_found');
    return this.require(id);
  }

  authenticate(roomId: string, memberId: string, token: string): Member {
    const room = this.require(roomId);
    const member = room.members.get(memberId);
    if (!member || member.token !== token) {
      throw new HttpError(401, 'Not a member of this room.', 'unauthorized');
    }
    return member;
  }

  setOnline(member: Member, online: boolean): void {
    member.online = online;
    member.lastSeen = Date.now();
  }

  updateLocation(
    member: Member,
    input: {
      lat: number;
      lng: number;
      accuracy?: number;
      heading?: number | null;
      speed?: number | null;
      battery?: number | null;
    },
  ): void {
    if (!Number.isFinite(input.lat) || !Number.isFinite(input.lng)) {
      throw new HttpError(400, 'Invalid coordinates.', 'invalid_location');
    }
    if (Math.abs(input.lat) > 90 || Math.abs(input.lng) > 180) {
      throw new HttpError(400, 'Coordinates out of range.', 'invalid_location');
    }
    const previous = member.location;
    member.location = {
      lat: input.lat,
      lng: input.lng,
      accuracy: Math.max(1, Math.min(5_000, input.accuracy ?? 25)),
      heading: input.heading ?? previous?.heading ?? null,
      speed: input.speed ?? null,
      battery: input.battery ?? previous?.battery ?? null,
      ts: Date.now(),
    };
  }

  updateSettings(
    room: Room,
    input: { units?: Units; precision?: Precision; arrivalRadius?: number },
  ): RoomSettings {
    if (input.units === 'metric' || input.units === 'imperial') room.settings.units = input.units;
    if (input.precision === 'exact' || input.precision === 'approximate') {
      room.settings.precision = input.precision;
    }
    if (typeof input.arrivalRadius === 'number' && Number.isFinite(input.arrivalRadius)) {
      room.settings.arrivalRadius = Math.max(10, Math.min(500, input.arrivalRadius));
    }
    return room.settings;
  }

  removeMember(room: Room, memberId: string): void {
    const member = room.members.get(memberId);
    if (!member || member.isHost) return;
    room.members.delete(memberId);
  }

  end(room: Room): void {
    room.ended = true;
    for (const member of room.members.values()) member.online = false;
  }

  /** Delete rooms that have ended or outlived their invite window. */
  sweep(now = Date.now()): Room[] {
    const removed: Room[] = [];
    for (const room of this.rooms.values()) {
      if (room.ended || room.expiresAt <= now) {
        this.end(room);
        this.rooms.delete(room.id);
        this.byCode.delete(room.code);
        removed.push(room);
      } else {
        for (const member of room.members.values()) {
          if (member.online && now - member.lastSeen > MEMBER_OFFLINE_AFTER_MS) {
            member.online = false;
          }
        }
      }
    }
    return removed;
  }

  get size(): number {
    return this.rooms.size;
  }

  private activeMemberCount(room: Room): number {
    return room.members.size;
  }

  private newMember(input: {
    name: string;
    avatar?: unknown;
    device: DeviceKind;
    isHost: boolean;
    seed: string;
  }): Member {
    const now = Date.now();
    return {
      id: randomUUID(),
      token: randomBytes(24).toString('base64url'),
      name: input.name,
      avatar:
        (typeof input.avatar === 'string' ? input.avatar.slice(0, 8) : '') ||
        pick(AVATARS, input.seed + input.name),
      color: pick(COLORS, input.seed + input.name + 'color'),
      device: input.device,
      isHost: input.isHost,
      demo: false,
      joinedAt: now,
      online: true,
      lastSeen: now,
      location: null,
    };
  }
}

export function publicRoom(room: Room): PublicRoom {
  return {
    id: room.id,
    code: room.code,
    hostId: room.hostId,
    createdAt: room.createdAt,
    expiresAt: room.expiresAt,
    ended: room.ended,
    settings: { ...room.settings },
  };
}

export function publicMember(room: Room, member: Member): PublicMember {
  const { token: _token, ...rest } = member;
  const location = rest.location;
  return {
    ...rest,
    location:
      location && room.settings.precision === 'approximate'
        ? { ...location, ...coarsen(location), accuracy: Math.max(location.accuracy, 100) }
        : location,
  };
}

export function publicMembers(room: Room): PublicMember[] {
  return [...room.members.values()].map((member) => publicMember(room, member));
}
