/*
 * MI_esp32 - smart feeder simulator.
 *
 * Every FEEDER_SEND_INTERVAL_MS the ESP32 sends, over CoAP/DTLS-PSK, one JSON object
 * for each cow of the COW_IDS list below (all objects carry the same date):
 *
 *   {"cow_id":"3C43FA39","date":"2026-01-01","age_months":86.0,"food_consumed_g":8819,
 *    "feed_offered_g":9821,"visits":12,"eating_minutes":103,"avg_meal_duration_min":10.3,
 *    "no_food_visits":2,"first_visit_hour":6.3,"last_visit_hour":21.1}
 *
 * Values are random inside fixed intervals; once all cows were sent, the date
 * advances by one day.
 * Target: coaps://FEEDER_SERVER_IP:FEEDER_SERVER_PORT/FEEDER_URI_PATH  (POST)
 */

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "freertos/FreeRTOS.h"
#include "freertos/event_groups.h"
#include "freertos/task.h"

#include "esp_event.h"
#include "esp_log.h"
#include "esp_netif.h"
#include "esp_random.h"
#include "esp_timer.h"
#include "esp_wifi.h"
#include "nvs_flash.h"

#include <sys/time.h>
#include <time.h>

#include "esp_sntp.h"
#include "lwip/inet.h"

#include "coap3/coap.h"

static const char *TAG = "MI_esp32";

#define WIFI_CONNECTED_BIT BIT0

static EventGroupHandle_t s_wifi_events;
static volatile bool s_reconnect = false;      /* set when the DTLS session must be rebuilt */

/* The cows that are simulated. Edit this list to add or remove cows. */
static const char *const COW_IDS[] = {
    "3C43FA39", "CC8B7922", "92EBEA51", "822D4251", "EC954B17", "92B47151", "EDFF4D24",
};
#define NUM_COWS (sizeof(COW_IDS) / sizeof(COW_IDS[0]))

/* ------------------------------ random helpers ----------------------------- */
static int rnd_int(int lo, int hi)
{
    return lo + (int)(esp_random() % (uint32_t)(hi - lo + 1));
}

static float rnd_float(float lo, float hi)
{
    return lo + (hi - lo) * ((float)(esp_random() % 100001) / 100000.0f);
}

/* ------------------------------ date handling ------------------------------ */
typedef struct {
    int y, m, d;
} date_t;

static int days_in_month(int y, int m)
{
    static const int dm[] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
    if (m == 2 && ((y % 4 == 0 && y % 100 != 0) || y % 400 == 0)) {
        return 29;
    }
    return dm[m - 1];
}

static void date_next_day(date_t *dt)
{
    dt->d++;
    if (dt->d > days_in_month(dt->y, dt->m)) {
        dt->d = 1;
        dt->m++;
        if (dt->m > 12) {
            dt->m = 1;
            dt->y++;
        }
    }
}

static date_t date_parse(const char *s)
{
    date_t dt = {2026, 1, 1};
    int y, m, d;
    if (sscanf(s, "%d-%d-%d", &y, &m, &d) == 3 && m >= 1 && m <= 12 && d >= 1 &&
        d <= days_in_month(y, m)) {
        dt.y = y;
        dt.m = m;
        dt.d = d;
    } else {
        ESP_LOGW(TAG, "Bad FEEDER_START_DATE '%s', using 2026-01-01", s);
    }
    return dt;
}

