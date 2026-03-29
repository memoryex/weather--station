
const counts = [
    {t: 1000, v: 0}, {t: 2000, v: 10}, {t: 3000, v: 20}, // Batch 1: starts 2000, ends 3000
    {t: 4000, v: 5},  {t: 5000, v: 15} // Batch 2: starts 4000, ends 5000
];
const barcodes = []; // No barcodes

// Mock helpers
function normalizeCode(v){ return v; }
const PRODUCT_MAP = new Map();
function toLTString(iso, tz) { return iso; }
function msToHMS(ms) { return ms; }

// Paste NEW buildSegments logic here
function buildSegments(barcodes, counts, tz){
  const segs=[];
  if(!counts.length) return segs;

  counts.sort((a,b)=>a.t-b.t);
  barcodes.sort((a,b)=>a.t-b.t);

  let batchStartI = 0;
  for (let i = 1; i < counts.length; i++) {
    if (counts[i].v < counts[i-1].v) {
        finalizeBatch(counts.slice(batchStartI, i));
        batchStartI = i;
    }
  }
  finalizeBatch(counts.slice(batchStartI));

  function finalizeBatch(batchCounts) {
      if(!batchCounts.length) return;

      let units = 0;
      for(let k=1; k<batchCounts.length; k++) {
          const d = batchCounts[k].v - batchCounts[k-1].v;
          if(d > 0) units += d;
      }

      if (batchCounts[0].v > 0 && batchCounts[0].v <= 5) {
          units += batchCounts[0].v;
      }

      // Start time: first record > 0 (start of production), or start of batch if all 0
      const firstPos = batchCounts.find(c => c.v > 0);
      const startT = firstPos ? firstPos.t : batchCounts[0].t;

      // End time: last record of the batch (peak before reset/end)
      const endT = batchCounts[batchCounts.length-1].t;

      let activeB = null;
      for (let b of barcodes) {
          if (b.t <= endT) {
              activeB = b;
          } else {
              break;
          }
      }

      let bVal = (activeB && activeB.val != null) ? activeB.val : "Nuskanuota iš seniau";
      if (bVal === "null") bVal = "Nuskanuota iš seniau";

      const bTime = activeB ? activeB.at : "";

      pushSegment(bVal, units, startT, endT, bTime);
  }

  function pushSegment(barcode, units, startT, endT, bTimeStr) {
      // Mock push
      segs.push({
        barcode: barcode,
        units,
        startT,
        endT
      });
  }
  return segs;
}

const res = buildSegments(barcodes, counts, "UTC");
console.log(JSON.stringify(res, null, 2));
