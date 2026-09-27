# Production Dependency Inventory

This repository contains the Edge Function source plus an inventory of live Supabase dependencies. The database itself remains authoritative; this file prevents accidental omission when reconstructing the bot.

## Edge Function RPC dependencies
- uzzapbot_validate_dispatch_token
- uzzapbot_random_word
- uzzapbot_cleanup_memory_v1
- uzzapbot_memory_semantic_search_v1
- uzzapbot_get_memory_v3
- uzzapbot_get_memory_v2
- uzzapbot_upsert_memory_v3
- uzzapbot_ai_admit
- room_bot_message
- uzzapbot_finish_receipt
- uzzapbot_grant_default_powerups
- uzzapbot_record_game_start
- uzzapbot_claim_receipt

## Table dependencies
- uzzapbot_questions
- uzzapbot_game_pools
- uzzapbot_memory
- room_messages
- game_sessions
- moderator_roles
- uzzapbot_room_settings
- uzzapbot_question_usage
- game_players
- uzzapbot_player_stats
- uzzapbot_achievements
- uzzapbot_player_achievements
- uzzapbot_titles
- uzzapbot_player_titles
- uzzapbot_xp_history
- uzzapbot_player_activity
- uzzapbot_powerup_uses
- uzzapbot_daily_challenges
- uzzapbot_battles
- uzzapbot_room_challenges
- uzzapbot_tournaments
- uzzapbot_room_activity
- profiles
- uzzapbot_powerups
- uzzapbot_event_receipts

## Trigger dependencies
- trg_room_message_rate_limit
- trg_room_message_sender
- trg_uzzapbot_dispatch

## Supporting production services
- Supabase Edge Functions
- PostgreSQL / RLS
- pgvector
- Supabase AI `gte-small`
- Realtime
- pg_net HTTP dispatch
- Supabase Vault
- Supabase Cron / activity tick
- Cloudflare AI gateway (source copied under `gateway/`)
- Puter AI backup

## Important boundary
The repository does not contain secrets, Vault values, generated production data, or the entire unrelated Supabase schema. SQL snapshots should be expanded from the live database before using this repository as a full infrastructure migration.
