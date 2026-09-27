# UzzapBot Architecture

UzzapBot 4.9.6 / CY Aether Core / Supabase Edge Function v182.

## Event flow

UzzapAndroid message -> room_messages INSERT -> room-message triggers -> uzzapbot_dispatch_new_message() -> Supabase Vault dispatch token -> UzzapBot Edge Function -> claim receipt -> command/game/AI processing -> room_bot_message() -> room_messages -> Realtime -> UzzapAndroid.

## AI

The Edge Function uses a separate AI gateway. Production order is Cloudflare Worker first, Puter backup. The application system prompt controls personality, language, memory and conversation behavior. Deterministic commands are handled without an AI call.

## Data

Questions are sourced from public.uzzapbot_questions. WordHunt data is sourced through uzzapbot_random_word. Game selection uses uzzapbot_game_pools with deterministic anti-repeat behavior.

## Security

The Edge Function requires the internal dispatch token. Service-role database access is used server-side. No credentials are committed here.
