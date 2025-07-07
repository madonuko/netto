# or textblocks
--define:"chronicles_sinks=textlines[stderr]"
when not defined(release):
  --define:"chronicles_log_level=trace"
when findExe("mold").len > 0 and defined(linux):
  switch("passL", "-fuse-ld=mold")
