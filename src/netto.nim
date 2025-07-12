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
import libnm
import ./[wifi, errhdl, chan]
import ./ui/ap
import owlkettle, owlkettle/he
import fungus
import sweet

import std/[strutils, options, strformat, sugar, algorithm, sets]

viewable App:
  chan: Chan = newChan()
  client: ptr NMClient
  scanning: bool = false
  wifi_devices: seq[ptr NMDeviceWifi] = @[]
  selected_wifidev: int = 0
  aps: seq[ptr NMAccessPoint]
  active_ap: ptr NMAccessPoint

  hooks:
    afterBuild:
      proc redrawer(): bool =
        if state.chan[].peek != 0:
          discard redraw state
        return true # keep
      discard addGlobalTimeout(200, redrawer)

      proc rescanner(): bool =
        if not nm_client_wireless_get_enabled(state.client).bool:
          trace "skip rescan, wireless disabled"
          return true
        if not state.scanning:
          state.scanning = true
          state.wifi_devices[state.selected_wifidev].scan state.chan
          nm_client_reload_connections_async(state.client, nil, nil, nil)
        else:
          warn "still scanning…?"
        return true # keep
      discard rescanner()
      discard addGlobalTimeout(2000, rescanner)

proc handleErr(app: AppState, e: Option[(int, string)], msg: cstring) =
  if e.isNone: return
  warn "displaying MessageDialog"
  let (rc, inner) = e.get
  discard app.open: gui:
    MessageDialog:
      message = block:
        if !rc: &"{msg}: {inner}"
        else: &"{msg}: exit code {rc}: {inner}"
      DialogButton {.addButton.}:
        text = "Ok"
        res = DialogAccept

proc handleErr(app: AppState, e: Option[ptr ptr GError], msg: cstring) =
  app.handleErr e.map(e => (0, $e)), msg

method view(app: AppState): Widget = 
  while app.chan[].peek != 0:
    let msg = app.chan[].recv
    debug "app.chan.recv", msg
    match msg:
    of FinEnableWireless as e: app.handleErr e, "Failed to set wireless to enabled"
    of FinScan as e:
      if e.isSome:
        warn "can't scan networks", err = e.get
      app.scanning = false
    # of Connect as (ap, cred):
    #   if cred.isSome:
    #     let (username, password) = cred.get
    #     app.client.connect ap, app.chan, password, username
    #   else:
    #     app.client.connect ap, app.chan
    of Disconnect:
      disconnect app.wifi_devices[app.selected_wifidev]
    of FinConnect as e: app.handleErr e, "Failed to connect to access point"
  app.active_ap = nm_device_wifi_get_active_access_point app.wifi_devices[app.selected_wifidev]
  app.aps = collect:
    for ap in app.wifi_devices[app.selected_wifidev].access_points:
      if app.active_ap != ap:
        ap
  app.aps.sort do (x, y: ptr NMAccessPoint) -> int: cmp(y.strength, x.strength)
  result = gui:
    HeApplicationWindow:
      title = "netto"
      defaultSize = (400, 800)

      # FIXME: HeViewMono inhibits UI updates entirely as there's only append method in bindings
      Box(orient=OrientY):
        HeAppBar(showRightTitleButtons = true) {.expand: false.}

        if app.wifi_devices.len == 0:
          HeEmptyPage:
            title = "No Wi-Fi Devices"
            description = "netto can't find any NMDeviceWifi."
            icon = "network-wireless-disabled-symbolic"
            buttonText = "" # FIXME: lains why does this button exist
        else:
          Box(orient = OrientY, spacing = 4):
            margin = Margin(left: 16, right: 16, bottom: 16)
            Box(orient = OrientX, spacing = 16) {.expand: false.}:
              Label(text="Wi-Fi Device:") {.expand: false.}
              DropDown {.expand: false.}:
                items = collect:
                  for w in app.wifi_devices:
                    $nm_device_get_iface(cast[ptr NMDevice](w))
                proc select(item: int) =
                  app.selected_wifidev = item
              Box()
              Switch {.expand: false, vAlign: AlignCenter.}:
                state = nm_client_wireless_get_enabled(app.client).bool
                # FIXME: App becomes nil when HeViewMono
                proc changed(state: bool) =
                  app.client.enableWireless(state, app.chan)

            if not isNil app.active_ap:
              ActiveAp(ap = app.active_ap, chan = app.chan) {.expand: false.}

            ScrolledWindow:
              ListBox:
                selectionMode = SelectionSingle
                for ap in app.aps:
                  ApRow(client = app.client, ap = ap, chan = app.chan) {.addRow.}

                proc select(rows: HashSet[int]) =
                  info "select", rows
                  if !rows.len: return
                  for i in rows.items:
                    let ssid = app.aps[i].ssid
                    if ssid.isNone:
                      warn "nil ssid", i
                      return
                    app.client.connect ssid.get, app.chan

proc main =
  let cli = nm_client_new(nil, nil)
  info "netto", nm_client_ver = cli.nm_client_get_version()

  he.brew(gui(App(client = cli, wifi_devices = get_wifi_devices(cli))), stylesheets=[
    newStylesheet("""
      .bold-label {
        font-weight: bold;
        filter: brightness(150%);
      }
      .fake-button {
        color: inherit;
        background-color: inherit;
      }
      .disconnect-btn {
        background: rgba(255, 0, 0, 0.2);
      }
    """)
  ])

main()
