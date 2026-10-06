//-----------------------------------------------------------------------------
// Testbench: tb_apb_reg
// Function : Direct self-checking testbench for apb_reg, covering every test
//            in doc/vplan/apb_reg_vplan.md (TC_APB_REG_001 .. TC_APB_REG_017).
//            Drives the APB bus (2-phase, no wait state), checks prdata/pready
//            against the expected values, and prints one PASS/FAIL line per
//            test plus a final summary line.
// DUT      : rtl/apb_reg.sv
// Vplan    : doc/vplan/apb_reg_vplan.md
// Run      : run all tests   -> sim/apb_reg/run.sh
//            run single test -> add +TEST=<n> (n = 1..17) to the sim command
//-----------------------------------------------------------------------------

module tb_apb_reg;

  // Clock / reset timing
  parameter CLK_PERIOD  = 10;
  parameter RST_CYCLES  = 2;
  parameter TIMEOUT_CYC = 2000;

  // Reused data patterns (doc/vplan/apb_reg_vplan.md, section 1)
  parameter logic [31:0] UNWRIT = 32'hDEAD_BEEF;
  parameter logic [31:0] P0     = 32'h0000_0000;
  parameter logic [31:0] P1     = 32'hFFFF_FFFF;
  parameter logic [31:0] P5     = 32'h5555_5555;
  parameter logic [31:0] PA     = 32'hAAAA_AAAA;

  // Valid register addresses
  parameter logic [3:0] ADDR0 = 4'h0;
  parameter logic [3:0] ADDR1 = 4'h4;
  parameter logic [3:0] ADDR2 = 4'h8;
  parameter logic [3:0] ADDR3 = 4'hC;

  // DUT signals
  logic        clk;
  logic        rst_n;
  logic        psel;
  logic [31:0] pwdata;
  logic [ 3:0] paddr;
  logic        penable;
  logic        pwrite;
  logic [31:0] prdata;
  logic        pready;

  // Scoreboard (single owner: report_test, called serially by test tasks)
  int pass_count;
  int fail_count;

  apb_reg u_dut (
    .clk     (clk),
    .rst_n   (rst_n),
    .psel    (psel),
    .pwdata  (pwdata),
    .paddr   (paddr),
    .penable (penable),
    .pwrite  (pwrite),
    .prdata  (prdata),
    .pready  (pready)
  );

  // Clock generation. The first edge happens at CLK_PERIOD/2, never at time 0.
  initial begin
    clk = 1'b0;
  end
  always #(CLK_PERIOD/2) clk = ~clk;

  // Global timeout, independent of the test sequencer below.
  initial begin
    #(CLK_PERIOD * TIMEOUT_CYC);
    $display("[TIMEOUT] simulation exceeded %0d cycles", TIMEOUT_CYC);
    $finish;
  end

  // Advance to the next negedge. All stimulus changes happen right after a
  // negedge (mid-cycle relative to the posedge that samples/clocks the DUT),
  // so no stimulus change ever races the clock's rising edge.
  task automatic step_cycle;
    @(negedge clk);
  endtask

  // Drive the whole APB bus in one place (rule 8: one clear owner per signal).
  task automatic drive_bus(logic psel_v, logic penable_v, logic pwrite_v,
                            logic [3:0] addr_v, logic [31:0] data_v);
    psel    = psel_v;
    penable = penable_v;
    pwrite  = pwrite_v;
    paddr   = addr_v;
    pwdata  = data_v;
  endtask

  // Synchronous-style reset: hold rst_n=0 for RST_CYCLES posedges, release on
  // a negedge, bus idle throughout.
  task automatic do_reset;
    rst_n = 1'b0;
    drive_bus(1'b0, 1'b0, 1'b0, 4'h0, 32'h0);
    repeat (RST_CYCLES) @(posedge clk);
    @(negedge clk);
    rst_n = 1'b1;
  endtask

  // Asynchronous reset pulse asserted/released away from any clock edge
  // (TC_APB_REG_002): hold for one full clock period mid-cycle.
  task automatic async_reset_pulse;
    step_cycle();
    #(CLK_PERIOD/4);
    rst_n = 1'b0;
    #(CLK_PERIOD);
    rst_n = 1'b1;
    step_cycle();
  endtask

  // Full APB write transfer: setup phase (1 cycle) -> access phase (1 cycle,
  // the write is captured on the posedge that ends it) -> idle.
  task automatic apb_write(logic [3:0] addr, logic [31:0] data);
    step_cycle();
    drive_bus(1'b1, 1'b0, 1'b1, addr, data);
    step_cycle();
    drive_bus(1'b1, 1'b1, 1'b1, addr, data);
    step_cycle();
    drive_bus(1'b0, 1'b0, 1'b0, 4'h0, 32'h0);
  endtask

  // Full APB read transfer: setup phase -> access phase, prdata sampled
  // during the access phase itself (combinational output, no added latency)
  // -> idle.
  task automatic apb_read(logic [3:0] addr, output logic [31:0] data);
    step_cycle();
    drive_bus(1'b1, 1'b0, 1'b0, addr, 32'h0);
    step_cycle();
    drive_bus(1'b1, 1'b1, 1'b0, addr, 32'h0);
    #1;
    data = prdata;
    step_cycle();
    drive_bus(1'b0, 1'b0, 1'b0, 4'h0, 32'h0);
  endtask

  // Pure comparison helper, no signal driving.
  function automatic bit eq32(logic [31:0] a, logic [31:0] b);
    return (a === b);
  endfunction

  // Single owner of pass_count/fail_count and the one-line PASS/FAIL log.
  task automatic report_test(string id, bit ok, string fail_msg);
    if (ok) begin
      pass_count++;
      $display("[TEST] %s PASS", id);
    end
    else begin
      fail_count++;
      $display("[TEST] %s FAIL: %s @%0t", id, fail_msg, $time);
    end
  endtask

  // TC_APB_REG_001: reset state, read all 4 registers, expect UNWRIT.
  task automatic tc_apb_reg_001;
    logic [31:0] d0, d1, d2, d3;
    bit ok;
    do_reset();
    apb_read(ADDR0, d0);
    apb_read(ADDR1, d1);
    apb_read(ADDR2, d2);
    apb_read(ADDR3, d3);
    ok = eq32(d0, UNWRIT) && eq32(d1, UNWRIT) && eq32(d2, UNWRIT) && eq32(d3, UNWRIT);
    report_test("TC_APB_REG_001", ok,
      $sformatf("prdata exp=%08h,%08h,%08h,%08h got=%08h,%08h,%08h,%08h",
                 UNWRIT, UNWRIT, UNWRIT, UNWRIT, d0, d1, d2, d3));
  endtask

  // TC_APB_REG_002: async reset mid-run clears both reg0 and reg0_written.
  task automatic tc_apb_reg_002;
    logic [31:0] d0, d0_after;
    bit ok;
    do_reset();
    apb_write(ADDR0, P5);
    apb_read(ADDR0, d0);
    async_reset_pulse();
    apb_read(ADDR0, d0_after);
    ok = eq32(d0, P5) && eq32(d0_after, UNWRIT);
    report_test("TC_APB_REG_002", ok,
      $sformatf("prdata exp=%08h,%08h got=%08h,%08h", P5, UNWRIT, d0, d0_after));
  endtask

  // TC_APB_REG_003: REG0 write/read-back with P1, P5, PA.
  task automatic tc_apb_reg_003;
    logic [31:0] d1, d2, d3;
    bit ok;
    do_reset();
    apb_write(ADDR0, P1); apb_read(ADDR0, d1);
    apb_write(ADDR0, P5); apb_read(ADDR0, d2);
    apb_write(ADDR0, PA); apb_read(ADDR0, d3);
    ok = eq32(d1, P1) && eq32(d2, P5) && eq32(d3, PA);
    report_test("TC_APB_REG_003", ok,
      $sformatf("prdata exp=%08h,%08h,%08h got=%08h,%08h,%08h", P1, P5, PA, d1, d2, d3));
  endtask

  // TC_APB_REG_004: REG1 write/read-back with P1, P5, PA.
  task automatic tc_apb_reg_004;
    logic [31:0] d1, d2, d3;
    bit ok;
    do_reset();
    apb_write(ADDR1, P1); apb_read(ADDR1, d1);
    apb_write(ADDR1, P5); apb_read(ADDR1, d2);
    apb_write(ADDR1, PA); apb_read(ADDR1, d3);
    ok = eq32(d1, P1) && eq32(d2, P5) && eq32(d3, PA);
    report_test("TC_APB_REG_004", ok,
      $sformatf("prdata exp=%08h,%08h,%08h got=%08h,%08h,%08h", P1, P5, PA, d1, d2, d3));
  endtask

  // TC_APB_REG_005: REG2 write/read-back with P1, P5, PA.
  task automatic tc_apb_reg_005;
    logic [31:0] d1, d2, d3;
    bit ok;
    do_reset();
    apb_write(ADDR2, P1); apb_read(ADDR2, d1);
    apb_write(ADDR2, P5); apb_read(ADDR2, d2);
    apb_write(ADDR2, PA); apb_read(ADDR2, d3);
    ok = eq32(d1, P1) && eq32(d2, P5) && eq32(d3, PA);
    report_test("TC_APB_REG_005", ok,
      $sformatf("prdata exp=%08h,%08h,%08h got=%08h,%08h,%08h", P1, P5, PA, d1, d2, d3));
  endtask

  // TC_APB_REG_006: REG3 write/read-back with P1, P5, PA.
  task automatic tc_apb_reg_006;
    logic [31:0] d1, d2, d3;
    bit ok;
    do_reset();
    apb_write(ADDR3, P1); apb_read(ADDR3, d1);
    apb_write(ADDR3, P5); apb_read(ADDR3, d2);
    apb_write(ADDR3, PA); apb_read(ADDR3, d3);
    ok = eq32(d1, P1) && eq32(d2, P5) && eq32(d3, PA);
    report_test("TC_APB_REG_006", ok,
      $sformatf("prdata exp=%08h,%08h,%08h got=%08h,%08h,%08h", P1, P5, PA, d1, d2, d3));
  endtask

  // TC_APB_REG_007: writing all-zero still sets the written flag.
  task automatic tc_apb_reg_007;
    logic [31:0] d_before, d_after;
    bit ok;
    do_reset();
    apb_read(ADDR2, d_before);
    apb_write(ADDR2, P0);
    apb_read(ADDR2, d_after);
    ok = eq32(d_before, UNWRIT) && eq32(d_after, P0);
    report_test("TC_APB_REG_007", ok,
      $sformatf("prdata exp=%08h,%08h got=%08h,%08h", UNWRIT, P0, d_before, d_after));
  endtask

  // TC_APB_REG_008: written flag stays set across repeated overwrites.
  task automatic tc_apb_reg_008;
    logic [31:0] d1, d2, d3;
    bit ok;
    do_reset();
    apb_write(ADDR3, PA); apb_read(ADDR3, d1);
    apb_write(ADDR3, P0); apb_read(ADDR3, d2);
    apb_write(ADDR3, P1); apb_read(ADDR3, d3);
    ok = eq32(d1, PA) && eq32(d2, P0) && eq32(d3, P1);
    report_test("TC_APB_REG_008", ok,
      $sformatf("prdata exp=%08h,%08h,%08h got=%08h,%08h,%08h", PA, P0, P1, d1, d2, d3));
  endtask

  // TC_APB_REG_009: writing one register does not affect the other three.
  task automatic tc_apb_reg_009;
    logic [31:0] d0, d1, d2, d3;
    bit ok;
    do_reset();
    apb_write(ADDR1, P5);
    apb_read(ADDR0, d0);
    apb_read(ADDR1, d1);
    apb_read(ADDR2, d2);
    apb_read(ADDR3, d3);
    ok = eq32(d0, UNWRIT) && eq32(d1, P5) && eq32(d2, UNWRIT) && eq32(d3, UNWRIT);
    report_test("TC_APB_REG_009", ok,
      $sformatf("prdata exp=%08h,%08h,%08h,%08h got=%08h,%08h,%08h,%08h",
                 UNWRIT, P5, UNWRIT, UNWRIT, d0, d1, d2, d3));
  endtask

  // TC_APB_REG_010: write all 4 registers, then read all 4 back.
  task automatic tc_apb_reg_010;
    logic [31:0] d0, d1, d2, d3;
    bit ok;
    do_reset();
    apb_write(ADDR0, P0);
    apb_write(ADDR1, P1);
    apb_write(ADDR2, P5);
    apb_write(ADDR3, PA);
    apb_read(ADDR0, d0);
    apb_read(ADDR1, d1);
    apb_read(ADDR2, d2);
    apb_read(ADDR3, d3);
    ok = eq32(d0, P0) && eq32(d1, P1) && eq32(d2, P5) && eq32(d3, PA);
    report_test("TC_APB_REG_010", ok,
      $sformatf("prdata exp=%08h,%08h,%08h,%08h got=%08h,%08h,%08h,%08h",
                 P0, P1, P5, PA, d0, d1, d2, d3));
  endtask

  // TC_APB_REG_011: writes to invalid addresses are ignored; transfers still
  // complete with pready=1.
  task automatic tc_apb_reg_011;
    logic [31:0] d0, d1, d2, d3;
    logic        pr1, pr2, pr3;
    bit ok;
    do_reset();

    step_cycle();
    drive_bus(1'b1, 1'b0, 1'b1, 4'h1, P1);
    step_cycle();
    drive_bus(1'b1, 1'b1, 1'b1, 4'h1, P1);
    #1; pr1 = pready;

    step_cycle();
    drive_bus(1'b1, 1'b0, 1'b1, 4'h7, P1);
    step_cycle();
    drive_bus(1'b1, 1'b1, 1'b1, 4'h7, P1);
    #1; pr2 = pready;

    step_cycle();
    drive_bus(1'b1, 1'b0, 1'b1, 4'hF, P1);
    step_cycle();
    drive_bus(1'b1, 1'b1, 1'b1, 4'hF, P1);
    #1; pr3 = pready;

    step_cycle();
    drive_bus(1'b0, 1'b0, 1'b0, 4'h0, 32'h0);

    apb_read(ADDR0, d0);
    apb_read(ADDR1, d1);
    apb_read(ADDR2, d2);
    apb_read(ADDR3, d3);

    ok = eq32(d0, UNWRIT) && eq32(d1, UNWRIT) && eq32(d2, UNWRIT) && eq32(d3, UNWRIT)
         && pr1 && pr2 && pr3;
    report_test("TC_APB_REG_011", ok,
      $sformatf("prdata/pready exp=%08h,%08h,%08h,%08h,1,1,1 got=%08h,%08h,%08h,%08h,%0d,%0d,%0d",
                 UNWRIT, UNWRIT, UNWRIT, UNWRIT, d0, d1, d2, d3, pr1, pr2, pr3));
  endtask

  // TC_APB_REG_012: reads from invalid addresses return 0, not UNWRIT/P1.
  task automatic tc_apb_reg_012;
    logic [31:0] d1, d2, d3, d4, d5;
    bit ok;
    do_reset();
    apb_write(ADDR0, P1);
    apb_write(ADDR1, P1);
    apb_write(ADDR2, P1);
    apb_write(ADDR3, P1);
    apb_read(4'h1, d1);
    apb_read(4'h2, d2);
    apb_read(4'h5, d3);
    apb_read(4'hD, d4);
    apb_read(4'hF, d5);
    ok = eq32(d1, P0) && eq32(d2, P0) && eq32(d3, P0) && eq32(d4, P0) && eq32(d5, P0);
    report_test("TC_APB_REG_012", ok,
      $sformatf("prdata exp=%08h,%08h,%08h,%08h,%08h got=%08h,%08h,%08h,%08h,%08h",
                 P0, P0, P0, P0, P0, d1, d2, d3, d4, d5));
  endtask

  // TC_APB_REG_013: prdata is 0 outside a read-access phase (idle, read
  // setup phase, write access phase).
  task automatic tc_apb_reg_013;
    logic [31:0] d_idle, d_setup, d_waccess;
    bit ok;
    do_reset();
    apb_write(ADDR0, P1);

    drive_bus(1'b0, 1'b0, 1'b0, ADDR0, 32'h0);
    #1; d_idle = prdata;

    step_cycle();
    drive_bus(1'b1, 1'b0, 1'b0, ADDR0, 32'h0);
    #1; d_setup = prdata;

    step_cycle();
    drive_bus(1'b1, 1'b1, 1'b1, ADDR0, P1);
    #1; d_waccess = prdata;

    step_cycle();
    drive_bus(1'b0, 1'b0, 1'b0, 4'h0, 32'h0);
    step_cycle();

    ok = eq32(d_idle, P0) && eq32(d_setup, P0) && eq32(d_waccess, P0);
    report_test("TC_APB_REG_013", ok,
      $sformatf("prdata exp=%08h,%08h,%08h got=%08h,%08h,%08h",
                 P0, P0, P0, d_idle, d_setup, d_waccess));
  endtask

  // TC_APB_REG_014: a transfer cancelled during setup phase (psel dropped
  // before entering access phase) must not write the register.
  task automatic tc_apb_reg_014;
    logic [31:0] d1;
    bit ok;
    do_reset();

    step_cycle();
    drive_bus(1'b1, 1'b0, 1'b1, ADDR1, PA);
    step_cycle();
    drive_bus(1'b0, 1'b0, 1'b0, 4'h0, 32'h0);
    step_cycle();

    apb_read(ADDR1, d1);
    ok = eq32(d1, UNWRIT);
    report_test("TC_APB_REG_014", ok,
      $sformatf("prdata exp=%08h got=%08h", UNWRIT, d1));
  endtask

  // TC_APB_REG_015: pready stays 1 across idle, setup/access of a write
  // (valid address) and setup/access of a read (invalid address).
  task automatic tc_apb_reg_015;
    logic p_idle, p_setup_w, p_access_w, p_setup_r, p_access_r;
    bit ok;
    do_reset();

    step_cycle();
    drive_bus(1'b0, 1'b0, 1'b0, ADDR0, 32'h0);
    #1; p_idle = pready;

    step_cycle();
    drive_bus(1'b1, 1'b0, 1'b1, ADDR0, P1);
    #1; p_setup_w = pready;

    step_cycle();
    drive_bus(1'b1, 1'b1, 1'b1, ADDR0, P1);
    #1; p_access_w = pready;

    step_cycle();
    drive_bus(1'b1, 1'b0, 1'b0, 4'h1, 32'h0);
    #1; p_setup_r = pready;

    step_cycle();
    drive_bus(1'b1, 1'b1, 1'b0, 4'h1, 32'h0);
    #1; p_access_r = pready;

    step_cycle();
    drive_bus(1'b0, 1'b0, 1'b0, 4'h0, 32'h0);
    step_cycle();

    ok = p_idle && p_setup_w && p_access_w && p_setup_r && p_access_r;
    report_test("TC_APB_REG_015", ok,
      $sformatf("pready exp=1,1,1,1,1 got=%0d,%0d,%0d,%0d,%0d",
                 p_idle, p_setup_w, p_access_w, p_setup_r, p_access_r));
  endtask

  // TC_APB_REG_016: prdata reflects the write with no added read latency
  // (sampled inside the access phase itself by apb_read).
  task automatic tc_apb_reg_016;
    logic [31:0] d0;
    bit ok;
    do_reset();
    apb_write(ADDR2, P5);
    apb_read(ADDR2, d0);
    ok = eq32(d0, P5);
    report_test("TC_APB_REG_016", ok,
      $sformatf("prdata exp=%08h got=%08h", P5, d0));
  endtask

  // TC_APB_REG_017: back-to-back write then read, no idle cycle in between.
  task automatic tc_apb_reg_017;
    logic [31:0] d0;
    bit ok;
    do_reset();

    step_cycle();
    drive_bus(1'b1, 1'b0, 1'b1, ADDR0, PA);
    step_cycle();
    drive_bus(1'b1, 1'b1, 1'b1, ADDR0, PA);
    step_cycle();
    drive_bus(1'b1, 1'b0, 1'b0, ADDR0, 32'h0);
    step_cycle();
    drive_bus(1'b1, 1'b1, 1'b0, ADDR0, 32'h0);
    #1; d0 = prdata;
    step_cycle();
    drive_bus(1'b0, 1'b0, 1'b0, 4'h0, 32'h0);
    step_cycle();

    ok = eq32(d0, PA);
    report_test("TC_APB_REG_017", ok,
      $sformatf("prdata exp=%08h got=%08h", PA, d0));
  endtask

  // Test selection and main sequence. +TEST=<n> (n = 1..17) runs a single
  // test; no plusarg runs the whole suite.
  int test_id;
  initial begin
    if (!$value$plusargs("TEST=%d", test_id)) begin
      test_id = 0;
    end
    pass_count = 0;
    fail_count = 0;

    if (test_id == 0 || test_id == 1)  tc_apb_reg_001();
    if (test_id == 0 || test_id == 2)  tc_apb_reg_002();
    if (test_id == 0 || test_id == 3)  tc_apb_reg_003();
    if (test_id == 0 || test_id == 4)  tc_apb_reg_004();
    if (test_id == 0 || test_id == 5)  tc_apb_reg_005();
    if (test_id == 0 || test_id == 6)  tc_apb_reg_006();
    if (test_id == 0 || test_id == 7)  tc_apb_reg_007();
    if (test_id == 0 || test_id == 8)  tc_apb_reg_008();
    if (test_id == 0 || test_id == 9)  tc_apb_reg_009();
    if (test_id == 0 || test_id == 10) tc_apb_reg_010();
    if (test_id == 0 || test_id == 11) tc_apb_reg_011();
    if (test_id == 0 || test_id == 12) tc_apb_reg_012();
    if (test_id == 0 || test_id == 13) tc_apb_reg_013();
    if (test_id == 0 || test_id == 14) tc_apb_reg_014();
    if (test_id == 0 || test_id == 15) tc_apb_reg_015();
    if (test_id == 0 || test_id == 16) tc_apb_reg_016();
    if (test_id == 0 || test_id == 17) tc_apb_reg_017();

    $display("[SUMMARY] PASS=%0d FAIL=%0d", pass_count, fail_count);
    $finish;
  end

endmodule
