/*
 * Project: ESP32-S3 AI Object Detection (Person=1, Car=2)
 * Hardware: DFRobot ESP32S3 AI Camera (OV3660)
 * Logic:
 *   - Signal 1: Person/Human detected
 *   - Signal 2: Car/Vehicle detected
 *   - Signal 0: Other or None
 */

#include <WiFi.h>
#include <WebServer.h>
#include <ESPmDNS.h>
#include <HTTPClient.h>

// Kameros nustatymų puslapis (suglaudintas)
#include "camera_index.h"

WebServer server(80);
#include <ArduinoJson.h>
#include "esp_camera.h"
#include "time.h"
#include <Preferences.h>
#include <Wire.h>
#include <esp_http_server.h>

// --- Pin definitions for DFR1154 ESP32-S3 AI CAM (OV3660) ---
#define PWDN_GPIO_NUM    -1
#define RESET_GPIO_NUM   -1
#define XCLK_GPIO_NUM     5
#define Y9_GPIO_NUM       4
#define Y8_GPIO_NUM       6
#define Y7_GPIO_NUM       7
#define Y6_GPIO_NUM      14
#define Y5_GPIO_NUM      17
#define Y4_GPIO_NUM      21
#define Y3_GPIO_NUM      18
#define Y2_GPIO_NUM      16
#define VSYNC_GPIO_NUM    1
#define HREF_GPIO_NUM     2
#define PCLK_GPIO_NUM    15
#define SIOD_GPIO_NUM     8
#define SIOC_GPIO_NUM     9

// ======= CONFIGURATION =======
const char* WIFI_SSID = "Bijunu_g";
const char* WIFI_PASS = "memoryexx";
const char* GEMINI_API_KEY = "AIzaSyDncx7EvrtOG_44xPoCwOkOHmtaITPP_6A";

// Update these with your Firebase config from the dashboard
const char* FIREBASE_PROJECT_ID = "esp32-s3-ai-cam";
const char* FIREBASE_DATABASE_ID = "(default)";
const char* FIREBASE_API_KEY = "AIzaSyAmVYkc3PxyvKcFnjCVEtyTY7bh0rsEveI";

#define ENABLE_FIREBASE true
const char* ntpServer = "pool.ntp.org";
const long gmtOffset_sec = 7200; // Lithuania (UTC+2)
const int daylightOffset_sec = 0;

Preferences preferences;
bool isStarted = false;

// ======= BASE64 ENCODING =======
const char base64_table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
String base64_encode(const uint8_t* data, size_t length) {
    String encoded = "";
    int i = 0;
    uint8_t array_3[3], array_4[4];
    while (length--) {
        array_3[i++] = *(data++);
        if (i == 3) {
            array_4[0] = (array_3[0] & 0xfc) >> 2;
            array_4[1] = ((array_3[0] & 0x03) << 4) + ((array_3[1] & 0xf0) >> 4);
            array_4[2] = ((array_3[1] & 0x0f) << 2) + ((array_3[2] & 0xc0) >> 6);
            array_4[3] = array_3[2] & 0x3f;
            for (i = 0; i < 4; i++) encoded += base64_table[array_4[i]];
            i = 0;
        }
    }
    if (i) {
        for (int j = i; j < 3; j++) array_3[j] = '\0';
        array_4[0] = (array_3[0] & 0xfc) >> 2;
        array_4[1] = ((array_3[0] & 0x03) << 4) + ((array_3[1] & 0xf0) >> 4);
        array_4[2] = ((array_3[1] & 0x0f) << 2) + ((array_3[2] & 0xc0) >> 6);
        array_4[3] = array_3[2] & 0x3f;
        for (int j = 0; j < i + 1; j++) encoded += base64_table[array_4[j]];
        while ((i++ < 3)) encoded += '=';
    }
    return encoded;
}

String getCurrentTime() {
    struct tm timeinfo;
    if (!getLocalTime(&timeinfo)) return "Time Error";
    char buffer[30];
    strftime(buffer, sizeof(buffer), "%Y-%m-%d %H:%M:%S", &timeinfo);
    return String(buffer);
}

void sendDataToFirebase(const String& desc, const String& dateTime, const String& imageBase64, int signal) {
    if (!ENABLE_FIREBASE) return;
    HTTPClient http;

    // Firestore REST API URL
    String url = "https://firestore.googleapis.com/v1/projects/" + String(FIREBASE_PROJECT_ID) +
                 "/databases/" + String(FIREBASE_DATABASE_ID) +
                 "/documents/detections?key=" + String(FIREBASE_API_KEY);

    http.begin(url);
    http.addHeader("Content-Type", "application/json");

    // Firestore JSON format is specific
    DynamicJsonDocument doc(25000);
    JsonObject fields = doc.createNestedObject("fields");

    fields["detected_objects"]["stringValue"] = desc;
    fields["date_time"]["stringValue"] = dateTime;
    fields["image"]["stringValue"] = imageBase64;
    fields["signal"]["integerValue"] = String(signal);

    String payload;
    serializeJson(doc, payload);

    int httpCode = http.POST(payload);
    http.end();
}

int parseSignal(String text) {
    text.toLowerCase();
    if (text.indexOf("person") != -1 || text.indexOf("human") != -1 || text.indexOf("zmo") != -1) return 1;
    if (text.indexOf("car") != -1 || text.indexOf("automobile") != -1 || text.indexOf("vehicle") != -1) return 2;
    return 0;
}

