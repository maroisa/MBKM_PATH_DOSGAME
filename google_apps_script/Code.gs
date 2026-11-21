/**
 * Google Apps Script Web App untuk Spreadsheet "Data Game DOS"
 * (1_5KTFCkMfApJd6mqU1qBDhrvOMRTULbgtgTqdFUC5lo)
 *
 * Sheet yang dikelola:
 * 1. PPLGA            -> Nilai Game 1..5 & Rata-rata kelas PPLG A
 * 2. PPLGB            -> Nilai Game 1..5 & Rata-rata kelas PPLG B
 * 3. HasilKeseluruhan -> Otomatis disinkronkan dari gabungan PPLGA + PPLGB
 * 4. LeaderBoard      -> Otomatis disinkronkan Top 10 dari HasilKeseluruhan
 * 5. LogJawaban       -> Riwayat detail jawaban siswa dari awal hingga akhir
 *
 * Cara Deploy / Update:
 * 1. Buka Spreadsheet -> Ekstensi (Extensions) -> Apps Script.
 * 2. Ganti seluruh isi Code.gs dengan kode ini -> Simpan (Ctrl+S).
 * 3. Jalankan fungsi "syncSemuaSheet" 1x dari editor Apps Script (tombol Run) untuk sinkron data yang sudah ada.
 * 4. Deploy -> Manage deployments -> klik ikon Pensil (Edit) -> Version: New version -> Deploy.
 *    (Atau Deploy -> New deployment -> Web app -> Execute as: Me -> Who has access: Anyone, lalu salin URL /exec).
 */

var CACHE_KEY_SNAPSHOT = "lb_snapshot_v2";
var CACHE_TTL_SECONDS = 15;

/**
 * Menu bantuan di toolbar Google Sheets agar guru bisa sinkron manual kapan saja (mis. setelah hapus baris).
 */
function onOpen() {
  try {
    SpreadsheetApp.getUi()
      .createMenu("DOS Rescue")
      .addItem("Sinkron HasilKeseluruhan & LeaderBoard", "syncSemuaSheet")
      .addToUi();
  } catch (_err) {}
}

/**
 * Simple trigger otomatis: setiap guru mengedit atau menghapus isi sel di sheet PPLGA / PPLGB,
 * HasilKeseluruhan & LeaderBoard langsung ikut ter-update otomatis.
 */
function onEdit(e) {
  try {
    if (!e || !e.range) {
      return;
    }
    var sheetName = e.range.getSheet().getName();
    if (sheetName !== "PPLGA" && sheetName !== "PPLGB") {
      return;
    }
    CacheService.getScriptCache().remove(CACHE_KEY_SNAPSHOT);
    var ss = e.source || SpreadsheetApp.getActiveSpreadsheet();
    SpreadsheetApp.flush();
    var snap = buildLeaderboardSnapshot_(ss);
    syncSummarySheets_(ss, snap);
  } catch (_err) {}
}

/**
 * Jalankan fungsi ini 1x dari Apps Script Editor (atau menu "DOS Rescue") untuk
 * langsung menyinkronkan data PPLGA + PPLGB ke HasilKeseluruhan & LeaderBoard.
 */
function syncSemuaSheet() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  CacheService.getScriptCache().remove(CACHE_KEY_SNAPSHOT);
  SpreadsheetApp.flush();
  var snap = buildLeaderboardSnapshot_(ss);
  syncSummarySheets_(ss, snap);
  return {
    ok: true,
    total_overall: snap.overall_list.length,
    total_pplga: snap.pplga_list.length,
    total_pplgb: snap.pplgb_list.length
  };
}

function doGet(e) {
  try {
    var params = (e && e.parameter) ? e.parameter : {};
    var nama = String(params.nama || "").trim();
    var absen = String(params.absen || "").trim();
    var kelas = String(params.kelas || "").trim();

    var snap = getLeaderboardSnapshot_();
    var myInfo = findPersonalRank_(snap, nama, absen, kelas);

    var response = {
      ok: true,
      updated_at: snap.updated_at,
      total_overall: snap.overall_list.length,
      total_pplga: snap.pplga_list.length,
      total_pplgb: snap.pplgb_list.length,
      overall_top10: snap.overall_list.slice(0, 10),
      pplga_top10: snap.pplga_list.slice(0, 10),
      pplgb_top10: snap.pplgb_list.slice(0, 10),
      my_info: myInfo
    };

    return ContentService
      .createTextOutput(JSON.stringify(response))
      .setMimeType(ContentService.MimeType.JSON);
  } catch (err) {
    return ContentService
      .createTextOutput(JSON.stringify({ ok: false, error: String(err) }))
      .setMimeType(ContentService.MimeType.JSON);
  }
}

