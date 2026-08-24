const express = require('express');
const bodyParser = require('body-parser');
const fs = require('fs');
const path = require('path');

const DATA_DIR = path.join(__dirname, 'data');
const SUB_FILE = path.join(DATA_DIR, 'submissions.json');

if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });
if (!fs.existsSync(SUB_FILE)) fs.writeFileSync(SUB_FILE, '[]', 'utf8');

const app = express();
app.use(bodyParser.json());
app.use(require('cors')());

app.post('/submit', (req, res) => {
  const { name, email, page } = req.body || {};
  if (!name || !email) return res.status(400).json({ error: 'name and email required' });

  const submissions = JSON.parse(fs.readFileSync(SUB_FILE, 'utf8'));
  const entry = {
    id: Date.now() + '-' + Math.random().toString(36).slice(2,8),
    name: String(name),
    email: String(email),
    page: page || 'generic',
    createdAt: new Date().toISOString(),
    processed: false
  };
  submissions.push(entry);
  fs.writeFileSync(SUB_FILE, JSON.stringify(submissions, null, 2), 'utf8');
  console.log('New submission:', entry);
  res.json({ status: 'ok' });
});

app.get('/health', (req, res) => res.json({ ok: true }));

const port = process.env.WEBHOOK_PORT ? parseInt(process.env.WEBHOOK_PORT, 10) : 3000;
app.listen(port, () => console.log('Webhook server listening on port', port));

module.exports = app;
