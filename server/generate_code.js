function pad(n){return n<10?'0'+n:''+n}

function getWeekNumber(d){
  // Copy date so don't modify original
  const date = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
  // Set to nearest Thursday: current date + 4 - current day number
  const dayNum = date.getUTCDay() || 7;
  date.setUTCDate(date.getUTCDate() + 4 - dayNum);
  const yearStart = new Date(Date.UTC(date.getUTCFullYear(),0,1));
  const weekNo = Math.ceil((((date - yearStart) / 86400000) + 1)/7);
  return weekNo;
}

function generateCode(type){
  const now = new Date();
  const rand = Math.random().toString(36).slice(2,8).toUpperCase();
  if(type === 'week'){
    const week = getWeekNumber(now);
    return `CODE-WEEK-${now.getFullYear()}W${pad(week)}-${rand}`;
  }
  if(type === 'day'){
    const d = `${now.getFullYear()}${pad(now.getMonth()+1)}${pad(now.getDate())}`;
    return `CODE-DAY-${d}-${rand}`;
  }
  // default
  return `CODE-GEN-${now.getTime().toString().slice(-6)}-${rand}`;
}

module.exports = { generateCode };
