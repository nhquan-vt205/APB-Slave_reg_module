#!/usr/bin/env bash
# Run the apb_reg testbench with Icarus Verilog (preferred) or Verilator.
# Usage:
#   ./run.sh            # run all tests
#   ./run.sh +TEST=5    # run only TC_APB_REG_005
set -euo pipefail
cd "$(dirname "$0")"

mkdir -p logs

if command -v iverilog >/dev/null 2>&1; then
  iverilog -g2012 -f apb_reg.f -o logs/apb_reg.vvp
  vvp logs/apb_reg.vvp "$@" | tee logs/run.log
elif command -v verilator >/dev/null 2>&1; then
  verilator --binary --timing -f apb_reg.f --top-module tb_apb_reg -o apb_reg_sim --Mdir logs/obj_dir
  ./logs/obj_dir/apb_reg_sim "$@" | tee logs/run.log
else
  echo "No simulator found (need iverilog or verilator)." >&2
  exit 1
fi
