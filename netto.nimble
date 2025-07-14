# Package

version       = "0.1.1"
author        = "madonuko"
description   = "GUI Network Applet"
license       = "GPL-3.0-or-later"
srcDir        = "src"
bin           = @["netto"]

# Dependencies

requires "nim >= 2.0.0"
requires "https://github.com/madonuko/libnm.nim >= 1.52.0"
requires "chronicles >= 0.11.0"
requires "sweet >= 0.1.3"
requires "https://github.com/madonuko/owlkettle#73bf54a"
requires "fungus >= 0.1.19"
