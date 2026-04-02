const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');

// --- 1. NEXT VENTILATION WITH EFFICIENCY ---
// Find "Find next ventilation window" and replace it
const nextVentSearch = `// Find next ventilation window
        let nextVent = "Nėra duomenų";
        if (forecast && forecast.list) {
            const window = forecast.list.find(f => f.main.humidity < 80);
            if (window) {
                const date = new Date(window.dt * 1000);
                const dayName = date.toLocaleDateString('lt-LT', { weekday: 'long' });
                const time = date.toLocaleTimeString('lt-LT', { hour: '2-digit', minute: '2-digit' });
                nextVent = \`\${dayName} \${time} (Drėgmė: \${window.main.humidity}%)\`;
            } else {
                nextVent = "Artimiausias 5 dienas drėgmė > 80%";
            }
        }`;

const nextVentReplace = `// Find next ventilation window and Solar Risk
        let nextVentObj = null;
        let nextVentStr = "Nėra duomenų";
        let solarRiskStr = "🌞 Saulės įkaitimo rizika: Nėra";
        let solarRiskColor = "var(--text-muted)";

        if (forecast && forecast.list) {
            nextVentObj = forecast.list.find(f => f.main.humidity < 80);
            if (nextVentObj) {
                const date = new Date(nextVentObj.dt * 1000);
                const dayName = date.toLocaleDateString('lt-LT', { weekday: 'long' });
                const time = date.toLocaleTimeString('lt-LT', { hour: '2-digit', minute: '2-digit' });
                nextVentStr = \`\${dayName} \${time} (Drėgmė: \${nextVentObj.main.humidity}%, Temp: \${Math.round(nextVentObj.main.temp)}°C)\`;
            } else {
                nextVentStr = "Artimiausias 5 dienas drėgmė > 80%";
            }

            // Solar risk: look for sunny warm days
            const sunnyWarm = forecast.list.find(f => f.main.temp > 18 && f.clouds.all < 30 && new Date(f.dt*1000).getHours() >= 10 && new Date(f.dt*1000).getHours() <= 16);
            if (sunnyWarm) {
                const date = new Date(sunnyWarm.dt * 1000);
                solarRiskStr = \`🌞 Rizika pietinei sienai: \${date.toLocaleDateString('lt-LT', {weekday:'short'})} (\${Math.round(sunnyWarm.main.temp)}°C, giedra)\`;
                solarRiskColor = "var(--warning)";
            }
        }`;
html = html.replace(nextVentSearch, nextVentReplace);

// Replace the nextVent usage in the card HTML
html = html.replace(
    `🌬️ Artimiausias vėdinimas (< 80%):<br><b>\${nextVent}</b>`,
    `🌬️ Artimiausias vėdinimas (< 80%):<br><b>\${nextVentStr}</b>\${ventEfficiencyHTML}`
);


// --- THE REST OF THE FEATURES INSIDE THE TOWER LOOP ---
// Find where `estHum` is calculated to add SST, Mold, Stratification, ROI

const insertionPoint = `const card = document.createElement('div');`;

