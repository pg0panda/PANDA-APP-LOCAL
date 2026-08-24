const fs = require('fs');
const path = require('path');

function loadJson(p){ return JSON.parse(fs.readFileSync(p,'utf8')); }
function saveJson(p,obj){ fs.writeFileSync(p, JSON.stringify(obj, null, 2), 'utf8'); }

async function main(){
  const args = process.argv.slice(2);
  if(args.length < 2){
    console.error('Usage: node claim_code.js <category> <code>');
    process.exit(2);
  }
  const [category, code] = args;
  const base = path.join(__dirname, '..', 'src', 'data');
  const availPath = path.join(base, 'available_codes.json');
  const claimedPath = path.join(base, 'claimed_codes.json');
  const avail = loadJson(availPath);
  const claimed = loadJson(claimedPath);
  if(!avail[category] || !Array.isArray(avail[category])){
    console.error('Unknown category', category); process.exit(3);
  }
  const idx = avail[category].indexOf(code);
  if(idx === -1){
    console.error('Code not found in available list'); process.exit(4);
  }
  // remove from available
  avail[category].splice(idx,1);
  saveJson(availPath, avail);
  // add to claimed with metadata
  if(!claimed.claimed) claimed.claimed = [];
  claimed.claimed.push({ code, category, claimedAt: new Date().toISOString() });
  saveJson(claimedPath, claimed);
  console.log('Moved', code, 'from', category, 'to claimed');
}

main().catch(e=>{ console.error(e); process.exit(10); });
