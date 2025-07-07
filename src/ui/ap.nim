import std/options
import owlkettle
import owlkettle/he
import libnm
import ../[wifi, chan]

viewable ApRow:
  ap: ptr NMAccessPoint
  chan: Chan
  connecting: bool = false
export ApRow
method view*(row: ApRowState): Widget = gui:
  ListBoxRow:
    Box:
      margin = Margin(top:6, bottom:6, left:12, right:12)
      spacing = 16

      HeButton {.expand: false, vAlign: AlignCenter.}:
        is_iconic = true
        icon = case row.ap.strength
          of 81..100: "network-wireless-signal-excellent-symbolic"
          of 56..80: "network-wireless-signal-good-symbolic"
          of 31..55: "network-wireless-signal-ok-symbolic"
          else: "network-wireless-signal-weak-symbolic"

      ScrolledWindow {.expand: true, vAlign: AlignCenter.}:
        propagateNaturalHeight = true
        Label:
          text = row.ap.ssid.get("<unknown ssid>") 
          # text = "meow!!!"
          style = [StyleClass("bold-label")]
          xAlign = 0

      if row.ap.needPasswd:
        Button {.expand: false, vAlign: AlignCenter.}:
          sensitive = false
          style = [StyleClass("fake-button")]
          icon = "network-wireless-encrypted-symbolic"
          tooltip = "encrypted"

      HeButton {.expand: false, vAlign: AlignCenter.}:
        if row.connecting:
          icon = "network-wired-acquiring-symbolic"
          sensitive = false
        else:
          icon = "pan-end-symbolic"
        is_iconic = true

        proc clicked() =
          row.connecting = true
          row.chan[].send Connect.init row.ap


viewable ActiveAp:
  ap: ptr NMAccessPoint
  chan: Chan
  disconnecting: bool = false
export ActiveAp
method view*(row: ActiveApState): Widget = gui:
  HeMiniContentBlock:
    title = row.ap.ssid.get("<unknown ssid>")
    # title = "MEOW"
    subtitle = "active connection"
    cardType = HeCardTypeElevated
    icon = case row.ap.strength
      of 81..100: "network-wireless-signal-excellent-symbolic"
      of 56..80: "network-wireless-signal-good-symbolic"
      of 31..55: "network-wireless-signal-ok-symbolic"
      else: "network-wireless-signal-weak-symbolic"

    HeButton:
      is_iconic = true
      if row.disconnecting:
        icon = "network-wired-acquiring-symbolic"
        sensitive = false
      else:
        icon = "network-wired-disconnected-symbolic"
        style = [StyleClass("error")]
        

      proc clicked() =
        row.disconnecting = true
        row.chan[].send Msg Disconnect.init
