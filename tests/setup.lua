package.path = "../?.lua;" .. package.path

require "love.image"
require "love.graphics"
require "love.filesystem"
artal = require "artal"

function deepAssert(shape, table, path)
  path = path or ""

  for key, expected in pairs(shape) do
    local actual = table[key]
    if type(expected) ~= type(actual) then
      error(
        string.format(
          "type mismatch at '%s': expected %s but got '%s'",
          path .. "." .. key,
          type(expected),
          type(actual)
        )
      )
    end

    if type(expected) == "table" then
      deepAssert(expected, actual, path .. "." .. key)
    else
      assert(
        expected == actual,
        string.format(
          "value mismatch at '%s': expected %s '%s' but got %s '%s'",
          path .. "." .. key,
          type(expected), expected,
          type(actual), actual
        )
      )
    end
  end
end

