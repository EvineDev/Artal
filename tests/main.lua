local tests = {
  "hierarchy"
}

for i, file in ipairs(tests) do
  local test = {
    thread = love.thread.newThread(file .. '.lua'),
    name = file
  }
  test.thread:start()
  tests[i] = test
end

local RUNNING, SUCCESS, FAILED = {255, 255, 0}, {0, 255, 0}, {255, 0, 0}

function love.draw()
  love.graphics.push()
  for i, test in ipairs(tests) do
    local color
    if test.thread:isRunning() then
      color = RUNNING
    else
      if test.error then
        color = FAILED
      elseif test.thread:getError() then
        color = FAILED
        test.error = test.thread:getError()
      else
        color = SUCCESS
      end
    end
    love.graphics.setColor(color)
    love.graphics.circle("fill", 10, 10, 6)
    love.graphics.translate(20, 0)
  end
  love.graphics.pop()

  local hovered = tests[math.ceil(love.mouse.getX() / 20)]
  if hovered then
    love.graphics.setColor(255, 255, 255)
    love.graphics.print(hovered.name, 10, 30)
    if hovered.error then
      love.graphics.printf(hovered.error, 10, 50, love.graphics.getWidth() - 20)
    end
  end
end

function love.keypressed(key)
  if key == "escape" then love.event.push "quit" end
end
