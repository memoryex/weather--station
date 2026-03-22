const tsapikey = "COR1QRIDA494XVDL"; // ThingSpeak API raktas (Jūsų kanalui 351746)
const tsurl = "https://api.thingspeak.com/update";
const interval = 60 * 1000; // 1 minutė

function updatePower() {
  print("--------------------------------------------------");
  print("🔄 Skaitomi Shelly 1PM (Gen3) galios duomenys...");

  // Shelly Gen3 atveju galime iškart kreiptis į Switch.GetStatus,
  // kur randasi relės būsena, srovė, ir momentinė galia (apower).
  Shelly.call("Switch.GetStatus", { id: 0 }, function(res, err_code, err_msg) {
    if (err_code !== 0) {
      print("❌ Nepavyko gauti Shelly 1PM statuso: " + err_msg);
      return;
    }

    // Patikriname, ar randame aktyvią galią 'apower' (Watais)
    if (typeof res.apower === "number") {
      var powerWatts = res.apower;
      print("⚡ Momentinė elektros galia: " + powerWatts + " W");

      // Suformuojame užklausą į field7
      var full_url = tsurl + "?api_key=" + tsapikey + "&field7=" + powerWatts;
      sendToThingSpeak(full_url, 0); // Pradedame siuntimą nuo bandymo nr. 0

    } else {
      print("⚠️ Nerasta momentinės galios (apower) informacijos. Ar tikrai tai 1PM / PM serijos įrenginys?");
    }
  });
}

// Atskirta siuntimo funkcija su "Retry" logika
function sendToThingSpeak(url, attempt) {
  print("📤 Siunčiama GET užklausa į ThingSpeak (field7) (Bandymas " + (attempt + 1) + ")...");

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
        print("✅ Pavyko! ThingSpeak išsaugojo galią. Įrašo eilės numeris: " + result.body);
      } else if (result.code === 200 && result.body === "0") {
        print("⚠️ ThingSpeak grąžino 0 (Limitų blokavimas / per dažnas siuntimas).");
        retry_needed = true;
      } else {
        print("⚠️ ThingSpeak klaida HTTP " + result.code + ": " + result.body);
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

print("▶️ Skriptas paleistas. Shelly 1PM (Gen3) galia bus siunčiama kas minutę į field7...");
updatePower();
Timer.set(interval, true, updatePower);