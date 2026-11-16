
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "freertos/FreeRTOS.h"
#include "freertos/event_groups.h"
#include "freertos/queue.h"
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

#include "driver/spi_master.h"
#include "rc522.h"
#include "driver/rc522_spi.h"
#include "rc522_picc.h"

static const char *TAG = "MI_esp32";

#define WIFI_CONNECTED_BIT BIT0

static EventGroupHandle_t s_wifi_events;
static volatile bool s_reconnect = false;      /* set when the DTLS session must be rebuilt */

#define FEED_URI_PATH  "feed"                  /* RFID request handled by the Pi flow */
#define FEED_WAIT_MS   5000                    /* wait for the Pi's answer, per attempt */
#define FEED_ATTEMPTS  2                       /* /feed tries before the random fallback */

/* The simulation starts this many days after the start date (14 days of history first). */
#define START_OFFSET_DAYS 14

/* A card must stay on the reader this long to count as ONE visit. */
#define HOLD_TIME_MS     15000
/* A short loss of the card (reader flicker) below this does not reset the timer. */
#define REMOVE_GRACE_MS  1500

static volatile bool s_waiting_feed = false;   /* true while a /feed answer is expected */
static volatile bool s_feed_done = false;      /* set by the response handler */
static char s_feed_resp[320];                  /* answer of the /feed request */

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

