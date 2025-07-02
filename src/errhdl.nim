import libnm
import std/strformat

proc `$`*(err: GError): string =
  &"E{err.code}: [GQuark {err.domain}] {g_quark_to_string(err.domain)}: {err.message}"

proc `$`*(err: ptr GError): string = $err[]
proc `$`*(err: ptr ptr GError): string = $err[][]
