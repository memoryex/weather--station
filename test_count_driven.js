
const counts = [
    {t: 1000, v: 10}, {t: 2000, v: 20}, {t: 3000, v: 30}, // Batch 1: units 20
    {t: 4000, v: 5},  {t: 5000, v: 15}, {t: 6000, v: 25}  // Batch 2: units 20 (reset at 4000)
];
const barcodes = [
    {t: 500, val: "A", at: "2023-01-01T00:00:00"},
    {t: 4500, val: "B", at: "2023-01-01T01:00:00"}
];

// Mock helpers
function normalizeCode(v){ return v; }
const PRODUCT_MAP = new Map();
function toLTString(iso, tz) { return iso; }
function msToHMS(ms) { return ms; }

// Paste the NEW buildSegments logic here
function buildSegments(barcodes, counts, tz){
  const segs=[];
  if(!counts.length) return segs;

  // Sort chronologically just in case
  counts.sort((a,b)=>a.t-b.t);
  barcodes.sort((a,b)=>a.t-b.t);

  let batchStartI = 0;
  for (let i = 1; i < counts.length; i++) {
    // Reset detected (value drops) -> Close current batch
    if (counts[i].v < counts[i-1].v) {
        finalizeBatch(counts.slice(batchStartI, i));
        batchStartI = i;
    }
  }
  // Close last batch
  finalizeBatch(counts.slice(batchStartI));

  function finalizeBatch(batchCounts) {
      if(!batchCounts.length) return;

      let units = 0;
      for(let k=1; k<batchCounts.length; k++) {
          const d = batchCounts[k].v - batchCounts[k-1].v;
          if(d > 0) units += d;
      }

      // Heuristic: Initial jump (0->X) or missed 0->1 transition
      if (batchCounts[0].v > 0 && batchCounts[0].v <= 5) {
          units += batchCounts[0].v;
      }

      const startT = batchCounts[0].t;
      const endT = batchCounts[batchCounts.length-1].t;

      // Find matching barcode: Last one with t <= startT (or within reason)
      // Since we fetchStartBarcode at 'from', we should have coverage.
      let activeB = null;
      for (let b of barcodes) {
          if (b.t <= startT + 5*60000) { // allow 5min jitter if count starts slightly before barcode log
              activeB = b;
          } else {
              break;
          }
      }

      const bVal = activeB ? activeB.val : "N/A";
      const bTime = activeB ? activeB.at : "";

      pushSegment(bVal, units, startT, endT, bTime);
  }

  function pushSegment(barcode, units, startT, endT, bTimeStr) {
      const code = normalizeCode(barcode);
      const prodName = PRODUCT_MAP.get(code) || "";

      const durationMs = endT - startT;

      // Format dates
      const startLT = toLTString(new Date(startT).toISOString(), tz);
      const endLT = toLTString(new Date(endT).toISOString(), tz);
      const bTimeLT = toLTString(bTimeStr, tz);

      const avg = (durationMs > 0 && units > 0) ? (units / (durationMs/3600000)) : 0;

      segs.push({
        barcode: barcode,
        product: prodName,
        startLT, endLT,
        duration: msToHMS(durationMs),
        units, avg,
        startDate: startLT ? new Date(startLT) : null,
        endDate:   endLT   ? new Date(endLT)   : null,
        barcodeTime: bTimeLT
      });
  }
  return segs;
}

const res = buildSegments(barcodes, counts, "UTC");
console.log(JSON.stringify(res, null, 2));

// Expectation:
// Segment 1: start 1000, end 3000. Barcode: "A" (500 <= 1000). Units 20 + 10(heuristic) = 30?
// counts: 10, 20, 30. Diff: 10+10=20. Init: 10 (>5). Heuristic only for <=5.
// So units 20.
// Segment 2: start 4000, end 6000. Barcode: "A" (500 <= 4000). Wait, 4500 > 4000.
// Barcode search: find LAST b where b.t <= startT (4000).
// Barcodes: 500, 4500.
// 500 <= 4000: Yes.
// 4500 <= 4000: No.
// So Segment 2 should be "A".
// Is this correct? If barcode changed at 4500 (mid-batch), should we split?
// Or assume batch started under old barcode?
// Usually barcode scan precedes production.
// If scan at 4500, maybe it applies to batch starting 4000?
// My logic uses "last known before start".
// If I want "closest", I might look ahead?
// But "paskutinis barcode" usually means "last known state".
// If operator forgot to scan and scanned mid-run, it's ambiguous.
// But mostly consistent.
