import std/options
import owlkettle
import owlkettle/he
import libnm
import ../[wifi, chan]
import chronicles


viewable Property:
  name: string
  child: Widget
method view(property: PropertyState): Widget =
  result = gui:
    Box:
      orient = OrientX
      spacing = 6
      
      Label:
        text = property.name
        xAlign = 0
      
      insert(property.child) {.expand: false.}
proc add(property: Property, child: Widget) =
  property.hasChild = true
  property.valChild = child


viewable CredDialog:
  needUser: bool
  username: string = ""
  password: string = ""
export CredDialog
method view*(dialog: CredDialogState): Widget = gui:
  Dialog:
    title = "Credentials"
    defaultSize = (320, 0)

    DialogButton {.addButton.}:
      text = "Connect"
      style = [ButtonSuggested]
      res = DialogAccept
    DialogButton {.addButton.}:
      text = "Cancel"
      res = DialogCancel

    Box:
      orient = OrientY
      spacing = 6
      margin = 12
      
      if dialog.needUser:
        Property:
          name = "Username"
          Entry:
            text = dialog.username
            proc changed(name: string) =
              dialog.username = name
      
      Property:
        name = "Password"
        Entry:
          text = dialog.password
          visibility = false
          proc changed(password: string) =
            dialog.password = password


viewable ApRow:
  client: ptr NMClient
  ap: ptr NMAccessPoint
  chan: Chan
  connecting: bool = false
export ApRow
proc connect(row: ApRowState) =
  let ssid = block:
    let ssid = row.ap.ssid
    warn "nil ssid"
    if ssid.isNone:
      return
    ssid.get
  info "activate()", ssid
  # let conn = row.client.saved_conn row.ap
  # if not conn.isNil:
  #   row.connecting = true
  #   row.client.addConnection conn, row.chan
  # if row.ap.needPasswd:
  #   let (res, state) = row.app.open(gui(CredDialog(needUser = row.ap.needUsername)))
  #   if row.unwrapInternalWidget.pointer == nil:
  #     warn "row gone", ssid
  #     return
  #   if res.kind == DialogAccept:
  #     let state = CredDialogState state
  #     row.connecting = true
  #     row.client.connect ssid, row.chan, state.password, state.username
  #   return
  # row.connecting = true
  # HACK: let nmcli pop out the GUI automagically
  row.client.connect ssid, row.chan
method view*(row: ApRowState): Widget = gui:
  ListBoxRow:
    proc activate() = connect row
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
        proc clicked() = connect row
        if row.connecting:
          icon = "network-wired-acquiring-symbolic"
          sensitive = false
        else:
          icon = "pan-end-symbolic"
        is_iconic = true


viewable ActiveAp:
  ap: ptr NMAccessPoint
  chan: Chan
  disconnecting: bool = false
export ActiveAp
method view*(row: ActiveApState): Widget = gui:
  HeMiniContentBlock:
    title = row.ap.ssid.get("<unknown ssid>")
    # title = "MEOW"
    if row.disconnecting:
      subtitle = "disconnecting…"
    else:
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
        style = [StyleClass("disconnect-btn")]
        # color = HeColorsRed
        

      proc clicked() =
        row.disconnecting = true
        row.chan[].send Msg Disconnect.init
