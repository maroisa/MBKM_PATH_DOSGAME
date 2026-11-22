/**
 * Google Apps Script Web App untuk Spreadsheet "Data Game DOS"
 * (1_5KTFCkMfApJd6mqU1qBDhrvOMRTULbgtgTqdFUC5lo)
 *
 * Mendukung penuh:
 * - Mode PRE-TEST & POST-TEST yang dikontrol dari Dashboard Admin (sheet "Config")
 * - Validasi 1 siswa = 1 kali percobaan per mode (real-time tanpa cache)
 * - Kontrol "Spill" (buka/sembunyikan nilai & peringkat Pre-Test / Post-Test untuk siswa)
 * - Rekap otomatis PreTest_*, PostTest_*, Rekap_PreVsPost, LogJawaban, serta mirror sheet aktif
 *
 * Cara Deploy / Update:
 * 1. Buka Spreadsheet -> Ekstensi (Extensions) -> Apps Script.
 * 2. Ganti seluruh isi Code.gs dengan kode ini -> Simpan (Ctrl+S).
 * 3. Jalankan fungsi "syncSemuaSheet" 1x dari editor Apps Script (tombol Run).
 * 4. Deploy -> Manage deployments -> klik ikon Pensil (Edit) -> Version: New version -> Deploy.
 */

var CACHE_KEY_PREFIX = "dos_lb_v3_";
var CACHE_TTL_SECONDS = 12;

var DEFAULT_CONFIG = {
  active_mode: "PRETEST",
  reveal_pretest_results: false,
  reveal_posttest_results: false,
  allow_materi_pretest: false,
  allow_materi_posttest: false,
  admin_pin: "6767"
};

function onOpen() {
  try {
    SpreadsheetApp.getUi()
      .createMenu("DOS Rescue")
      .addItem("Sinkron Semua Sheet (Pre & Post)", "syncSemuaSheet")
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
    if (!e || !e.range) {
      return;
    }
    var sheetName = e.range.getSheet().getName();
    var watched = [
      "Config",
      "PreTest_PPLGA", "PreTest_PPLGB",
      "PostTest_PPLGA", "PostTest_PPLGB",
      "PPLGA", "PPLGB"
    ];
    if (watched.indexOf(sheetName) === -1) {
      return;
    }
    clearAllCaches_();
    var ss = e.source || SpreadsheetApp.getActiveSpreadsheet();
    SpreadsheetApp.flush();
    syncAllModes_(ss);
  } catch (_err) {}
}

function syncSemuaSheet() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  clearAllCaches_();
  ensureConfigSheet_(ss);
  SpreadsheetApp.flush();
  var out = syncAllModes_(ss);
  return {
    ok: true,
    active_mode: out.config.active_mode,
    pretest_total: out.pretest.overall_list.length,
    posttest_total: out.posttest.overall_list.length
  };
}

