const tsapikey = "COR1QRIDA494XVDL"; // ThingSpeak API raktas
const tsurl = "https://api.thingspeak.com/update";
const interval = 60 * 1000; // 1 minutė

function updateTemperatures() {
  print("--------------------------------------------------");
  print("🔄 Skaitomi Shelly įrenginio duomenys...");

  Shelly.call("Shelly.GetStatus", null, function(res, err_code, err_msg) {
    if (err_code !== 0) {
      print("❌ Nepavyko gauti Shelly statuso: " + err_msg);
      return;
    }

    var fieldsStr = "";
    var validFieldsCount = 0;

    // 1. Ieškome temperatūros jutiklių ("temperature:")
    // Kadangi turite 5 jutiklius, jie užpildys field1, field2, field3, field4, field5
    for (var key in res) {
      if (key.indexOf("temperature:") === 0) {
        var tempObj = res[key];
        if (tempObj && typeof tempObj.tC === "number") {
          validFieldsCount++;
          fieldsStr += "&field" + validFieldsCount + "=" + tempObj.tC;
          print("🌡️ Rastas jutiklis [" + key + "] temperatūra: " + tempObj.tC + " °C");
        }
      }
    }

    // 2. Ieškome įtampos jutiklių ("voltmeter:" - Shelly UNI Plus atveju)
    // ThingSpeak užpildys sekantį laisvą lauką po temperatūrų (t.y. field6)
    for (var vkey in res) {
      if (vkey.indexOf("voltmeter:") === 0) {
        var voltObj = res[vkey];
        if (voltObj && typeof voltObj.voltage === "number") {
          validFieldsCount++;
          fieldsStr += "&field" + validFieldsCount + "=" + voltObj.voltage;
          print("⚡ Rasta Saulės baterija [" + vkey + "] įtampa: " + voltObj.voltage + " V");
        }
      }
    }

    if (validFieldsCount === 0) {
      print("⚠️ Nerasta jokių temperatūros ar įtampos jutiklių!");
      return;
    }

    var full_url = tsurl + "?api_key=" + tsapikey + fieldsStr;
    sendToThingSpeak(full_url, 0); // Paleidžiame siuntimą pradedant nuo bandymo nr. 0
  });
}

// Atskirta siuntimo funkcija su "Retry" logika
function sendToThingSpeak(url, attempt) {
  print("📤 Siunčiama GET užklausa į ThingSpeak (Bandymas " + (attempt + 1) + ")...");

  Shelly.call("HTTP.GET", {
    url: url,
    timeout: 15
  }, function(result, error_code, error_msg) {
    var retry_needed = false;

    if (error_code !== 0) {
      print("❌ Klaida siunčiant į ThingSpeak: " + error_msg);
      retry_needed = true;
    } else {
      if (result.code === 200 && result.body !== "0") {
        print("✅ Pavyko! ThingSpeak išsaugojo duomenis. Įrašo eilės numeris: " + result.body);
      } else if (result.code === 200 && result.body === "0") {
        print("⚠️ ThingSpeak grąžino 0 (Limitų blokavimas / per dažnas siuntimas).");
        retry_needed = true;
      } else {
        print("⚠️ ThingSpeak HTTP klaida " + result.code + ": " + result.body);
        retry_needed = true;
      }
    }

    if (retry_needed) {
      if (attempt < 3) {
        print("⏳ Laukiami 16 sekundžių iki sekančio bandymo...");
        Timer.set(16000, false, function() {
          sendToThingSpeak(url, attempt + 1);
        });
      } else {
        print("❌ Atšaukiama. Pasiektas maksimalus (3) bandymų skaičius.");
      }
    }
  });
}

print("▶️ Skriptas paleistas. Autodetektuojami jutikliai (temp. ir voltmetras) siunčiami kas minutę...");
updateTemperatures();
Timer.set(interval, true, updateTemperatures);