static void date_add_days(date_t *dt, int n)
{
    while (n-- > 0) {
        date_next_day(dt);
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

/* ------------------------------ day plan / payload -------------------------- */
#define MIN_VISITS    3
#define MAX_VISITS    10

/* The whole day of one cow, planned at her first scan, then revealed one visit per scan. */
typedef struct {
    int   n;                        /* number of visits planned for the day */
    int   offered;                  /* feed offered (g), fixed for the day */
    int   food[MAX_VISITS];         /* grams eaten at each visit */
    int   minutes[MAX_VISITS];      /* minutes eating at each visit */
    bool  nofood[MAX_VISITS];       /* visit without eating */
    float hour[MAX_VISITS];         /* time of each visit (hour of the day) */
} day_plan_t;

static void plan_day(day_plan_t *p, int offered_g)
{
    memset(p, 0, sizeof(*p));
    p->n = rnd_int(MIN_VISITS, MAX_VISITS);
    /* feed served by the regression model; random fallback if the Pi did not answer */
    p->offered = (offered_g >= 1000 && offered_g <= 30000) ? offered_g : rnd_int(8000, 12000);

    int total_food = (int)((float)p->offered * rnd_float(0.70f, 0.99f));
    int total_min = rnd_int(60, 140);
    float first_h = rnd_float(5.0f, 8.0f);
    float last_h = rnd_float(18.0f, 22.0f);

    /* up to 4 visits without food, but at least one visit must eat */
    int n_nofood = rnd_int(0, (4 < p->n - 1) ? 4 : p->n - 1);
    while (n_nofood > 0) {
        int i = rnd_int(0, p->n - 1);
        if (!p->nofood[i]) {
            p->nofood[i] = true;
            n_nofood--;
        }
    }

    /* split the day's food and eating time between the eating visits */
    float w[MAX_VISITS], sum = 0.0f;
    for (int i = 0; i < p->n; i++) {
        w[i] = p->nofood[i] ? 0.0f : rnd_float(0.5f, 1.5f);
        sum += w[i];
    }
    for (int i = 0; i < p->n; i++) {
        p->food[i] = (int)((float)total_food * w[i] / sum);
        p->minutes[i] = (int)((float)total_min * w[i] / sum + 0.5f);
        p->hour[i] = first_h + (last_h - first_h) * (float)i / (float)(p->n - 1);
    }
}

/* JSON after visit k (0-based): totals of the day so far. */
static int build_visit_json(char *buf, size_t size, const date_t *dt, const char *cow_id,
                            float age_months, const day_plan_t *p, int k)
{
    int consumed = 0, eating_min = 0, no_food = 0, meals = 0;
    for (int i = 0; i <= k; i++) {
        consumed += p->food[i];
        eating_min += p->minutes[i];
        if (p->nofood[i]) {
            no_food++;
        } else {
            meals++;
        }
    }
    float avg_meal = meals ? (float)eating_min / (float)meals : 0.0f;

    int n = snprintf(buf, size,
                     "{\"cow_id\":\"%s\",\"date\":\"%04d-%02d-%02d\",\"age_months\":%.1f,"
                     "\"food_consumed_g\":%d,\"feed_offered_g\":%d,\"visits\":%d,"
                     "\"eating_minutes\":%d,\"avg_meal_duration_min\":%.1f,"
                     "\"no_food_visits\":%d,\"first_visit_hour\":%.1f,\"last_visit_hour\":%.1f,"
                     "\"day_over\":%s}",
                     cow_id, dt->y, dt->m, dt->d, age_months, consumed, p->offered, k + 1,
                     eating_min, avg_meal, no_food, p->hour[0], p->hour[k],
                     (k + 1 >= p->n) ? "true" : "false");
    return n < (int)size ? n : (int)size - 1;
}

/* ------------------------------ RFID (MFRC522) ----------------------------- */
/* Wiring (classic ESP32): SDA=5, SCK=18, MOSI=23, MISO=19, RST=22, 3.3V, GND */
#define RFID_MISO_GPIO 19
#define RFID_MOSI_GPIO 23
#define RFID_SCLK_GPIO 18
#define RFID_SDA_GPIO  5
#define RFID_RST_GPIO  22

#define UID_STR_LEN 17                      /* up to 8 UID bytes as hex + '\0' */
typedef struct {
    char uid[UID_STR_LEN];
    bool present;                           /* true: card detected, false: card removed */
} card_evt_t;
static QueueHandle_t s_card_q;              /* card events from the reader */

/* Every card seen so far has its OWN date, age and current day plan. */
#define MAX_COWS 16
typedef struct {
    char       id[UID_STR_LEN];
    float      age;
    date_t     date;
    day_plan_t plan;
    bool       plan_ready;                  /* a day is in progress for this cow */
    int        visit;                       /* visits already sent today */
} cow_t;
static cow_t s_cows[MAX_COWS];
static int   s_ncows = 0;

static cow_t *find_or_add_cow(const char *id, const date_t *start)
{
    for (int i = 0; i < s_ncows; i++) {
        if (strcmp(s_cows[i].id, id) == 0) {
            return &s_cows[i];
        }
    }
    if (s_ncows >= MAX_COWS) {
        return NULL;
    }
    cow_t *c = &s_cows[s_ncows++];
    memset(c, 0, sizeof(*c));
    strlcpy(c->id, id, sizeof(c->id));
    c->age = (float)rnd_int(240, 1200) / 10.0f;   /* fallback until the Pi sends the profile */
    c->date = *start;
    return c;
}

static void on_picc_state_changed(void *arg, esp_event_base_t base, int32_t event_id, void *data)
{
    rc522_picc_state_changed_event_t *ev = (rc522_picc_state_changed_event_t *)data;
    rc522_picc_t *picc = ev->picc;

    card_evt_t evt = {0};
    if (picc->state == RC522_PICC_STATE_ACTIVE) {
        evt.present = true;
        for (int i = 0; i < picc->uid.length && i < 8; i++) {
            sprintf(evt.uid + 2 * i, "%02X", picc->uid.value[i]);   /* uppercase, like "3C43FA39" */
        }
    } else if (picc->state == RC522_PICC_STATE_IDLE) {
        evt.present = false;                       /* card removed from the reader */
    } else {
        return;
    }
    xQueueSend(s_card_q, &evt, 0);                 /* never block the reader's task */
}

static void rfid_init(void)
{
    s_card_q = xQueueCreate(8, sizeof(card_evt_t));

    static spi_bus_config_t bus_config = {
        .miso_io_num = RFID_MISO_GPIO,
        .mosi_io_num = RFID_MOSI_GPIO,
        .sclk_io_num = RFID_SCLK_GPIO,
        .quadwp_io_num = -1,
        .quadhd_io_num = -1,
    };
    static rc522_spi_config_t driver_config = {
        .host_id = SPI3_HOST,
        .bus_config = &bus_config,
        .dev_config = {.spics_io_num = RFID_SDA_GPIO},
        .rst_io_num = RFID_RST_GPIO,
    };
    static rc522_driver_handle_t driver;
    static rc522_handle_t scanner;

    ESP_ERROR_CHECK(rc522_spi_create(&driver_config, &driver));
    ESP_ERROR_CHECK(rc522_driver_install(driver));

    rc522_config_t scanner_config = {.driver = driver};
    ESP_ERROR_CHECK(rc522_create(&scanner_config, &scanner));
    ESP_ERROR_CHECK(rc522_register_events(scanner, RC522_EVENT_PICC_STATE_CHANGED,
                                          on_picc_state_changed, NULL));
    ESP_ERROR_CHECK(rc522_start(scanner));
    ESP_LOGI(TAG, "RFID reader started");
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
    size_t len = 0;
    const uint8_t *data = NULL;
    coap_get_data(received, &len, &data);

    ESP_LOGD(TAG, "Response from proxy: %d.%02d, %u bytes", (code >> 5), (code & 0x1F), (unsigned)len);

    /* Only the /feed answer carries JSON; the reading replies are a plain "OK". */
    if (s_waiting_feed && data && len > 0) {
        const uint8_t *p = memchr(data, '{', len);     /* tolerate a leading quote */
        if (p) {
            size_t n = len - (size_t)(p - data);
            if (n >= sizeof(s_feed_resp)) {
                n = sizeof(s_feed_resp) - 1;
            }
            memcpy(s_feed_resp, p, n);
            s_feed_resp[n] = '\0';
            s_feed_done = true;
        }
    }
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
        ESP_LOGD(TAG, "CoAP event 0x%x", (unsigned)event);
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

static bool send_message(coap_session_t *session, const char *path, const char *payload, size_t len)
{
    coap_pdu_t *pdu = coap_pdu_init(COAP_MESSAGE_CON, COAP_REQUEST_CODE_POST,
                                    coap_new_message_id(session),
                                    coap_session_max_pdu_size(session));
    if (!pdu) {
        ESP_LOGE(TAG, "coap_pdu_init failed");
        return false;
    }

    unsigned char fmt[4];
    coap_add_option(pdu, COAP_OPTION_URI_PATH, strlen(path), (const uint8_t *)path);
    coap_add_option(pdu, COAP_OPTION_CONTENT_FORMAT,
                    coap_encode_var_safe(fmt, sizeof(fmt), COAP_MEDIATYPE_APPLICATION_JSON), fmt);
    coap_add_data(pdu, len, (const uint8_t *)payload);

    return coap_send(session, pdu) != COAP_INVALID_MID;
}

/* Finds `key` in the text and returns the number after its ':' (works with "key": and \"key\":). */
static bool find_number(const char *json, const char *key, double *out)
{
    const char *k = strstr(json, key);
    if (!k) {
        return false;
    }
    const char *colon = strchr(k + strlen(key), ':');
    if (!colon) {
        return false;
    }
    char *end = NULL;
    double v = strtod(colon + 1, &end);
    if (end == colon + 1) {
        return false;                      /* no number after the colon */
    }
    *out = v;
    return true;
}

/* Reads age_months (profile) and food_g from the Pi's /feed answer. */
static bool parse_feed_reply(const char *json, float *age, int *food_g)
{
    double a, f;
    if (!find_number(json, "age_months", &a) || !find_number(json, "food_g", &f)) {
        return false;                      /* unknown_cow, already_served or error: no usable data */
    }
    *age = (float)a;
    *food_g = (int)f;
    return *age > 0.0f && *food_g > 0;
}

/* RFID request: asks the Pi for this cow's profile and the food to serve on this simulated day. */
static bool request_feed(coap_context_t *ctx, coap_session_t *session, const char *cow_id,
                         const date_t *dt, float *age, int *food_g)
{
    char body[96];
    int n = snprintf(body, sizeof(body), "{\"rfid\":\"%s\",\"date\":\"%04d-%02d-%02d\"}",
                     cow_id, dt->y, dt->m, dt->d);
    if (n <= 0 || n >= (int)sizeof(body)) {
        return false;
    }

    s_feed_done = false;
    s_feed_resp[0] = '\0';
    s_waiting_feed = true;
    bool ok = send_message(session, FEED_URI_PATH, body, (size_t)n);

    int64_t end = esp_timer_get_time() + (int64_t)FEED_WAIT_MS * 1000;
    while (ok && !s_feed_done && !s_reconnect && esp_timer_get_time() < end) {
        if (coap_io_process(ctx, 200) < 0) {
            s_reconnect = true;
        }
    }
    s_waiting_feed = false;

    if (!s_feed_done) {
        ESP_LOGW(TAG, "No /feed answer for %s", cow_id);
        return false;
    }
    ESP_LOGI(TAG, "Feed answer: %s", s_feed_resp);
    return parse_feed_reply(s_feed_resp, age, food_g);
}

static void coap_task(void *arg)
{
    coap_startup();
    coap_set_log_level(COAP_LOG_WARN);

    /* The first date is today's real date; the fixed start date is only the fallback. */
    xEventGroupWaitBits(s_wifi_events, WIFI_CONNECTED_BIT, pdFALSE, pdTRUE, portMAX_DELAY);
    date_t start = date_parse(CONFIG_FEEDER_START_DATE);
#ifdef CONFIG_FEEDER_USE_REAL_DATE
    if (!date_from_internet(&start)) {
        ESP_LOGW(TAG, "Falling back to FEEDER_START_DATE %s", CONFIG_FEEDER_START_DATE);
    }
#endif

    /* Start after the simulated history. */
    date_add_days(&start, START_OFFSET_DAYS);
    ESP_LOGI(TAG, "Simulation starts on %04d-%02d-%02d", start.y, start.m, start.d);

    char payload[320];                                      /* one cow's JSON is about 215 bytes */

    char pending[UID_STR_LEN] = {0};                        /* visit being processed */
    bool has_pending = false;                               /* kept until it is really sent */

    char hold_uid[UID_STR_LEN] = {0};                       /* card currently on the reader */
    bool holding = false;                                   /* a card is on the reader */
    bool lost = false;                                      /* reader reported it removed */
    bool counted = false;                                   /* this presence already gave a visit */
    int64_t hold_since = 0;                                 /* when the card was first detected */
    int64_t lost_at = 0;                                    /* when the removal was reported */

    coap_context_t *ctx = NULL;
    coap_session_t *session = NULL;

    ESP_LOGI(TAG, "Ready: hold a cow card on the reader for %d s (one presence = one visit)",
             HOLD_TIME_MS / 1000);

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
            ESP_LOGI(TAG, "Session to coaps://%s:%d opened", CONFIG_FEEDER_SERVER_IP,
                     CONFIG_FEEDER_SERVER_PORT);
        }

        /* Idle: track the card on the reader. A visit counts once the card has stayed
         * HOLD_TIME_MS. Keep the DTLS session alive meanwhile. */
        if (!has_pending) {
            card_evt_t evt;
            while (xQueueReceive(s_card_q, &evt, 0) == pdTRUE) {
                int64_t t = esp_timer_get_time();
                if (evt.present) {
                    if (holding && strcmp(hold_uid, evt.uid) == 0) {
                        lost = false;                       /* same card is back: keep the timer */
                    } else {
                        strlcpy(hold_uid, evt.uid, sizeof(hold_uid));
                        holding = true;
                        lost = false;
                        counted = false;
                        hold_since = t;
                        ESP_LOGI(TAG, "Card %s detected: keep it on the reader for %d s",
                                 hold_uid, HOLD_TIME_MS / 1000);
                    }
                } else if (holding && !lost) {
                    lost = true;                            /* maybe removed, wait for the grace time */
                    lost_at = t;
                }
            }

            int64_t now = esp_timer_get_time();
            if (holding && lost && (now - lost_at) > (int64_t)REMOVE_GRACE_MS * 1000) {
                if (!counted) {
                    ESP_LOGI(TAG, "Card %s removed after %.1f s: too short, visit not counted",
                             hold_uid, (double)(lost_at - hold_since) / 1e6);
                }
                holding = false;
                lost = false;
            }

            if (holding && !lost && !counted &&
                (now - hold_since) >= (int64_t)HOLD_TIME_MS * 1000) {
                counted = true;                             /* one visit per presence */
                strlcpy(pending, hold_uid, sizeof(pending));
                has_pending = true;
                ESP_LOGI(TAG, "Card %s stayed %d s: visit counted", pending, HOLD_TIME_MS / 1000);
            }

            if (!has_pending) {
                if (coap_io_process(ctx, 200) < 0) {
                    s_reconnect = true;
                }
                continue;
            }
        }

        cow_t *cur = find_or_add_cow(pending, &start);
        if (!cur) {
            ESP_LOGW(TAG, "Cow table full, card %s ignored", pending);
            has_pending = false;
            continue;
        }
        date_t *date = &cur->date;                          /* this cow's current day */

        /* First scan of this cow's day: ask the Pi and plan the day. */
        if (!cur->plan_ready) {
            int served_g = 0;
            float prof_age = 0.0f;

            bool got = false;
            for (int attempt = 0; attempt < FEED_ATTEMPTS && !got && !s_reconnect; attempt++) {
                got = request_feed(ctx, session, cur->id, date, &prof_age, &served_g);
            }
            if (s_reconnect) {
                continue;                  /* session died meanwhile: rebuild it, keep the scan */
            }

            if (got) {
                cur->age = prof_age;       /* profile age from the Pi replaces the random one */
            } else {
                served_g = 0;              /* fallback: random feed amount, previous age */
                ESP_LOGW(TAG, "Cow %s: no profile from the Pi, using fallback values", cur->id);
            }
            plan_day(&cur->plan, served_g);
            cur->visit = 0;
            cur->plan_ready = true;
            ESP_LOGI(TAG, "Cow %s: new day %04d-%02d-%02d (%d visits planned)", cur->id,
                     date->y, date->m, date->d, cur->plan.n);
        }

        /* This scan is visit number cur->visit + 1 of her day. */
        int len = build_visit_json(payload, sizeof(payload), date, cur->id,
                                   cur->age, &cur->plan, cur->visit);
        ESP_LOGI(TAG, "Cow %s visit %d/%d: %s", cur->id, cur->visit + 1, cur->plan.n, payload);
        if (!send_message(session, CONFIG_FEEDER_URI_PATH, payload, (size_t)len)) {
            ESP_LOGW(TAG, "Send failed, will rebuild the session and resend this visit");
            s_reconnect = true;            /* the scan stays pending and is resent */
            continue;
        }
        coap_io_process(ctx, 300);         /* let DTLS/CoAP flush and read the reply */

        has_pending = false;               /* this scan is done */
        cur->visit++;
        if (cur->visit >= cur->plan.n) {   /* last visit of the day: THIS cow's day ends */
            date_next_day(date);           /* only this cow moves to the next day */
            cur->plan_ready = false;
            ESP_LOGI(TAG, "Cow %s: day over, her next day is %04d-%02d-%02d",
                     cur->id, date->y, date->m, date->d);
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
    rfid_init();
    xTaskCreate(coap_task, "coap_task", 8192, NULL, 5, NULL);
}