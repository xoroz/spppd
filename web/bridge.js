// Bridge between the game (Lua in love.js) and the page: the browser window's size.
// Lua can't see the browser window, so it prints a request line:
//   SPPPD_WEB|<save dir>|hello     -> the page starts writing <save dir>/viewport.txt
// viewport.txt holds "<width> <height> <phone>" of the browser window in CSS pixels,
// phone being 1 on a touch screen without a mouse; src/web.lua resizes the game's
// window to it, so the game fills the screen and follows rotation on a phone, and a
// phone gets the touch controls and the bigger menus.
// build.sh injects this file into the love.js index.html before game.js.
(function () {
  var PREFIX = "SPPPD_WEB|";
  var print = Module.print || console.log.bind(console);

  var saveDir = null;

  function writeFile(dir, name, text) {
    var path = dir.replace(/\/+$/, "");
    try { Module.FS_unlink(path + "/" + name); } catch (e) {}
    Module.FS_createPath("/", path.replace(/^\/+/, ""), true, true);
    Module.FS_createDataFile(path, name, text, true, true);
  }

  function sendViewport() {
    var phone = navigator.maxTouchPoints > 0 && window.matchMedia("(pointer: coarse)").matches ? 1 : 0;
    if (saveDir) writeFile(saveDir, "viewport.txt", window.innerWidth + " " + window.innerHeight + " " + phone + "\n");
  }
  window.addEventListener("resize", sendViewport);
  window.addEventListener("orientationchange", function () { setTimeout(sendViewport, 300); });

  // Browsers may deliver a press before the pointer move that led to it (moves are batched per
  // frame), and SDL takes a press's position from the last move. Replaying the move first keeps
  // taps and clicks on the menu rows where they were aimed.
  ["mousedown", "mouseup"].forEach(function (type) {
    window.addEventListener(type, function (e) {
      if (!e.isTrusted || !e.target || e.target.id !== "canvas") return;
      e.target.dispatchEvent(new MouseEvent("mousemove", {
        bubbles: true, clientX: e.clientX, clientY: e.clientY, screenX: e.screenX, screenY: e.screenY,
      }));
    }, true);
  });

  // Keys the game uses that the browser would otherwise take: scrolling, Tab focus, quick find.
  window.addEventListener("keydown", function (e) {
    if ([" ", "ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", "Tab", "/", "'"].indexOf(e.key) >= 0) {
      e.preventDefault();
    }
  }, { passive: false });

  Module.print = function (line) {
    if (typeof line === "string" && line.indexOf(PREFIX) === 0) {
      var parts = line.split("|");
      if (parts[2] === "hello") {
        saveDir = parts[1];
        sendViewport();
      }
    } else {
      print(line);
    }
  };
})();
