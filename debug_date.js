
const tz = "Europe/Vilnius";
const startT = 1770706669000; // Random timestamp

function toLTString(isoStr, tz){
  if(!isoStr) return "";
  return new Date(isoStr).toLocaleString('lt-LT',{
    timeZone:tz, year:'numeric', month:'2-digit', day:'2-digit',
    hour:'2-digit', minute:'2-digit', second:'2-digit'
  }).replace(',','');
}

const iso = new Date(startT).toISOString();
const ltStr = toLTString(iso, tz);
console.log(`ISO: ${iso}`);
console.log(`LT String: '${ltStr}'`);

const parsed = new Date(ltStr);
console.log(`Parsed Date: ${parsed}`);
console.log(`Parsed Valid? ${!isNaN(parsed.getTime())}`);
