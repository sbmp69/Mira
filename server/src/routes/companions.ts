import express from 'express';
import { PrismaClient } from '@prisma/client';
import { Pool } from 'pg';
import { PrismaPg } from '@prisma/adapter-pg';

const router = express.Router();
const connectionString = process.env.DATABASE_URL;
const pool = new Pool({ connectionString });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

// GET /api/companions
router.get('/', async (req, res) => {
  try {
    const companions = await prisma.companion.findMany({
      select: {
        id: true,
        name: true,
        avatar: true,
        description: true,
      }
    });
    res.json({ companions });
  } catch (error) {
    console.error('Failed to fetch companions:', error);
    res.status(500).json({ error: 'Failed to fetch companions' });
  }
});

export default router;
