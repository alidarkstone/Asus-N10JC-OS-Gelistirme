#!/bin/bash
# Fail if olddefconfig silently dropped a setting that matters for the N10JC.
set -euo pipefail
cfg="${1:-.config}"
fail=0
need() { grep -qx "$1" "$cfg" || { echo "MISSING: $1"; fail=1; }; }

need CONFIG_MATOM=y
need CONFIG_X86_PAE=y
grep -qx "# CONFIG_HIGHMEM4G is not set" "$cfg" || { echo "MISSING: HIGHMEM4G must be off"; fail=1; }
need CONFIG_LRU_GEN_ENABLED=y
need CONFIG_ZRAM=y
need CONFIG_ZRAM_DEF_COMP_LZ4=y
need CONFIG_PREEMPT_DYNAMIC=y
need CONFIG_HZ_300=y
need CONFIG_DRM_I915=y
need CONFIG_SQUASHFS=y
need CONFIG_OVERLAY_FS=y
grep -q '^CONFIG_VMSPLIT_2G=y\|^CONFIG_VMSPLIT_2G_OPT=y\|^CONFIG_VMSPLIT_3G_OPT=y' "$cfg" \
  || { echo "MISSING: a VMSPLIT option that maps 1 GB as lowmem"; fail=1; }

[ "$fail" = 0 ] && echo ">> kernel config OK"
exit "$fail"
