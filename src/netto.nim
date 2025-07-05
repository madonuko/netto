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

import chronicles
import results
import libnm
import ./[wifi, errhdl, chan]
import owlkettle, owlkettle/he
import fungus

import std/[strutils, options, strformat, sugar]

viewable App:
  chan: Chan
  client: ptr NMClient
  scanning: bool = true
  wifi_devices: seq[ptr NMDeviceWifi] = @[]
  selected_wifidev: int = 0

method view(app: AppState): Widget = 
  while app.chan.peek != 0:
    let msg = app.chan.recv
    debug "app.chan.recv", msg
    match msg:
    of FinEnableWireless as e:
      if e.isSome:
        warn "displaying MessageDialog"
        discard app.open: gui:
          MessageDialog:
            message = &"Error: {e.get}"
            DialogButton {.addButton.}:
              text = "Ok"
              res = DialogAccept
  result = gui:
    HeApplicationWindow:
      title = "Meow!"

      HeViewMono:
        showRightTitleButtons = true

        Box(orient = OrientY, spacing = 4, margin = 16):
          if app.wifi_devices.len == 0:
            HeEmptyPage:
              title = "No Wi-Fi Devices"
              description = "netto can't find any NMDeviceWifi."
              icon = "network-wireless-disabled-symbolic"
              buttonText = "" # FIXME: lains why does this button exist
          else:
            Box(orient = OrientX, spacing = 4, margin = 16) {.expand: false.}:
              Label(text="Wi-Fi Device:") {.expand: false.}
              DropDown {.expand: false, hAlign: AlignEnd.}:
                items = collect:
                  for w in app.wifi_devices:
                    $nm_device_get_iface(cast[ptr NMDevice](w))
                proc select(item: int) =
                  app.selected_wifidev = item
              Switch {.expand: false.}:
                state = nm_client_wireless_get_enabled(app.client).bool
                # FIXME: App becomes nil after this??
                # proc changed(state: bool) =
                #   app.client.enableWireless(state, app.chan)
            ListBox:
              selectionMode = SelectionNone
              for ap in app.wifi_devices[app.selected_wifidev].access_points:
                ListBoxRow {.addRow.}:
                  Box:
                    margin = Margin(top:6, bottom:6, left:12, right:12)

                    Label(text = ap.ssid.get("<unknown ssid>")) {.hAlign: AlignStart.}

proc main =
  let cli = nm_client_new(nil, nil)
  echo "netto"
  echo "nm client " & $cli.nm_client_get_version()
  # echo $nm_device_wifi_get_hw_address(wifidev)
  # wifidev.scan[]
  # for ap in wifidev.access_points:
  #   echo ap.ssid.get("<unknown ssid>").alignLeft(32) & &" {ap.needPasswd}"

  he.brew gui App(client = cli, wifi_devices = get_wifi_devices(cli))

main()
