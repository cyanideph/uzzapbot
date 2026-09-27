-- Production UzzapBot memory/vector/dispatch snapshot.
-- This file documents the live architecture; review against production before migration.

-- Required extension/type is provided by Supabase pgvector.
-- public.uzzapbot_memory.embedding is extensions.vector(384).

CREATE INDEX IF NOT EXISTS uzzapbot_memory_embedding_hnsw
  ON public.uzzapbot_memory USING hnsw (embedding vector_ip_ops);

CREATE OR REPLACE FUNCTION public.uzzapbot_memory_semantic_search_v1(
  p_user_id uuid,
  p_room_name text,
  query_embedding extensions.vector(384),
  p_match_threshold real DEFAULT 0.55,
  p_match_count integer DEFAULT 8
)
RETURNS TABLE(
  id bigint, user_id uuid, room_name text, memory_key text, memory_value text,
  memory_type text, source text, confidence numeric, importance smallint,
  memory_scope text, expires_at timestamptz, similarity real, updated_at timestamptz
)
LANGUAGE sql STABLE SECURITY INVOKER
SET search_path = public, extensions
AS $$
  select m.id,m.user_id,m.room_name,m.memory_key,m.memory_value,m.memory_type,
    m.source,m.confidence,m.importance,m.memory_scope,m.expires_at,
    ((m.embedding <#> query_embedding) * -1)::real as similarity,
    m.updated_at
  from public.uzzapbot_memory m
  where m.embedding is not null
    and m.user_id = p_user_id
    and m.room_name is not distinct from p_room_name
    and (m.expires_at is null or m.expires_at > now())
    and ((m.embedding <#> query_embedding) * -1) >= p_match_threshold
  order by m.embedding <#> query_embedding
  limit greatest(1,least(coalesce(p_match_count,8),20));
$$;

REVOKE ALL ON FUNCTION public.uzzapbot_memory_semantic_search_v1(uuid,text,extensions.vector(384),real,integer) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.uzzapbot_memory_semantic_search_v1(uuid,text,extensions.vector(384),real,integer) TO service_role;

CREATE OR REPLACE FUNCTION public.uzzapbot_upsert_memory_v3(
  p_user_id uuid,p_room_name text,p_memory_key text,p_memory_value text,
  p_memory_type text DEFAULT 'fact',p_source text DEFAULT 'explicit',
  p_confidence numeric DEFAULT 1.00,p_importance smallint DEFAULT 50,
  p_memory_scope text DEFAULT 'long_term',p_expires_at timestamptz DEFAULT NULL
)
RETURNS public.uzzapbot_memory
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
declare v_row public.uzzapbot_memory;
begin
  if p_user_id is null then raise exception 'user_id is required'; end if;
  if p_memory_key is null or btrim(p_memory_key)='' then raise exception 'memory_key is required'; end if;
  if p_memory_value is null or btrim(p_memory_value)='' then raise exception 'memory_value is required'; end if;
  if p_importance < 0 or p_importance > 100 then raise exception 'importance must be 0..100'; end if;
  if p_memory_scope not in ('long_term','room','session','temporary') then raise exception 'invalid memory_scope'; end if;
  if p_memory_scope='temporary' and p_expires_at is null then raise exception 'temporary memory requires expires_at'; end if;
  insert into public.uzzapbot_memory(user_id,room_name,memory_key,memory_value,memory_type,source,confidence,importance,memory_scope,expires_at,updated_at)
  values(p_user_id,p_room_name,btrim(p_memory_key),btrim(p_memory_value),p_memory_type,p_source,greatest(0,least(1,p_confidence)),p_importance,p_memory_scope,p_expires_at,now())
  on conflict (user_id,room_name,memory_key) do update set
    memory_value=excluded.memory_value,memory_type=excluded.memory_type,source=excluded.source,
    confidence=excluded.confidence,importance=excluded.importance,memory_scope=excluded.memory_scope,
    expires_at=excluded.expires_at,updated_at=now()
  returning * into v_row;
  return v_row;
end;
$$;

CREATE OR REPLACE FUNCTION public.uzzapbot_cleanup_memory_v1(
  p_user_id uuid,p_room_name text DEFAULT NULL,p_max_per_room integer DEFAULT 50
)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
declare v_deleted integer:=0; v_trimmed integer:=0; v_max integer:=greatest(1,least(coalesce(p_max_per_room,50),50));
begin
  if p_user_id is null then raise exception 'user_id is required'; end if;
  delete from public.uzzapbot_memory where user_id=p_user_id and room_name is not distinct from p_room_name and
    ((expires_at is not null and expires_at<=now()) or
     (memory_scope='session' and updated_at<now()-interval '3 days') or
     (memory_scope='room' and updated_at<now()-interval '30 days') or
     (memory_scope='long_term' and importance<80 and updated_at<now()-interval '180 days') or
     (memory_scope='long_term' and importance>=80 and updated_at<now()-interval '365 days'));
  get diagnostics v_deleted=row_count;
  with ranked as (select id,row_number() over(order by importance asc,confidence asc,updated_at asc,id asc) rn
                  from public.uzzapbot_memory where user_id=p_user_id and room_name is not distinct from p_room_name)
  delete from public.uzzapbot_memory m using ranked r where m.id=r.id and r.rn>v_max;
  get diagnostics v_trimmed=row_count;
  return v_deleted+v_trimmed;
end;
$$;

CREATE TRIGGER trg_uzzapbot_dispatch
AFTER INSERT ON public.room_messages
FOR EACH ROW
WHEN (COALESCE(new.sender,'') <> ALL (ARRAY['UzzapBot','uzzapbot']))
EXECUTE FUNCTION public.uzzapbot_dispatch_new_message();

-- Live dispatch function uses Vault; credentials are intentionally not copied here.