function doPost(e) {
  var lock = LockService.getScriptLock();
  lock.waitLock(15000);
  try {
    var raw = (e && e.postData && e.postData.contents) ? e.postData.contents : "{}";
    var data = JSON.parse(raw);
    var ss = SpreadsheetApp.getActiveSpreadsheet();

    if (data.event === "BATCH_SYNC" && Array.isArray(data.items)) {
      var latestSummary = null;
      var logItems = [];
      for (var i = 0; i < data.items.length; i++) {
        var item = data.items[i] || {};
        if (item.event === "LEVEL_LOG") {
          logItems.push(item);
        }
        latestSummary = item;
      }
      if (logItems.length > 0) {
        appendAnswerLogsBatch_(ss, logItems);
      }
      if (latestSummary) {
        upsertClassRow_(ss, latestSummary);
      }
    } else {
      processSingleEvent_(ss, data);
    }

    // Pastikan formula Rata-rata di PPLGA/PPLGB selesai dihitung sebelum menyinkronkan sheet rekap
    SpreadsheetApp.flush();
    CacheService.getScriptCache().remove(CACHE_KEY_SNAPSHOT);
    var freshSnap = buildLeaderboardSnapshot_(ss);
    syncSummarySheets_(ss, freshSnap);
    try {
      CacheService.getScriptCache().put(CACHE_KEY_SNAPSHOT, JSON.stringify(freshSnap), CACHE_TTL_SECONDS);
    } catch (_cacheErr) {}

    return ContentService
      .createTextOutput(JSON.stringify({ ok: true, event: data.event || "unknown" }))
      .setMimeType(ContentService.MimeType.JSON);
  } catch (err) {
    return ContentService
      .createTextOutput(JSON.stringify({ ok: false, error: String(err) }))
      .setMimeType(ContentService.MimeType.JSON);
  } finally {
    lock.releaseLock();
  }
}

function processSingleEvent_(ss, data) {
  if (!data) {
    return;
  }
  if (data.event === "LEVEL_LOG") {
    appendAnswerLogsBatch_(ss, [data]);
    upsertClassRow_(ss, data);
  } else if (data.event === "SESSION_START" || data.event === "SESSION_FINISH" || data.event === "SESSION_SYNC") {
    upsertClassRow_(ss, data);
  }
}

function getClassSheetName_(kelas) {
  var norm = String(kelas || "").toUpperCase().replace(/\s+/g, "");
  if (norm === "PPLGB") {
    return "PPLGB";
  }
  return "PPLGA";
}

function upsertClassRow_(ss, data) {
  var nama = String(data.nama || "").trim();
  if (!nama) {
    return;
  }
  var absen = String(data.absen || "").trim();
  var sheetName = getClassSheetName_(data.kelas);
  var sheet = ss.getSheetByName(sheetName);
  if (!sheet) {
    sheet = ensureClassSheet_(ss, sheetName);
  }

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
    if (inc !== undefined && inc !== null && inc !== "" && Number(inc) > 0) {
      var curNum = (existingScores[g] !== "" && existingScores[g] !== null) ? Number(existingScores[g]) : 0;
      finalScores.push(Math.max(curNum, Number(inc)));
    } else if (existingScores[g] !== "" && existingScores[g] !== null) {
      finalScores.push(existingScores[g]);
    } else {
      finalScores.push("");
    }
  }

  // Tulis hanya kolom B..H agar formula di kolom A (No) dan I (Rata-rata) tetap utuh.
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

function ensureHasilKeseluruhanSheet_(ss) {
  var sheet = ss.getSheetByName("HasilKeseluruhan");
  if (!sheet) {
    sheet = ss.insertSheet("HasilKeseluruhan");
    sheet.appendRow(["No", "Nama", "Absen", "Kelas", "Rata-rata"]);
  } else if (sheet.getLastRow() < 1) {
    sheet.appendRow(["No", "Nama", "Absen", "Kelas", "Rata-rata"]);
  }
  return sheet;
}

function ensureLeaderBoardSheet_(ss) {
  var sheet = ss.getSheetByName("LeaderBoard");
  if (!sheet) {
    sheet = ss.insertSheet("LeaderBoard");
    sheet.appendRow(["Rank", "Nama", "Kelas", "Poin"]);
  } else if (sheet.getLastRow() < 1) {
    sheet.appendRow(["Rank", "Nama", "Kelas", "Poin"]);
  }
  return sheet;
}

/**
 * Menyinkronkan sheet HasilKeseluruhan (gabungan PPLGA + PPLGB) dan LeaderBoard (Top 10)
 * secara langsung dari nilai PPLGA & PPLGB tanpa bergantung pada rumus lintas-locale.
 */
