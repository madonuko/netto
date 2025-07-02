import std/options

import chronicles
import results
import libnm

import ./ghelpers

iterator get_devices*(client: ptr NMClient): ptr NMDevice =
  for ret in gIter[NMDevice](nm_client_get_devices(client)):
    yield ret

proc get_wifi_device*(client: ptr NMClient): Option[ptr NMDeviceWifi] =
  for dev in get_devices(client):
    if dev.nm_device_get_type_description == "wifi":
      return some cast[ptr NMDeviceWifi](dev)

proc scan*(wifidev: ptr NMDeviceWifi): Result[void, ptr ptr GError] =
  type UserData = tuple[
    dev: ptr NMDeviceWifi,
    loop: ptr GMainLoop,
    err: ptr ptr GError,
  ]

  proc reqScanCb(source_object: ptr GObject, res: ptr GAsyncResult, user_data: gpointer) {.cdecl.} = 
    var u = cast[ptr UserData](user_data)
    
    let success = nm_device_wifi_request_scan_finish(u[].dev, res, u[].err)
    trace "scan finished ", success = success
    g_main_loop_quit u[].loop

  var
    loop = g_main_loop_new(nil, false.gboolean)
    u: UserData = (wifidev, loop, nil)

  trace "requesting scan"
  nm_device_wifi_request_scan_async(
    wifidev,
    nil, # GCancellable
    reqScanCb, # GAsyncReadyCallback
    addr u, # gpointer user_data
  )
  g_main_loop_run loop
  trace "loop finished", hasErr = not u.err.isNil
  if not u.err.isNil:
    return err u.err
  return ok()

iterator access_points*(wifidev: ptr NMDeviceWifi): ptr NMAccessPoint =
  for ret in gIter[NMAccessPoint](nm_device_wifi_get_access_points(wifidev)):
    yield ret

proc ssid*(ap: ptr NMAccessPoint): Option[string] =
  let ssid = nm_access_point_get_ssid ap
  if ssid == nil:
    none(string)
  else:
    some($ssid)

proc needPasswd*(ap: ptr NMAccessPoint): bool =
  nm_access_point_get_flags(ap) != NM_802_11_AP_FLAGS_NONE
