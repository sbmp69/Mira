import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import chatRouter from './routes/chat';
import companionsRouter from './routes/companions';
import authRouter from './routes/auth';
import cronRouter from './routes/cron';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'Mira AI Backend' });
});

app.use('/api/chat', chatRouter);
app.use('/api/companions', companionsRouter);
app.use('/api/auth', authRouter);
app.use('/api/cron', cronRouter);

app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});

// Keep event loop alive explicitly (should not be needed, but just in case)
setInterval(() => {}, 1000 * 60 * 60);

export default app;