function syncSummarySheets_(ss, snap) {
  var dataSnap = snap || buildLeaderboardSnapshot_(ss);
  var overall = dataSnap.overall_list || [];

  // 1. Sinkron sheet HasilKeseluruhan (A: No, B: Nama, C: Absen, D: Kelas, E: Rata-rata)
  var hasilSheet = ensureHasilKeseluruhanSheet_(ss);
  var hasilClearRows = Math.max(hasilSheet.getLastRow() - 1, overall.length, 1);
  if (hasilClearRows > 0) {
    hasilSheet.getRange(2, 1, hasilClearRows, 5).clearContent();
  }
  if (overall.length > 0) {
    var hasilRows = [];
    for (var i = 0; i < overall.length; i++) {
      var it = overall[i];
      hasilRows.push([
        i + 1,
        it.nama,
        it.absen === "" ? "" : (isNaN(Number(it.absen)) ? it.absen : Number(it.absen)),
        it.kelas,
        it.poin
      ]);
    }
    hasilSheet.getRange(2, 1, hasilRows.length, 5).setValues(hasilRows);
  }

  // 2. Sinkron sheet LeaderBoard (A: Rank 1..10, B: Nama, C: Kelas, D: Poin)
  var lbSheet = ensureLeaderBoardSheet_(ss);
  var lbClearRows = Math.max(lbSheet.getLastRow() - 1, 10);
  if (lbClearRows > 0) {
    lbSheet.getRange(2, 2, lbClearRows, 3).clearContent();
  }
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

function appendAnswerLogsBatch_(ss, items) {
  var sheet = ss.getSheetByName("LogJawaban");
  if (!sheet) {
    sheet = ss.insertSheet("LogJawaban");
    sheet.appendRow([
      "Timestamp", "Session_ID", "Nama", "Kelas", "Absen",
      "Minigame_ID", "Level_ID", "Jawaban_Siswa", "Kunci_Jawaban",
      "Hasil", "Percobaan_Ke", "Poin", "Durasi_Detik"
    ]);
  }

  // Cegah duplikasi log bila terjadi retry jaringan (cek 100 baris terakhir)
  var seen = {};
  var lastRow = sheet.getLastRow();
  if (lastRow >= 2) {
    var startRow = Math.max(2, lastRow - 99);
    var existing = sheet.getRange(startRow, 2, lastRow - startRow + 1, 10).getValues(); // B..K
    for (var r = 0; r < existing.length; r++) {
      var sid = String(existing[r][0] || "");
      var lid = String(existing[r][5] || "");
      var att = String(existing[r][9] || "");
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
    rowsToAdd.push([
      new Date(),
      kSid,
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
  }

  if (rowsToAdd.length > 0) {
    var insertAt = Math.max(2, sheet.getLastRow() + 1);
    sheet.getRange(insertAt, 1, rowsToAdd.length, 13).setValues(rowsToAdd);
  }
}

function buildLeaderboardSnapshot_(ss) {
  var pplgaList = readClassRanking_(ss.getSheetByName("PPLGA"), "PPLG A");
  var pplgbList = readClassRanking_(ss.getSheetByName("PPLGB"), "PPLG B");

  // Clone objek agar penetapan rank keseluruhan tidak menimpa rank per-kelas di pplgaList/pplgbList!
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
    updated_at: new Date().toISOString(),
    overall_list: overallList,
    pplga_list: pplgaList,
    pplgb_list: pplgbList
  };
}

function getLeaderboardSnapshot_() {
  var cache = CacheService.getScriptCache();
  var cached = cache.get(CACHE_KEY_SNAPSHOT);
  if (cached) {
    try {
      return JSON.parse(cached);
    } catch (_e) {}
  }

  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var snap = buildLeaderboardSnapshot_(ss);
  // Ikut perbarui HasilKeseluruhan & LeaderBoard saat cache refresh (mis. setelah guru menghapus baris manual)
  try {
    syncSummarySheets_(ss, snap);
  } catch (_syncErr) {}
  try {
    cache.put(CACHE_KEY_SNAPSHOT, JSON.stringify(snap), CACHE_TTL_SECONDS);
  } catch (_e2) {}
  return snap;
}

function readClassRanking_(sheet, kelasLabel) {
  if (!sheet) {
    return [];
  }
  var lastRow = sheet.getLastRow();
  if (lastRow < 2) {
    return [];
  }
  var values = sheet.getRange(2, 2, lastRow - 1, 8).getValues(); // B..I
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

function findPersonalRank_(snap, nama, absen, kelas) {
  if (!nama) {
    return { found: false };
  }
  var keyName = nama.toLowerCase();
  var keyAbsen = String(absen || "").trim();
  var hasKelas = String(kelas || "").trim() !== "";
  var keyKelas = getClassSheetName_(kelas);

  var overallRank = 0;
  var myPoin = 0;
  var myScores = [0, 0, 0, 0, 0];
  for (var i = 0; i < snap.overall_list.length; i++) {
    var item = snap.overall_list[i];
    var kelasMatch = !hasKelas || (getClassSheetName_(item.kelas) === keyKelas);
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