void speakText(String text) {
    Serial.println("[TTS] Generating...");
    HTTPClient http;
    String url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=" + String(GEMINI_API_KEY);
    http.begin(url);
    http.addHeader("Content-Type", "application/json");
    String payload = "{\"contents\":[{\"parts\":[{\"text\":\"Perskaityk aiškiai lietuviškai: " + text + "\"}]}],\"generationConfig\":{\"responseModalities\":[\"AUDIO\"],\"speechConfig\":{\"voiceConfig\":{\"prebuiltVoiceConfig\":{\"voiceName\":\"Kore\"}}}}}";
    int httpCode = http.POST(payload);
    if (httpCode == 200) {
        String response = http.getString();
        DynamicJsonDocument doc(60000);
        deserializeJson(doc, response);
        const char* audioBase64 = doc["candidates"][0]["content"]["parts"][0]["inlineData"]["data"];
        if (audioBase64) {
            size_t audio_len = strlen(audioBase64);
            uint8_t* audio_buf = (uint8_t*)malloc(audio_len);
            if (audio_buf) {
                // assume decode_base64 utility exists or add locally
                // ... (decoding and i2s write logic)
                free(audio_buf);
            }
        }
    }
    http.end();
}

void detectObjects() {
    camera_fb_t* fb = esp_camera_fb_get();
    if (!fb) return;
    String base64Image = base64_encode(fb->buf, fb->len);
    esp_camera_fb_return(fb);

    HTTPClient http;
    String url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=" + String(GEMINI_API_KEY);
    http.begin(url);
    http.setTimeout(30000);
    http.addHeader("Content-Type", "application/json");
    String prompt = "Aprašyk lietuviškai, ką matai šioje nuotraukoje. Jei matai žmogų ar automobilį, paminėk tai pirmiausia.";
    String payload = "{\"contents\":[{\"parts\":[{\"inline_data\":{\"mime_type\":\"image/jpeg\",\"data\":\"" + base64Image + "\"}},{\"text\":\"" + prompt + "\"}]}]}";
    int httpCode = http.POST(payload);
    if (httpCode == 200) {
        String response = http.getString();
        DynamicJsonDocument doc(16384);
        deserializeJson(doc, response);
        if (doc.containsKey("candidates")) {
            const char* aiText = doc["candidates"][0]["content"]["parts"][0]["text"];
            if (aiText) {
                String desc = String(aiText);
                int sig = parseSignal(desc);
                sendDataToFirebase(desc, getCurrentTime(), base64Image, sig);
                speakText(desc);
            }
        }
    }
    http.end();
}

void handleStream() {
    WiFiClient client = server.client();
    client.print("HTTP/1.1 200 OK\r\nContent-Type: multipart/x-mixed-replace;boundary=123456789\r\n\r\n");
    while (client.connected()) {
        camera_fb_t * fb = esp_camera_fb_get();
        if (!fb) break;
        client.printf("--123456789\r\nContent-Type: image/jpeg\r\nContent-Length: %u\r\n\r\n", fb->len);
        client.write(fb->buf, fb->len);
        client.print("\r\n");
        esp_camera_fb_return(fb);
        delay(1);
    }
}

void setup() {
    delay(2000);
    Serial.begin(115200);
    camera_config_t cfg;
    cfg.ledc_channel = LEDC_CHANNEL_0; cfg.ledc_timer = LEDC_TIMER_0;
    cfg.pin_d0 = Y2_GPIO_NUM; cfg.pin_d1 = Y3_GPIO_NUM; cfg.pin_d2 = Y4_GPIO_NUM;
    cfg.pin_d3 = Y5_GPIO_NUM; cfg.pin_d4 = Y6_GPIO_NUM; cfg.pin_d5 = Y7_GPIO_NUM;
    cfg.pin_d6 = Y8_GPIO_NUM; cfg.pin_d7 = Y9_GPIO_NUM; cfg.pin_xclk = XCLK_GPIO_NUM;
    cfg.pin_pclk = PCLK_GPIO_NUM; cfg.pin_vsync = VSYNC_GPIO_NUM; cfg.pin_href = HREF_GPIO_NUM;
    cfg.pin_sccb_sda = SIOD_GPIO_NUM; cfg.pin_sccb_scl = SIOC_GPIO_NUM;
    cfg.pin_pwdn = PWDN_GPIO_NUM; cfg.pin_reset = RESET_GPIO_NUM;
    cfg.xclk_freq_hz = 10000000; cfg.pixel_format = PIXFORMAT_JPEG;
    cfg.frame_size = FRAMESIZE_QVGA; cfg.jpeg_quality = 12; cfg.fb_count = 2;
    cfg.fb_location = CAMERA_FB_IN_PSRAM; cfg.grab_mode = CAMERA_GRAB_LATEST;
    if (esp_camera_init(&cfg) != ESP_OK) return;

    WiFi.begin(WIFI_SSID, WIFI_PASS);
    while (WiFi.status() != WL_CONNECTED) delay(500);

    server.on("/", HTTP_GET, []() {
        server.sendHeader("Content-Encoding", "gzip");
        server.send_P(200, "text/html", (const char*)index_ov3660_html_gz, index_ov3660_html_gz_len);
    });
    server.on("/stream", HTTP_GET, handleStream);
    server.begin();

    xTaskCreate([](void*) {
        while (1) { if (isStarted) detectObjects(); delay(60000); }
    }, "AI", 8192, NULL, 1, NULL);
}

void loop() {
    server.handleClient();
    if (Serial.available()) {
        String in = Serial.readStringUntil('\n'); in.trim();
        if (in.equalsIgnoreCase("start")) isStarted = true;
        else if (in.equalsIgnoreCase("stop")) isStarted = false;
    }
}
