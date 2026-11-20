-- XOROZ 6-car garage, categories, 1-5 star stats, TOP view, ghost default ON,
-- player name on records/ghosts, and in-game changelog.
local h = require("tests.harness")
local Race = require("src.sim.race")
local Track = require("src.sim.track")
local catalog = require("src.tracks.catalog")
local garage = require("src.entities.garage")
local dynamics = require("src.sim.dynamics")
local stats = require("src.sim.car_stats")
local AI = require("src.ai_controller")
local config = require("src.config")

local DT = config.PHYSICS_DT

local function lapOn(spec, assist)
  local track = Track.new(catalog.find("mugello").def)
  local race = Race.new({ mode = "race", track = track, laps = 1, opponents = 0, spec = spec,
    assist = assist, seed = 7, startDelay = 0.5 })
  race.player.driver = AI.new(track, race.player, { skill = 1.0 })
  local t = 0
  while not race.player.finished and t < 300 do
    race:step(DT)
    t = t + DT
  end
  local finished, time = race.player.finished, race.player.finishTime
  race:destroy()
  return finished and time or math.huge
end

h.describe("garage and categories", function()
  h.it("has exactly 6 cars: 3 ROAD (FWD, RWD, AWD) and 3 RACE", function()
    h.assertEq(#garage, 6, "6 cars total")
    local road, race = garage.byCategory("road"), garage.byCategory("race")
    h.assertEq(#road, 3, "3 road cars")
    h.assertEq(#race, 3, "3 race cars")
    local drives = {}
    for _, spec in ipairs(road) do drives[spec.drive] = true end
    h.assertTrue(drives.FWD and drives.RWD and drives.AWD, "road cars cover FWD, RWD and AWD")
    h.assertEq(garage.byId("pursa_gt3").drive, "AWD", "PURSA GT3 is AWD")
    h.assertEq(garage.byId("paname").drive, "AWD", "PANAME is AWD")
  end)

  h.it("keeps ROAD and RACE opponents separate by default", function()
    local track = Track.new(catalog.find("mugello").def)
    for _, id in ipairs({ "hot_hatch", "formula_kid" }) do
      local spec = garage.byId(id)
      local race = Race.new({ mode = "race", track = track, laps = 1, opponents = 4, spec = spec, seed = 5, startDelay = 0.5 })
      for i = 2, #race.cars do
        h.assertEq(race.cars[i].spec.category, spec.category, race.cars[i].name .. " matches " .. spec.category)
      end
      race:destroy()
    end
  end)

  h.it("race cars are faster than road cars on track", function()
    local roadLap = lapOn(garage.byId("hot_hatch"), "arcade")
    local f3Lap = lapOn(garage.byId("formula_kid"), "arcade")
    local f1Lap = lapOn(garage.byId("formula_1_1988"), "arcade")
    print(string.format("        mugello arcade: HOT HATCH %.1fs  FORMULA KID %.1fs  F1 1988 %.1fs", roadLap, f3Lap, f1Lap))
    h.assertTrue(f3Lap < roadLap, "FORMULA KID beats HOT HATCH")
    h.assertTrue(f1Lap < f3Lap, "FORMULA 1 1988 beats FORMULA KID")
  end)
end)

h.describe("easy handling", function()
  h.it("is ARCADE with half as much grip again", function()
    local easy, arcade = dynamics.ASSISTS.easy, dynamics.ASSISTS.arcade
    h.assertNear(easy.grip, arcade.grip * 1.5, 1e-9, "grip")
    for k, v in pairs(arcade) do
      if k ~= "grip" then h.assertEq(easy[k], v, k) end
    end
  end)

  h.it("lets every car steer to a tighter line than ARCADE", function()
    for _, spec in ipairs(garage) do
      local easy = dynamics.steerLimit(dynamics.new(spec, "easy"), 40)
      local arcade = dynamics.steerLimit(dynamics.new(spec, "arcade"), 40)
      h.assertTrue(easy > arcade, spec.name)
    end
  end)

  h.it("is the player's alone: the AI drives ARCADE", function()
    local track = Track.new(catalog.builtin()[1].def)
    local race = Race.new({ mode = "race", track = track, laps = 1, opponents = 3, spec = garage[1],
      assist = "easy", seed = 3, startDelay = 1 })
    h.assertEq(race.player.model.assist, dynamics.ASSISTS.easy, "player on EASY")
    for i = 2, #race.cars do
      h.assertEq(race.cars[i].model.assist, dynamics.ASSISTS.arcade, race.cars[i].name)
    end
    race:destroy()
  end)

  h.it("laps quicker than ARCADE in the same hands", function()
    for _, id in ipairs({ "hot_hatch", "formula_kid" }) do
      local spec = garage.byId(id)
      local easy, arcade = lapOn(spec, "easy"), lapOn(spec, "arcade")
      print(string.format("        %-15s easy %.1fs  arcade %.1fs", spec.name, easy, arcade))
      h.assertTrue(easy < math.huge, spec.name .. " finishes on EASY")
      h.assertTrue(easy < arcade, spec.name .. " is quicker on EASY")
    end
  end)

  h.it("isn't used online, where everyone shares ARCADE", function()
    h.assertEq(dynamics.DEFAULT_ASSIST, "arcade")
  end)
end)

h.describe("car stats (1-5 stars)", function()
  for _, spec in ipairs(garage) do
    h.it(spec.name .. " has all five stats scored 0..1 and 1..5 stars", function()
      local s = stats.of(spec)
      print(string.format("        %-15s [%s] %-3s MAX %.0f km/h | SPD:%d* ACC:%d*(%.1fs) BRK:%d* HND:%d* TIR:%d*(%.2fg)",
        spec.name, spec.category:upper(), spec.drive, s.speed.value,
        s.speed.stars, s.accel.stars, s.accel.value, s.brake.stars, s.handling.stars, s.tires.stars, s.tires.value))
      for _, key in ipairs(stats.ORDER) do
        h.assertTrue(s[key], key)
        h.assertBetween(s[key].score, 0, 1, key)
        h.assertBetween(s[key].stars, 1, 5, key .. " stars")
        h.assertTrue(#s[key].text > 0, key .. " text")
      end
      h.assertTrue(stats.of(spec) == s, "measured once")
    end)
  end

  h.it("ranks FORMULA 1 1988 faster than HOT HATCH and FORMULA KID highest grip", function()
    local f1 = stats.of(garage.byId("formula_1_1988"))
    local f3 = stats.of(garage.byId("formula_kid"))
    local hatch = stats.of(garage.byId("hot_hatch"))
    h.assertTrue(f1.speed.value > hatch.speed.value, "F1 1988 is faster than HOT HATCH")
    h.assertTrue(f1.accel.value < hatch.accel.value, "F1 1988 accelerates faster")
    h.assertTrue(f3.tires.value > hatch.tires.value, "FORMULA KID has much grippier soft tyres")
  end)
end)

h.describe("defaults, player name, ghost and changelog", function()
  local rm = require("src.race_manager")
  local menu = require("src.menu")
  local settings = require("src.settings")

  h.it("defaults to TOP camera, ghost ON, Mugello, and saves player name on records and ghosts", function()
    love.filesystem.remove("settings.lua")
    love.filesystem.remove("records.lua")
    settings.camera = "top"
    settings.selectedGhost = 1
    settings.playerName = "XOROZ"
    settings.save()
    settings.playerName = "OTHER"
    settings.load()
    h.assertEq(settings.camera, "top", "TOP camera default")
    h.assertEq(settings.selectedGhost, 1, "ghost default ON")
    h.assertEq(settings.playerName, "XOROZ", "player name persists")
    local frames = {}
    for i = 1, 60 do frames[#frames + 1] = i frames[#frames + 1] = i frames[#frames + 1] = 0 end
    settings.submitLap("mugello", "formula_kid", 58.25, frames, "clean")
    local top = settings.topGhosts("mugello")
    h.assertEq(top[1].name, "XOROZ", "ghost saved with player name")
    local recs = settings.trackRecords("mugello")
    h.assertEq(recs[1].name, "XOROZ", "record saved with player name")
    love.filesystem.remove("settings.lua")
    love.filesystem.remove("records.lua")
  end)

  h.it("loads CHANGELOG.md inside the game", function()
    local lines = menu.loadChangelogLines()
    h.assertTrue(type(lines) == "table" and #lines > 5, "changelog lines loaded")
  end)

  local function trialFromMenu(selected)
    settings.mode, settings.track, settings.selectedGhost = "trial", "mugello", selected
    menu.startRace()
    local race = rm.race()
    race.player.driver = AI.new(race.track, race.player, { skill = 0.95 })
    local t = 0
    while race.player.lapsDone < 2 and t < 300 do rm.update(1 / 30) t = t + 1 / 30 end
    h.assertTrue(race.player.lapsDone >= 2, "two laps done")
    local ghost = rm.ghost()
    rm.stop()
    return ghost
  end

  h.it("OFF shows no ghost in time trial, even after a best lap", function()
    h.assertEq(trialFromMenu(0), nil)
  end)

  h.it("a chosen ghost still races alongside", function()
    local frames = {}
    for i = 1, 60 do frames[#frames + 1] = i frames[#frames + 1] = i frames[#frames + 1] = 0 end
    settings.submitLap("mugello", "formula_kid", 59.5, frames, "clean", { hue = 1, name = "XOROZ" })
    h.assertTrue(#settings.topGhosts("mugello") >= 1, "a ghost to pick")
    h.assertTrue(trialFromMenu(1) ~= nil, "ghost #1 loaded")
  end)

  h.it("shipped car stats match how each car drives now (else run make car-stats)", function()
    for _, spec in ipairs(garage) do
      local shipped = stats.shipped[spec.id]
      h.assertTrue(shipped ~= nil, spec.name .. " has no shipped stats")
      local now = stats.round(stats.measure(spec))
      for _, key in ipairs(stats.ORDER) do
        h.assertNear(shipped[key], now[key], math.abs(now[key]) * 0.005 + 1e-9, spec.name .. " " .. key)
      end
    end
  end)
end)