/* Gets today's real date from the internet (SNTP). Needs WiFi with internet access. */
static bool date_from_internet(date_t *out)
{
    esp_sntp_setoperatingmode(ESP_SNTP_OPMODE_POLL);
    esp_sntp_setservername(0, "pool.ntp.org");
    esp_sntp_setservername(1, "time.google.com");
    esp_sntp_init();

    ESP_LOGI(TAG, "Waiting for the time from the internet...");
    for (int i = 0; i < 30; i++) {
        time_t now = time(NULL);
        if (now > 1700000000) {                        /* clock is set (after Nov 2023) */
            setenv("TZ", "CET-1", 1);                  /* Tunisia: UTC+1, no daylight saving */
            tzset();
            struct tm tm;
            localtime_r(&now, &tm);
            out->y = tm.tm_year + 1900;
            out->m = tm.tm_mon + 1;
            out->d = tm.tm_mday;
            ESP_LOGI(TAG, "Real date: %04d-%02d-%02d", out->y, out->m, out->d);
            return true;
        }
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
    ESP_LOGW(TAG, "Could not get the time from the internet");
    return false;
}

/* ------------------------------ payload ------------------------------------ */
/* Builds the JSON object of one cow. Returns the length (without the final 0). */
static int build_cow_json(char *buf, size_t size, const date_t *dt, const char *cow_id,
                          float age_months)
{
    int offered = rnd_int(8000, 12000);
    int consumed = (int)((float)offered * rnd_float(0.70f, 0.99f));
    int visits = rnd_int(6, 16);
    int eating_min = rnd_int(60, 140);
    float avg_meal = rnd_float(6.0f, 14.0f);
    int no_food = rnd_int(0, 4);
    float first_h = rnd_float(5.0f, 8.0f);
    float last_h = rnd_float(18.0f, 22.0f);

    int n = snprintf(buf, size,
                     "{\"cow_id\":\"%s\",\"date\":\"%04d-%02d-%02d\",\"age_months\":%.1f,"
                     "\"food_consumed_g\":%d,\"feed_offered_g\":%d,\"visits\":%d,"
                     "\"eating_minutes\":%d,\"avg_meal_duration_min\":%.1f,"
                     "\"no_food_visits\":%d,\"first_visit_hour\":%.1f,\"last_visit_hour\":%.1f}",
                     cow_id, dt->y, dt->m, dt->d, age_months, consumed, offered, visits,
                     eating_min, avg_meal, no_food, first_h, last_h);
    return n < (int)size ? n : (int)size - 1;
}

/* ------------------------------ WiFi --------------------------------------- */
static void wifi_event_handler(void *arg, esp_event_base_t base, int32_t id, void *data)
{
    if (base == WIFI_EVENT && id == WIFI_EVENT_STA_START) {
        esp_wifi_connect();
    } else if (base == WIFI_EVENT && id == WIFI_EVENT_STA_DISCONNECTED) {
        xEventGroupClearBits(s_wifi_events, WIFI_CONNECTED_BIT);
        s_reconnect = true;
        ESP_LOGW(TAG, "WiFi lost, retrying...");
        esp_wifi_connect();
    } else if (base == IP_EVENT && id == IP_EVENT_STA_GOT_IP) {
        ip_event_got_ip_t *ev = (ip_event_got_ip_t *)data;
        ESP_LOGI(TAG, "Got IP: " IPSTR, IP2STR(&ev->ip_info.ip));
        xEventGroupSetBits(s_wifi_events, WIFI_CONNECTED_BIT);
    }
}

static void wifi_init(void)
{
    s_wifi_events = xEventGroupCreate();
    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());
    esp_netif_create_default_wifi_sta();

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));
    ESP_ERROR_CHECK(esp_event_handler_register(WIFI_EVENT, ESP_EVENT_ANY_ID, &wifi_event_handler, NULL));
    ESP_ERROR_CHECK(esp_event_handler_register(IP_EVENT, IP_EVENT_STA_GOT_IP, &wifi_event_handler, NULL));

    wifi_config_t wc = {0};
    strlcpy((char *)wc.sta.ssid, CONFIG_FEEDER_WIFI_SSID, sizeof(wc.sta.ssid));
    strlcpy((char *)wc.sta.password, CONFIG_FEEDER_WIFI_PASSWORD, sizeof(wc.sta.password));
    wc.sta.threshold.authmode = WIFI_AUTH_WPA2_PSK;
    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &wc));
    ESP_ERROR_CHECK(esp_wifi_start());
}

/* ------------------------------ CoAP / DTLS-PSK ---------------------------- */
static coap_response_t response_handler(coap_session_t *session, const coap_pdu_t *sent,
                                        const coap_pdu_t *received, const coap_mid_t mid)
{
    coap_pdu_code_t code = coap_pdu_get_code(received);
    ESP_LOGI(TAG, "Response from proxy: %d.%02d", (code >> 5), (code & 0x1F));
    return COAP_RESPONSE_OK;
}

static int event_handler(coap_session_t *session, const coap_event_t event)
{
    switch (event) {
    case COAP_EVENT_DTLS_CLOSED:
    case COAP_EVENT_DTLS_ERROR:
    case COAP_EVENT_TCP_CLOSED:
    case COAP_EVENT_TCP_FAILED:
        ESP_LOGW(TAG, "DTLS session closed/failed (event 0x%x), will reconnect", (unsigned)event);
        s_reconnect = true;
        break;
    case COAP_EVENT_DTLS_CONNECTED:
        ESP_LOGI(TAG, "DTLS handshake done");
        break;
    default:
        break;
    }
    return 0;
}

static coap_session_t *open_session(coap_context_t *ctx)
{
    coap_address_t dst;
    coap_address_init(&dst);
    dst.addr.sin.sin_family = AF_INET;
    dst.addr.sin.sin_port = htons(CONFIG_FEEDER_SERVER_PORT);
    if (inet_pton(AF_INET, CONFIG_FEEDER_SERVER_IP, &dst.addr.sin.sin_addr) != 1) {
        ESP_LOGE(TAG, "Invalid FEEDER_SERVER_IP '%s'", CONFIG_FEEDER_SERVER_IP);
        return NULL;
    }

    coap_dtls_cpsk_t psk;
    memset(&psk, 0, sizeof(psk));
    psk.version = COAP_DTLS_CPSK_SETUP_VERSION;
    psk.psk_info.identity.s = (const uint8_t *)CONFIG_FEEDER_PSK_IDENTITY;
    psk.psk_info.identity.length = strlen(CONFIG_FEEDER_PSK_IDENTITY);
    psk.psk_info.key.s = (const uint8_t *)CONFIG_FEEDER_PSK_KEY;
    psk.psk_info.key.length = strlen(CONFIG_FEEDER_PSK_KEY);

    return coap_new_client_session_psk2(ctx, NULL, &dst, COAP_PROTO_DTLS, &psk);
}

