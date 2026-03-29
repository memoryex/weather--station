
const tz = "Europe/Vilnius";
function toLTString(isoStr) { return isoStr; }
function msToHMS(ms) { return Math.floor(ms/1000) + "s"; }
function normalizeCode(v){ return v; }
const PRODUCT_MAP = new Map([["A", "ProdA"], ["B", "ProdB"]]);

// Mock Data with Reset
const barcodes = [
    { t: 1000, val: "A", at: "1000" },
    { t: 2000, val: "A", at: "2000" },
    { t: 3000, val: "A", at: "3000" },
    { t: 4000, val: "A", at: "4000" },
    { t: 5000, val: "A", at: "5000" }, // End of A run 1

    { t: 6000, val: "B", at: "6000" },
    { t: 7000, val: "B", at: "7000" }
];

const counts = [
    { t: 1000, v: 10 },
    { t: 2000, v: 20 },
    { t: 3000, v: 30 }, // Reset after this?
    { t: 4000, v: 5 },  // Reset detected (30 -> 5)
    { t: 5000, v: 15 },

    { t: 6000, v: 100 },
    { t: 7000, v: 110 }
];

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
  processRun(currentRun, currentRun.end + 1);

  function processRun(run, cutoffTime) {
      const runCounts = counts.filter(c => c.t >= run.start && c.t < cutoffTime);
      if(!runCounts.length) return;

      // Sub-segment logic
      let subStartI = 0;
      let u = 0;

      for(let i=1; i<runCounts.length; i++) {
          const prev = runCounts[i-1];
          const curr = runCounts[i];

          if (curr.v < prev.v) {
              // Reset detected. Finalize previous sub-segment
              finalizeSubSegment(runCounts.slice(subStartI, i));
              // Start new
              subStartI = i;
              u = 0;
          }
      }
      // Finalize last sub-segment
      finalizeSubSegment(runCounts.slice(subStartI));

      function finalizeSubSegment(subCounts) {
          if(!subCounts.length) return;

          // Calculate units
          let units = 0;
          for(let k=1; k<subCounts.length; k++) {
              const d = subCounts[k].v - subCounts[k-1].v;
              if(d > 0) units += d;
          }

          if (units > 0) {
              const code = normalizeCode(run.barcode);
              const prodName = PRODUCT_MAP.get(code) || "";

              const startT = subCounts[0].t;
              const endT = subCounts[subCounts.length-1].t;
              const durationMs = endT - startT;

              segs.push({
                barcode: run.barcode,
                product: prodName,
                start: startT,
                end: endT,
                duration: durationMs,
                units: units
              });
          }
      }
  }

  return segs;
}

const result = buildSegments(barcodes, counts, tz);
console.log(JSON.stringify(result, null, 2));
