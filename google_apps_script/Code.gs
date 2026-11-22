/**
 * Google Apps Script Web App untuk Spreadsheet "Data Game DOS"
 * Struktur Sederhana — HANYA 5 Sheet Inti:
 *   1. PreTest    : No | Nama | Absen | Kelas | Game 1..5 | Rata-rata
 *   2. PostTest   : No | Nama | Absen | Kelas | Game 1..5 | Rata-rata
 *   3. Rekap      : Perbandingan otomatis Pre-Test vs Post-Test + Selisih (Gain)
 *   4. LogJawaban : Riwayat detail jawaban tiap soal (dengan kolom Mode)
 *   5. Config     : Pengaturan Mode Aktif, Spill Hasil, Materi, & PIN Admin
 *
 * Cara Update:
 * 1. Tempel seluruh kode ini di Spreadsheet -> Ekstensi -> Apps Script -> Simpan (Ctrl+S).
 * 2. Pilih fungsi "rapikanSpreadsheet" -> klik Run (1x saja) untuk memindahkan data lama,
 *    merapikan LogJawaban & Config, serta menghapus sheet-sheet lama.
 * 3. Deploy -> Manage deployments -> Edit -> Version: New version -> Deploy.
 */

var CACHE_KEY_PREFIX = "dos_lb_v5_";
var CACHE_TTL_SECONDS = 12;

var DEFAULT_CONFIG = {
  active_mode: "PRETEST",
  reveal_pretest_results: false,
  reveal_posttest_results: false,
  allow_materi_pretest: false,
  allow_materi_posttest: false,
  admin_pin: "6767"
};

var LEGACY_SHEETS_TO_CLEAN = [
  "PPLGA", "PPLGB", "HasilKeseluruhan", "LeaderBoard",
  "PreTest_PPLGA", "PreTest_PPLGB", "PreTest_Hasil", "PreTest_LeaderBoard",
  "PostTest_PPLGA", "PostTest_PPLGB", "PostTest_Hasil", "PostTest_LeaderBoard",
  "Rekap_PreVsPost"
];

function onOpen() {
  try {
    SpreadsheetApp.getUi()
      .createMenu("DOS Rescue")
      .addItem("Rapikan & Bersihkan Sheet Lama (5 Sheet)", "rapikanSpreadsheet")
      .addItem("Sinkron Semua Sheet", "syncSemuaSheet")
      .addItem("Set Mode: PRE-TEST", "menuSetPretest")
      .addItem("Set Mode: POST-TEST", "menuSetPosttest")
      .addToUi();
  } catch (_err) {}
}

function menuSetPretest() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  writeConfigValues_(ss, { active_mode: "PRETEST" });
  syncSemuaSheet();
}

function menuSetPosttest() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  writeConfigValues_(ss, { active_mode: "POSTTEST" });
  syncSemuaSheet();
}

function onEdit(e) {
  try {
    if (!e || !e.range) return;
    var name = e.range.getSheet().getName();
    if (name !== "PreTest" && name !== "PostTest" && name !== "Config") return;
    clearAllCaches_();
    var ss = e.source || SpreadsheetApp.getActiveSpreadsheet();
    SpreadsheetApp.flush();
    syncAllModes_(ss);
  } catch (_err) {}
}

/**
 * Jalankan 1x dari editor Apps Script (tombol Run):
 * - Membuat 5 sheet bersih (PreTest, PostTest, Rekap, LogJawaban, Config)
 * - Memindahkan seluruh data siswa dari sheet lama ke PreTest/PostTest tanpa duplikat
 * - Menambahkan kolom Mode pada LogJawaban lama bila belum ada
 * - Merapikan Config & meng-upgrade PIN default lama (2026) ke PIN baru
 * - Menghapus semua sheet lama yang tidak dibutuhkan
 */
function rapikanSpreadsheet() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  clearAllCaches_();

  ensureModeSheet_(ss, "PreTest");
  ensureModeSheet_(ss, "PostTest");
  ensureRekapSheet_(ss);
  upgradeLogSheetIfNeeded_(ss);
  cleanAndUpgradeConfigSheet_(ss);

  var migrated = migrateLegacyData_(ss);
  SpreadsheetApp.flush();

  var deleted = [];
  for (var i = 0; i < LEGACY_SHEETS_TO_CLEAN.length; i++) {
    var oldSheet = ss.getSheetByName(LEGACY_SHEETS_TO_CLEAN[i]);
    if (oldSheet && ss.getSheets().length > 1) {
      ss.deleteSheet(oldSheet);
      deleted.push(LEGACY_SHEETS_TO_CLEAN[i]);
    }
  }

  var order = ["PreTest", "PostTest", "Rekap", "LogJawaban", "Config"];
  for (var j = 0; j < order.length; j++) {
    var sh = ss.getSheetByName(order[j]);
    if (sh) {
      ss.setActiveSheet(sh);
      ss.moveActiveSheet(j + 1);
    }
  }
  var firstSh = ss.getSheetByName("PreTest");
  if (firstSh) ss.setActiveSheet(firstSh);

  SpreadsheetApp.flush();
  var out = syncAllModes_(ss);
  return {
    ok: true,
    migrated_rows: migrated,
    deleted_sheets: deleted,
    pretest_total: out.pretest.overall_list.length,
    posttest_total: out.posttest.overall_list.length
  };
}

function syncSemuaSheet() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  clearAllCaches_();
  bootstrapIfMissing_(ss);
  var out = syncAllModes_(ss);
  return {
    ok: true,
    active_mode: out.config.active_mode,
    pretest_total: out.pretest.overall_list.length,
    posttest_total: out.posttest.overall_list.length
  };
}

/**
 * Jika pengguna langsung Deploy tanpa sempat klik Run "rapikanSpreadsheet",
 * fungsi ini otomatis membuat sheet inti & menyalin data lama 1x agar peringkat tidak kosong.
 */
