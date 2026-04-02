sed -i 's/let fillTons = (submergedCount \/ (activeSensors.length || 5)) \* ch.capacity;/let fillPercent = Math.round((submergedCount \/ (activeSensors.length || 5)) \* 90);\n                let fillTons = (fillPercent \/ 100) \* ch.capacity;/' index.html
sed -i 's/let fillPercent = Math.round((fillTons \/ ch.capacity) \* 100);//' index.html
