const functions = require("firebase-functions");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");
const {defineString} = require("firebase-functions/params");

admin.initializeApp();

/**
 * FIRMS API (v4+) MAP_KEY ister.
 * Endpoint formatı (Area):
 * /api/area/csv/[MAP_KEY]/[SOURCE]/[AREA_COORDS|world]/[DAY_RANGE]/[DATE?]
 */

// Params (functions.config yerine)
const FIRMS_MAP_KEY = defineString("FIRMS_MAP_KEY");
const FIRMS_SOURCE = defineString("FIRMS_SOURCE");
const FIRMS_AREA = defineString("FIRMS_AREA");
const FIRMS_DAY_RANGE = defineString("FIRMS_DAY_RANGE");
const FIRMS_DATE = defineString("FIRMS_DATE");

// Bu değişken en son görülen yangın sayısını tutar.
// (Cold start olursa sıfırlanır.)
let lastFireCount = 0;

/**
 * Builds FIRMS URL from params.
 * @return {string} FIRMS API URL
 */
function buildFirmsUrl() {
  const mapKey = FIRMS_MAP_KEY.value();
  const source = FIRMS_SOURCE.value() || "MODIS_NRT";
  const area = FIRMS_AREA.value() || "world";
  const dayRange = FIRMS_DAY_RANGE.value() || "1";
  const date = FIRMS_DATE.value() || "";

  if (!mapKey) {
    throw new Error(
        "FIRMS_MAP_KEY missing. Set it in functions/.env.<projectId>.",
    );
  }

  const base = "https://firms.modaps.eosdis.nasa.gov/api/area/csv";
  const parts = [base, encodeURIComponent(mapKey), source, area, dayRange];

  if (date) {
    parts.push(date);
  }

  return parts.join("/");
}

exports.checkFires = functions.pubsub
    .schedule("every 10 minutes")
    .timeZone("Europe/Istanbul")
    .onRun(async () => {
      logger.info("⏰ Yangın kontrolü başlatıldı...");

      let url = "";
      try {
        url = buildFirmsUrl();
        logger.info("FIRMS URL hazır.", {source: FIRMS_SOURCE.value()});

        const response = await fetch(url, {
          headers: {
            "User-Agent": "FireSafetyApp-FirebaseFunction",
          },
        });

        const text = await response.text();

        if (!response.ok) {
          logger.error("❌ FIRMS HTTP hatası", {
            status: response.status,
            statusText: response.statusText,
            body: text.slice(0, 500),
          });
          return null;
        }

        const lines = text.split("\n").slice(1); // header atla
        const fires = [];

        for (const line of lines) {
          if (!line.trim()) continue;

          const cols = line.split(",");
          if (cols.length < 2) continue;

          const lat = Number.parseFloat(cols[0]);
          const lon = Number.parseFloat(cols[1]);

          if (Number.isNaN(lat) || Number.isNaN(lon)) continue;

          // Türkiye koordinat aralığı (yaklaşık filtre)
          if (lat >= 36 && lat <= 42 && lon >= 26 && lon <= 45) {
            fires.push({lat, lon});
          }
        }

        logger.info("🔥 Türkiye'de bulunan yangın sayısı", {
          count: fires.length,
        });

        if (fires.length > lastFireCount) {
          const message = {
            notification: {
              title: "🔥 Yeni Yangın Tespit Edildi!",
              body: `Türkiye'de ${fires.length} aktif yangın var.`,
            },
            topic: "fires",
          };

          await admin.messaging().send(message);
          logger.info("📩 Bildirim gönderildi!");
        }

        lastFireCount = fires.length;
        return null;
      } catch (err) {
        logger.error("❌ checkFires exception", {
          error: String(err),
          url,
        });
        return null;
      }
    });
