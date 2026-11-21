/**
 * Google Apps Script Web App untuk Spreadsheet "Data Game DOS"
 * (1_5KTFCkMfApJd6mqU1qBDhrvOMRTULbgtgTqdFUC5lo)
 *
 * Sheet yang dikelola:
 * 1. PPLGA            -> Nilai Game 1..5 & Rata-rata kelas PPLG A
 * 2. PPLGB            -> Nilai Game 1..5 & Rata-rata kelas PPLG B
 * 3. HasilKeseluruhan -> Otomatis terisi rumus QUERY(VSTACK(PPLGA; PPLGB))
 * 4. LeaderBoard      -> Otomatis terisi rumus Top 10 dari HasilKeseluruhan
 * 5. LogJawaban       -> Riwayat detail jawaban siswa dari awal hingga akhir
 *
 * Cara Deploy:
 * 1. Buka Spreadsheet -> Extensions -> Apps Script.
 * 2. Tempel seluruh kode ini -> Save.
 * 3. Deploy -> New deployment -> Web app -> Execute as: Me -> Who has access: Anyone.
 * 4. Salin URL Web App (/exec) ke data/game_config.json & docs/game_config.json field "apps_script_url".
 */

var CACHE_KEY_SNAPSHOT = "lb_snapshot_v1";
var CACHE_TTL_SECONDS = 15;

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

    CacheService.getScriptCache().remove(CACHE_KEY_SNAPSHOT);

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

  // Tulis hanya kolom B..H agar formula ARRAYFORMULA di kolom A (No) dan I (Rata-rata) tetap utuh.
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
  sheet.getRange("A2").setFormula('=ARRAYFORMULA(IF(B2:B="";"";ROW(B2:B)-1))');
  sheet.getRange("I2").setFormula('=ARRAYFORMULA(IF(B2:B="";"";(N(D2:D)+N(E2:E)+N(F2:F)+N(G2:G)+N(H2:H))/5))');
  return sheet;
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

function getLeaderboardSnapshot_() {
  var cache = CacheService.getScriptCache();
  var cached = cache.get(CACHE_KEY_SNAPSHOT);
  if (cached) {
    try {
      return JSON.parse(cached);
    } catch (_e) {}
  }

  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var pplgaList = readClassRanking_(ss.getSheetByName("PPLGA"), "PPLG A");
  var pplgbList = readClassRanking_(ss.getSheetByName("PPLGB"), "PPLG B");
  var overallList = pplgaList.concat(pplgbList);
  overallList.sort(function(a, b) {
    if (b.poin !== a.poin) {
      return b.poin - a.poin;
    }
    return a.nama.localeCompare(b.nama);
  });
  for (var i = 0; i < overallList.length; i++) {
    overallList[i].rank = i + 1;
  }

  var snap = {
    updated_at: new Date().toISOString(),
    overall_list: overallList,
    pplga_list: pplgaList,
    pplgb_list: pplgbList
  };
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
  var keyKelas = getClassSheetName_(kelas);

  var overallRank = 0;
  var myPoin = 0;
  var myScores = [0, 0, 0, 0, 0];
  for (var i = 0; i < snap.overall_list.length; i++) {
    var item = snap.overall_list[i];
    if (item.nama.toLowerCase() === keyName && (!keyAbsen || item.absen === keyAbsen)) {
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
