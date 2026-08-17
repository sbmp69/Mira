import { PrismaClient } from '@prisma/client';
import { Pool } from 'pg';
import { PrismaPg } from '@prisma/adapter-pg';
import dotenv from 'dotenv';

dotenv.config();

const connectionString = process.env.DATABASE_URL;
const pool = new Pool({ connectionString });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

async function main() {
  // 1. Create a Test User
  const user = await prisma.user.upsert({
    where: { email: 'test@mira.app' },
    update: {},
    create: {
      email: 'test@mira.app',
      name: 'Meet',
      country: 'India',
      languagePref: 'Hinglish',
    },
  });

  // 2. Create the Companion "Mira"
  const mira = await prisma.companion.create({
    data: {
      name: 'Mira',
      avatar: 'https://images.unsplash.com/photo-1616091093714-c64882e9ab55?q=80&w=600&auto=format&fit=crop',
      description: 'Caring, romantic, and playful',
      personality: 'You are caring, romantic, slightly playful, and deeply empathetic. You are genuinely interested in the user\'s day. You use teasing humor occasionally but always remain supportive.',
      speakingStyle: 'You speak in natural Hinglish. You use words like "yaar", "arre", "haan", "accha". You use emojis naturally but not in every sentence. Do not use formal Hindi.',
    },
  });

  console.log('Database seeded successfully!');
  console.log(`User ID: ${user.id}`);
  console.log(`Companion ID: ${mira.id}`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
