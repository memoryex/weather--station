/*
 * Project: ESP32-S3 AI Object Detection (Person=1, Car=2) with Web Management
 * Hardware: DFRobot ESP32S3 AI Camera (OV3660) v1.1
 * Logic:
 *   - Gemini 2.0 Flash for image analysis and Lithuanian TTS įgarsinimas.
 *   - Firestore RTDB for logging detections.
 *   - ESP-IDF HTTP Server for MJPEG streaming and parameter control.
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include "esp_camera.h"
#include "time.h"
#include <Preferences.h>
#include <Wire.h>
#include <driver/i2s.h>
#include "camera_index.h"

// Prototypes for Web Server (defined in app_httpd.cpp)
void startCameraServer();

// --- DFRobot DFR1154 ESP32-S3 AI CAM (v1.1) Pins ---
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

#define FLASH_LED_PIN    48
#define LIGHT_SENSOR_PIN  1

// I2S Pins for DFRobot DFR1154 (MAX98357 Amplifier)
#define I2S_BCLK         42
#define I2S_LRCK         41
#define I2S_DATA         40
#define I2S_MIC_CLK      38
#define I2S_MIC_DATA     39

// ======= CONFIGURATION =======
const char* WIFI_SSID = "Bijunu_g";
const char* WIFI_PASS = "memoryexx";
const char* GEMINI_API_KEY = "AIzaSyDncx7EvrtOG_44xPoCwOkOHmtaITPP_6A";

const char* FIREBASE_PROJECT_ID = "esp32-s3-ai-cam";
const char* FIREBASE_DATABASE_ID = "(default)";
const char* FIREBASE_API_KEY = "AIzaSyAmVYkc3PxyvKcFnjCVEtyTY7bh0rsEveI";

#define ENABLE_FIREBASE true
const char* ntpServer = "pool.ntp.org";
const long gmtOffset_sec = 7200; // Lithuania (UTC+2)
const int daylightOffset_sec = 0;

Preferences preferences;
bool isStarted = false;

// ======= UTILITIES =======
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
    String url = "https://firestore.googleapis.com/v1/projects/" + String(FIREBASE_PROJECT_ID) +
                 "/databases/" + String(FIREBASE_DATABASE_ID) +
                 "/documents/detections?key=" + String(FIREBASE_API_KEY);
    http.begin(url);
    http.addHeader("Content-Type", "application/json");
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
    if (text.indexOf("car") != -1 || text.indexOf("automobil") != -1 || text.indexOf("vehicle") != -1) return 2;
    return 0;
}

// ======= AUDIO (I2S) =======
void initI2S() {
    i2s_driver_uninstall(I2S_NUM_0);
    i2s_config_t i2s_config = {
        .mode = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_TX),
        .sample_rate = 16000,
        .bits_per_sample = I2S_BITS_PER_SAMPLE_16BIT,
        .channel_format = I2S_CHANNEL_FMT_RIGHT_LEFT,
        .communication_format = (i2s_comm_format_t)(I2S_COMM_FORMAT_STAND_I2S),
        .intr_alloc_flags = ESP_INTR_FLAG_LEVEL1,
        .dma_buf_count = 8,
        .dma_buf_len = 64,
        .use_apll = false
    };
    i2s_pin_config_t pin_config = {
        .bck_io_num = I2S_BCLK,
        .ws_io_num = I2S_LRCK,
        .data_out_num = I2S_DATA,
        .data_in_num = I2S_PIN_NO_CHANGE
    };
    i2s_driver_install(I2S_NUM_0, &i2s_config, 0, NULL);
    i2s_set_pin(I2S_NUM_0, &pin_config);
    i2s_zero_dma_buffer(I2S_NUM_0);
}

size_t decode_base64(const char* input, uint8_t* output) {
    const char* lookup = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    size_t len = strlen(input);
    if (len % 4 != 0) return 0;
    size_t out_len = len / 4 * 3;
    if (input[len - 1] == '=') out_len--;
    if (input[len - 2] == '=') out_len--;
    for (size_t i = 0, j = 0; i < len; i += 4, j += 3) {
        uint32_t v = 0;
        for (int k = 0; k < 4; k++) {
            const char* p = strchr(lookup, input[i + k]);
            v = (v << 6) | (p ? (p - lookup) : 0);
        }
        output[j] = (v >> 16) & 0xFF;
        if (input[i + 2] != '=') output[j + 1] = (v >> 8) & 0xFF;
        if (input[i + 3] != '=') output[j + 2] = v & 0xFF;
    }
    return out_len;
}

void speakText(String text) {
    Serial.println("[TTS] Generating...");
    i2s_zero_dma_buffer(I2S_NUM_0);
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
        if (doc.containsKey("candidates")) {
            const char* audioBase64 = doc["candidates"][0]["content"]["parts"][0]["inlineData"]["data"];
            if (audioBase64) {
                size_t audio_len = strlen(audioBase64);
                uint8_t* audio_buf = (uint8_t*)malloc(audio_len);
                if (audio_buf) {
                    size_t decoded_len = decode_base64(audioBase64, audio_buf);
                    size_t bw;
                    i2s_write(I2S_NUM_0, audio_buf, decoded_len, &bw, portMAX_DELAY);
                    free(audio_buf);
                }
            }
        }
    }
    http.end();
}

// ======= AI DETECTION =======
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
    String prompt = "Aprašyk lietuviškai, ką matai šioje nuotraukoje. Jei matai žmogų ar automobilį, paminėk tai pirmiausia. Atsakyk trumpai, vienu sakiniu.";
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
                int signal = parseSignal(desc);
                String dateTime = getCurrentTime();
                Serial.println("\n[AI] " + desc + " (Signal: " + String(signal) + ")");
                sendDataToFirebase(desc, dateTime, base64Image, signal);
                speakText(desc);
            }
        }
    } else {
        Serial.printf("[Gemini] FAILED (%d)\n", httpCode);
    }
    http.end();
}

// ======= SETUP & LOOP =======
void runSelfTest() {
    Serial.println("\n--- [SELF-TEST] ---");
    pinMode(FLASH_LED_PIN, OUTPUT);
    digitalWrite(FLASH_LED_PIN, HIGH); delay(1000); digitalWrite(FLASH_LED_PIN, LOW);
    Serial.println("1. LED OK");

    int16_t beep[200]; for(int i=0; i<200; i++) beep[i] = (i % 20 < 10) ? 6000 : -6000;
    size_t bw; for(int i=0; i<100; i++) i2s_write(I2S_NUM_0, beep, sizeof(beep), &bw, 100);
    Serial.println("2. Speaker OK");

    camera_fb_t * fb = esp_camera_fb_get();
    if (fb) { Serial.println("3. Camera OK"); esp_camera_fb_return(fb); }
    Serial.println("--- [DONE] ---\n");
}

void setup() {
    Serial.begin(115200);
    Wire.begin(SIOD_GPIO_NUM, SIOC_GPIO_NUM);

    camera_config_t config;
    config.ledc_channel = LEDC_CHANNEL_0; config.ledc_timer = LEDC_TIMER_0;
    config.pin_d0 = Y2_GPIO_NUM; config.pin_d1 = Y3_GPIO_NUM; config.pin_d2 = Y4_GPIO_NUM;
    config.pin_d3 = Y5_GPIO_NUM; config.pin_d4 = Y6_GPIO_NUM; config.pin_d5 = Y7_GPIO_NUM;
    config.pin_d6 = Y8_GPIO_NUM; config.pin_d7 = Y9_GPIO_NUM; config.pin_xclk = XCLK_GPIO_NUM;
    config.pin_pclk = PCLK_GPIO_NUM; config.pin_vsync = VSYNC_GPIO_NUM; config.pin_href = HREF_GPIO_NUM;
    config.pin_sccb_sda = SIOD_GPIO_NUM; config.pin_sccb_scl = SIOC_GPIO_NUM;
    config.pin_pwdn = PWDN_GPIO_NUM; config.pin_reset = RESET_GPIO_NUM;
    config.xclk_freq_hz = 20000000; config.pixel_format = PIXFORMAT_JPEG;
    config.frame_size = FRAMESIZE_QVGA; config.jpeg_quality = 12;
    config.fb_count = 2; config.fb_location = CAMERA_FB_IN_PSRAM; config.grab_mode = CAMERA_GRAB_LATEST;

    if (esp_camera_init(&config) != ESP_OK) {
        Serial.println("Camera Error!");
        return;
    }

    sensor_t *s = esp_camera_sensor_get();
    if (s->id.PID == OV3660_PID) { s->set_vflip(s, 1); s->set_brightness(s, 1); s->set_saturation(s, -2); }

    initI2S();

    WiFi.begin(WIFI_SSID, WIFI_PASS);
    while (WiFi.status() != WL_CONNECTED) { delay(500); Serial.print("."); }
    Serial.println("\nWiFi Connected! IP: " + WiFi.localIP().toString());

    startCameraServer();
    configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);
    runSelfTest();

    xTaskCreate([](void*) {
        while (1) { if (isStarted && WiFi.status() == WL_CONNECTED) detectObjects(); delay(60000); }
    }, "AITask", 8192, NULL, 1, NULL);
}

void loop() {
    if (Serial.available()) {
        String in = Serial.readStringUntil('\n'); in.trim();
        if (in.equalsIgnoreCase("start")) { isStarted = true; Serial.println("AI STARTED"); }
        else if (in.equalsIgnoreCase("stop")) { isStarted = false; Serial.println("AI STOPPED"); }
        else if (in.equalsIgnoreCase("test")) runSelfTest();
    }
    delay(100);
}
