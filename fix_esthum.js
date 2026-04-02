const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');

// The issue is that `estHum` is declared inside `if (sysData && sysData.feeds && forecast && forecast.list) { ... let estHum = ... }`
// but accessed outside.
// Let's modify it so estHum is declared outside, defaulting to say 13.5.

const search = `                let grainHumHTML = '';
                if (sysData && sysData.feeds && forecast && forecast.list) {
                    let pastHum = sysData.feeds.map(f => parseFloat(f.field2)).filter(n => !isNaN(n));
                    let avgPastHum = pastHum.length ? pastHum.reduce((a,b)=>a+b,0)/pastHum.length : 65;

                    let futureHum = forecast.list.slice(0, 16).map(f => f.main.humidity); // next ~48h
                    let avgFutureHum = futureHum.length ? futureHum.reduce((a,b)=>a+b,0)/futureHum.length : 65;

                    let estHum = 13.5 + Math.max(0, avgPastHum - 65) * 0.04 + Math.max(0, avgFutureHum - 65) * 0.02;`;

const replace = `                let grainHumHTML = '';
                let estHum = 13.5;
                if (sysData && sysData.feeds && forecast && forecast.list) {
                    let pastHum = sysData.feeds.map(f => parseFloat(f.field2)).filter(n => !isNaN(n));
                    let avgPastHum = pastHum.length ? pastHum.reduce((a,b)=>a+b,0)/pastHum.length : 65;

                    let futureHum = forecast.list.slice(0, 16).map(f => f.main.humidity); // next ~48h
                    let avgFutureHum = futureHum.length ? futureHum.reduce((a,b)=>a+b,0)/futureHum.length : 65;

                    estHum = 13.5 + Math.max(0, avgPastHum - 65) * 0.04 + Math.max(0, avgFutureHum - 65) * 0.02;`;

html = html.replace(search, replace);
fs.writeFileSync('index.html', html);
console.log("Fixed estHum scope");
