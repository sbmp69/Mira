const { PrismaClient } = require('@prisma/client'); 
const { Pool } = require('pg'); 
const { PrismaPg } = require('@prisma/adapter-pg'); 
require('dotenv').config(); 
const pool = new Pool({ connectionString: process.env.DATABASE_URL }); 
const adapter = new PrismaPg(pool); 
const prisma = new PrismaClient({ adapter }); 
async function run() { 
  try { 
    // Delete any messages that depend on conversations
    const conversations = await prisma.conversation.findMany({ where: { companionId: '715ca4b0-1ffe-441f-b519-66ef79040b30' } });
    for (const c of conversations) {
      await prisma.message.deleteMany({ where: { conversationId: c.id } });
    }
    // Delete conversations
    await prisma.conversation.deleteMany({ where: { companionId: '715ca4b0-1ffe-441f-b519-66ef79040b30' }}); 
    // Delete companion
    await prisma.companion.delete({ where: { id: '715ca4b0-1ffe-441f-b519-66ef79040b30' }}); 
    console.log('Deleted Aarohi'); 
  } catch (e) { 
    console.log(e); 
  } finally { 
    await prisma.$disconnect(); 
  } 
} 
run();
