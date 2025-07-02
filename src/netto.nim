#[
  netto
  Copyright © 2025  madonuko <mado@fyralabs.com>

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along
  with this program; if not, write to the Free Software Foundation, Inc.,
  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
]#

import results
import libnm
import ./[wifi, errhdl]
import owlkettle, owlkettle/he

import std/[strutils, options, strformat]

viewable App: discard

method view(app: AppState): Widget = 
  result = gui:
    HeApplicationWindow:
      title = "Meow!"

      HeViewMono:
        showRightTitleButtons = true

        HeViewTitle(label = "HeViewTitle") {.title.}

        Box(orient = OrientY, spacing = 4, margin = 16):
          Label {.expand: false.}:
            text = "label!"
          HeButton {.expand: false, hAlign: AlignCenter.}:
            icon = "emote-love-symbolic"
            is_pill = true


proc main =
  let cli = nm_client_new(nil, nil)
  echo "netto"
  echo "nm client " & $cli.nm_client_get_version()
  let wifidev: ptr NMDeviceWifi = get get_wifi_device cli
  echo $nm_device_wifi_get_hw_address(wifidev)
  wifidev.scan[]
  for ap in wifidev.access_points:
    echo ap.ssid.get("<unknown ssid>").alignLeft(32) & &" {ap.needPasswd}"

  he.brew gui App()

main()
