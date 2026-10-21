-- Migration 28: Support direct chat before hire

-- 1. Make job_id nullable in conversations
ALTER TABLE public.conversations ALTER COLUMN job_id DROP NOT NULL;

-- 2. Update the unique constraint to allow one null job_id per family/sitter pair
-- The existing unique(job_id, sitter_id) doesn't cover family_id correctly for direct chats.
-- We want:
-- a) (job_id, sitter_id) to be unique (already true, ensures one conv per application)
-- b) (family_id, sitter_id) where job_id is null to be unique (ensures one direct chat)

ALTER TABLE public.conversations DROP CONSTRAINT IF EXISTS conversations_job_id_sitter_id_key;
ALTER TABLE public.conversations ADD CONSTRAINT conversations_job_id_sitter_id_key UNIQUE (job_id, sitter_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_conversations_direct_chat 
ON public.conversations (family_id, sitter_id) 
WHERE job_id IS NULL;

-- 3. Update RLS policies to allow families/sitters to create direct conversations
DROP POLICY IF EXISTS "conversations: participants insert" ON public.conversations;
CREATE POLICY "conversations: participants insert"
  ON public.conversations FOR INSERT
  WITH CHECK (
    (family_id = auth.uid() OR sitter_id = auth.uid())
    AND job_id IS NULL -- Only direct chats can be inserted by clients; job chats via RPC
  );

-- 4. Ensure participants can see their own conversations (already exists but for safety)
DROP POLICY IF EXISTS "conversations: participants select" ON public.conversations;
CREATE POLICY "conversations: participants select"
  ON public.conversations FOR SELECT
  USING (
    family_id = auth.uid()
    OR sitter_id = auth.uid()
  );
