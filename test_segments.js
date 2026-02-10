
const tz = "Europe/Vilnius";

// Mock helper
function toLTString(isoStr) { return isoStr; } // Simplified
function msToHMS(ms) { return Math.floor(ms/1000) + "s"; }

// Mock Data
// Time: 1000, 2000, 3000...
const barcodes = [
    { t: 1000, val: "A", at: "1000" },
    { t: 2000, val: "A", at: "2000" },
    { t: 3000, val: "A", at: "3000" }, // End of A run 1

    { t: 5000, val: "B", at: "5000" }, // Start of B
    { t: 6000, val: "B", at: "6000" }, // End of B

    { t: 8000, val: "A", at: "8000" }, // Start of A run 2 (Return to A)
    { t: 9000, val: "A", at: "9000" }
];

const counts = [
    { t: 1000, v: 10 },
    { t: 2000, v: 20 },
    { t: 3000, v: 30 }, // Delta +20

    { t: 5000, v: 5 },  // Reset? or just different line? Same line.
    // If counts are absolute: 30 -> 5 (Reset). Delta ignored?
    // User logic: sumPositiveDeltas.
    // 30->5 is -25 (ignored).
    { t: 6000, v: 15 }, // 5->15 (+10)

    { t: 8000, v: 100 }, // 15->100 (+85)
    { t: 9000, v: 110 }  // 100->110 (+10)
];

const PRODUCT_MAP = new Map([["A", "ProdA"], ["B", "ProdB"]]);
function normalizeCode(v){ return v; }

// --- LOGIC TO TEST ---
function buildSegments(barcodes, counts, tz) {
  const segs = [];
  if (!barcodes.length) return segs;

  let currentRun = {
      barcode: barcodes[0].val,
      start: barcodes[0].t,
      end: barcodes[0].t,
      at: barcodes[0].at
  };

  for (let i = 1; i < barcodes.length; i++) {
    const b = barcodes[i];
    if (b.val === currentRun.barcode) {
        currentRun.end = b.t;
    } else {
        processRun(currentRun, b.t);
        currentRun = {
            barcode: b.val,
            start: b.t,
            end: b.t,
            at: b.at
        };
    }
  }
  processRun(currentRun, currentRun.end + 1); // Close last

  function processRun(run, cutoffTime) {
      // Filter counts: t >= run.start AND t < cutoffTime
      // Is cutoff inclusive?
      // If A is 1000-3000, B starts 5000.
      // cutoff 5000.
      // counts at 3000 should be included in A.
      // counts at 5000 should be included in B.

      const runCounts = counts.filter(c => c.t >= run.start && c.t < cutoffTime);

      const {units, firstT, lastT} = calculateUnitsAndBoundaries(runCounts);

      if (units > 0) {
          const code = normalizeCode(run.barcode);
          const prodName = PRODUCT_MAP.get(code) || "";

          const effectiveStart = run.start;
          const effectiveEnd = (lastT && lastT > run.end) ? lastT : run.end;
          const durationMs = effectiveEnd - effectiveStart;

          segs.push({
            barcode: run.barcode,
            product: prodName,
            // startLT, endLT mocked
            start: effectiveStart,
            end: effectiveEnd,
            duration: durationMs,
            units: units
          });
      }
  }

  return segs;
}

function calculateUnitsAndBoundaries(cnts) {
    if(!cnts.length) return {units:0, firstT:null, lastT:null};
    let u = 0;
    // We assume counts are sorted
    for(let i=1; i<cnts.length; i++) {
        const d = cnts[i].v - cnts[i-1].v;
        if(d > 0) u += d;
    }
    return { units: u, firstT: cnts[0].t, lastT: cnts[cnts.length-1].t };
}

// --- RUN ---
const result = buildSegments(barcodes, counts, tz);
console.log(JSON.stringify(result, null, 2));

// Expectation:
// Segment 1: A. Start 1000, End 3000 (or later?). Units: 10->20->30 (+20).
// Segment 2: B. Start 5000, End 6000. Units: 5->15 (+10). (30->5 ignored).
// Segment 3: A. Start 8000, End 9000. Units: 15->100 (+85), 100->110 (+10) -> Total 95.
