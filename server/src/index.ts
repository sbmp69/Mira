import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

import chatRouter from './routes/chat';

app.use(cors());
app.use(express.json());

app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'Mira AI Backend' });
});

app.use('/api/chat', chatRouter);

app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});
