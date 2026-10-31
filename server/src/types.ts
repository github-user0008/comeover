export type DeviceKind = 'phone' | 'tablet' | 'tv';
export type Units = 'metric' | 'imperial';
export type Precision = 'exact' | 'approximate';

export interface Location {
  lat: number;
  lng: number;
  accuracy: number;
  heading: number | null;
  speed: number | null;
  battery: number | null;
  ts: number;
}

export interface Member {
  id: string;
  token: string;
  name: string;
  avatar: string;
  color: string;
  device: DeviceKind;
  isHost: boolean;
  demo: boolean;
  joinedAt: number;
  online: boolean;
  lastSeen: number;
  location: Location | null;
}

export interface RoomSettings {
  units: Units;
  precision: Precision;
  /** Radius in metres at which the traveller counts as "arrived". */
  arrivalRadius: number;
}

export interface Room {
  id: string;
  code: string;
  hostId: string;
  createdAt: number;
  expiresAt: number;
  ended: boolean;
  settings: RoomSettings;
  members: Map<string, Member>;
}

/** A member as sent over the wire (never includes the auth token). */
export type PublicMember = Omit<Member, 'token'>;

export interface PublicRoom {
  id: string;
  code: string;
  hostId: string;
  createdAt: number;
  expiresAt: number;
  ended: boolean;
  settings: RoomSettings;
}

export const AVATARS = ['🦊', '🐧', '🐼', '🦁', '🐙', '🦄', '🐸', '🦉'];
export const COLORS = [
  '#FFB4A2',
  '#A9D6E5',
  '#C7F9CC',
  '#FFD6A5',
  '#BDB2FF',
  '#FDE2E4',
  '#CAFFBF',
  '#9BF6FF',
];

export interface JoinResult {
  room: PublicRoom;
  member: PublicMember;
  token: string;
  members: PublicMember[];
}
