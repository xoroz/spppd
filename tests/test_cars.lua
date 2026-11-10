-- EASY handling, the measured car stats and the TATUS.
local h = require("tests/harness")
local Race = require("src/sim/race")
local Track = require("src/sim/track")
local catalog = require("src/tracks/catalog")
local garage = require("src/entities/garage")
local dynamics = require("src/sim/dynamics")
local stats = require("src/sim/car_stats")
local AI = require("src/ai_controller")
local config = require("src/config")

local DT = config.PHYSICS_DT

-- One lap of Mirage with a bot at the wheel, on the given handling.
local function lapOn(spec, assist)
  local track = Track.new(catalog.find("mirage").def)
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
    for _, id in ipairs({ "hot_hatch", "tatus" }) do
      local spec = garage.byId(id)
      local easy, arcade = lapOn(spec, "easy"), lapOn(spec, "arcade")
      print(string.format("        %-10s easy %.1fs  arcade %.1fs", spec.name, easy, arcade))
      h.assertTrue(easy < math.huge, spec.name .. " finishes on EASY")
      h.assertTrue(easy < arcade, spec.name .. " is quicker on EASY")
    end
  end)

  h.it("isn't used online, where everyone shares ARCADE", function()
    h.assertEq(dynamics.DEFAULT_ASSIST, "arcade")
  end)
end)

h.describe("car stats", function()
  for _, spec in ipairs(garage) do
    h.it(spec.name .. " has all five, each scored 0..1", function()
      local s = stats.of(spec)
      for _, key in ipairs(stats.ORDER) do
        h.assertTrue(s[key], key)
        h.assertBetween(s[key].score, 0, 1, key)
        h.assertTrue(#s[key].text > 0, key .. " text")
      end
      h.assertTrue(stats.of(spec) == s, "measured once")
    end)
  end

  h.it("ranks the obvious ones the obvious way", function()
    local quad, hatch = stats.of(garage.byId("quad_turbo")), stats.of(garage.byId("hot_hatch"))
    h.assertTrue(quad.speed.value > hatch.speed.value, "QUAD TURBO is faster than the HOT HATCH")
    h.assertTrue(quad.accel.value < hatch.accel.value, "and gets to 100 sooner")
  end)
end)

h.describe("tatus", function()
  local tatus = garage.byId("tatus")

  h.it("is in the garage, at the end so saved picks keep their car", function()
    h.assertEq(tatus.id, "tatus")
    h.assertEq(garage[#garage], tatus)
  end)

  h.it("has the grippiest tyres and the lowest top speed", function()
    local mine = stats.of(tatus)
    for _, spec in ipairs(garage) do
      if spec ~= tatus then
        local other = stats.of(spec)
        h.assertTrue(mine.tires.value > other.tires.value, "tyres beat " .. spec.name)
        h.assertTrue(mine.speed.value < other.speed.value, "slower than " .. spec.name)
      end
    end
  end)

  h.it("handles in the middle of the pack", function()
    h.assertBetween(stats.of(tatus).handling.score, 0.35, 0.65, "handling")
  end)
end)

h.describe("load ghost", function()
  local rm = require("src/race_manager")
  local menu = require("src/menu")
  local settings = require("src/settings")

  local function trialFromMenu(selected)
    settings.mode, settings.track, settings.selectedGhost = "trial", "mirage", selected
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
    settings.submitLap("mirage", "tatus", 59.5, frames, "clean", { hue = 1, name = "TEST" })
    h.assertTrue(#settings.topGhosts("mirage") >= 1, "a ghost to pick")
    h.assertTrue(trialFromMenu(1) ~= nil, "ghost #1 loaded")
  end)
end)
