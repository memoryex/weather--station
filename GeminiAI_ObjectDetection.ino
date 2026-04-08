/*
 * Project: ESP32-S3 AI Object Detection (Person=1, Car=2)
 * Hardware: DFRobot ESP32S3 AI Camera v1.1 (OV3660)
 * 2-File Structure: GeminiAI_ObjectDetection.ino, camera_index.h
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <Wire.h>
#include "esp_camera.h"
#include "camera_index.h"
#include <esp_http_server.h>
#include <driver/i2s.h>

// --- Pin Definitions ---
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
#define MIC_LED_PIN       3
#define LTR308_ADDR    0x23

// --- I2S Speaker Pins (MAX98357A) ---
#define I2S_BCK_IO      41
#define I2S_WS_IO       40
#define I2S_DO_IO       42
#define I2S_NUM         I2S_NUM_0

// ======= CONFIGURATION (Replace with your own credentials) =======
const char* WIFI_SSID = "YOUR_WIFI_SSID";
const char* WIFI_PASS = "YOUR_WIFI_PASSWORD";
const char* GEMINI_API_KEY = "YOUR_GEMINI_API_KEY";

// Firebase/Firestore Configuration
const char* FIREBASE_PROJECT_ID = "YOUR_FIREBASE_PROJECT_ID";
const char* FIREBASE_API_KEY = "YOUR_FIREBASE_API_KEY";

bool isStarted = false;
httpd_handle_t stream_httpd = NULL;
httpd_handle_t camera_httpd = NULL;

// ======= BASE64 UTILITIES =======
const char base64_table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

// Simplified Base64 Decoding Table
static const int B64index[256] = { 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0, 62, 63, 62, 62, 63, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61,  0,  0,  0,  0,  0,  0,
0,  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25,  0,  0,  0,  0, 63,
0, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51 };

size_t base64_decode(uint8_t *output, const char *input, size_t inputLen) {
    size_t i = 0, j = 0;
    for (; i < inputLen; i += 4) {
        int a = B64index[(int)input[i]];
        int b = B64index[(int)input[i + 1]];
        int c = B64index[(int)input[i + 2]];
        int d = B64index[(int)input[i + 3]];
        output[j++] = (uint8_t)((a << 2) | (b >> 4));
        if (input[i + 2] != '=') output[j++] = (uint8_t)((b << 4) | (c >> 2));
        if (input[i + 3] != '=') output[j++] = (uint8_t)((c << 6) | d);
    }
    return j;
}

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

// ======= PERIPHERAL HELPERS =======
void setFlash(bool on) {
    digitalWrite(FLASH_LED_PIN, on ? HIGH : LOW);
}

float readLight() {
    Wire.beginTransmission(LTR308_ADDR);
    Wire.write(0x0D); // CH0 Data lower
    if (Wire.endTransmission() != 0) return -1;
    Wire.requestFrom(LTR308_ADDR, 3);
    if (Wire.available() >= 3) {
        uint32_t als = Wire.read() | (Wire.read() << 8) | (Wire.read() << 16);
        return (float)als;
    }
    return 0;
}

void initI2S(bool speaker) {
    if (speaker) {
        i2s_config_t i2s_config = {
            .mode = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_TX),
            .sample_rate = 16000, // Gemini TTS standard
            .bits_per_sample = I2S_BITS_PER_SAMPLE_16BIT,
            .channel_format = I2S_CHANNEL_FMT_ONLY_RIGHT,
            .communication_format = I2S_COMM_FORMAT_STAND_I2S,
            .intr_alloc_flags = ESP_INTR_FLAG_LEVEL1,
            .dma_buf_count = 8,
            .dma_buf_len = 64,
            .use_apll = false
        };
        i2s_pin_config_t pin_config = {
            .bck_io_num = I2S_BCK_IO,
            .ws_io_num = I2S_WS_IO,
            .data_out_num = I2S_DO_IO,
            .data_in_num = I2S_PIN_NO_CHANGE
        };
        i2s_driver_install(I2S_NUM, &i2s_config, 0, NULL);
        i2s_set_pin(I2S_NUM, &pin_config);
    } else {
        // Microphone init logic (if PDM/I2S mic is used)
        // For now, we deinstall speaker to free resources if needed
        i2s_driver_uninstall(I2S_NUM);
    }
}

void playAudio(const uint8_t* data, size_t len) {
    initI2S(true);
    digitalWrite(MIC_LED_PIN, HIGH);
    size_t bytes_written;
    i2s_write(I2S_NUM, data, len, &bytes_written, portMAX_DELAY);
    i2s_zero_dma_buffer(I2S_NUM);
    digitalWrite(MIC_LED_PIN, LOW);
    delay(100);
    i2s_driver_uninstall(I2S_NUM); // Release I2S to avoid conflict with other peripherals
}

void speakText(String text) {
    Serial.println("[TTS] Generating Lithuanian Audio...");
    HTTPClient http;
    String url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=" + String(GEMINI_API_KEY);
    http.begin(url);
    http.addHeader("Content-Type", "application/json");

    // Requesting Audio Modality (TTS) from Gemini
    String payload = "{\"contents\":[{\"parts\":[{\"text\":\"Perskaityk aiškiai lietuviškai: " + text + "\"}]}],\"generationConfig\":{\"responseModalities\":[\"AUDIO\"],\"speechConfig\":{\"voiceConfig\":{\"prebuiltVoiceConfig\":{\"voiceName\":\"Kore\"}}}}}";

    int httpCode = http.POST(payload);
    if (httpCode == 200) {
        String response = http.getString();
        DynamicJsonDocument doc(64000); // High memory for audio data
        deserializeJson(doc, response);

        const char* audioBase64 = doc["candidates"][0]["content"]["parts"][0]["inlineData"]["data"];
        if (audioBase64) {
            size_t audio_b64_len = strlen(audioBase64);
            size_t audio_buf_len = (audio_b64_len * 3) / 4;
            uint8_t* audio_buf = (uint8_t*)malloc(audio_buf_len);
            if (audio_buf) {
                size_t actual_len = base64_decode(audio_buf, audioBase64, audio_b64_len);
                playAudio(audio_buf, actual_len);
                free(audio_buf);
            }
        }
    } else {
        Serial.printf("[TTS] Error: %d\n", httpCode);
    }
    http.end();
}

// ======= AI LOGIC =======
void sendToFirestore(String desc, String base64, int signal) {
    HTTPClient http;
    String url = "https://firestore.googleapis.com/v1/projects/" + String(FIREBASE_PROJECT_ID) + "/databases/(default)/documents/detections?key=" + String(FIREBASE_API_KEY);
    http.begin(url);
    http.addHeader("Content-Type", "application/json");

    DynamicJsonDocument doc(30000);
    JsonObject fields = doc.createNestedObject("fields");
    fields["desc"]["stringValue"] = desc;
    fields["image"]["stringValue"] = base64;
    fields["signal"]["integerValue"] = String(signal);
    fields["lux"]["doubleValue"] = readLight();

    String payload;
    serializeJson(doc, payload);
    http.POST(payload);
    http.end();
}

void detectAndProcess() {
    camera_fb_t* fb = esp_camera_fb_get();
    if (!fb) return;
    String base64 = base64_encode(fb->buf, fb->len);
    esp_camera_fb_return(fb);

    HTTPClient http;
    // Using gemini-2.0-flash for vision and potential audio modality
    String url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=" + String(GEMINI_API_KEY);
    http.begin(url);
    http.addHeader("Content-Type", "application/json");

    // Lithuanian prompt for object detection and signal extraction
    String prompt = "Aprašyk lietuviškai ką matai šioje nuotraukoje. "
                    "Jei matai žmogų, būtinai paminėk 'SIGNAL:1'. "
                    "Jei matai automobilį, būtinai paminėk 'SIGNAL:2'. "
                    "Jei nieko iš jų nematai, naudok 'SIGNAL:0'. "
                    "Atsakyk trumpai ir aiškiai.";

    String payload = "{\"contents\":[{\"parts\":["
                     "{\"inline_data\":{\"mime_type\":\"image/jpeg\",\"data\":\"" + base64 + "\"}},"
                     "{\"text\":\"" + prompt + "\"}"
                     "]}]}";

    int code = http.POST(payload);
    if (code == 200) {
        String res = http.getString();
        // Larger buffer for complex responses
        DynamicJsonDocument d(16384);
        deserializeJson(d, res);

        if (d["candidates"][0]["content"]["parts"][0].containsKey("text")) {
            const char* txt = d["candidates"][0]["content"]["parts"][0]["text"];
            if (txt) {
                String desc = String(txt);
                int sig = 0;
                if (desc.indexOf("SIGNAL:1") != -1) sig = 1;
                else if (desc.indexOf("SIGNAL:2") != -1) sig = 2;

                Serial.println("AI Description: " + desc);
                sendToFirestore(desc, base64, sig);
                speakText(desc);
            }
        }
    } else {
        Serial.printf("Gemini API Error: %d\n", code);
    }
    http.end();
}

// ======= WEB SERVER =======
static esp_err_t index_handler(httpd_req_t *req){
    httpd_resp_set_type(req, "text/html");
    httpd_resp_set_hdr(req, "Content-Encoding", "gzip");
    return httpd_resp_send(req, (const char *)index_ov3660_html_gz, index_ov3660_html_gz_len);
}

static esp_err_t stream_handler(httpd_req_t *req){
    camera_fb_t * fb = NULL;
    esp_err_t res = ESP_OK;
    char part_buf[64];

    res = httpd_resp_set_type(req, "multipart/x-mixed-replace;boundary=123456789");
    if(res != ESP_OK) return res;

    while(true){
        fb = esp_camera_fb_get();
        if (!fb) {
            res = ESP_FAIL;
        } else {
            size_t hlen = snprintf(part_buf, 64, "--123456789\r\nContent-Type: image/jpeg\r\nContent-Length: %u\r\n\r\n", fb->len);
            res = httpd_resp_send_chunk(req, part_buf, hlen);
            if(res == ESP_OK) res = httpd_resp_send_chunk(req, (const char *)fb->buf, fb->len);
            if(res == ESP_OK) res = httpd_resp_send_chunk(req, "\r\n", 2);
            esp_camera_fb_return(fb);
        }
        if(res != ESP_OK) break;
        vTaskDelay(5 / portTICK_PERIOD_MS);
    }
    return res;
}

static esp_err_t cmd_handler(httpd_req_t *req){
    char variable[32];
    char value[32];
    if (httpd_req_get_url_query_str(req, variable, sizeof(variable)) == ESP_OK) {
        if (httpd_query_key_value(variable, "var", variable, sizeof(variable)) == ESP_OK &&
            httpd_query_key_value(variable, "val", value, sizeof(value)) == ESP_OK) {
            int val = atoi(value);
            sensor_t * s = esp_camera_sensor_get();
            if (!strcmp(variable, "start")) isStarted = (val == 1);
            else if (!strcmp(variable, "flash")) setFlash(val == 1);
            else if (!strcmp(variable, "vflip")) s->set_vflip(s, val);
            else if (!strcmp(variable, "hmirror")) s->set_hmirror(s, val);
        }
    }
    httpd_resp_set_hdr(req, "Access-Control-Allow-Origin", "*");
    return httpd_resp_send(req, NULL, 0);
}

void startCameraServer(){
    httpd_config_t config = HTTPD_DEFAULT_CONFIG();
    config.server_port = 80;
    config.ctrl_port = 32768;

    if (httpd_start(&camera_httpd, &config) == ESP_OK) {
        httpd_uri_t index_uri = { .uri = "/", .method = HTTP_GET, .handler = index_handler, .user_ctx = NULL };
        httpd_uri_t cmd_uri = { .uri = "/control", .method = HTTP_GET, .handler = cmd_handler, .user_ctx = NULL };
        httpd_register_uri_handler(camera_httpd, &index_uri);
        httpd_register_uri_handler(camera_httpd, &cmd_uri);
    }

    config.server_port = 81;
    config.ctrl_port = 32769;
    if (httpd_start(&stream_httpd, &config) == ESP_OK) {
        httpd_uri_t stream_uri = { .uri = "/", .method = HTTP_GET, .handler = stream_handler, .user_ctx = NULL };
        httpd_register_uri_handler(stream_httpd, &stream_uri);
    }
}

// ======= SETUP & LOOP =======
void setup() {
    pinMode(FLASH_LED_PIN, OUTPUT);
    pinMode(MIC_LED_PIN, OUTPUT);
    digitalWrite(FLASH_LED_PIN, LOW);

    Serial.begin(115200);
    delay(2000); // Stabilization

    Wire.begin(SIOD_GPIO_NUM, SIOC_GPIO_NUM);

    camera_config_t config;
    config.ledc_channel = LEDC_CHANNEL_0;
    config.ledc_timer = LEDC_TIMER_0;
    config.pin_d0 = Y2_GPIO_NUM; config.pin_d1 = Y3_GPIO_NUM; config.pin_d2 = Y4_GPIO_NUM;
    config.pin_d3 = Y5_GPIO_NUM; config.pin_d4 = Y6_GPIO_NUM; config.pin_d5 = Y7_GPIO_NUM;
    config.pin_d6 = Y8_GPIO_NUM; config.pin_d7 = Y9_GPIO_NUM; config.pin_xclk = XCLK_GPIO_NUM;
    config.pin_pclk = PCLK_GPIO_NUM; config.pin_vsync = VSYNC_GPIO_NUM; config.pin_href = HREF_GPIO_NUM;
    config.pin_sccb_sda = SIOD_GPIO_NUM; config.pin_sccb_scl = SIOC_GPIO_NUM;
    config.pin_pwdn = PWDN_GPIO_NUM; config.pin_reset = RESET_GPIO_NUM;
    config.xclk_freq_hz = 10000000;
    config.pixel_format = PIXFORMAT_JPEG;
    config.frame_size = FRAMESIZE_QVGA;
    config.jpeg_quality = 12;
    config.fb_count = psramFound() ? 2 : 1;
    config.fb_location = psramFound() ? CAMERA_FB_IN_PSRAM : CAMERA_FB_IN_DRAM;
    config.grab_mode = CAMERA_GRAB_LATEST;

    if (esp_camera_init(&config) != ESP_OK) {
        Serial.println("Camera Init Failed");
        return;
    }

    WiFi.begin(WIFI_SSID, WIFI_PASS);
    while (WiFi.status() != WL_CONNECTED) { delay(500); Serial.print("."); }
    Serial.println("\nWiFi Connected: " + WiFi.localIP().toString());

    startCameraServer();

    xTaskCreate([](void*){
        while(1){
            if(isStarted) detectAndProcess();
            delay(60000);
        }
    }, "AI_Task", 16384, NULL, 1, NULL);
}

void loop() {
    if (Serial.available()) {
        String in = Serial.readStringUntil('\n'); in.trim();
        if (in == "start") isStarted = true;
        else if (in == "stop") isStarted = false;
        else if (in == "test_audio") {
            uint8_t dummy[1024] = {0}; // Silence test
            playAudio(dummy, 1024);
        }
    }
    delay(100);
}
