/*
 * Project: ESP32-S3 AI Object Detection (Person=1, Car=2) with Web Management
 * Hardware: DFRobot ESP32S3 AI CAM (OV3660) v1.1
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include "esp_camera.h"
#include "time.h"
#include <Preferences.h>
#include <Wire.h>
#include <driver/i2s.h>
#include "esp_http_server.h"
#include "img_converters.h"
#include "camera_index.h"

// --- Pins for DFRobot DFR1154 v1.1 ---
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
#define MIC_LED_PIN      3
#define LTR308_ADDR      0x23

#define I2S_BCLK         42
#define I2S_LRCK         41
#define I2S_DATA         40

// ======= CONFIGURATION =======
const char* WIFI_SSID = "Bijunu_g";
const char* WIFI_PASS = "memoryexx";
const char* GEMINI_API_KEY = "AIzaSyDncx7EvrtOG_44xPoCwOkOHmtaITPP_6A";

const char* FIREBASE_PROJECT_ID = "esp32-s3-ai-cam";
const char* FIREBASE_DATABASE_ID = "(default)";
const char* FIREBASE_API_KEY = "AIzaSyAmVYkc3PxyvKcFnjCVEtyTY7bh0rsEveI";

#define ENABLE_FIREBASE true
const char* ntpServer = "pool.ntp.org";
const long gmtOffset_sec = 7200;
const int daylightOffset_sec = 0;

Preferences preferences;
bool isStarted = false;
httpd_handle_t camera_httpd = NULL;
httpd_handle_t stream_httpd = NULL;

// MJPEG Stream Constants
#define PART_BOUNDARY "123456789000000000000987654321"
static const char* _STREAM_CONTENT_TYPE = "multipart/x-mixed-replace;boundary=" PART_BOUNDARY;
static const char* _STREAM_BOUNDARY = "\r\n--" PART_BOUNDARY "\r\n";
static const char* _STREAM_PART = "Content-Type: image/jpeg\r\nContent-Length: %u\r\n\r\n";

// ======= UTILITIES =======
const char base64_chars[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

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
            for (i = 0; i < 4; i++) encoded += base64_chars[array_4[i]];
            i = 0;
        }
    }
    if (i) {
        for (int j = i; j < 3; j++) array_3[j] = '\0';
        array_4[0] = (array_3[0] & 0xfc) >> 2;
        array_4[1] = ((array_3[0] & 0x03) << 4) + ((array_3[1] & 0xf0) >> 4);
        array_4[2] = ((array_3[1] & 0x0f) << 2) + ((array_3[2] & 0xc0) >> 6);
        array_4[3] = array_3[2] & 0x3f;
        for (int j = 0; j < i + 1; j++) encoded += base64_chars[array_4[j]];
        while ((i++ < 3)) encoded += '=';
    }
    return encoded;
}

size_t decode_base64(const char* input, uint8_t* output) {
    size_t len = strlen(input);
    if (len % 4 != 0) return 0;
    size_t out_len = len / 4 * 3;
    if (input[len - 1] == '=') out_len--;
    if (input[len - 2] == '=') out_len--;
    for (size_t i = 0, j = 0; i < len; i += 4, j += 3) {
        uint32_t v = 0;
        for (int k = 0; k < 4; k++) {
            const char* p = strchr(base64_chars, input[i + k]);
            v = (v << 6) | (p ? (p - base64_chars) : 0);
        }
        output[j] = (v >> 16) & 0xFF;
        if (input[i + 2] != '=') output[j + 1] = (v >> 8) & 0xFF;
        if (input[i + 3] != '=') output[j + 2] = v & 0xFF;
    }
    return out_len;
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
    http.POST(payload);
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
    i2s_config_t i2s_config = {
        .mode = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_TX),
        .sample_rate = 16000,
        .bits_per_sample = I2S_BITS_PER_SAMPLE_16BIT,
        .channel_format = I2S_CHANNEL_FMT_ONLY_RIGHT,
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
    i2s_stop(I2S_NUM_0);
}

void speakText(String text) {
    Serial.println("[TTS] Generating...");
    i2s_start(I2S_NUM_0);
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
        if (doc.containsKey("candidates") && doc["candidates"].size() > 0) {
            const char* audioBase = doc["candidates"][0]["content"]["parts"][0]["inlineData"]["data"];
            if (audioBase) {
                size_t audio_len = strlen(audioBase);
                uint8_t* buf = (uint8_t*)malloc(audio_len);
                if (buf) {
                    size_t actual_len = decode_base64(audioBase, buf);
                    size_t bw;
                    i2s_write(I2S_NUM_0, buf, actual_len, &bw, portMAX_DELAY);
                    free(buf);
                }
            }
        }
    }
    http.end();
    i2s_zero_dma_buffer(I2S_NUM_0);
    i2s_stop(I2S_NUM_0);
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
    String prompt = "Aprašyk lietuviškai, ką matai šioje nuotraukoje. Jei matai žmogų ar automobilį, paminėk tai pirmiausia.";
    String payload = "{\"contents\":[{\"parts\":[{\"inline_data\":{\"mime_type\":\"image/jpeg\",\"data\":\"" + base64Image + "\"}},{\"text\":\"" + prompt + "\"}]}]}";
    int httpCode = http.POST(payload);
    if (httpCode == 200) {
        String response = http.getString();
        DynamicJsonDocument doc(16384);
        deserializeJson(doc, response);
        if (doc.containsKey("candidates") && doc["candidates"].size() > 0) {
            const char* aiText = doc["candidates"][0]["content"]["parts"][0]["text"];
            if (aiText) {
                String desc = String(aiText);
                int sig = parseSignal(desc);
                Serial.println("\n[AI] " + desc);
                sendDataToFirebase(desc, getCurrentTime(), base64Image, sig);
                speakText(desc);
            }
        }
    } else {
        Serial.printf("[Gemini] Error %d\n", httpCode);
    }
    http.end();
}

// ======= LIGHT SENSOR (I2C) =======
uint16_t readLux() {
    Wire.beginTransmission(LTR308_ADDR);
    Wire.write(0x00); Wire.write(0x01);
    Wire.endTransmission();
    delay(10);
    Wire.beginTransmission(LTR308_ADDR);
    Wire.write(0x0D);
    if (Wire.endTransmission() != 0) return 0;
    Wire.requestFrom(LTR308_ADDR, 3);
    if (Wire.available() >= 3) {
        uint32_t val = Wire.read() | (Wire.read() << 8) | (Wire.read() << 16);
        return val & 0xFFFFF;
    }
    return 0;
}

// ======= WEB SERVER HANDLERS =======
static esp_err_t index_handler(httpd_req_t *req) {
    httpd_resp_set_type(req, "text/html");
    httpd_resp_set_hdr(req, "Content-Encoding", "gzip");
    return httpd_resp_send(req, (const char *)index_ov3660_html_gz, index_ov3660_html_gz_len);
}

static esp_err_t status_handler(httpd_req_t *req) {
    static char json_response[1024];
    sensor_t *s = esp_camera_sensor_get();
    char *p = json_response;
    *p++ = '{';
    p += sprintf(p, "\"framesize\":%u,", s->status.framesize);
    p += sprintf(p, "\"quality\":%u,", s->status.quality);
    p += sprintf(p, "\"brightness\":%d,", s->status.brightness);
    p += sprintf(p, "\"contrast\":%d,", s->status.contrast);
    p += sprintf(p, "\"saturation\":%d,", s->status.saturation);
    p += sprintf(p, "\"sharpness\":%d,", s->status.sharpness);
    p += sprintf(p, "\"special_effect\":%u,", s->status.special_effect);
    p += sprintf(p, "\"wb_mode\":%u,", s->status.wb_mode);
    p += sprintf(p, "\"awb\":%u,", s->status.awb);
    p += sprintf(p, "\"awb_gain\":%u,", s->status.awb_gain);
    p += sprintf(p, "\"aec\":%u,", s->status.aec);
    p += sprintf(p, "\"aec2\":%u,", s->status.aec2);
    p += sprintf(p, "\"ae_level\":%d,", s->status.ae_level);
    p += sprintf(p, "\"aec_value\":%u,", s->status.aec_value);
    p += sprintf(p, "\"agc\":%u,", s->status.agc);
    p += sprintf(p, "\"agc_gain\":%u,", s->status.agc_gain);
    p += sprintf(p, "\"gainceiling\":%u,", s->status.gainceiling);
    p += sprintf(p, "\"bpc\":%u,", s->status.bpc);
    p += sprintf(p, "\"wpc\":%u,", s->status.wpc);
    p += sprintf(p, "\"raw_gma\":%u,", s->status.raw_gma);
    p += sprintf(p, "\"lenc\":%u,", s->status.lenc);
    p += sprintf(p, "\"vflip\":%u,", s->status.vflip);
    p += sprintf(p, "\"hmirror\":%u,", s->status.hmirror);
    p += sprintf(p, "\"dcw\":%u,", s->status.dcw);
    p += sprintf(p, "\"colorbar\":%u", s->status.colorbar);
    *p++ = '}';
    *p++ = 0;
    httpd_resp_set_type(req, "application/json");
    httpd_resp_set_hdr(req, "Access-Control-Allow-Origin", "*");
    return httpd_resp_send(req, json_response, strlen(json_response));
}

static esp_err_t cmd_handler(httpd_req_t *req) {
    char *buf = NULL;
    size_t buf_len = httpd_req_get_url_query_len(req) + 1;
    if (buf_len > 1) {
        buf = (char *)malloc(buf_len);
        if (httpd_req_get_url_query_str(req, buf, buf_len) == ESP_OK) {
            char var[32], val[32];
            if (httpd_query_key_value(buf, "var", var, sizeof(var)) == ESP_OK &&
                httpd_query_key_value(buf, "val", val, sizeof(val)) == ESP_OK) {
                int value = atoi(val);
                sensor_t *s = esp_camera_sensor_get();
                if (!strcmp(var, "framesize")) s->set_framesize(s, (framesize_t)value);
                else if (!strcmp(var, "quality")) s->set_quality(s, value);
                else if (!strcmp(var, "contrast")) s->set_contrast(s, value);
                else if (!strcmp(var, "brightness")) s->set_brightness(s, value);
                else if (!strcmp(var, "saturation")) s->set_saturation(s, value);
                else if (!strcmp(var, "gainceiling")) s->set_gainceiling(s, (gainceiling_t)value);
                else if (!strcmp(var, "colorbar")) s->set_colorbar(s, value);
                else if (!strcmp(var, "awb")) s->set_whitebal(s, value);
                else if (!strcmp(var, "agc")) s->set_gain_ctrl(s, value);
                else if (!strcmp(var, "aec")) s->set_exposure_ctrl(s, value);
                else if (!strcmp(var, "hmirror")) s->set_hmirror(s, value);
                else if (!strcmp(var, "vflip")) s->set_vflip(s, value);
                else if (!strcmp(var, "awb_gain")) s->set_awb_gain(s, value);
                else if (!strcmp(var, "agc_gain")) s->set_agc_gain(s, value);
                else if (!strcmp(var, "aec_value")) s->set_aec_value(s, value);
                else if (!strcmp(var, "aec2")) s->set_aec2(s, value);
                else if (!strcmp(var, "dcw")) s->set_dcw(s, value);
                else if (!strcmp(var, "bpc")) s->set_bpc(s, value);
                else if (!strcmp(var, "wpc")) s->set_wpc(s, value);
                else if (!strcmp(var, "raw_gma")) s->set_raw_gma(s, value);
                else if (!strcmp(var, "lenc")) s->set_lenc(s, value);
                else if (!strcmp(var, "special_effect")) s->set_special_effect(s, value);
                else if (!strcmp(var, "wb_mode")) s->set_wb_mode(s, value);
                else if (!strcmp(var, "ae_level")) s->set_ae_level(s, value);
            }
        }
        free(buf);
    }
    httpd_resp_set_hdr(req, "Access-Control-Allow-Origin", "*");
    return httpd_resp_send(req, NULL, 0);
}

static esp_err_t capture_handler(httpd_req_t *req) {
    camera_fb_t *fb = esp_camera_fb_get();
    if (!fb) { httpd_resp_send_500(req); return ESP_FAIL; }
    httpd_resp_set_type(req, "image/jpeg");
    httpd_resp_set_hdr(req, "Content-Disposition", "inline; filename=capture.jpg");
    httpd_resp_set_hdr(req, "Access-Control-Allow-Origin", "*");
    esp_err_t res = httpd_resp_send(req, (const char *)fb->buf, fb->len);
    esp_camera_fb_return(fb);
    return res;
}

static esp_err_t stream_handler(httpd_req_t *req) {
    camera_fb_t *fb = NULL;
    char part_buf[64];
    httpd_resp_set_type(req, _STREAM_CONTENT_TYPE);
    httpd_resp_set_hdr(req, "Access-Control-Allow-Origin", "*");
    while (true) {
        fb = esp_camera_fb_get();
        if (!fb) break;
        size_t hlen = snprintf(part_buf, 64, _STREAM_PART, fb->len);
        if (httpd_resp_send_chunk(req, (const char *)part_buf, hlen) != ESP_OK) { esp_camera_fb_return(fb); break; }
        if (httpd_resp_send_chunk(req, (const char *)fb->buf, fb->len) != ESP_OK) { esp_camera_fb_return(fb); break; }
        if (httpd_resp_send_chunk(req, _STREAM_BOUNDARY, strlen(_STREAM_BOUNDARY)) != ESP_OK) { esp_camera_fb_return(fb); break; }
        esp_camera_fb_return(fb);
    }
    return ESP_OK;
}

void startServer() {
    httpd_config_t config = HTTPD_DEFAULT_CONFIG();
    config.server_port = 80;
    httpd_uri_t index_uri = { .uri = "/", .method = HTTP_GET, .handler = index_handler };
    httpd_uri_t status_uri = { .uri = "/status", .method = HTTP_GET, .handler = status_handler };
    httpd_uri_t cmd_uri = { .uri = "/control", .method = HTTP_GET, .handler = cmd_handler };
    httpd_uri_t capture_uri = { .uri = "/capture", .method = HTTP_GET, .handler = capture_handler };
    if (httpd_start(&camera_httpd, &config) == ESP_OK) {
        httpd_register_uri_handler(camera_httpd, &index_uri);
        httpd_register_uri_handler(camera_httpd, &status_uri);
        httpd_register_uri_handler(camera_httpd, &cmd_uri);
        httpd_register_uri_handler(camera_httpd, &capture_uri);
    }
    config.server_port = 81;
    httpd_uri_t stream_uri = { .uri = "/stream", .method = HTTP_GET, .handler = stream_handler };
    if (httpd_start(&stream_httpd, &config) == ESP_OK) {
        httpd_register_uri_handler(stream_httpd, &stream_uri);
    }
}

// ======= SYSTEM =======
void setup() {
    Serial.begin(115200);
    Wire.begin(SIOD_GPIO_NUM, SIOC_GPIO_NUM);

    camera_config_t cfg;
    cfg.ledc_channel = LEDC_CHANNEL_0; cfg.ledc_timer = LEDC_TIMER_0;
    cfg.pin_d0 = Y2_GPIO_NUM; cfg.pin_d1 = Y3_GPIO_NUM; cfg.pin_d2 = Y4_GPIO_NUM;
    cfg.pin_d3 = Y5_GPIO_NUM; cfg.pin_d4 = Y6_GPIO_NUM; cfg.pin_d5 = Y7_GPIO_NUM;
    cfg.pin_d6 = Y8_GPIO_NUM; cfg.pin_d7 = Y9_GPIO_NUM; cfg.pin_xclk = XCLK_GPIO_NUM;
    cfg.pin_pclk = PCLK_GPIO_NUM; cfg.pin_vsync = VSYNC_GPIO_NUM; cfg.pin_href = HREF_GPIO_NUM;
    cfg.pin_sccb_sda = SIOD_GPIO_NUM; cfg.pin_sccb_scl = SIOC_GPIO_NUM;
    cfg.pin_pwdn = PWDN_GPIO_NUM; cfg.pin_reset = RESET_GPIO_NUM;
    cfg.xclk_freq_hz = 20000000; cfg.pixel_format = PIXFORMAT_JPEG;
    cfg.frame_size = FRAMESIZE_QVGA; cfg.jpeg_quality = 12; cfg.fb_count = 2;
    cfg.fb_location = CAMERA_FB_IN_PSRAM; cfg.grab_mode = CAMERA_GRAB_LATEST;

    if (esp_camera_init(&cfg) == ESP_OK) {
        sensor_t *s = esp_camera_sensor_get();
        if (s->id.PID == OV3660_PID) { s->set_vflip(s, 1); s->set_brightness(s, 1); }
    }

    initI2S();
    WiFi.begin(WIFI_SSID, WIFI_PASS);
    while (WiFi.status() != WL_CONNECTED) { delay(500); Serial.print("."); }
    startServer();
    configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);

    xTaskCreate([](void*) {
        while (1) { if (isStarted) detectObjects(); delay(60000); }
    }, "AI", 8192, NULL, 1, NULL);
}

void loop() {
    if (Serial.available()) {
        String in = Serial.readStringUntil('\n'); in.trim();
        if (in.equalsIgnoreCase("start")) isStarted = true;
        else if (in.equalsIgnoreCase("stop")) isStarted = false;
        else if (in.equalsIgnoreCase("test")) {
            Serial.printf("Lux: %u\n", readLux());
            i2s_start(I2S_NUM_0);
            int16_t b[200]; for(int i=0; i<200; i++) b[i]=(i%20<10)?8000:-8000;
            size_t bw; for(int i=0; i<100; i++) i2s_write(I2S_NUM_0, b, sizeof(b), &bw, 10);
            i2s_stop(I2S_NUM_0);
        }
    }
    delay(100);
}
