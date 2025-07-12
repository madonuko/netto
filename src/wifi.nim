import std/[options, sugar, osproc, streams, os]
from owlkettle import addGlobalTimeout

import chronicles
import libnm
import sweet

import ./ghelpers
import ./errhdl
import ./chan

iterator get_devices*(client: ptr NMClient): ptr NMDevice =
  for ret in gIter[NMDevice](nm_client_get_devices(client)):
    yield ret

iterator get_connections*(client: ptr NMClient): ptr NMRemoteConnection =
  for ret in gIter[NMRemoteConnection](nm_client_get_connections(client)):
    yield ret

proc get_wifi_devices*(client: ptr NMClient): seq[ptr NMDeviceWifi] = collect:
  for dev in get_devices(client):
    if dev.nm_device_get_type_description == "wifi":
      cast[ptr NMDeviceWifi](dev)

proc scan*(wifidev: ptr NMDeviceWifi, chan: Chan) =
  proc nattouReqScanCb(source_object: ptr GObject, res: ptr GAsyncResult, user_data: gpointer) {.cdecl.} = 
    var err: ptr ptr GError
    cast[Chan](user_data)[].send: FinScan.init:
      if bool nm_device_wifi_request_scan_finish(cast[ptr NMDeviceWifi](source_object), res, err):
        trace "scan finished"
        none(ptr ptr GError)
      else:
        trace "scan finished", err
        some(err)

  trace "requesting scan"
  nm_device_wifi_request_scan_async(
    wifidev,
    nil, # GCancellable
    nattouReqScanCb, # GAsyncReadyCallback
    chan, # gpointer user_data
  )

iterator access_points*(wifidev: ptr NMDeviceWifi): ptr NMAccessPoint =
  for ret in gIter[NMAccessPoint](nm_device_wifi_get_access_points(wifidev)):
    yield ret

proc ssid*(ap: ptr NMAccessPoint): Option[string] =
  let ssid = nm_access_point_get_ssid ap
  if ssid == nil:
    none(string)
  else:
    some($ssid)

proc strength*(ap: ptr NMAccessPoint): int =
  ap.nm_access_point_get_strength.int

proc needPasswd*(ap: ptr NMAccessPoint): bool =
  nm_access_point_get_flags(ap) != NM_802_11_AP_FLAGS_NONE

proc needUsername*(ap: ptr NMAccessPoint): bool =
  # Check if AP has security enabled (not open)
  if (ap.nm_access_point_get_flags.int & NM_802_11_AP_FLAGS_PRIVACY.int) == 0:
    return false

  # Check WPA/RSN flags for enterprise
  let wpaFlags = ap.nm_access_point_get_wpa_flags().int
  let rsnFlags = ap.nm_access_point_get_rsn_flags().int

  (wpaFlags & NM_802_11_AP_SEC_KEY_MGMT_802_1X.int) != 0 or
    (rsnFlags & NM_802_11_AP_SEC_KEY_MGMT_802_1X.int) != 0

proc enableWireless*(client: ptr NMClient, state: bool, chan: Chan) =
  proc nattouEnableWirelessCb(source_object: ptr GObject, res: ptr GAsyncResult, u: gpointer) {.cdecl.} =
    var err: ptr ptr GError
    cast[Chan](u)[].send: FinEnableWireless.init:
      if not bool nm_client_dbus_set_property_finish(cast[ptr NMClient](source_object), res, err):
        trace "nm_client_dbus_set_property_finish", err
        some err
      else:
        trace "nm_client_dbus_set_property_finish"
        none(ptr ptr GError)

  client.nm_client_dbus_set_property(NM_DBUS_PATH, NM_DBUS_INTERFACE, "WirelessEnabled".cstring, GVariant(state),
    5000, # timeout_msec
    nil, # calcellable
    nattouEnableWirelessCb, # GAsyncReadyCallback
    chan
  )

proc connect*(client: ptr NMClient, ssid: string, chan: Chan, password = "", username = "") =
  info "connecting", ssid
  var args = @["dev", "wifi", "connect", ssid]
  if !!username.len:
    debug "username", username
    args.add ["username", username]
  if !!password.len:
    debug "password"
    args.add ["password", password]
  let p = startProcess(findExe("nmcli"), args = args)
  proc waitForProc(): bool =
    if p.running: return true
    defer: close p
    let rc = p.peekExitCode
    assert rc != -1
    chan[].send: FinConnect.init:
      if rc != 0: some((rc, p.outputStream.readAll))
      else: none((int, string))
    return false
  discard addGlobalTimeout(200, waitForProc)

proc disconnect*(dev: ptr NMDeviceWifi) =
  nm_device_disconnect_async(cast[ptr NMDevice](dev), nil, nil, nil)

let gTypeNMSettingWireless = g_type_from_name("NMSettingWireless")

proc saved_conn*(client: ptr NMClient, ssid: ptr GBytes): ptr NMConnection =
  for conn in client.get_connections:
    if conn.isNil:
      error "nil conn from iter"
      continue
    let conn = cast[ptr NMConnection](conn)
    let sett = cast[ptr NMSettingWireless](conn.nm_connection_get_setting gTypeNMSettingWireless)
    if not sett.isNil and bool sett.nm_setting_wireless_get_ssid.g_bytes_equal ssid:
      return conn
  return nil

proc saved_conn*(client: ptr NMClient, ap: ptr NMAccessPoint): ptr NMConnection =
  client.saved_conn ap.nm_access_point_get_ssid
