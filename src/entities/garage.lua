-- The 6 selectable cars, in menu order (3 ROAD + 3 RACE).
-- XOROZ edition: race and road categories stay separated by default.
local garage = {
  require("src/entities/vehicles/hot_hatch"),
  require("src/entities/vehicles/rocket"),
  require("src/entities/vehicles/paname"),
  require("src/entities/vehicles/formula_kid"),
  require("src/entities/vehicles/pursa_gt3"),
  require("src/entities/vehicles/formula_1_1988"),
}

garage.CATEGORIES = { "road", "race" }
garage.CATEGORY_NAMES = { road = "ROAD", race = "RACE" }

function garage.byId(id)
  for _, spec in ipairs(garage) do
    if spec.id == id then return spec end
  end
  return garage[1]
end

function garage.byCategory(category)
  local out = {}
  for _, spec in ipairs(garage) do
    if spec.category == category then out[#out + 1] = spec end
  end
  return #out > 0 and out or garage
end

return garage
