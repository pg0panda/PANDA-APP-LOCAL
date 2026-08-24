const fs = require('fs');
const path = require('path');
const { generateCode } = require('./generate_code');
const nodemailer = require('nodemailer');

const DATA_DIR = path.join(__dirname, '..', 'data');
const SUB_FILE = path.join(DATA_DIR, 'submissions.json');

function loadConfig(){
  // Prefer env vars, fallback to server/config.json
  const user = process.env.GMAIL_USER;
  const pass = process.env.GMAIL_PASS;
  if(user && pass) return { user, pass };
  try{
    const cfg = JSON.parse(fs.readFileSync(path.join(__dirname, 'config.json'), 'utf8'));
    return { user: cfg.gmail.user, pass: cfg.gmail.pass };
  }catch(e){
    console.error('No Gmail config found. Set GMAIL_USER/GMAIL_PASS or server/config.json');
    process.exit(1);
  }
}

async function sendEmail({to, subject, text}){
  const { user, pass } = loadConfig();
  const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: { user, pass }
  });
  await transporter.sendMail({ from: user, to, subject, text });
}

function readSubmissions(){
  if(!fs.existsSync(SUB_FILE)) return [];
  try{return JSON.parse(fs.readFileSync(SUB_FILE, 'utf8'));}catch(e){return []}
}

function saveSubmissions(list){
  fs.writeFileSync(SUB_FILE, JSON.stringify(list, null, 2), 'utf8');
}

async function processOnce(){
  const submissions = readSubmissions();
  let changed = false;
  for(const s of submissions){
    if(s.processed) continue;
    const code = generateCode(s.page === 'week' ? 'week' : (s.page === 'day' ? 'day' : 'generic'));
    const subject = `Your code from Panda-Toolbox`;
    const text = `مرحبا ${s.name}\n\nهذا هو الكود الخاص بك:\n\n${code}\n\nشكراً لدعمك.`;
    try{
      console.log('Sending code to', s.email, 'code=', code);
      await sendEmail({ to: s.email, subject, text });
      s.processed = true;
      s.code = code;
      s.sentAt = new Date().toISOString();
      changed = true;
    }catch(e){
      console.error('Failed to send to', s.email, e.message);
    }
  }
  if(changed) saveSubmissions(submissions);
}

async function start(){
  console.log('Poller started - checking submissions every 30 seconds');
  await processOnce();
  setInterval(processOnce, 30*1000);
}

start().catch(err=>{console.error(err); process.exit(1)});
