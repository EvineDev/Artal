require "setup"

local info = artal.newPSD("cases/unicode_names.psd", "info")

deepAssert({ name = "very long ☭ unicode name with extra characters wow is this long"}, info[1])
