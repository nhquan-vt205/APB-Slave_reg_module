//-----------------------------------------------------------------------------
// Module  : apb_reg
// Function: APB slave register block with four 32-bit RW registers. No wait
//           state (pready tied high). Each register has a sticky written flag;
//           a register that has never been written reads back as 32'hDEAD_BEEF.
// Spec    : doc/spec/apb_reg_spec.md
// Diagram : doc/diagram/apb_reg/apb_reg.mmd  (L2)
// Language: Verilog-2005 (IEEE 1364-2005)
//-----------------------------------------------------------------------------

module apb_reg (
  // Clock and reset
  input  wire        clk,
  input  wire        rst_n,
  // APB slave interface
  input  wire        psel,
  input  wire [31:0] pwdata,
  input  wire [ 3:0] paddr,
  input  wire        penable,
  input  wire        pwrite,
  output reg  [31:0] prdata,
  output wire        pready
);

  // Register byte addresses (paddr is a byte address, spacing is 4 bytes)
  localparam ADDR_REG0 = 4'h0;
  localparam ADDR_REG1 = 4'h4;
  localparam ADDR_REG2 = 4'h8;
  localparam ADDR_REG3 = 4'hC;

  // Read value of a register that has never been written
  localparam UNWRITTEN = 32'hDEAD_BEEF;

  // State: register values
  reg [31:0] reg0_q;
  reg [31:0] reg1_q;
  reg [31:0] reg2_q;
  reg [31:0] reg3_q;

  // State: sticky written flags, set on the first write, held until reset
  reg        reg0_written_q;
  reg        reg1_written_q;
  reg        reg2_written_q;
  reg        reg3_written_q;

  // Internal combinational signals
  wire       wr_en;
  wire       rd_en;

  // APB access phase qualifiers
  assign wr_en = psel & penable &  pwrite;
  assign rd_en = psel & penable & ~pwrite;

  // Write decode. A write always sets the written flag, including a write of
  // all zeros, so the register then reads back as 0 instead of UNWRITTEN.
  // An address that does not exist leaves all state unchanged.
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      reg0_q         <= 32'h0000_0000;
      reg1_q         <= 32'h0000_0000;
      reg2_q         <= 32'h0000_0000;
      reg3_q         <= 32'h0000_0000;
      reg0_written_q <= 1'b0;
      reg1_written_q <= 1'b0;
      reg2_written_q <= 1'b0;
      reg3_written_q <= 1'b0;
    end
    else if (wr_en) begin
      case (paddr)
        ADDR_REG0: begin
          reg0_q         <= pwdata;
          reg0_written_q <= 1'b1;
        end
        ADDR_REG1: begin
          reg1_q         <= pwdata;
          reg1_written_q <= 1'b1;
        end
        ADDR_REG2: begin
          reg2_q         <= pwdata;
          reg2_written_q <= 1'b1;
        end
        ADDR_REG3: begin
          reg3_q         <= pwdata;
          reg3_written_q <= 1'b1;
        end
        default: begin
          // Non-existent address: write is ignored, state is held
        end
      endcase
    end
  end

  // Read mux. Combinational output, no added latency. Outside a read access
  // and for a non-existent address prdata is zero.
  always @(*) begin
    prdata = 32'h0000_0000;
    if (rd_en) begin
      case (paddr)
        ADDR_REG0: prdata = reg0_written_q ? reg0_q : UNWRITTEN;
        ADDR_REG1: prdata = reg1_written_q ? reg1_q : UNWRITTEN;
        ADDR_REG2: prdata = reg2_written_q ? reg2_q : UNWRITTEN;
        ADDR_REG3: prdata = reg3_written_q ? reg3_q : UNWRITTEN;
        default:   prdata = 32'h0000_0000;
      endcase
    end
  end

  // Zero wait state: the slave is always ready
  assign pready = 1'b1;

endmodule
