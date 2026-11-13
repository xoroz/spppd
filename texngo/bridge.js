(function () {
  var PREFIX = "SPPPD_API|";
  var API_URL = "api/records";
  var lastSaveDir = "";

  function luaString(val) {
    return '"' + String(val || "").replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/[\r\n]/g, " ") + '"';
  }

  function tracksToLua(tracks) {
    if (!tracks || typeof tracks !== "object") return "return {}\n";
    var lines = ["return {"];
    var trackNames = Object.keys(tracks).sort();
    for (var i = 0; i < trackNames.length; i++) {
      var tname = trackNames[i];
      var list = tracks[tname];
      if (!Array.isArray(list) || list.length === 0) continue;
      lines.push("  [" + luaString(tname) + "] = {");
      for (var j = 0; j < list.length && j < 5; j++) {
        var e = list[j];
        if (!e || typeof e.time !== "number" || !Array.isArray(e.ghost) || e.ghost.length < 6) continue;
        var nums = [];
        for (var k = 0; k < e.ghost.length; k++) {
          var n = Number(e.ghost[k]);
          if (isFinite(n)) nums.push(String(n));
        }
        if (nums.length < 6) continue;
        lines.push(
          "    [" + (j + 1) + "] = { " +
            '["time"] = ' + Number(e.time) + ", " +
            '["car"] = ' + luaString(e.car || "hot_hatch") + ", " +
            '["hue"] = ' + ( parseInt(e.hue, 10) || 1 ) + ", " +
            '["name"] = ' + luaString(e.name || "YOU") + ", " +
            '["rules"] = ' + luaString(e.rules === "open" ? "open" : "clean") + ", " +
            '["ghost"] = { ' + nums.join(", ") + " } },"
        );
      }
      lines.push("  },");
    }
    lines.push("}\n");
    return lines.join("\n");
  }

  function ensureDir(dir) {
    if (!dir || typeof Module === "undefined" || !Module.FS_createPath) return;
    var parts = dir.split("/").filter(Boolean);
    var current = "/";
    for (var i = 0; i < parts.length; i++) {
      try {
        Module.FS_createPath(current, parts[i], true, true);
      } catch (_err) {}
      current = (current === "/" ? "" : current) + "/" + parts[i];
    }
  }

  function writeSyncStatus(dir, status) {
    if (!dir || typeof Module === "undefined" || !Module.FS_createDataFile) return;
    try {
      ensureDir(dir);
      var target = dir.replace(/\/+$/, "") + "/central-sync-status.txt";
      try {
        if (Module.FS && Module.FS.unlink) {
          Module.FS.unlink(target);
        }
      } catch (_err) {}
      Module.FS_createDataFile(dir, "central-sync-status.txt", String(status || "local"), true, true, true);
    } catch (_err) {}
  }

  function writeSyncFile(dir, tracks) {
    if (!dir || typeof Module === "undefined" || !Module.FS_createDataFile) return;
    try {
      ensureDir(dir);
      var target = dir.replace(/\/+$/, "") + "/central-sync.lua";
      try {
        if (Module.FS && Module.FS.unlink) {
          Module.FS.unlink(target);
        }
      } catch (_err) {}
      var content = tracksToLua(tracks);
      Module.FS_createDataFile(dir, "central-sync.lua", content, true, true, true);
    } catch (_err) {}
  }

  function requestRecords(dir, method, bodyJson) {
    var options = {
      method: method || "GET",
      headers: { Accept: "application/json" },
      cache: "no-store",
    };
    if (bodyJson) {
      options.headers["Content-Type"] = "application/json";
      options.body = bodyJson;
    }
    fetch(API_URL, options)
      .then(function (res) {
        if (!res.ok) throw new Error("HTTP " + res.status);
        return res.json();
      })
      .then(function (data) {
        var targetDir = dir || lastSaveDir;
        if (data && data.tracks) {
          writeSyncFile(targetDir, data.tracks);
        }
        writeSyncStatus(targetDir, "central");
      })
      .catch(function () {
        // Offline or central server unreachable: signal local fallback cleanly
        writeSyncStatus(dir || lastSaveDir, "local");
      });
  }

  function handleLine(text) {
    var raw = String(text || "");
    var lines = raw.split(/\r?\n/);
    var passthrough = [];
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      if (line.indexOf(PREFIX) === 0) {
        var rest = line.slice(PREFIX.length);
        var p1 = rest.indexOf("|");
        if (p1 !== -1) {
          var saveDir = rest.slice(0, p1);
          var rem = rest.slice(p1 + 1);
          var p2 = rem.indexOf("|");
          var cmd = p2 === -1 ? rem : rem.slice(0, p2);
          var payload = p2 === -1 ? "" : rem.slice(p2 + 1);
          if (saveDir) lastSaveDir = saveDir;
          if (cmd === "fetch") {
            requestRecords(saveDir, "GET", null);
          } else if (cmd === "submit" && payload) {
            requestRecords(saveDir, "POST", payload);
          }
        }
      } else if (line.length > 0) {
        passthrough.push(line);
      }
    }
    return passthrough.join("\n");
  }

  function patchModule() {
    if (typeof window === "undefined" || !window.Module) return false;
    var mod = window.Module;
    if (mod.__spppdBridgePatched) return true;
    mod.__spppdBridgePatched = true;

    try {
      var params = new URLSearchParams(window.location.search || "");
      var testFilter = params.get("test");
      if (testFilter && Array.isArray(mod.arguments)) {
        mod.arguments.push("--test");
        if (testFilter !== "1" && testFilter !== "all") {
          mod.arguments.push(testFilter);
        }
      }
    } catch (_err) {}

    var prevPrint = typeof mod.print === "function" ? mod.print.bind(mod) : function (t) { console.log(t); };
    mod.print = function (text) {
      var filtered = handleLine(text);
      if (filtered) prevPrint(filtered);
    };
    return true;
  }

  if (!patchModule()) {
    var timer = setInterval(function () {
      if (patchModule()) clearInterval(timer);
    }, 20);
  }
})();