function bootstrapIfMissing_(ss) {
  var hadPre = !!ss.getSheetByName("PreTest");
  ensureModeSheet_(ss, "PreTest");
  ensureModeSheet_(ss, "PostTest");
  ensureRekapSheet_(ss);
  ensureLogSheet_(ss);
  ensureConfigSheet_(ss);
  if (!hadPre) {
    migrateLegacyData_(ss);
    SpreadsheetApp.flush();
    syncAllModes_(ss);
  }
}

function doGet(e) {
  try {
    var params = (e && e.parameter) ? e.parameter : {};
    var action = String(params.action || "leaderboard").trim().toLowerCase();
    var nama = String(params.nama || "").trim();
    var absen = normalizeAbsen_(params.absen);
    var kelas = String(params.kelas || "").trim();
    var ss = SpreadsheetApp.getActiveSpreadsheet();

    bootstrapIfMissing_(ss);
    var cfg = readConfig_(ss);
    var reqMode = normalizeMode_(params.mode || cfg.active_mode);

    if (action === "public_config") {
      return jsonOut_({
        ok: true,
        config: sanitizePublicConfig_(cfg)
      });
    }

    if (action === "check_student") {
      var checkRes = checkStudentAlreadyUsed_(ss, nama, absen, kelas, reqMode);
      checkRes.config = sanitizePublicConfig_(cfg);
      return jsonOut_(checkRes);
    }

    if (action === "admin_dashboard") {
      var pin = String(params.pin || "").trim();
      if (!verifyAdminPin_(cfg, pin)) {
        return jsonOut_({ ok: false, unauthorized: true, error: "PIN Admin salah." });
      }
      var preSnap = buildModeSnapshot_(ss, "PRETEST");
      var postSnap = buildModeSnapshot_(ss, "POSTTEST");
      return jsonOut_({
        ok: true,
        updated_at: new Date().toISOString(),
        config: sanitizePublicConfig_(cfg),
        pretest: preSnap,
        posttest: postSnap,
        comparison: buildPrePostComparison_(preSnap, postSnap),
        recent_logs: readRecentLogs_(ss, 200)
      });
    }

    // Leaderboard untuk siswa (menghormati saklar Spill Admin)
    var snap = getModeSnapshot_(ss, reqMode);
    var revealed = isModeRevealed_(cfg, reqMode);
    var myInfo = findPersonalRank_(snap, nama, absen, kelas);

    if (!revealed) {
      return jsonOut_({
        ok: true,
        mode: reqMode,
        revealed: false,
        config: sanitizePublicConfig_(cfg),
        updated_at: snap.updated_at,
        total_overall: snap.overall_list.length,
        total_pplga: snap.pplga_list.length,
        total_pplgb: snap.pplgb_list.length,
        overall_top10: [],
        pplga_top10: [],
        pplgb_top10: [],
        used_students: {
          "PPLG A": extractUsedKeys_(snap.pplga_list),
          "PPLG B": extractUsedKeys_(snap.pplgb_list)
        },
        my_info: {
          found: myInfo.found,
          revealed: false,
          kelas: myInfo.kelas || ""
        },
        message: "Nilai & peringkat " + modeLabel_(reqMode) + " belum dibuka oleh Admin."
      });
    }

    return jsonOut_({
      ok: true,
      mode: reqMode,
      revealed: true,
      config: sanitizePublicConfig_(cfg),
      updated_at: snap.updated_at,
      total_overall: snap.overall_list.length,
      total_pplga: snap.pplga_list.length,
      total_pplgb: snap.pplgb_list.length,
      overall_top10: snap.overall_list.slice(0, 10),
      pplga_top10: snap.pplga_list.slice(0, 10),
      pplgb_top10: snap.pplgb_list.slice(0, 10),
      used_students: {
        "PPLG A": extractUsedKeys_(snap.pplga_list),
        "PPLG B": extractUsedKeys_(snap.pplgb_list)
      },
      my_info: myInfo
    });
  } catch (err) {
    return jsonOut_({ ok: false, error: String(err) });
  }
}

