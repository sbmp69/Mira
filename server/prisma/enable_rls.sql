-- Enable Row Level Security (RLS) on all public tables for Supabase security compliance
ALTER TABLE "public"."User" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."Companion" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."Conversation" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."Message" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."Memory" ENABLE ROW LEVEL SECURITY;