function doGet(e) {
  try {
    var params = (e && e.parameter) ? e.parameter : {};
    var action = String(params.action || "leaderboard").trim().toLowerCase();
    var nama = String(params.nama || "").trim();
    var absen = String(params.absen || "").trim();
    var kelas = String(params.kelas || "").trim();
    var ss = SpreadsheetApp.getActiveSpreadsheet();
    var cfg = readConfig_(ss);
    var reqMode = normalizeMode_(params.mode || cfg.active_mode);

    // 1. Konfigurasi publik untuk game siswa (tanpa admin_pin)
    if (action === "public_config") {
      return jsonOut_({
        ok: true,
        config: sanitizePublicConfig_(cfg)
      });
    }

    // 2. Validasi real-time (tanpa cache) 1 siswa = 1 kali percobaan untuk mode aktif
    if (action === "check_student") {
      var checkRes = checkStudentAlreadyUsed_(ss, nama, absen, kelas, reqMode);
      checkRes.config = sanitizePublicConfig_(cfg);
      return jsonOut_(checkRes);
    }

    // 3. Dashboard Admin (wajib PIN benar, selalu live tanpa cache)
    if (action === "admin_dashboard") {
      var pin = String(params.pin || "").trim();
      if (!verifyAdminPin_(cfg, pin)) {
        return jsonOut_({ ok: false, unauthorized: true, error: "PIN Admin salah." });
      }
      var preSnap = buildModeSnapshot_(ss, "PRETEST");
      var postSnap = buildModeSnapshot_(ss, "POSTTEST");
      var comparison = buildPrePostComparison_(preSnap, postSnap);
      var recentLogs = readRecentLogs_(ss, 200);
      return jsonOut_({
        ok: true,
        updated_at: new Date().toISOString(),
        config: sanitizePublicConfig_(cfg),
        pretest: preSnap,
        posttest: postSnap,
        comparison: comparison,
        recent_logs: recentLogs
      });
    }

    // 4. Leaderboard untuk siswa (menghormati kontrol Spill Admin!)
    var snap = getModeSnapshot_(ss, reqMode);
    var revealed = isModeRevealed_(cfg, reqMode);
    var myInfo = findPersonalRank_(snap, nama, absen, kelas);

    if (!revealed) {
      // Sembunyikan nilai & peringkat di sisi server agar tidak bisa diintip sebelum di-spill Admin
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
    var cfg = readConfig_(ss);
    var ev = String(data.event || "").trim();

    // --- AKSI ADMIN (wajib PIN) ---
    if (ev === "ADMIN_UPDATE_CONFIG") {
      if (!verifyAdminPin_(cfg, String(data.pin || "").trim())) {
        return jsonOut_({ ok: false, unauthorized: true, error: "PIN Admin salah." });
      }
      var patch = {};
      if (data.active_mode !== undefined) {
        patch.active_mode = normalizeMode_(data.active_mode);
      }
      if (data.reveal_pretest_results !== undefined) {
        patch.reveal_pretest_results = toBool_(data.reveal_pretest_results);
      }
      if (data.reveal_posttest_results !== undefined) {
        patch.reveal_posttest_results = toBool_(data.reveal_posttest_results);
      }
      if (data.allow_materi_pretest !== undefined) {
        patch.allow_materi_pretest = toBool_(data.allow_materi_pretest);
      }
      if (data.allow_materi_posttest !== undefined) {
        patch.allow_materi_posttest = toBool_(data.allow_materi_posttest);
      }
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
      var removed = deleteStudentRow_(ss, String(data.nama || ""), String(data.absen || ""), String(data.kelas || ""), targetMode);
      clearAllCaches_();
      SpreadsheetApp.flush();
      syncAllModes_(ss);
      return jsonOut_({
        ok: true,
        event: ev,
        removed: removed,
        mode: targetMode,
        message: removed
          ? ("Data " + modeLabel_(targetMode) + " untuk " + String(data.nama || "") + " berhasil direset. Siswa kini dapat mengerjakan ulang.")
          : "Baris siswa tidak ditemukan pada sheet " + modeLabel_(targetMode) + "."
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

    // --- AKSI SISWA (TELEMETRI & SKOR) ---
    var fallbackMode = cfg.active_mode;
    if (ev === "BATCH_SYNC" && Array.isArray(data.items)) {
      var latestSummary = null;
      var logItems = [];
      for (var i = 0; i < data.items.length; i++) {
        var item = data.items[i] || {};
        if (!item.test_mode) {
          item.test_mode = fallbackMode;
        }
        if (item.event === "LEVEL_LOG") {
          logItems.push(item);
        }
        latestSummary = item;
      }
      if (logItems.length > 0) {
        appendAnswerLogsBatch_(ss, logItems, fallbackMode);
      }
      if (latestSummary) {
        upsertClassRow_(ss, latestSummary, normalizeMode_(latestSummary.test_mode || fallbackMode));
      }
    } else {
      var itemMode = normalizeMode_(data.test_mode || fallbackMode);
      data.test_mode = itemMode;
      processSingleEvent_(ss, data, itemMode);
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

function toBool_(v) {
  if (typeof v === "boolean") {
    return v;
  }
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

function ensureConfigSheet_(ss) {
  var sheet = ss.getSheetByName("Config");
  if (!sheet) {
    sheet = ss.insertSheet("Config");
    sheet.appendRow(["Key", "Value", "Keterangan"]);
    sheet.appendRow(["active_mode", DEFAULT_CONFIG.active_mode, "Mode aktif: PRETEST atau POSTTEST"]);
    sheet.appendRow(["reveal_pretest_results", "FALSE", "TRUE = nilai & peringkat Pre-Test ditampilkan ke siswa"]);
    sheet.appendRow(["reveal_posttest_results", "FALSE", "TRUE = nilai & peringkat Post-Test ditampilkan ke siswa"]);
    sheet.appendRow(["allow_materi_pretest", "FALSE", "TRUE = tombol Buku Materi dibuka saat Pre-Test"]);
    sheet.appendRow(["allow_materi_posttest", "FALSE", "TRUE = tombol Buku Materi dibuka saat Post-Test"]);
    sheet.appendRow(["admin_pin", DEFAULT_CONFIG.admin_pin, "PIN masuk Dashboard Admin (admin.html)"]);
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
  if (lastRow < 2) {
    return out;
  }
  var vals = sheet.getRange(2, 1, lastRow - 1, 2).getValues();
  for (var i = 0; i < vals.length; i++) {
    var k = String(vals[i][0] || "").trim();
    var v = vals[i][1];
    if (k === "active_mode") out.active_mode = normalizeMode_(v);
    else if (k === "reveal_pretest_results") out.reveal_pretest_results = toBool_(v);
    else if (k === "reveal_posttest_results") out.reveal_posttest_results = toBool_(v);
    else if (k === "allow_materi_pretest") out.allow_materi_pretest = toBool_(v);
    else if (k === "allow_materi_posttest") out.allow_materi_posttest = toBool_(v);
    else if (k === "admin_pin" && String(v || "").trim() !== "") out.admin_pin = String(v).trim();
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
      if (rk) {
        keyToRow[rk] = i + 2;
      }
    }
  }
  for (var j = 0; j < keys.length; j++) {
    var k = keys[j];
    var rawV = patch[k];
    var storeV = (typeof rawV === "boolean") ? (rawV ? "TRUE" : "FALSE") : String(rawV);
    if (keyToRow[k]) {
      sheet.getRange(keyToRow[k], 2).setValue(storeV);
    } else {
      sheet.appendRow([k, storeV, ""]);
    }
  }
  SpreadsheetApp.flush();
  return readConfig_(ss);
}

function clearAllCaches_() {
  var cache = CacheService.getScriptCache();
  cache.remove(CACHE_KEY_PREFIX + "PRETEST");
  cache.remove(CACHE_KEY_PREFIX + "POSTTEST");
}

function processSingleEvent_(ss, data, mode) {
  if (!data) {
    return;
  }
  if (data.event === "LEVEL_LOG") {
    appendAnswerLogsBatch_(ss, [data], mode);
    upsertClassRow_(ss, data, mode);
  } else if (data.event === "SESSION_START" || data.event === "SESSION_FINISH" || data.event === "SESSION_SYNC") {
    upsertClassRow_(ss, data, mode);
  }
}

function getClassCode_(kelas) {
  var norm = String(kelas || "").toUpperCase().replace(/\s+/g, "");
  return (norm === "PPLGB") ? "PPLGB" : "PPLGA";
}

function getModeClassSheetName_(mode, kelas) {
  var prefix = (normalizeMode_(mode) === "POSTTEST") ? "PostTest_" : "PreTest_";
  return prefix + getClassCode_(kelas);
}

function ensureClassSheet_(ss, sheetName) {
  var sheet = ss.getSheetByName(sheetName);
  if (sheet) {
    return sheet;
  }
  sheet = ss.insertSheet(sheetName);
  sheet.appendRow(["No", "Nama", "Absen", "Game 1", "Game 2", "Game 3", "Game 4", "Game 5", "Rata-rata"]);
  sheet.getRange("A2").setFormula('=ARRAYFORMULA(IF(B2:B="","",ROW(B2:B)-1))');
  sheet.getRange("I2").setFormula('=ARRAYFORMULA(IF(B2:B="","",(N(D2:D)+N(E2:E)+N(F2:F)+N(G2:G)+N(H2:H))/5))');
  return sheet;
}

function upsertClassRow_(ss, data, mode) {
  var nama = String(data.nama || "").trim();
  if (!nama) {
    return;
  }
  var absen = String(data.absen || "").trim();
  var sheetName = getModeClassSheetName_(mode, data.kelas);
  var sheet = ensureClassSheet_(ss, sheetName);

  var lastRow = sheet.getLastRow();
  var targetRow = -1;
  var existingScores = ["", "", "", "", ""];

  if (lastRow >= 2) {
    var rows = sheet.getRange(2, 2, lastRow - 1, 7).getValues(); // B..H
    var keyTarget = nama.toLowerCase() + "|" + absen;
    for (var i = 0; i < rows.length; i++) {
      var rNama = String(rows[i][0] || "").trim().toLowerCase();
      var rAbsen = String(rows[i][1] || "").trim();
      if (!rNama) {
        if (targetRow === -1) {
          targetRow = i + 2;
        }
        continue;
      }
      if ((rNama + "|" + rAbsen) === keyTarget) {
        targetRow = i + 2;
        existingScores = [rows[i][2], rows[i][3], rows[i][4], rows[i][5], rows[i][6]];
        break;
      }
    }
    if (targetRow === -1) {
      targetRow = lastRow + 1;
    }
  } else {
    targetRow = 2;
  }

  var incoming = [
    data.skor_mg1,
    data.skor_mg2,
    data.skor_mg3,
    data.skor_mg4,
    data.skor_mg5
  ];

  var finalScores = [];
  for (var g = 0; g < 5; g++) {
    var inc = incoming[g];
    if (inc !== undefined && inc !== null && inc !== "") {
      var incNum = Number(inc);
      var hasExisting = (existingScores[g] !== "" && existingScores[g] !== null && existingScores[g] !== undefined);
      var curNum = hasExisting ? Number(existingScores[g]) : 0;
      if (incNum > 0) {
        finalScores.push(Math.max(curNum, incNum));
      } else if (hasExisting) {
        finalScores.push(existingScores[g]);
      } else {
        finalScores.push(0);
      }
    } else if (existingScores[g] !== "" && existingScores[g] !== null && existingScores[g] !== undefined) {
      finalScores.push(existingScores[g]);
    } else {
      finalScores.push("");
    }
  }

  sheet.getRange(targetRow, 2, 1, 7).setValues([[
    nama,
    absen === "" ? "" : Number(absen),
    finalScores[0],
    finalScores[1],
    finalScores[2],
    finalScores[3],
    finalScores[4]
  ]]);
}

function deleteStudentRow_(ss, nama, absen, kelas, mode) {
  var sheetName = getModeClassSheetName_(mode, kelas);
  var sheet = ss.getSheetByName(sheetName);
  if (!sheet || sheet.getLastRow() < 2) {
    return false;
  }
  var targetNama = String(nama || "").trim().toLowerCase();
  var targetAbsen = String(absen || "").trim();
  var rows = sheet.getRange(2, 2, sheet.getLastRow() - 1, 2).getValues();
  var removed = false;
  for (var i = rows.length - 1; i >= 0; i--) {
    var rNama = String(rows[i][0] || "").trim().toLowerCase();
    var rAbsen = String(rows[i][1] || "").trim();
    if (!rNama) {
      continue;
    }
    if ((targetNama && rNama === targetNama) || (targetAbsen && rAbsen === targetAbsen)) {
      sheet.deleteRow(i + 2);
      removed = true;
    }
  }
  return removed;
}

function checkStudentAlreadyUsed_(ss, nama, absen, kelas, mode) {
  var sheetName = getModeClassSheetName_(mode, kelas);
  var kelasLabel = (getClassCode_(kelas) === "PPLGB") ? "PPLG B" : "PPLG A";
  var sheet = ss.getSheetByName(sheetName);
  var targetNama = String(nama || "").trim().toLowerCase();
  var targetAbsen = String(absen || "").trim();
  var exists = false;
  var matchedNama = nama;
  var matchedAbsen = absen;

  if (sheet && targetNama && sheet.getLastRow() >= 2) {
    var rows = sheet.getRange(2, 2, sheet.getLastRow() - 1, 2).getValues();
    for (var i = 0; i < rows.length; i++) {
      var rNama = String(rows[i][0] || "").trim();
      var rAbsen = String(rows[i][1] || "").trim();
      if (!rNama) {
        continue;
      }
      var sameName = (rNama.toLowerCase() === targetNama);
      var sameAbsen = (targetAbsen !== "" && rAbsen !== "" && rAbsen === targetAbsen);
      if (sameName || sameAbsen) {
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
      ? ("Nama \"" + matchedNama + "\" (Absen " + matchedAbsen + ") sudah dipakai untuk " + modeLabel_(mode) + ". Hubungi guru/admin jika ingin mengulang.")
      : ("Nama tersedia untuk " + modeLabel_(mode) + ".")
  };
}

function ensureNamedSheet_(ss, name, headers) {
  var sheet = ss.getSheetByName(name);
  if (!sheet) {
    sheet = ss.insertSheet(name);
    sheet.appendRow(headers);
  } else if (sheet.getLastRow() < 1) {
    sheet.appendRow(headers);
  }
  return sheet;
}

function syncModeSummarySheets_(ss, mode, snap) {
  var prefix = (normalizeMode_(mode) === "POSTTEST") ? "PostTest_" : "PreTest_";
  var overall = snap.overall_list || [];

  var hasilSheet = ensureNamedSheet_(ss, prefix + "Hasil", ["No", "Nama", "Absen", "Kelas", "Rata-rata"]);
  var clearN = Math.max(hasilSheet.getLastRow() - 1, overall.length, 1);
  hasilSheet.getRange(2, 1, clearN, 5).clearContent();
  if (overall.length > 0) {
    var hRows = [];
    for (var i = 0; i < overall.length; i++) {
      var it = overall[i];
      hRows.push([i + 1, it.nama, it.absen === "" ? "" : (isNaN(Number(it.absen)) ? it.absen : Number(it.absen)), it.kelas, it.poin]);
    }
    hasilSheet.getRange(2, 1, hRows.length, 5).setValues(hRows);
  }

  var lbSheet = ensureNamedSheet_(ss, prefix + "LeaderBoard", ["Rank", "Nama", "Kelas", "Poin"]);
  var lbClear = Math.max(lbSheet.getLastRow() - 1, 10);
  lbSheet.getRange(2, 2, lbClear, 3).clearContent();
  var lbRows = [];
  for (var r = 0; r < 10; r++) {
    if (r < overall.length) {
      lbRows.push([r + 1, overall[r].nama, overall[r].kelas, overall[r].poin]);
    } else {
      lbRows.push([r + 1, "", "", ""]);
    }
  }
  lbSheet.getRange(2, 1, 10, 4).setValues(lbRows);
}

function syncComparisonSheet_(ss, preSnap, postSnap) {
  var comp = buildPrePostComparison_(preSnap, postSnap);
  var sheet = ensureNamedSheet_(ss, "Rekap_PreVsPost", [
    "No", "Nama", "Absen", "Kelas", "Pre-Test", "Post-Test", "Selisih (Gain)"
  ]);
  var clearN = Math.max(sheet.getLastRow() - 1, comp.length, 1);
  sheet.getRange(2, 1, clearN, 7).clearContent();
  if (comp.length > 0) {
    var rows = [];
    for (var i = 0; i < comp.length; i++) {
      var c = comp[i];
      rows.push([
        i + 1,
        c.nama,
        c.absen === "" ? "" : (isNaN(Number(c.absen)) ? c.absen : Number(c.absen)),
        c.kelas,
        c.pre_done ? c.pre_avg : "",
        c.post_done ? c.post_avg : "",
        (c.pre_done && c.post_done) ? c.gain : ""
      ]);
    }
    sheet.getRange(2, 1, rows.length, 7).setValues(rows);
  }
}

function syncLegacyActiveMirror_(ss, activeSnap) {
  var overall = activeSnap.overall_list || [];
  var hasilSheet = ss.getSheetByName("HasilKeseluruhan");
  if (hasilSheet) {
    var clearN = Math.max(hasilSheet.getLastRow() - 1, overall.length, 1);
    hasilSheet.getRange(2, 1, clearN, 5).clearContent();
    if (overall.length > 0) {
      var hRows = [];
      for (var i = 0; i < overall.length; i++) {
        var it = overall[i];
        hRows.push([i + 1, it.nama, it.absen === "" ? "" : (isNaN(Number(it.absen)) ? it.absen : Number(it.absen)), it.kelas, it.poin]);
      }
      hasilSheet.getRange(2, 1, hRows.length, 5).setValues(hRows);
    }
  }
  var lbSheet = ss.getSheetByName("LeaderBoard");
  if (lbSheet) {
    var lbClear = Math.max(lbSheet.getLastRow() - 1, 10);
    lbSheet.getRange(2, 2, lbClear, 3).clearContent();
    var lbRows = [];
    for (var r = 0; r < 10; r++) {
      if (r < overall.length) {
        lbRows.push([r + 1, overall[r].nama, overall[r].kelas, overall[r].poin]);
      } else {
        lbRows.push([r + 1, "", "", ""]);
      }
    }
    lbSheet.getRange(2, 1, 10, 4).setValues(lbRows);
  }
}

function syncAllModes_(ss) {
  var cfg = readConfig_(ss);
  var preSnap = buildModeSnapshot_(ss, "PRETEST");
  var postSnap = buildModeSnapshot_(ss, "POSTTEST");
  syncModeSummarySheets_(ss, "PRETEST", preSnap);
  syncModeSummarySheets_(ss, "POSTTEST", postSnap);
  syncComparisonSheet_(ss, preSnap, postSnap);
  syncLegacyActiveMirror_(ss, cfg.active_mode === "POSTTEST" ? postSnap : preSnap);
  try {
    var cache = CacheService.getScriptCache();
    cache.put(CACHE_KEY_PREFIX + "PRETEST", JSON.stringify(preSnap), CACHE_TTL_SECONDS);
    cache.put(CACHE_KEY_PREFIX + "POSTTEST", JSON.stringify(postSnap), CACHE_TTL_SECONDS);
  } catch (_e) {}
  return { config: cfg, pretest: preSnap, posttest: postSnap };
}

function appendAnswerLogsBatch_(ss, items, fallbackMode) {
  var sheet = ss.getSheetByName("LogJawaban");
  if (!sheet) {
    sheet = ss.insertSheet("LogJawaban");
    sheet.appendRow([
      "Timestamp", "Session_ID", "Mode", "Nama", "Kelas", "Absen",
      "Minigame_ID", "Level_ID", "Jawaban_Siswa", "Kunci_Jawaban",
      "Hasil", "Percobaan_Ke", "Poin", "Durasi_Detik"
    ]);
  }
  var colCount = Math.max(13, sheet.getLastColumn());
  var header2 = String(sheet.getRange(1, 3).getValue() || "").trim();
  var hasModeCol = (header2 === "Mode");

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
      if (sid && lid) {
        seen[sid + "|" + lid + "|" + att] = true;
      }
    }
  }

  var rowsToAdd = [];
  for (var i = 0; i < items.length; i++) {
    var data = items[i] || {};
    var kSid = String(data.session_id || "");
    var kLid = String(data.level_id || "");
    var kAtt = String(Number(data.percobaan_ke || 1));
    var dedupeKey = kSid + "|" + kLid + "|" + kAtt;
    if (kSid && kLid && seen[dedupeKey]) {
      continue;
    }
    if (kSid && kLid) {
      seen[dedupeKey] = true;
    }
    var mStr = normalizeMode_(data.test_mode || fallbackMode);
    if (hasModeCol) {
      rowsToAdd.push([
        new Date(),
        kSid,
        mStr,
        String(data.nama || ""),
        String(data.kelas || ""),
        String(data.absen || ""),
        String(data.minigame_id || ""),
        kLid,
        String(data.jawaban_siswa || ""),
        String(data.kunci_jawaban || ""),
        String(data.hasil || ""),
        Number(data.percobaan_ke || 1),
        Number(data.poin || 0),
        Number(data.durasi_detik || 0)
      ]);
    } else {
      rowsToAdd.push([
        new Date(),
        kSid,
        "[" + mStr + "] " + String(data.nama || ""),
        String(data.kelas || ""),
        String(data.absen || ""),
        String(data.minigame_id || ""),
        kLid,
        String(data.jawaban_siswa || ""),
        String(data.kunci_jawaban || ""),
        String(data.hasil || ""),
        Number(data.percobaan_ke || 1),
        Number(data.poin || 0),
        Number(data.durasi_detik || 0)
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
  if (!sheet || sheet.getLastRow() < 2) {
    return [];
  }
  var header2 = String(sheet.getRange(1, 3).getValue() || "").trim();
  var hasModeCol = (header2 === "Mode");
  var lastRow = sheet.getLastRow();
  var count = Math.min(maxRows, lastRow - 1);
  var startRow = lastRow - count + 1;
  var cols = hasModeCol ? 14 : 13;
  var vals = sheet.getRange(startRow, 1, count, cols).getValues();
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
        absen: String(r[5] || ""),
        minigame_id: String(r[6] || ""),
        level_id: String(r[7] || ""),
        jawaban_siswa: String(r[8] || ""),
        kunci_jawaban: String(r[9] || ""),
        hasil: String(r[10] || ""),
        poin: Number(r[12] || 0),
        durasi_detik: Number(r[13] || 0)
      });
    } else {
      out.push({
        timestamp: r[0] ? new Date(r[0]).toISOString() : "",
        session_id: String(r[1] || ""),
        mode: "PRETEST",
        nama: String(r[2] || ""),
        kelas: String(r[3] || ""),
        absen: String(r[4] || ""),
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

function getModeSnapshot_(ss, mode) {
  var m = normalizeMode_(mode);
  var cacheKey = CACHE_KEY_PREFIX + m;
  var cache = CacheService.getScriptCache();
  var cached = cache.get(cacheKey);
  if (cached) {
    try {
      return JSON.parse(cached);
    } catch (_e) {}
  }
  var snap = buildModeSnapshot_(ss, m);
  try {
    cache.put(cacheKey, JSON.stringify(snap), CACHE_TTL_SECONDS);
  } catch (_e2) {}
  return snap;
}

function buildModeSnapshot_(ss, mode) {
  var m = normalizeMode_(mode);
  var pplgaList = readClassRanking_(ss.getSheetByName(getModeClassSheetName_(m, "PPLG A")), "PPLG A");
  var pplgbList = readClassRanking_(ss.getSheetByName(getModeClassSheetName_(m, "PPLG B")), "PPLG B");

  var overallList = [];
  var combined = pplgaList.concat(pplgbList);
  for (var c = 0; c < combined.length; c++) {
    var src = combined[c];
    overallList.push({
      rank: 0,
      nama: src.nama,
      absen: src.absen,
      kelas: src.kelas,
      poin: src.poin,
      scores: src.scores.slice()
    });
  }
  overallList.sort(function(a, b) {
    if (b.poin !== a.poin) {
      return b.poin - a.poin;
    }
    return a.nama.localeCompare(b.nama);
  });
  for (var i = 0; i < overallList.length; i++) {
    overallList[i].rank = i + 1;
  }

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
      var k = getClassCode_(it.kelas) + "|" + it.nama.toLowerCase();
      if (!map[k]) {
        map[k] = {
          nama: it.nama,
          absen: it.absen,
          kelas: it.kelas,
          pre_done: false,
          pre_avg: 0,
          pre_scores: [0, 0, 0, 0, 0],
          post_done: false,
          post_avg: 0,
          post_scores: [0, 0, 0, 0, 0],
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
      if (!map[k].absen && it.absen) {
        map[k].absen = it.absen;
      }
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
    if (a.kelas !== b.kelas) {
      return a.kelas.localeCompare(b.kelas);
    }
    var aa = Number(a.absen) || 999;
    var ba = Number(b.absen) || 999;
    if (aa !== ba) {
      return aa - ba;
    }
    return a.nama.localeCompare(b.nama);
  });
  return out;
}

function readClassRanking_(sheet, kelasLabel) {
  if (!sheet || sheet.getLastRow() < 2) {
    return [];
  }
  var values = sheet.getRange(2, 2, sheet.getLastRow() - 1, 8).getValues(); // B..I
  var list = [];
  for (var i = 0; i < values.length; i++) {
    var nama = String(values[i][0] || "").trim();
    if (!nama) {
      continue;
    }
    var absen = String(values[i][1] || "").trim();
    var scores = [
      values[i][2] === "" ? 0 : Number(values[i][2]),
      values[i][3] === "" ? 0 : Number(values[i][3]),
      values[i][4] === "" ? 0 : Number(values[i][4]),
      values[i][5] === "" ? 0 : Number(values[i][5]),
      values[i][6] === "" ? 0 : Number(values[i][6])
    ];
    var avgRaw = values[i][7];
    var avg = (typeof avgRaw === "number" && !isNaN(avgRaw))
      ? Math.round(avgRaw * 100) / 100
      : Math.round(((scores[0] + scores[1] + scores[2] + scores[3] + scores[4]) / 5) * 100) / 100;
    list.push({
      rank: 0,
      nama: nama,
      absen: absen,
      kelas: kelasLabel,
      poin: avg,
      scores: scores
    });
  }
  list.sort(function(a, b) {
    if (b.poin !== a.poin) {
      return b.poin - a.poin;
    }
    return a.nama.localeCompare(b.nama);
  });
  for (var k = 0; k < list.length; k++) {
    list[k].rank = k + 1;
  }
  return list;
}

function extractUsedKeys_(classList) {
  var out = [];
  for (var i = 0; i < classList.length; i++) {
    out.push({
      nama: classList[i].nama,
      absen: classList[i].absen
    });
  }
  return out;
}

function findPersonalRank_(snap, nama, absen, kelas) {
  if (!nama) {
    return { found: false };
  }
  var keyName = nama.toLowerCase();
  var keyAbsen = String(absen || "").trim();
  var hasKelas = String(kelas || "").trim() !== "";
  var keyKelas = getClassCode_(kelas);

  var overallRank = 0;
  var myPoin = 0;
  var myScores = [0, 0, 0, 0, 0];
  for (var i = 0; i < snap.overall_list.length; i++) {
    var item = snap.overall_list[i];
    var kelasMatch = !hasKelas || (getClassCode_(item.kelas) === keyKelas);
    if (item.nama.toLowerCase() === keyName && kelasMatch && (!keyAbsen || item.absen === keyAbsen)) {
      overallRank = item.rank;
      myPoin = item.poin;
      myScores = item.scores;
      break;
    }
  }

  var classList = (keyKelas === "PPLGB") ? snap.pplgb_list : snap.pplga_list;
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
    kelas: (keyKelas === "PPLGB") ? "PPLG B" : "PPLG A",
    rata_rata: myPoin,
    scores: myScores
  };
}