function doPost(e) {
  var lock = LockService.getScriptLock();
  lock.waitLock(15000);
  try {
    var raw = (e && e.postData && e.postData.contents) ? e.postData.contents : "{}";
    var data = JSON.parse(raw);
    var ss = SpreadsheetApp.getActiveSpreadsheet();
    bootstrapIfMissing_(ss);
    var cfg = readConfig_(ss);
    var ev = String(data.event || "").trim();

    // --- AKSI ADMIN ---
    if (ev === "ADMIN_UPDATE_CONFIG") {
      if (!verifyAdminPin_(cfg, String(data.pin || "").trim())) {
        return jsonOut_({ ok: false, unauthorized: true, error: "PIN Admin salah." });
      }
      var patch = {};
      if (data.active_mode !== undefined) patch.active_mode = normalizeMode_(data.active_mode);
      if (data.reveal_pretest_results !== undefined) patch.reveal_pretest_results = toBool_(data.reveal_pretest_results);
      if (data.reveal_posttest_results !== undefined) patch.reveal_posttest_results = toBool_(data.reveal_posttest_results);
      if (data.allow_materi_pretest !== undefined) patch.allow_materi_pretest = toBool_(data.allow_materi_pretest);
      if (data.allow_materi_posttest !== undefined) patch.allow_materi_posttest = toBool_(data.allow_materi_posttest);
      if (data.new_pin !== undefined && String(data.new_pin).trim().length >= 4) {
        patch.admin_pin = String(data.new_pin).trim();
      }
      var updatedCfg = writeConfigValues_(ss, patch);
      clearAllCaches_();
      syncAllModes_(ss);
      return jsonOut_({ ok: true, event: ev, config: sanitizePublicConfig_(updatedCfg) });
    }

    if (ev === "ADMIN_RESET_STUDENT") {
      if (!verifyAdminPin_(cfg, String(data.pin || "").trim())) {
        return jsonOut_({ ok: false, unauthorized: true, error: "PIN Admin salah." });
      }
      var targetMode = normalizeMode_(data.mode || cfg.active_mode);
      var removed = deleteStudentRow_(ss, String(data.nama || ""), normalizeAbsen_(data.absen), String(data.kelas || ""), targetMode);
      clearAllCaches_();
      SpreadsheetApp.flush();
      syncAllModes_(ss);
      return jsonOut_({
        ok: true,
        event: ev,
        removed: removed,
        mode: targetMode,
        message: removed
          ? ("Data " + modeLabel_(targetMode) + " untuk " + String(data.nama || "") + " berhasil direset.")
          : "Baris siswa tidak ditemukan pada sheet " + getModeSheetName_(targetMode) + "."
      });
    }

    if (ev === "ADMIN_SYNC_ALL") {
      if (!verifyAdminPin_(cfg, String(data.pin || "").trim())) {
        return jsonOut_({ ok: false, unauthorized: true, error: "PIN Admin salah." });
      }
      clearAllCaches_();
      syncAllModes_(ss);
      return jsonOut_({ ok: true, event: ev });
    }

    // --- AKSI SISWA ---
    var fallbackMode = cfg.active_mode;
    if (ev === "BATCH_SYNC" && Array.isArray(data.items)) {
      var latestSummary = null;
      var logItems = [];
      for (var i = 0; i < data.items.length; i++) {
        var item = data.items[i] || {};
        if (!item.test_mode) item.test_mode = fallbackMode;
        if (item.event === "LEVEL_LOG") logItems.push(item);
        latestSummary = item;
      }
      if (logItems.length > 0) appendAnswerLogsBatch_(ss, logItems, fallbackMode);
      if (latestSummary) upsertModeRow_(ss, latestSummary, normalizeMode_(latestSummary.test_mode || fallbackMode));
    } else {
      var itemMode = normalizeMode_(data.test_mode || fallbackMode);
      data.test_mode = itemMode;
      if (ev === "LEVEL_LOG") {
        appendAnswerLogsBatch_(ss, [data], itemMode);
        upsertModeRow_(ss, data, itemMode);
      } else if (ev === "SESSION_START" || ev === "SESSION_FINISH" || ev === "SESSION_SYNC") {
        upsertModeRow_(ss, data, itemMode);
      }
    }

    SpreadsheetApp.flush();
    clearAllCaches_();
    syncAllModes_(ss);

    return jsonOut_({ ok: true, event: ev || "unknown", active_mode: cfg.active_mode });
  } catch (err) {
    return jsonOut_({ ok: false, error: String(err) });
  } finally {
    lock.releaseLock();
  }
}

/* ========================= HELPERS ========================= */

function jsonOut_(obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}

function normalizeMode_(raw) {
  var s = String(raw || "").toUpperCase().replace(/[^A-Z]/g, "");
  return (s === "POSTTEST") ? "POSTTEST" : "PRETEST";
}

function modeLabel_(mode) {
  return (normalizeMode_(mode) === "POSTTEST") ? "POST-TEST" : "PRE-TEST";
}

function getModeSheetName_(mode) {
  return (normalizeMode_(mode) === "POSTTEST") ? "PostTest" : "PreTest";
}

function normalizeClassLabel_(kelas) {
  var s = String(kelas || "").toUpperCase().replace(/\s+/g, "");
  return (s === "PPLGB") ? "PPLG B" : "PPLG A";
}

function normalizeAbsen_(v) {
  var s = String(v == null ? "" : v).trim();
  if (/^\d+$/.test(s)) return String(Number(s));
  return s;
}

function toBool_(v) {
  if (typeof v === "boolean") return v;
  var s = String(v || "").trim().toUpperCase();
  return (s === "TRUE" || s === "1" || s === "YES" || s === "ON");
}

function isModeRevealed_(cfg, mode) {
  return (normalizeMode_(mode) === "POSTTEST") ? !!cfg.reveal_posttest_results : !!cfg.reveal_pretest_results;
}

function verifyAdminPin_(cfg, pin) {
  var expected = String(cfg.admin_pin || DEFAULT_CONFIG.admin_pin).trim();
  return pin !== "" && pin === expected;
}

function sanitizePublicConfig_(cfg) {
  return {
    active_mode: normalizeMode_(cfg.active_mode),
    reveal_pretest_results: !!cfg.reveal_pretest_results,
    reveal_posttest_results: !!cfg.reveal_posttest_results,
    allow_materi_pretest: !!cfg.allow_materi_pretest,
    allow_materi_posttest: !!cfg.allow_materi_posttest
  };
}

function clearAllCaches_() {
  var cache = CacheService.getScriptCache();
  cache.remove(CACHE_KEY_PREFIX + "PRETEST");
  cache.remove(CACHE_KEY_PREFIX + "POSTTEST");
}

/* ========================= SHEET SETUP ========================= */

function styleHeaderRow_(sheet, colCount) {
  try {
    sheet.setFrozenRows(1);
    sheet.getRange(1, 1, 1, colCount).setFontWeight("bold");
  } catch (_e) {}
}

function ensureConfigSheet_(ss) {
  var sheet = ss.getSheetByName("Config");
  if (!sheet) {
    sheet = ss.insertSheet("Config");
    sheet.appendRow(["Key", "Value", "Keterangan"]);
    sheet.appendRow(["active_mode", DEFAULT_CONFIG.active_mode, "Mode aktif: PRETEST atau POSTTEST"]);
    sheet.appendRow(["reveal_pretest_results", "FALSE", "TRUE = nilai & peringkat Pre-Test dibuka ke siswa"]);
    sheet.appendRow(["reveal_posttest_results", "FALSE", "TRUE = nilai & peringkat Post-Test dibuka ke siswa"]);
    sheet.appendRow(["allow_materi_pretest", "FALSE", "TRUE = tombol Buku Materi dibuka saat Pre-Test"]);
    sheet.appendRow(["allow_materi_posttest", "FALSE", "TRUE = tombol Buku Materi dibuka saat Post-Test"]);
    sheet.appendRow(["admin_pin", DEFAULT_CONFIG.admin_pin, "PIN Dashboard Admin"]);
    sheet.getRange(7, 2).setNumberFormat("@").setValue(DEFAULT_CONFIG.admin_pin);
    styleHeaderRow_(sheet, 3);
  }
  return sheet;
}

