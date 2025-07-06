import std/[options, sugar]

import chronicles
import libnm

import ./ghelpers
import ./errhdl
import ./chan

iterator get_devices*(client: ptr NMClient): ptr NMDevice =
  for ret in gIter[NMDevice](nm_client_get_devices(client)):
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

proc addConnection(client: ptr NMClient, conn: ptr NMConnection, chan: Chan) =
  proc nattouAddConnCb(source_object: ptr GObject, res: ptr GAsyncResult, user_data: gpointer) {.cdecl.} =
    var
      chan = cast[Chan](user_data)
      err: ptr ptr GError
      conn = nm_client_add_connection_finish(cast[ptr NMClient](source_object), res, err)
    trace "added connection"
    chan[].send: FinConnect.init:
      if conn.isNil:
        some(err)
      else:
        none(ptr ptr GError)
  trace "adding conn"
  client.nm_client_add_connection_async(
    conn,
    true.gboolean, # gboolean save_to_disk
    nil, # GCancellable *cancellable
    nattouAddConnCb, # GAsyncReadyCallback callback
    addr chan, # gpointer user_data
  )

# asked deepseek and somehow they're giving me methods that actually exist
# TODO: check all paths somehow?
proc connect*(client: ptr NMClient, ap: ptr NMAccessPoint, chan: Chan, password = "", username = "") =
  var
    conn = nm_simple_connection_new()
    wifi_setting = nm_setting_wireless_new()
  
  wifi_setting.nm_setting_option_set(NM_SETTING_WIRELESS_BSSID, GVariant(nm_access_point_get_bssid(ap)))
  conn.nm_connection_add_setting wifi_setting

  # configure security
  let
    flags = nm_access_point_get_flags ap
    rsnFlags = nm_access_point_get_rsn_flags ap

  if flags == NM_802_11_AP_FLAGS_PRIVACY:
    let sec_setting = nm_setting_wireless_security_new()
    
    # WPA2-Personal (PSK)
    if rsnFlags == NM_802_11_AP_SEC_KEY_MGMT_PSK:
      sec_setting.nm_setting_option_set(NM_SETTING_WIRELESS_SECURITY_KEY_MGMT, GVariant("wpa-psk"))
      sec_setting.nm_setting_option_set(NM_SETTING_WIRELESS_SECURITY_PSK, GVariant(password))
    
    # WEP
    elif ap.nm_access_point_get_wpa_flags != NM_802_11_AP_SEC_NONE or rsnFlags == NM_802_11_AP_SEC_NONE:
      sec_setting.nm_setting_option_set(NM_SETTING_WIRELESS_SECURITY_KEY_MGMT, GVariant("none"))
      sec_setting.nm_setting_option_set(NM_SETTING_WIRELESS_SECURITY_WEP_KEY0, GVariant(password))
      sec_setting.nm_setting_option_set(NM_SETTING_WIRELESS_SECURITY_AUTH_ALG, GVariant("open"))
    
    # Enterprise (WPA-EAP)
    elif rsnFlags == NM_802_11_AP_SEC_KEY_MGMT_802_1X:
      sec_setting.nm_setting_option_set(NM_SETTING_WIRELESS_SECURITY_KEY_MGMT, GVariant("wpa-eap"))
      let eap_setting = nm_setting_802_1x_new()
      eap_setting.nm_setting_option_set(NM_SETTING_802_1X_EAP, GVariant("peap"))
      eap_setting.nm_setting_option_set(NM_SETTING_802_1X_IDENTITY, GVariant(username))
      eap_setting.nm_setting_option_set(NM_SETTING_802_1X_PASSWORD, GVariant(password))
      eap_setting.nm_setting_option_set(NM_SETTING_802_1X_PHASE2_AUTH, GVariant("mschapv2"))
      conn.nm_connection_add_setting eap_setting
    
    conn.nm_connection_add_setting sec_setting

  # configure IPv4
  let ip4_setting = nm_setting_ip4_config_new()
  ip4_setting.nm_setting_option_set(NM_SETTING_IP_CONFIG_METHOD, GVariant("auto"))
  conn.nm_connection_add_setting ip4_setting

  # activate
  client.addConnection conn, chan

proc disconnect*(dev: ptr NMDeviceWifi) =
  nm_device_disconnect_async(cast[ptr NMDevice](dev), nil, nil, nil)
