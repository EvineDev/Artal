require "setup"

local info = artal.newPSD("cases/folder_test.psd", "info")
local test = {name = "Really long name and filled with weird unicode characters from my native land from årdal and øl æ fint"}
deepAssert(test, info[2])
deepAssert(test, info[3])