function cleanAndUpgradeConfigSheet_(ss) {
  var cfg = readConfig_(ss);
  var pinNow = String(cfg.admin_pin || "").trim();
  if (!pinNow || pinNow === "2026") {
    pinNow = DEFAULT_CONFIG.admin_pin;
  }
  var sheet = ensureConfigSheet_(ss);
  sheet.clearContents();
  var rows = [
    ["Key", "Value", "Keterangan"],
    ["active_mode", normalizeMode_(cfg.active_mode), "Mode aktif: PRETEST atau POSTTEST"],
    ["reveal_pretest_results", cfg.reveal_pretest_results ? "TRUE" : "FALSE", "TRUE = nilai & peringkat Pre-Test dibuka ke siswa"],
    ["reveal_posttest_results", cfg.reveal_posttest_results ? "TRUE" : "FALSE", "TRUE = nilai & peringkat Post-Test dibuka ke siswa"],
    ["allow_materi_pretest", cfg.allow_materi_pretest ? "TRUE" : "FALSE", "TRUE = tombol Buku Materi dibuka saat Pre-Test"],
    ["allow_materi_posttest", cfg.allow_materi_posttest ? "TRUE" : "FALSE", "TRUE = tombol Buku Materi dibuka saat Post-Test"],
    ["admin_pin", pinNow, "PIN Dashboard Admin"]
  ];
  sheet.getRange(1, 1, rows.length, 3).setValues(rows);
  sheet.getRange(7, 2).setNumberFormat("@").setValue(pinNow);
  styleHeaderRow_(sheet, 3);
}

function ensureModeSheet_(ss, sheetName) {
  var sheet = ss.getSheetByName(sheetName);
  if (!sheet) {
    sheet = ss.insertSheet(sheetName);
    sheet.appendRow(["No", "Nama", "Absen", "Kelas", "Game 1", "Game 2", "Game 3", "Game 4", "Game 5", "Rata-rata"]);
    styleHeaderRow_(sheet, 10);
  } else if (sheet.getLastRow() < 1) {
    sheet.appendRow(["No", "Nama", "Absen", "Kelas", "Game 1", "Game 2", "Game 3", "Game 4", "Game 5", "Rata-rata"]);
    styleHeaderRow_(sheet, 10);
  }
  return sheet;
}

function ensureRekapSheet_(ss) {
  var sheet = ss.getSheetByName("Rekap");
  if (!sheet) {
    sheet = ss.insertSheet("Rekap");
    sheet.appendRow(["No", "Nama", "Absen", "Kelas", "Pre-Test", "Post-Test", "Selisih"]);
    styleHeaderRow_(sheet, 7);
  } else if (sheet.getLastRow() < 1) {
    sheet.appendRow(["No", "Nama", "Absen", "Kelas", "Pre-Test", "Post-Test", "Selisih"]);
    styleHeaderRow_(sheet, 7);
  }
  return sheet;
}

function ensureLogSheet_(ss) {
  var sheet = ss.getSheetByName("LogJawaban");
  if (!sheet) {
    sheet = ss.insertSheet("LogJawaban");
    sheet.appendRow([
      "Timestamp", "Session_ID", "Mode", "Nama", "Kelas", "Absen",
      "Minigame_ID", "Level_ID", "Jawaban_Siswa", "Kunci_Jawaban",
      "Hasil", "Percobaan_Ke", "Poin", "Durasi_Detik"
    ]);
    styleHeaderRow_(sheet, 14);
  }
  return sheet;
}

function upgradeLogSheetIfNeeded_(ss) {
  var sheet = ensureLogSheet_(ss);
  var h3 = String(sheet.getRange(1, 3).getValue() || "").trim();
  if (h3 !== "Mode") {
    sheet.insertColumnBefore(3);
    sheet.getRange(1, 3).setValue("Mode");
    var lastRow = sheet.getLastRow();
    if (lastRow >= 2) {
      var names = sheet.getRange(2, 4, lastRow - 1, 1).getValues();
      var modes = [];
      var cleanedNames = [];
      for (var i = 0; i < names.length; i++) {
        var nm = String(names[i][0] || "");
        if (nm.indexOf("[POSTTEST] ") === 0) {
          modes.push(["POSTTEST"]);
          cleanedNames.push([nm.substring(11)]);
        } else if (nm.indexOf("[PRETEST] ") === 0) {
          modes.push(["PRETEST"]);
          cleanedNames.push([nm.substring(10)]);
        } else {
          modes.push(["PRETEST"]);
          cleanedNames.push([nm]);
        }
      }
      sheet.getRange(2, 3, modes.length, 1).setValues(modes);
      sheet.getRange(2, 4, cleanedNames.length, 1).setValues(cleanedNames);
    }
    styleHeaderRow_(sheet, 14);
  }
  return sheet;
}

