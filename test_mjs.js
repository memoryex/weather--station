var key = "temperature:103";
if (key.indexOf("temperature:") === 0) {
  var idStr = key.slice(12);
  var idNum = JSON.parse(idStr); // parseInt is safer, but JSON.parse works in mJS usually. Or just Number(idStr).
  var fieldNum = idNum - 99; // 100 -> 1, 101 -> 2, 102 -> 3, 103 -> 4, 104 -> 5
  console.log("Field " + fieldNum);
}