const newFeaturesStr = `
                // 1. SST (Safe Storage Time)
                let sstDays = 300 * Math.pow(0.5, (estHum - 12)) * Math.pow(0.5, (currentAvg - 10) / 5);
                sstDays = Math.max(1, Math.round(sstDays));
                let sstLabel = sstDays > 60 ? 'Saugu ilgam' : sstDays > 30 ? 'Vidutinis terminas' : 'Rizikingas terminas';
                let sstColor = sstDays > 60 ? 'var(--success)' : sstDays > 30 ? 'var(--warning)' : 'var(--danger)';

                // 2. Ventilation Efficiency
                let ventEfficiencyHTML = "";
                if (nextVentObj) {
                    let coolingPot = currentAvg - nextVentObj.main.temp;
                    let effLabel = coolingPot > 5 ? "AUKŠTAS" : coolingPot > 2 ? "VIDUTINIS" : "ŽEMAS";
                    let effColor = coolingPot > 5 ? "var(--success)" : coolingPot > 2 ? "var(--warning)" : "var(--danger)";
                    ventEfficiencyHTML = \`<br><span style="color:\${effColor}; font-size:0.75rem;">Efektyvumas: \${effLabel} (Potencialas: \${coolingPot>0?'-':'+'}\${Math.abs(coolingPot).toFixed(1)}°C)</span>\`;
                }

                // 3. Mold / Microtoxin Risk
                let moldRisk = (estHum > 14.5 && currentAvg > 10);
                let moldStr = moldRisk ? "⚠️ Palankios sąlygos pelėsiui!" : "✅ Pelėsio rizika maža";
                let moldColor = moldRisk ? "var(--danger)" : "var(--success)";

                // 5. Stratification (Moisture Migration)
                let maxDepthTemp = Math.max(...sensorTemps);
                let minDepthTemp = Math.min(...sensorTemps);
                let stratDiff = maxDepthTemp - minDepthTemp;
                let stratRisk = stratDiff > 5.0;
                let stratStr = stratRisk ? \`⚠️ Migracijos rizika (ΔT = \${stratDiff.toFixed(1)}°C tarp sluoksnių)\` : \`✅ Sluoksniai stabilūs (ΔT = \${stratDiff.toFixed(1)}°C)\`;
                let stratColor = stratRisk ? "var(--danger)" : "var(--text-muted)";

                // 6. Fan ROI Estimation (Fallback/Mock as we don't have historical relay state in TS)
                // We'll calculate max temperature drop in the last 48h
                let past48hMax = Math.max(...historicalAvgs);
                let past48hDrop = past48hMax - currentAvg;
                let roiStr = past48hDrop > 0.5 ? \`Paskutinis atvėsimas: -\${past48hDrop.toFixed(1)}°C\` : "Reikšmingo vėsimo nefiksuota";

                let newIndicatorsHTML = \`
                    <div style="display:grid; grid-template-columns: 1fr 1fr; gap:5px; margin-top:10px; font-size:0.7rem; color:var(--text-muted);">
                        <div style="background:rgba(255,255,255,0.05); padding:5px; border-radius:4px; border-left:2px solid \${sstColor};">
                            ⏳ <b>SST Laikas:</b><br><span style="color:\${sstColor}">~\${sstDays} d. (\${sstLabel})</span>
                        </div>
                        <div style="background:rgba(255,255,255,0.05); padding:5px; border-radius:4px; border-left:2px solid \${moldColor};">
                            🦠 <b>Pelėsis/Toksinai:</b><br><span style="color:\${moldColor}">\${moldStr}</span>
                        </div>
                        <div style="background:rgba(255,255,255,0.05); padding:5px; border-radius:4px; border-left:2px solid \${stratColor};">
                            📉 <b>Sluoksniavimasis:</b><br><span style="color:\${stratColor}">\${stratStr}</span>
                        </div>
                        <div style="background:rgba(255,255,255,0.05); padding:5px; border-radius:4px; border-left:2px solid \${solarRiskColor};">
                            ☀️ <b>Išorinis poveikis:</b><br><span style="color:\${solarRiskColor}">\${solarRiskStr}</span>
                        </div>
                        <div style="grid-column: span 2; background:rgba(255,255,255,0.05); padding:5px; border-radius:4px; border-left:2px solid var(--accent); text-align:center;">
                            🔄 <b>Vėdinimo ROI:</b> \${roiStr}
                        </div>
                    </div>
                \`;
`;

html = html.replace(insertionPoint, newFeaturesStr + '\n' + insertionPoint);

// Insert `newIndicatorsHTML` into the card HTML
html = html.replace(
    `\${grainHumHTML}`,
    `\${grainHumHTML}
                        \${newIndicatorsHTML}`
);

fs.writeFileSync('index.html', html);
console.log("Patched successfully");
