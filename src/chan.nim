import fungus
import std/options
import libnm

adtEnum Msg:
  FinEnableWireless: Option[ptr ptr GError]
  FinScan: Option[ptr ptr GError]
  Connect: ptr NMAccessPoint
  Disconnect
  FinConnect: Option[ptr ptr GError]

type Chan* = ptr Channel[Msg]
export Msg

var chan: Channel[Msg]
open chan
proc newChan*(): Chan = addr chan
