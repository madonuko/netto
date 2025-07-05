import fungus
import std/options
import libnm

adtEnum Msg:
  FinEnableWireless: Option[ptr ptr GError]

type Chan* = Channel[Msg]
export Msg