static bool send_reading(coap_session_t *session, const char *payload, size_t len)
{
    coap_pdu_t *pdu = coap_pdu_init(COAP_MESSAGE_CON, COAP_REQUEST_CODE_POST,
                                    coap_new_message_id(session),
                                    coap_session_max_pdu_size(session));
    if (!pdu) {
        ESP_LOGE(TAG, "coap_pdu_init failed");
        return false;
    }

    unsigned char fmt[4];
    coap_add_option(pdu, COAP_OPTION_URI_PATH, strlen(CONFIG_FEEDER_URI_PATH),
                    (const uint8_t *)CONFIG_FEEDER_URI_PATH);
    coap_add_option(pdu, COAP_OPTION_CONTENT_FORMAT,
                    coap_encode_var_safe(fmt, sizeof(fmt), COAP_MEDIATYPE_APPLICATION_JSON), fmt);
    coap_add_data(pdu, len, (const uint8_t *)payload);

    return coap_send(session, pdu) != COAP_INVALID_MID;
}

static void coap_task(void *arg)
{
    coap_startup();
    coap_set_log_level(COAP_LOG_WARN);

    /* The first date is today's real date; the fixed start date is only the fallback. */
    xEventGroupWaitBits(s_wifi_events, WIFI_CONNECTED_BIT, pdFALSE, pdTRUE, portMAX_DELAY);
    date_t date = date_parse(CONFIG_FEEDER_START_DATE);
#ifdef CONFIG_FEEDER_USE_REAL_DATE
    if (!date_from_internet(&date)) {
        ESP_LOGW(TAG, "Falling back to FEEDER_START_DATE %s", CONFIG_FEEDER_START_DATE);
    }
#endif
    float ages[NUM_COWS];                                   /* 24.0 - 120.0, fixed per cow per boot */
    for (size_t i = 0; i < NUM_COWS; i++) {
        ages[i] = (float)rnd_int(240, 1200) / 10.0f;
    }
    char payload[320];                                      /* one cow's JSON is about 215 bytes */

    coap_context_t *ctx = NULL;
    coap_session_t *session = NULL;

    for (;;) {
        xEventGroupWaitBits(s_wifi_events, WIFI_CONNECTED_BIT, pdFALSE, pdTRUE, portMAX_DELAY);

        if (s_reconnect || !ctx || !session) {
            if (session) {
                coap_session_release(session);
                session = NULL;
            }
            if (ctx) {
                coap_free_context(ctx);
                ctx = NULL;
            }
            s_reconnect = false;

            ctx = coap_new_context(NULL);
            if (!ctx) {
                ESP_LOGE(TAG, "coap_new_context failed");
                vTaskDelay(pdMS_TO_TICKS(3000));
                continue;
            }
            coap_register_response_handler(ctx, response_handler);
            coap_register_event_handler(ctx, event_handler);

            session = open_session(ctx);
            if (!session) {
                ESP_LOGE(TAG, "Could not create DTLS session, retrying in 3 s");
                coap_free_context(ctx);
                ctx = NULL;
                vTaskDelay(pdMS_TO_TICKS(3000));
                continue;
            }
            ESP_LOGI(TAG, "Session to coaps://%s:%d/%s opened", CONFIG_FEEDER_SERVER_IP,
                     CONFIG_FEEDER_SERVER_PORT, CONFIG_FEEDER_URI_PATH);
        }

        /* One JSON object per cow, all with the same date. */
        bool ok = true;
        for (size_t i = 0; i < NUM_COWS && ok; i++) {
            int len = build_cow_json(payload, sizeof(payload), &date, COW_IDS[i], ages[i]);
            ESP_LOGI(TAG, "Sending: %s", payload);
            ok = send_reading(session, payload, (size_t)len);
            coap_io_process(ctx, 100);        /* let DTLS/CoAP flush and read the reply */
        }

        if (ok) {
            date_next_day(&date);             /* one more day for the next round */
        } else {
            ESP_LOGW(TAG, "Send failed, will rebuild the session");
            s_reconnect = true;
        }

        /* Run the CoAP/DTLS engine until the next sending time. */
        int64_t end = esp_timer_get_time() + (int64_t)CONFIG_FEEDER_SEND_INTERVAL_MS * 1000;
        while (esp_timer_get_time() < end && !s_reconnect) {
            if (coap_io_process(ctx, 500) < 0) {
                ESP_LOGW(TAG, "coap_io_process error, will rebuild the session");
                s_reconnect = true;
            }
        }
    }
}

/* ------------------------------ entry point -------------------------------- */
void app_main(void)
{
    esp_err_t err = nvs_flash_init();
    if (err == ESP_ERR_NVS_NO_FREE_PAGES || err == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        err = nvs_flash_init();
    }
    ESP_ERROR_CHECK(err);

    wifi_init();
    xTaskCreate(coap_task, "coap_task", 8192, NULL, 5, NULL);
}
