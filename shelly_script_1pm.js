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
      print("📤 Siunčiama GET užklausa į ThingSpeak (field7)...");

      Shelly.call("HTTP.GET", {
        url: full_url,
        timeout: 15
      }, function(result, error_code, error_msg) {
        if (error_code !== 0) {
          print("❌ Klaida siunčiant į ThingSpeak: " + error_msg);
        } else {
          if (result.code === 200 && result.body !== "0") {
            print("✅ Pavyko! ThingSpeak išsaugojo galią. Įrašo eilės numeris: " + result.body);
          } else if (result.code === 200 && result.body === "0") {
            print("⚠️ ThingSpeak grąžino 0. Tai reiškia, kad siunčiate per dažnai (nemokama versija - 15 sek. limitas).");
          } else {
            print("⚠️ ThingSpeak klaida HTTP " + result.code + ": " + result.body);
          }
        }
      });

    } else {
      print("⚠️ Nerasta momentinės galios (apower) informacijos. Ar tikrai tai 1PM / PM serijos įrenginys?");
    }
  });
}

print("▶️ Skriptas paleistas. Shelly 1PM (Gen3) galia bus siunčiama kas minutę į field7...");
updatePower();
Timer.set(interval, true, updatePower);