function readConfig_(ss) {
  var sheet = ensureConfigSheet_(ss);
  var out = {
    active_mode: DEFAULT_CONFIG.active_mode,
    reveal_pretest_results: DEFAULT_CONFIG.reveal_pretest_results,
    reveal_posttest_results: DEFAULT_CONFIG.reveal_posttest_results,
    allow_materi_pretest: DEFAULT_CONFIG.allow_materi_pretest,
    allow_materi_posttest: DEFAULT_CONFIG.allow_materi_posttest,
    admin_pin: DEFAULT_CONFIG.admin_pin
  };
  var lastRow = sheet.getLastRow();
  if (lastRow < 2) return out;
  var vals = sheet.getRange(2, 1, lastRow - 1, 2).getValues();
  for (var i = 0; i < vals.length; i++) {
    var k = String(vals[i][0] || "").trim();
    var v = vals[i][1];
    if (k === "active_mode") out.active_mode = normalizeMode_(v);
    else if (k === "reveal_pretest_results") out.reveal_pretest_results = toBool_(v);
    else if (k === "reveal_posttest_results") out.reveal_posttest_results = toBool_(v);
    else if (k === "allow_materi_pretest") out.allow_materi_pretest = toBool_(v);
    else if (k === "allow_materi_posttest") out.allow_materi_posttest = toBool_(v);
    else if (k === "admin_pin" && String(v == null ? "" : v).trim() !== "") out.admin_pin = String(v).trim();
  }
  return out;
}

function writeConfigValues_(ss, patch) {
  var sheet = ensureConfigSheet_(ss);
  var keys = Object.keys(patch);
  var lastRow = sheet.getLastRow();
  var keyToRow = {};
  if (lastRow >= 2) {
    var colA = sheet.getRange(2, 1, lastRow - 1, 1).getValues();
    for (var i = 0; i < colA.length; i++) {
      var rk = String(colA[i][0] || "").trim();
      if (rk) keyToRow[rk] = i + 2;
    }
  }
  for (var j = 0; j < keys.length; j++) {
    var k = keys[j];
    var rawV = patch[k];
    var storeV = (typeof rawV === "boolean") ? (rawV ? "TRUE" : "FALSE") : String(rawV);
    if (keyToRow[k]) {
      var cell = sheet.getRange(keyToRow[k], 2);
      if (k === "admin_pin") cell.setNumberFormat("@");
      cell.setValue(storeV);
    } else {
      sheet.appendRow([k, storeV, ""]);
      if (k === "admin_pin") sheet.getRange(sheet.getLastRow(), 2).setNumberFormat("@").setValue(storeV);
    }
  }
  SpreadsheetApp.flush();
  return readConfig_(ss);
}

/* ========================= DATA OPERATIONS ========================= */

function migrateLegacyData_(ss) {
  var sources = [
    { name: "PPLGA", kelas: "PPLG A", mode: "PRETEST" },
    { name: "PPLGB", kelas: "PPLG B", mode: "PRETEST" },
    { name: "PreTest_PPLGA", kelas: "PPLG A", mode: "PRETEST" },
    { name: "PreTest_PPLGB", kelas: "PPLG B", mode: "PRETEST" },
    { name: "PostTest_PPLGA", kelas: "PPLG A", mode: "POSTTEST" },
    { name: "PostTest_PPLGB", kelas: "PPLG B", mode: "POSTTEST" }
  ];
  var count = 0;
  for (var s = 0; s < sources.length; s++) {
    var src = ss.getSheetByName(sources[s].name);
    if (!src || src.getLastRow() < 2) continue;
    var rows = src.getRange(2, 2, src.getLastRow() - 1, 7).getValues(); // B..H (sheet lama)
    for (var i = 0; i < rows.length; i++) {
      var rNama = String(rows[i][0] || "").trim();
      if (!rNama) continue;
      upsertModeRow_(ss, {
        nama: rNama,
        absen: normalizeAbsen_(rows[i][1]),
        kelas: sources[s].kelas,
        skor_mg1: rows[i][2],
        skor_mg2: rows[i][3],
        skor_mg3: rows[i][4],
        skor_mg4: rows[i][5],
        skor_mg5: rows[i][6]
      }, sources[s].mode);
      count++;
    }
  }
  return count;
}

function upsertModeRow_(ss, data, mode) {
  var nama = String(data.nama || "").trim();
  if (!nama) return;
  var absen = normalizeAbsen_(data.absen);
  var kelas = normalizeClassLabel_(data.kelas);
  var sheet = ensureModeSheet_(ss, getModeSheetName_(mode));

  var lastRow = sheet.getLastRow();
  var targetRow = -1;
  var existingScores = ["", "", "", "", ""];

  if (lastRow >= 2) {
    var rows = sheet.getRange(2, 2, lastRow - 1, 8).getValues(); // B..I (Nama, Absen, Kelas, G1..G5)
    var namaLow = nama.toLowerCase();
    for (var i = 0; i < rows.length; i++) {
      var rNama = String(rows[i][0] || "").trim().toLowerCase();
      var rAbsen = normalizeAbsen_(rows[i][1]);
      var rKelas = normalizeClassLabel_(rows[i][2]);
      if (!rNama) {
        if (targetRow === -1) targetRow = i + 2;
        continue;
      }
      if (rKelas === kelas && (rNama === namaLow || (absen !== "" && rAbsen === absen))) {
        targetRow = i + 2;
        existingScores = [rows[i][3], rows[i][4], rows[i][5], rows[i][6], rows[i][7]];
        if (!absen && rAbsen) absen = rAbsen;
        break;
      }
    }
    if (targetRow === -1) targetRow = lastRow + 1;
  } else {
    targetRow = 2;
  }

  var incoming = [data.skor_mg1, data.skor_mg2, data.skor_mg3, data.skor_mg4, data.skor_mg5];
  var finalScores = [];
  var sumNum = 0;
  for (var g = 0; g < 5; g++) {
    var inc = incoming[g];
    var val = "";
    if (inc !== undefined && inc !== null && inc !== "") {
      var incNum = Number(inc);
      var hasEx = (existingScores[g] !== "" && existingScores[g] !== null && existingScores[g] !== undefined);
      var curNum = hasEx ? Number(existingScores[g]) : 0;
      if (!isNaN(incNum) && incNum > 0) val = Math.max(isNaN(curNum) ? 0 : curNum, incNum);
      else if (hasEx) val = existingScores[g];
      else val = 0;
    } else if (existingScores[g] !== "" && existingScores[g] !== null && existingScores[g] !== undefined) {
      val = existingScores[g];
    }
    finalScores.push(val);
    sumNum += (val === "" || isNaN(Number(val))) ? 0 : Number(val);
  }
  var avgNum = Math.round((sumNum / 5) * 100) / 100;

  sheet.getRange(targetRow, 1, 1, 10).setValues([[
    targetRow - 1,
    nama,
    absen === "" ? "" : (/^\d+$/.test(absen) ? Number(absen) : absen),
    kelas,
    finalScores[0],
    finalScores[1],
    finalScores[2],
    finalScores[3],
    finalScores[4],
    avgNum
  ]]);
}

