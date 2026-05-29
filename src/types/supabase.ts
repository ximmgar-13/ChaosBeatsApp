export type MembershipTier = "free" | "early_bird" | "premium" | "lifetime";
export type SongStatus = "draft" | "published" | "archived";
export type NotificationType = "new_song" | "playlist_update" | "donation" | "system" | "comment" | "follow";
export type QualityPreference = "low" | "medium" | "high" | "lossless";
export type PlanType = "monthly" | "yearly" | "lifetime";
export type MembershipStatus = "active" | "canceled" | "past_due" | "expired" | "trialing";
export type SupporterTier = "beta_tester" | "founder" | "early_bird" | "angel";
export type PaymentStatus = "pending" | "completed" | "failed" | "refunded";

export interface User {
  id: string;
  username: string;
  display_name: string | null;
  avatar_url: string | null;
  bio: string | null;
  website: string | null;
  phone: string | null;
  is_premium: boolean;
  membership_tier: MembershipTier | null;
  membership_expires_at: string | null;
  storage_used_mb: number;
  storage_limit_mb: number;
  created_at: string;
  updated_at: string;
}

export interface Song {
  id: string;
  artist_id: string;
  title: string;
  album: string | null;
  genre: string | null;
  duration_seconds: number | null;
  audio_url: string;
  cover_url: string | null;
  lyrics: string | null;
  is_explicit: boolean;
  play_count: number;
  download_count: number;
  is_offline_available: boolean;
  status: SongStatus;
  created_at: string;
  updated_at: string;
  artist?: Pick<User, "id" | "username" | "display_name" | "avatar_url">;
}

export interface Playlist {
  id: string;
  owner_id: string;
  name: string;
  description: string | null;
  cover_url: string | null;
  is_public: boolean;
  is_collaborative: boolean;
  song_count: number;
  total_duration_seconds: number;
  created_at: string;
  updated_at: string;
}

export interface PlaylistSong {
  id: string;
  playlist_id: string;
  song_id: string;
  position: number;
  added_at: string;
  added_by: string | null;
}

export interface Favorite {
  id: string;
  user_id: string;
  song_id: string;
  created_at: string;
}

export interface Donation {
  id: string;
  user_id: string;
  amount: number;
  currency: string;
  message: string | null;
  is_anonymous: boolean;
  payment_method: string | null;
  payment_status: PaymentStatus;
  created_at: string;
}

export interface EarlyListener {
  id: string;
  user_id: string;
  supporter_tier: SupporterTier;
  access_granted_at: string;
  expires_at: string | null;
  is_active: boolean;
}

export interface Comment {
  id: string;
  user_id: string;
  song_id: string;
  parent_id: string | null;
  content: string;
  is_edited: boolean;
  created_at: string;
  updated_at: string;
}

export interface Notification {
  id: string;
  user_id: string;
  title: string;
  body: string | null;
  data: unknown;
  type: NotificationType;
  is_read: boolean;
  sent_at: string;
  read_at: string | null;
}

export interface UserSettings {
  user_id: string;
  language: string;
  dark_mode: boolean;
  notifications_enabled: boolean;
  push_notifications_enabled: boolean;
  email_notifications: boolean;
  offline_auto_download: boolean;
  quality_preference: QualityPreference;
  show_explicit_content: boolean;
  autoplay: boolean;
  updated_at: string;
}

export interface UserMembership {
  id: string;
  user_id: string;
  stripe_customer_id: string | null;
  stripe_subscription_id: string | null;
  plan_type: PlanType;
  status: MembershipStatus;
  current_period_start: string | null;
  current_period_end: string | null;
  canceled_at: string | null;
  created_at: string;
}
