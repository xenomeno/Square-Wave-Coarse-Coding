dofile("Bitmap.lua")
dofile("Graphics.lua")

local FEATURES                = 50
local ALPHA                   = 0.2
local EXAMPLES                = {10, 40, 160, 640, 2560, 10240}
local FEATURE_WIDTHS          = {0.1, 0.25, 0.6}

local SQUARE_LEFT             = 0.0
local SQUARE_RIGHT            = 2.0
local SQUARE_MIN              = 0.0
local SQUARE_MAX              = 1.0
local SQUARE_WIDTH            = SQUARE_RIGHT - SQUARE_LEFT
local SQUARE_HEIGHT           = SQUARE_MAX - SQUARE_MIN
local SQUARE_LEFT_DOWN        = 0.30
local SQUARE_LEFT_UP          = 0.35
local SQUARE_RIGHT_UP         = 0.65
local SQUARE_RIGHT_DOWN       = 0.70

local IMAGE_WIDTH             = 540
local IMAGE_HEIGHT            = 540
local IMAGE_FILENAME          = "SquareWave/SquareWave.bmp"

local function SquareWave(x)
  if x < SQUARE_WIDTH * SQUARE_LEFT_DOWN then
    return SQUARE_MIN
  elseif x < SQUARE_WIDTH * SQUARE_LEFT_UP then
    return SQUARE_MIN + (x - SQUARE_WIDTH * SQUARE_LEFT_DOWN) * SQUARE_HEIGHT / ((SQUARE_LEFT_UP - SQUARE_LEFT_DOWN)  * SQUARE_WIDTH)
  elseif x < SQUARE_WIDTH * SQUARE_RIGHT_UP then
    return SQUARE_MAX
  elseif x < SQUARE_WIDTH * SQUARE_RIGHT_DOWN then
    return SQUARE_MAX - (x - SQUARE_WIDTH * SQUARE_RIGHT_UP) * SQUARE_HEIGHT / ((SQUARE_RIGHT_DOWN - SQUARE_RIGHT_UP) * SQUARE_WIDTH)
  else
    return SQUARE_MIN
  end
end

local function GetSample()
  local x = SQUARE_LEFT + math.random() * SQUARE_WIDTH
  local y = SquareWave(x)
  
  return x, y
end

local ValueFunction =
{
  features = false,
  feature_width = false,
  interval_starts = false,
  weight = false,
}

function ValueFunction:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  
  if o.features then
    o:Init()
  end
  
  return o
end

function ValueFunction:Init()
  self.alpha = self.alpha / self.features
  local start = SQUARE_LEFT - self.feature_width / 2
  self.interval_starts, self.weights = {}, {}
  for f = 1, self.features do
    self.interval_starts[f] = start + math.random() * SQUARE_WIDTH
    self.weights[f] = 0.0
  end
end

function ValueFunction:GetValue(x)
  local interval_starts, weights = self.interval_starts, self.weights
  local feature_width = self.feature_width
  
  local value = 0
  for f, interval_start in ipairs(interval_starts) do
    if x >= interval_start and x < interval_start + feature_width then
      value = value + weights[f]
    end
  end
  
  return value
end

function ValueFunction:Update(x, delta)
  local interval_starts, weights = self.interval_starts, self.weights
  local feature_width = self.feature_width
  
  for f, interval_start in ipairs(interval_starts) do
    if x >= interval_start and x < interval_start + feature_width then
      weights[f] = weights[f] + delta
    end
  end
end

function ValueFunction:Train(x, y)
  local value = self:GetValue(x)
  local delta = self.alpha * (y - value)
  self:Update(x, delta)
end

local function CoarseCoding(train_samples, feature_width)
  local VF = ValueFunction:new{features = FEATURES, feature_width = feature_width, alpha = ALPHA}
  for sample = 1, train_samples do
    local x, y = GetSample()
    VF:Train(x, y)
  end
  
  local graphs = {funcs = {}, name_x = string.format("Feature Width: %.2f", feature_width), name_y = string.format("#%d Samples", train_samples)}
  local points = {color = RGB_GREEN}
  for k = 1, IMAGE_WIDTH do
    local x = SQUARE_LEFT + (SQUARE_RIGHT - SQUARE_LEFT) * (k - 1) / (IMAGE_WIDTH - 1)
    local y = VF:GetValue(x)
    points[k] = {x = x, y = y}
  end
  graphs.funcs[string.format("Coarse Coded Square Wave", train_samples, feature_width)] = points
  
  local points = {color = RGB_BLUE}
  for k = 1, IMAGE_WIDTH do
    local x = SQUARE_LEFT + (SQUARE_RIGHT - SQUARE_LEFT) * (k - 1) / (IMAGE_WIDTH - 1)
    local y = SquareWave(x)
    points[k] = {x = x, y = y}
  end
  graphs.funcs["Desired Function"] = points
  
  return graphs, VF
end

local bmp = Bitmap.new(IMAGE_WIDTH * #FEATURE_WIDTHS, IMAGE_HEIGHT * #EXAMPLES, RGB_BLACK)
local graphs_descr = {skip_KP = true, scale_uniformly = true, width = IMAGE_WIDTH, height = IMAGE_HEIGHT}
for row, train_samples in ipairs(EXAMPLES) do
  graphs_descr.start_y = (row - 1) * IMAGE_HEIGHT
  for col, feature_width in ipairs(FEATURE_WIDTHS) do
    graphs_descr.start_x = (col - 1) * IMAGE_WIDTH
    math.randomseed(0)
    local graphs, VF = CoarseCoding(train_samples, feature_width * SQUARE_WIDTH)
    DrawGraphs(bmp, graphs, graphs_descr)
  end
end
bmp:WriteBMP(IMAGE_FILENAME)