function normalizeModeSheetNumbers_(sheet) {
  if (!sheet || sheet.getLastRow() < 2) return;
  var count = sheet.getLastRow() - 1;
  var vals = sheet.getRange(2, 2, count, 8).getValues(); // B..I
  var colA = [];
  var colJ = [];
  var num = 0;
  for (var i = 0; i < vals.length; i++) {
    var nama = String(vals[i][0] || "").trim();
    if (!nama) {
      colA.push([""]);
      colJ.push([""]);
      continue;
    }
    num++;
    var sum = 0;
    for (var g = 3; g <= 7; g++) {
      var v = vals[i][g];
      sum += (v === "" || v === null || v === undefined || isNaN(Number(v))) ? 0 : Number(v);
    }
    colA.push([num]);
    colJ.push([Math.round((sum / 5) * 100) / 100]);
  }
  sheet.getRange(2, 1, count, 1).setValues(colA);
  sheet.getRange(2, 10, count, 1).setValues(colJ);
}

function deleteStudentRow_(ss, nama, absen, kelas, mode) {
  var sheet = ss.getSheetByName(getModeSheetName_(mode));
  if (!sheet || sheet.getLastRow() < 2) return false;
  var targetNama = String(nama || "").trim().toLowerCase();
  var targetAbsen = normalizeAbsen_(absen);
  var targetKelas = normalizeClassLabel_(kelas);
  var rows = sheet.getRange(2, 2, sheet.getLastRow() - 1, 3).getValues(); // B..D
  var removed = false;
  for (var i = rows.length - 1; i >= 0; i--) {
    var rNama = String(rows[i][0] || "").trim().toLowerCase();
    var rAbsen = normalizeAbsen_(rows[i][1]);
    var rKelas = normalizeClassLabel_(rows[i][2]);
    if (!rNama || rKelas !== targetKelas) continue;
    if ((targetNama && rNama === targetNama) || (targetAbsen !== "" && rAbsen === targetAbsen)) {
      sheet.deleteRow(i + 2);
      removed = true;
    }
  }
  return removed;
}

function checkStudentAlreadyUsed_(ss, nama, absen, kelas, mode) {
  var sheet = ss.getSheetByName(getModeSheetName_(mode));
  var kelasLabel = normalizeClassLabel_(kelas);
  var targetNama = String(nama || "").trim().toLowerCase();
  var targetAbsen = normalizeAbsen_(absen);
  var exists = false;
  var matchedNama = nama;
  var matchedAbsen = absen;

  if (sheet && targetNama && sheet.getLastRow() >= 2) {
    var rows = sheet.getRange(2, 2, sheet.getLastRow() - 1, 3).getValues(); // B..D
    for (var i = 0; i < rows.length; i++) {
      var rNama = String(rows[i][0] || "").trim();
      var rAbsen = normalizeAbsen_(rows[i][1]);
      var rKelas = normalizeClassLabel_(rows[i][2]);
      if (!rNama || rKelas !== kelasLabel) continue;
      if (rNama.toLowerCase() === targetNama || (targetAbsen !== "" && rAbsen === targetAbsen)) {
        exists = true;
        matchedNama = rNama;
        matchedAbsen = rAbsen;
        break;
      }
    }
  }

  return {
    ok: true,
    mode: normalizeMode_(mode),
    exists: exists,
    allowed: !exists,
    nama: matchedNama,
    absen: matchedAbsen,
    kelas: kelasLabel,
    message: exists
      ? ("Nama \"" + matchedNama + "\" (Absen " + matchedAbsen + ") sudah dipakai untuk " + modeLabel_(mode) + ". Hubungi guru jika ingin mengulang.")
      : ("Nama tersedia untuk " + modeLabel_(mode) + ".")
  };
}

/* ========================= SYNC & RANKING ========================= */

function syncAllModes_(ss) {
  var cfg = readConfig_(ss);
  normalizeModeSheetNumbers_(ensureModeSheet_(ss, "PreTest"));
  normalizeModeSheetNumbers_(ensureModeSheet_(ss, "PostTest"));

  var preSnap = buildModeSnapshot_(ss, "PRETEST");
  var postSnap = buildModeSnapshot_(ss, "POSTTEST");
  syncRekapSheet_(ss, preSnap, postSnap);

  try {
    var cache = CacheService.getScriptCache();
    cache.put(CACHE_KEY_PREFIX + "PRETEST", JSON.stringify(preSnap), CACHE_TTL_SECONDS);
    cache.put(CACHE_KEY_PREFIX + "POSTTEST", JSON.stringify(postSnap), CACHE_TTL_SECONDS);
  } catch (_e) {}

  return { config: cfg, pretest: preSnap, posttest: postSnap };
}

