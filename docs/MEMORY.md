# UzzapBot Vector Memory

Production memory architecture snapshot.

## Vector layer
- Table: public.uzzapbot_memory
- Embedding column: extensions.vector(384)
- Embedding model: Supabase Edge Runtime `gte-small`
- Index: `uzzapbot_memory_embedding_hnsw`
- Distance path: inner-product operator `<#>`
- Semantic RPC: `uzzapbot_memory_semantic_search_v1`
- Threshold used by UzzapBot: 0.55
- Retrieval count: 8

## Retrieval pipeline
1. Clean expired/old memory.
2. Lazily backfill rows without embeddings.
3. Embed the current query with `gte-small`.
4. Run user + room scoped semantic search.
5. Apply deterministic intent bonuses for nickname, language, music, work, and style.
6. Fall back to v3/v2 non-vector retrieval if semantic retrieval is unavailable.

## Write pipeline
`uzzapbot_upsert_memory_v3` writes the memory, then the Edge Function embeds `memory_key + ': ' + memory_value` and stores the 384-dimensional vector.

## Retention
- temporary: requires expiry
- session: cleaned after 3 days
- room: cleaned after 30 days
- long-term importance < 80: cleaned after 180 days
- long-term importance >= 80: cleaned after 365 days
- maximum retained per user/room: 50

## Security
Memory RLS is user-scoped. Semantic search is restricted to service_role. Legacy memory RPC execution is restricted from anon/authenticated clients. The dispatch token remains in Supabase Vault and is never stored in this repository.
