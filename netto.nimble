# Package

version       = "0.1.0"
author        = "madonuko"
description   = "GUI Network Applet"
license       = "GPL-3.0-or-later"
srcDir        = "src"
bin           = @["netto"]

# Dependencies

requires "nim >= 2.0.0"
requires "futhark"
requires "https://github.com/madonuko/libnm.nim >= 1.52.0"
requires "chronicles >= 0.11.0"
requires "results >= 0.5.1"
requires "sweet >= 0.1.3"
requires "https://github.com/madonuko/owlkettle#aa9bddb3a626138fd46900a23b0cfbeeebe252b9"