function syncRekapSheet_(ss, preSnap, postSnap) {
  var comp = buildPrePostComparison_(preSnap, postSnap);
  var sheet = ensureRekapSheet_(ss);
  var clearN = Math.max(sheet.getLastRow() - 1, comp.length, 1);
  sheet.getRange(2, 1, clearN, 7).clearContent();
  if (comp.length > 0) {
    var rows = [];
    for (var i = 0; i < comp.length; i++) {
      var c = comp[i];
      rows.push([
        i + 1,
        c.nama,
        c.absen === "" ? "" : (/^\d+$/.test(c.absen) ? Number(c.absen) : c.absen),
        c.kelas,
        c.pre_done ? c.pre_avg : "",
        c.post_done ? c.post_avg : "",
        (c.pre_done && c.post_done) ? c.gain : ""
      ]);
    }
    sheet.getRange(2, 1, rows.length, 7).setValues(rows);
  }
}

function getModeSnapshot_(ss, mode) {
  var m = normalizeMode_(mode);
  var cacheKey = CACHE_KEY_PREFIX + m;
  var cache = CacheService.getScriptCache();
  var cached = cache.get(cacheKey);
  if (cached) {
    try { return JSON.parse(cached); } catch (_e) {}
  }
  var snap = buildModeSnapshot_(ss, m);
  try { cache.put(cacheKey, JSON.stringify(snap), CACHE_TTL_SECONDS); } catch (_e2) {}
  return snap;
}

function sortAndRankList_(list) {
  list.sort(function(a, b) {
    if (b.poin !== a.poin) return b.poin - a.poin;
    return a.nama.localeCompare(b.nama);
  });
  for (var i = 0; i < list.length; i++) {
    list[i].rank = i + 1;
  }
  return list;
}

function buildModeSnapshot_(ss, mode) {
  var m = normalizeMode_(mode);
  var sheet = ss.getSheetByName(getModeSheetName_(m));
  var overallList = [];
  var pplgaList = [];
  var pplgbList = [];

  if (sheet && sheet.getLastRow() >= 2) {
    var vals = sheet.getRange(2, 2, sheet.getLastRow() - 1, 9).getValues(); // B..J
    for (var i = 0; i < vals.length; i++) {
      var nama = String(vals[i][0] || "").trim();
      if (!nama) continue;
      var absen = normalizeAbsen_(vals[i][1]);
      var kelas = normalizeClassLabel_(vals[i][2]);
      var scores = [
        vals[i][3] === "" ? 0 : Number(vals[i][3]) || 0,
        vals[i][4] === "" ? 0 : Number(vals[i][4]) || 0,
        vals[i][5] === "" ? 0 : Number(vals[i][5]) || 0,
        vals[i][6] === "" ? 0 : Number(vals[i][6]) || 0,
        vals[i][7] === "" ? 0 : Number(vals[i][7]) || 0
      ];
      var avg = Math.round(((scores[0] + scores[1] + scores[2] + scores[3] + scores[4]) / 5) * 100) / 100;
      overallList.push({ rank: 0, nama: nama, absen: absen, kelas: kelas, poin: avg, scores: scores });
      var copy = { rank: 0, nama: nama, absen: absen, kelas: kelas, poin: avg, scores: scores.slice() };
      if (kelas === "PPLG B") pplgbList.push(copy);
      else pplgaList.push(copy);
    }
  }

  sortAndRankList_(overallList);
  sortAndRankList_(pplgaList);
  sortAndRankList_(pplgbList);

  return {
    mode: m,
    updated_at: new Date().toISOString(),
    overall_list: overallList,
    pplga_list: pplgaList,
    pplgb_list: pplgbList
  };
}

function buildPrePostComparison_(preSnap, postSnap) {
  var map = {};
  var keys = [];
  function upsertSide(list, isPost) {
    for (var i = 0; i < list.length; i++) {
      var it = list[i];
      var k = it.kelas + "|" + it.nama.toLowerCase();
      if (!map[k]) {
        map[k] = {
          nama: it.nama, absen: it.absen, kelas: it.kelas,
          pre_done: false, pre_avg: 0, pre_scores: [0, 0, 0, 0, 0],
          post_done: false, post_avg: 0, post_scores: [0, 0, 0, 0, 0],
          gain: 0
        };
        keys.push(k);
      }
      if (!isPost) {
        map[k].pre_done = true;
        map[k].pre_avg = it.poin;
        map[k].pre_scores = it.scores.slice();
      } else {
        map[k].post_done = true;
        map[k].post_avg = it.poin;
        map[k].post_scores = it.scores.slice();
      }
      if (!map[k].absen && it.absen) map[k].absen = it.absen;
    }
  }
  upsertSide(preSnap.overall_list || [], false);
  upsertSide(postSnap.overall_list || [], true);

  var out = [];
  for (var j = 0; j < keys.length; j++) {
    var rec = map[keys[j]];
    if (rec.pre_done && rec.post_done) {
      rec.gain = Math.round((rec.post_avg - rec.pre_avg) * 100) / 100;
    }
    out.push(rec);
  }
  out.sort(function(a, b) {
    if (a.kelas !== b.kelas) return a.kelas.localeCompare(b.kelas);
    var aa = Number(a.absen) || 999;
    var ba = Number(b.absen) || 999;
    if (aa !== ba) return aa - ba;
    return a.nama.localeCompare(b.nama);
  });
  return out;
}

function extractUsedKeys_(classList) {
  var out = [];
  for (var i = 0; i < classList.length; i++) {
    out.push({ nama: classList[i].nama, absen: classList[i].absen });
  }
  return out;
}

