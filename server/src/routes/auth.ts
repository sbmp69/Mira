import express from "express";
import { createClient } from "@supabase/supabase-js";
import { prisma } from "../db";
import { requireAuth } from "../middleware/auth";

const router = express.Router();

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_ANON_KEY!
);

// POST /api/auth/register
router.post("/register", async (req, res) => {
  try {
    const { email, password, name } = req.body;
    if (!email || !password || !name) {
      return res.status(400).json({ error: "Missing required fields" });
    }

    const { data, error } = await supabase.auth.signUp({ email, password, options: { data: { name } } });
    if (error) return res.status(400).json({ error: error.message });
    if (!data.user) return res.status(400).json({ error: "Signup failed" });

    // Create user profile in our DB using Supabase Auth UUID
    await prisma.user.upsert({
      where: { id: data.user.id },
      update: {},
      create: { id: data.user.id, email, name },
    });

    res.json({
      token: data.session?.access_token,
      user: { id: data.user.id, email, name }
    });
  } catch (error) {
    console.error("Registration error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

// POST /api/auth/login
router.post("/login", async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ error: "Missing email or password" });
    }

    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) return res.status(401).json({ error: error.message });
    if (!data.user || !data.session) return res.status(401).json({ error: "Login failed" });

    // Ensure user profile exists in our DB
    await prisma.user.upsert({
      where: { id: data.user.id },
      update: { email: data.user.email },
      create: {
        id: data.user.id,
        email: data.user.email,
        name: data.user.user_metadata?.name || data.user.email?.split("@")[0] || "User",
      }
    });

    const user = await prisma.user.findUnique({ where: { id: data.user.id } });

    res.json({
      token: data.session.access_token,
      user: { id: data.user.id, email: data.user.email, name: user?.name }
    });
  } catch (error) {
    console.error("Login error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

// POST /api/auth/push-token  (protected)
router.post("/push-token", requireAuth, async (req, res) => {
  try {
    const userId = (req as any).userId;
    const { pushToken } = req.body;
    if (!pushToken) return res.status(400).json({ error: "Missing pushToken" });

    await prisma.user.update({
      where: { id: userId },
      data: { expoPushToken: pushToken }
    });

    res.json({ success: true });
  } catch (error) {
    console.error("Push token error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
// DELETE /api/auth/account (protected)
router.delete("/account", requireAuth, async (req, res) => {
  try {
    const userId = (req as any).userId;
    // We only delete from public.User, which cascades to memories, messages, etc.
    // Deleting from auth.users requires the Supabase Service Role key.
    await prisma.user.delete({
      where: { id: userId }
    });
    // Attempt to delete from Supabase Auth if service role is available (optional)
    if (process.env.SUPABASE_SERVICE_ROLE_KEY) {
      const adminClient = createClient(process.env.SUPABASE_URL!, process.env.SUPABASE_SERVICE_ROLE_KEY);
      await adminClient.auth.admin.deleteUser(userId);
    }
    res.json({ success: true });
  } catch (error) {
    console.error("Delete account error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

export default router;
