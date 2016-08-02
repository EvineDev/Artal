require "setup"

deepAssert(
  {
    width = 128,
    height = 128,
    {
      name = "bottom",
    },
    {
      name = "group",
    },
    {
      name = "child 1",
    },
    {
      name = "child 2",
    },
    {
      name = "group",
    },
    {
      name = "top",
    },
  },
  artal.newPSD("cases/hierarchy.psd", "info")
)