function findPersonalRank_(snap, nama, absen, kelas) {
  if (!nama) return { found: false };
  var keyName = nama.toLowerCase();
  var keyAbsen = normalizeAbsen_(absen);
  var hasKelas = String(kelas || "").trim() !== "";
  var keyKelas = normalizeClassLabel_(kelas);

  var overallRank = 0;
  var myPoin = 0;
  for (var i = 0; i < snap.overall_list.length; i++) {
    var item = snap.overall_list[i];
    if (item.nama.toLowerCase() === keyName && (!hasKelas || item.kelas === keyKelas) && (!keyAbsen || item.absen === keyAbsen)) {
      overallRank = item.rank;
      myPoin = item.poin;
      break;
    }
  }

  var classList = (keyKelas === "PPLG B") ? snap.pplgb_list : snap.pplga_list;
  var classRank = 0;
  for (var j = 0; j < classList.length; j++) {
    var citem = classList[j];
    if (citem.nama.toLowerCase() === keyName && (!keyAbsen || citem.absen === keyAbsen)) {
      classRank = citem.rank;
      break;
    }
  }

  return {
    found: overallRank > 0,
    overall_rank: overallRank,
    overall_total: snap.overall_list.length,
    class_rank: classRank,
    class_total: classList.length,
    kelas: keyKelas,
    rata_rata: myPoin
  };
}

/* ========================= LOG JAWABAN ========================= */

function appendAnswerLogsBatch_(ss, items, fallbackMode) {
  var sheet = ensureLogSheet_(ss);
  var header3 = String(sheet.getRange(1, 3).getValue() || "").trim();
  var hasModeCol = (header3 === "Mode");

  var seen = {};
  var lastRow = sheet.getLastRow();
  if (lastRow >= 2) {
    var startRow = Math.max(2, lastRow - 99);
    var width = hasModeCol ? 11 : 10;
    var existing = sheet.getRange(startRow, 2, lastRow - startRow + 1, width).getValues();
    for (var r = 0; r < existing.length; r++) {
      var sid = String(existing[r][0] || "");
      var lid = String(existing[r][hasModeCol ? 6 : 5] || "");
      var att = String(existing[r][hasModeCol ? 10 : 9] || "");
      if (sid && lid) seen[sid + "|" + lid + "|" + att] = true;
    }
  }

  var rowsToAdd = [];
  for (var i = 0; i < items.length; i++) {
    var data = items[i] || {};
    var kSid = String(data.session_id || "");
    var kLid = String(data.level_id || "");
    var kAtt = String(Number(data.percobaan_ke || 1));
    var dedupeKey = kSid + "|" + kLid + "|" + kAtt;
    if (kSid && kLid && seen[dedupeKey]) continue;
    if (kSid && kLid) seen[dedupeKey] = true;
    var mStr = normalizeMode_(data.test_mode || fallbackMode);
    if (hasModeCol) {
      rowsToAdd.push([
        new Date(), kSid, mStr, String(data.nama || ""), String(data.kelas || ""),
        normalizeAbsen_(data.absen), String(data.minigame_id || ""), kLid,
        String(data.jawaban_siswa || ""), String(data.kunci_jawaban || ""),
        String(data.hasil || ""), Number(data.percobaan_ke || 1),
        Number(data.poin || 0), Number(data.durasi_detik || 0)
      ]);
    } else {
      rowsToAdd.push([
        new Date(), kSid, "[" + mStr + "] " + String(data.nama || ""), String(data.kelas || ""),
        normalizeAbsen_(data.absen), String(data.minigame_id || ""), kLid,
        String(data.jawaban_siswa || ""), String(data.kunci_jawaban || ""),
        String(data.hasil || ""), Number(data.percobaan_ke || 1),
        Number(data.poin || 0), Number(data.durasi_detik || 0)
      ]);
    }
  }

  if (rowsToAdd.length > 0) {
    var insertAt = Math.max(2, sheet.getLastRow() + 1);
    sheet.getRange(insertAt, 1, rowsToAdd.length, hasModeCol ? 14 : 13).setValues(rowsToAdd);
  }
}

function readRecentLogs_(ss, maxRows) {
  var sheet = ss.getSheetByName("LogJawaban");
  if (!sheet || sheet.getLastRow() < 2) return [];
  var header3 = String(sheet.getRange(1, 3).getValue() || "").trim();
  var hasModeCol = (header3 === "Mode");
  var lastRow = sheet.getLastRow();
  var count = Math.min(maxRows, lastRow - 1);
  var startRow = lastRow - count + 1;
  var vals = sheet.getRange(startRow, 1, count, hasModeCol ? 14 : 13).getValues();
  var out = [];
  for (var i = vals.length - 1; i >= 0; i--) {
    var r = vals[i];
    if (hasModeCol) {
      out.push({
        timestamp: r[0] ? new Date(r[0]).toISOString() : "",
        session_id: String(r[1] || ""),
        mode: String(r[2] || "PRETEST"),
        nama: String(r[3] || ""),
        kelas: String(r[4] || ""),
        absen: normalizeAbsen_(r[5]),
        minigame_id: String(r[6] || ""),
        level_id: String(r[7] || ""),
        jawaban_siswa: String(r[8] || ""),
        kunci_jawaban: String(r[9] || ""),
        hasil: String(r[10] || ""),
        poin: Number(r[12] || 0),
        durasi_detik: Number(r[13] || 0)
      });
    } else {
      var rawNm = String(r[2] || "");
      var parsedMode = "PRETEST";
      if (rawNm.indexOf("[POSTTEST] ") === 0) {
        parsedMode = "POSTTEST";
        rawNm = rawNm.substring(11);
      } else if (rawNm.indexOf("[PRETEST] ") === 0) {
        rawNm = rawNm.substring(10);
      }
      out.push({
        timestamp: r[0] ? new Date(r[0]).toISOString() : "",
        session_id: String(r[1] || ""),
        mode: parsedMode,
        nama: rawNm,
        kelas: String(r[3] || ""),
        absen: normalizeAbsen_(r[4]),
        minigame_id: String(r[5] || ""),
        level_id: String(r[6] || ""),
        jawaban_siswa: String(r[7] || ""),
        kunci_jawaban: String(r[8] || ""),
        hasil: String(r[9] || ""),
        poin: Number(r[11] || 0),
        durasi_detik: Number(r[12] || 0)
      });
    }
  }
  return out;
}
