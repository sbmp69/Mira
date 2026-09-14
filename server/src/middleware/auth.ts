import { Request, Response, NextFunction } from "express";
import { createClient } from "@supabase/supabase-js";
import { prisma } from "../db";

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_ANON_KEY!
);

export async function requireAuth(req: Request, res: Response, next: NextFunction) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return res.status(401).json({ error: "Missing or invalid authorization header" });
  }
  const token = authHeader.split(" ")[1];
  if (!token) {
    return res.status(401).json({ error: "Missing token" });
  }

  const { data: { user }, error } = await supabase.auth.getUser(token);
  if (error || !user) {
    return res.status(401).json({ error: "Invalid or expired token" });
  }

  // Ensure user profile exists in our DB (auto-create on first API call)
  const existingUser = await prisma.user.findUnique({ where: { id: user.id } });
  if (!existingUser) {
    await prisma.user.create({
      data: {
        id: user.id,
        email: user.email,
        name: user.user_metadata?.name || user.email?.split("@")[0] || "User",
      }
    });
  }

  (req as any).userId = user.id;
  next();
}
