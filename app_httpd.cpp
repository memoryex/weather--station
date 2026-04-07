#include <esp_http_server.h>
#include <esp_timer.h>
#include "esp_camera.h"
#include "Arduino.h"

extern const uint8_t index_ov3660_html_gz[];
extern const size_t index_ov3660_html_gz_len;

static esp_err_t index_handler(httpd_req_t *req) {
    httpd_resp_set_type(req, "text/html");
    httpd_resp_set_header(req, "Content-Encoding", "gzip");
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
    p += sprintf(p, "\"colorbar\":%u,", s->status.colorbar);
    p += sprintf(p, "\"led_intensity\":%d", 0);
    *p++ = '}';
    *p++ = 0;
    httpd_resp_set_type(req, "application/json");
    httpd_resp_set_header(req, "Access-Control-Allow-Origin", "*");
    return httpd_resp_send(req, json_response, strlen(json_response));
}

static esp_err_t cmd_handler(httpd_req_t *req) {
    char *buf = NULL;
    size_t buf_len = httpd_req_get_url_query_len(req) + 1;
    if (buf_len > 1) {
        buf = (char *)malloc(buf_len);
        if (!buf) {
            httpd_resp_send_500(req);
            return ESP_FAIL;
        }
        if (httpd_req_get_url_query_str(req, buf, buf_len) == ESP_OK) {
            char var[32];
            char val[32];
            if (httpd_query_key_value(buf, "var", var, sizeof(var)) == ESP_OK &&
                httpd_query_key_value(buf, "val", val, sizeof(val)) == ESP_OK) {
                int value = atoi(val);
                sensor_t *s = esp_camera_sensor_get();
                int res = 0;

                if (!strcmp(var, "framesize")) res = s->set_framesize(s, (framesize_t)value);
                else if (!strcmp(var, "quality")) res = s->set_quality(s, value);
                else if (!strcmp(var, "contrast")) res = s->set_contrast(s, value);
                else if (!strcmp(var, "brightness")) res = s->set_brightness(s, value);
                else if (!strcmp(var, "saturation")) res = s->set_saturation(s, value);
                else if (!strcmp(var, "gainceiling")) res = s->set_gainceiling(s, (gainceiling_t)value);
                else if (!strcmp(var, "colorbar")) res = s->set_colorbar(s, value);
                else if (!strcmp(var, "awb")) res = s->set_whitebal(s, value);
                else if (!strcmp(var, "agc")) res = s->set_gain_ctrl(s, value);
                else if (!strcmp(var, "aec")) res = s->set_exposure_ctrl(s, value);
                else if (!strcmp(var, "hmirror")) res = s->set_hmirror(s, value);
                else if (!strcmp(var, "vflip")) res = s->set_vflip(s, value);
                else if (!strcmp(var, "awb_gain")) res = s->set_awb_gain(s, value);
                else if (!strcmp(var, "agc_gain")) res = s->set_agc_gain(s, value);
                else if (!strcmp(var, "aec_value")) res = s->set_aec_value(s, value);
                else if (!strcmp(var, "aec2")) res = s->set_aec2(s, value);
                else if (!strcmp(var, "dcw")) res = s->set_dcw(s, value);
                else if (!strcmp(var, "bpc")) res = s->set_bpc(s, value);
                else if (!strcmp(var, "wpc")) res = s->set_wpc(s, value);
                else if (!strcmp(var, "raw_gma")) res = s->set_raw_gma(s, value);
                else if (!strcmp(var, "lenc")) res = s->set_lenc(s, value);
                else if (!strcmp(var, "special_effect")) res = s->set_special_effect(s, value);
                else if (!strcmp(var, "wb_mode")) res = s->set_wb_mode(s, value);
                else if (!strcmp(var, "ae_level")) res = s->set_ae_level(s, value);
                else res = -1;

                if (res) {
                    return httpd_resp_send_500(req);
                }
            } else {
                free(buf);
                return httpd_resp_send_404(req);
            }
        }
        free(buf);
    }
    httpd_resp_set_header(req, "Access-Control-Allow-Origin", "*");
    return httpd_resp_send(req, NULL, 0);
}

static esp_err_t capture_handler(httpd_req_t *req) {
    camera_fb_t *fb = NULL;
    esp_err_t res = ESP_OK;
    fb = esp_camera_fb_get();
    if (!fb) {
        Serial.println("Camera capture failed");
        httpd_resp_send_500(req);
        return ESP_FAIL;
    }
    httpd_resp_set_type(req, "image/jpeg");
    httpd_resp_set_header(req, "Content-Disposition", "inline; filename=capture.jpg");
    httpd_resp_set_header(req, "Access-Control-Allow-Origin", "*");
    res = httpd_resp_send(req, (const char *)fb->buf, fb->len);
    esp_camera_fb_return(fb);
    return res;
}

void startCameraServer() {
    httpd_config_t config = HTTPD_DEFAULT_CONFIG();
    config.server_port = 80;
    httpd_handle_t camera_httpd = NULL;

    httpd_uri_t index_uri = { .uri = "/", .method = HTTP_GET, .handler = index_handler, .user_ctx = NULL };
    httpd_uri_t status_uri = { .uri = "/status", .method = HTTP_GET, .handler = status_handler, .user_ctx = NULL };
    httpd_uri_t cmd_uri = { .uri = "/control", .method = HTTP_GET, .handler = cmd_handler, .user_ctx = NULL };
    httpd_uri_t capture_uri = { .uri = "/capture", .method = HTTP_GET, .handler = capture_handler, .user_ctx = NULL };

    if (httpd_start(&camera_httpd, &config) == ESP_OK) {
        httpd_register_uri_handler(camera_httpd, &index_uri);
        httpd_register_uri_handler(camera_httpd, &status_uri);
        httpd_register_uri_handler(camera_httpd, &cmd_uri);
        httpd_register_uri_handler(camera_httpd, &capture_uri);
        Serial.println("HTTP server started");
    }
}

void setupLedFlash(int pin) {
    pinMode(pin, OUTPUT);
}
