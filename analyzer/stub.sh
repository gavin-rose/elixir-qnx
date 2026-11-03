#!/bin/sh
# Dev-host stub analyzer: emits the same telemetry format as the native QNX
# analyzer so the Elixir side can be developed without QNX. Not used on QNX.
seq=0
while true; do
  reading=$(awk "BEGIN{printf \"%.2f\", 50 + 20*sin($seq*0.5/3.0)}")
  temp=$(awk "BEGIN{printf \"%.2f\", 36.5 + 0.5*sin($seq*0.5/7.0)}")
  printf "TELEM %d %s %s 101.30 ok\n" "$seq" "$reading" "$temp"
  seq=$((seq + 1))
  sleep 0.5
done
