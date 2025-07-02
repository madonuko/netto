import libnm
import ptr_math

iterator gIter*[R](gpa: ptr GPtrArray): ptr R =
  for i in 0..gpa[].len.int-1:
    yield cast[ptr ptr R](gpa[].pdata + i)[]

proc `$`*(gbytes: ptr GBytes): string =
  var
    size: gsize
    p = g_bytes_get_data(gbytes, addr size)
  ($cast[cstring](p))[0..size.int-1]

proc GVariant*(s: string): ptr GVariant =
  g_variant_new_string s.cstring

proc GVariant*(s: cstring): ptr GVariant =
  g_variant_new_string s
