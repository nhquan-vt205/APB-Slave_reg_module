# APB Slave Register Block Specification

## 1. Module Overview

Module là một **APB Slave Register Block** có nhiệm vụ cung cấp giao tiếp APB để đọc/ghi 4 thanh ghi 32-bit.

Module chứa 4 thanh ghi:

| Register | Address | Width | Access |
|---|---:|---:|---|
| `REG0` | `4'h0` | 32 bit | RW |
| `REG1` | `4'h4` | 32 bit | RW |
| `REG2` | `4'h8` | 32 bit | RW |
| `REG3` | `4'hC` | 32 bit | RW |

Module sử dụng:

- Clock đồng bộ `clk`
- Asynchronous active-low reset `rst_n`

Một register chưa từng được ghi kể từ lần reset gần nhất sẽ trả về:

```text
32'hDEAD_BEEF
```

khi được đọc.

Sau khi một register được ghi ít nhất một lần, các lần đọc tiếp theo phải trả về **giá trị cuối cùng đã ghi**.

---

# 2. Interface Specification

## 2.1 Top-level ports

```systemverilog
input  logic        clk;
input  logic        rst_n;

input  logic        psel;
input  logic [31:0] pwdata;
input  logic [3:0]  paddr;
input  logic        penable;
input  logic        pwrite;

output logic [31:0] prdata;
output logic        pready;
```

| Signal | Direction | Width | Description |
|---|---|---:|---|
| `clk` | Input | 1 | Module clock |
| `rst_n` | Input | 1 | Asynchronous active-low reset |
| `psel` | Input | 1 | APB slave select |
| `pwdata` | Input | 32 | APB write data |
| `paddr` | Input | 4 | APB register address |
| `penable` | Input | 1 | APB access phase indicator |
| `pwrite` | Input | 1 | `1` = write, `0` = read |
| `prdata` | Output | 32 | APB read data |
| `pready` | Output | 1 | APB transfer ready |

---

# 3. Reset Behavior

Reset là **asynchronous active-low**.

Reset được kích hoạt khi:

```text
rst_n = 0
```

Các register storage và trạng thái `written` phải được reset như sau:

```text
REG0         = 32'h0000_0000
REG1         = 32'h0000_0000
REG2         = 32'h0000_0000
REG3         = 32'h0000_0000

REG0_WRITTEN = 1'b0
REG1_WRITTEN = 1'b0
REG2_WRITTEN = 1'b0
REG3_WRITTEN = 1'b0
```

Việc đọc sau reset không sử dụng giá trị storage `0`, mà dựa vào cờ `*_WRITTEN`.

Do đó sau reset:

```text
read(REG0) -> 32'hDEAD_BEEF
read(REG1) -> 32'hDEAD_BEEF
read(REG2) -> 32'hDEAD_BEEF
read(REG3) -> 32'hDEAD_BEEF
```

---

# 4. Register State

Mỗi register có hai thành phần state:

1. Register value
2. Register written flag

Cụ thể:

```systemverilog
logic [31:0] reg0;
logic [31:0] reg1;
logic [31:0] reg2;
logic [31:0] reg3;

logic        reg0_written;
logic        reg1_written;
logic        reg2_written;
logic        reg3_written;
```

Ý nghĩa của `*_written`:

```text
0 -> register chưa từng được ghi kể từ reset
1 -> register đã từng được ghi kể từ reset
```

Một register vẫn được xem là đã ghi ngay cả khi giá trị ghi vào là:

```text
32'h0000_0000
```

Ví dụ:

```text
write REG0 = 32'h0000_0000
```

sau đó:

```text
read REG0 = 32'h0000_0000
```

không được trả về `32'hDEAD_BEEF`.

---

# 5. APB Transaction Model

Module hỗ trợ APB transaction theo hai phase.

## 5.1 Setup phase

Transaction bắt đầu khi:

```text
psel    = 1
penable = 0
```

Trong setup phase, Master cung cấp:

```text
paddr
pwrite
pwdata   // đối với write transaction
```

Các giá trị này được giữ ổn định cho access phase.

## 5.2 Access phase

Transaction thực hiện khi:

```text
psel    = 1
penable = 1
```

Module không sử dụng wait state.

Do đó:

```text
pready = 1
```

cho mọi transfer.

Mỗi APB transaction hoàn thành trong một access cycle.

---

# 6. Write Transaction

Một write transaction hợp lệ được xác định bởi:

```text
psel    = 1
penable = 1
pwrite  = 1
```

Write được thực hiện tại cạnh lên của `clk`.

Điều kiện cập nhật state:

```systemverilog
if (psel && penable && pwrite)
```

Trong trường hợp này, module decode `paddr`.

## 6.1 Write REG0

Khi:

```text
paddr = 4'h0
```

thì:

```systemverilog
reg0         <= pwdata;
reg0_written <= 1'b1;
```

## 6.2 Write REG1

Khi:

```text
paddr = 4'h4
```

thì:

```systemverilog
reg1         <= pwdata;
reg1_written <= 1'b1;
```

## 6.3 Write REG2

Khi:

```text
paddr = 4'h8
```

thì:

```systemverilog
reg2         <= pwdata;
reg2_written <= 1'b1;
```

## 6.4 Write REG3

Khi:

```text
paddr = 4'hC
```

thì:

```systemverilog
reg3         <= pwdata;
reg3_written <= 1'b1;
```

---

# 7. Read Transaction

Một read transaction hợp lệ được xác định bởi:

```text
psel    = 1
penable = 1
pwrite  = 0
```

Read data được tạo combinationally dựa trên:

```text
paddr
*_written
register value
```

## 7.1 Read REG0

```text
paddr = 4'h0
```

Nếu:

```text
reg0_written = 0
```

thì:

```text
prdata = 32'hDEAD_BEEF
```

Nếu:

```text
reg0_written = 1
```

thì:

```text
prdata = reg0
```

## 7.2 Read REG1

```text
paddr = 4'h4
```

Nếu:

```text
reg1_written = 0
```

thì:

```text
prdata = 32'hDEAD_BEEF
```

Ngược lại:

```text
prdata = reg1
```

## 7.3 Read REG2

```text
paddr = 4'h8
```

Nếu:

```text
reg2_written = 0
```

thì:

```text
prdata = 32'hDEAD_BEEF
```

Ngược lại:

```text
prdata = reg2
```

## 7.4 Read REG3

```text
paddr = 4'hC
```

Nếu:

```text
reg3_written = 0
```

thì:

```text
prdata = 32'hDEAD_BEEF
```

Ngược lại:

```text
prdata = reg3
```

---

# 8. Invalid Address Handling

Các giá trị `paddr` khác:

```text
4'h0
4'h4
4'h8
4'hC
```

được xem là **unmapped / invalid address**.

Do module không có `pslverr`, invalid transaction vẫn được hoàn thành bình thường.

## 8.1 Invalid read

```text
prdata = 32'h0000_0000
```

## 8.2 Invalid write

Không register nào được thay đổi.

Ví dụ:

```text
paddr  = 4'h1
pwrite = 1
pwdata = 32'h1234_5678
```

thì:

```text
REG0 unchanged
REG1 unchanged
REG2 unchanged
REG3 unchanged
```

Transaction vẫn hoàn thành với:

```text
pready = 1
```

---

# 9. PREADY Behavior

Module không chèn wait state.

Trong access phase:

```text
psel    = 1
penable = 1
```

`pready` phải bằng:

```text
1'b1
```

Có thể triển khai:

```systemverilog
assign pready = 1'b1;
```

`pready` không phụ thuộc vào:

```text
paddr
pwrite
pwdata
```

Do đó cả valid và invalid address đều hoàn thành trong một access cycle.

---

# 10. PRDATA Behavior

`prdata` chỉ có ý nghĩa trong một read access:

```text
psel    = 1
penable = 1
pwrite  = 0
```

Để tránh latch và tạo behavior xác định trong simulation, có thể quy định:

```text
prdata = 32'h0000_0000
```

khi không ở read access.

Behavior:

```text
if (psel && penable && !pwrite)
    decode paddr and generate read data
else
    prdata = 32'h0000_0000
```

`prdata` là combinational output.

---

# 11. Register Map

```text
+---------+----------+--------+--------+
| Address | Register | Width  | Access |
+---------+----------+--------+--------+
| 0x0     | REG0     | 32-bit | RW     |
| 0x4     | REG1     | 32-bit | RW     |
| 0x8     | REG2     | 32-bit | RW     |
| 0xC     | REG3     | 32-bit | RW     |
+---------+----------+--------+--------+
```

Các address khác:

```text
0x1, 0x2, 0x3,
0x5, 0x6, 0x7,
0x9, 0xA, 0xB,
0xD, 0xE, 0xF
```

là unmapped.

---

# 12. Address Interpretation

`paddr` là **byte address**.

Khoảng cách giữa hai register liên tiếp là:

```text
0x4 bytes
```

vì mỗi register có kích thước:

```text
32 bits = 4 bytes
```

Address mapping:

```text
0x0 -> REG0
0x4 -> REG1
0x8 -> REG2
0xC -> REG3
```

Không hỗ trợ unaligned address.

---

# 13. Clocked State Update

Tất cả state của module phải được cập nhật trong một sequential block sử dụng:

```systemverilog
always_ff @(posedge clk or negedge rst_n)
```

Reset:

```systemverilog
if (!rst_n)
```

phải reset tất cả register storage và `*_written` flag về giá trị mặc định.

Write operation chỉ xảy ra tại:

```text
posedge clk
```

khi:

```text
psel && penable && pwrite
```

đồng thời bằng `1`.

---

# 14. Functional Requirements

### FR-01
Module phải implement 4 register 32-bit:

```text
REG0 @ 0x0
REG1 @ 0x4
REG2 @ 0x8
REG3 @ 0xC
```

### FR-02
Tất cả 4 register phải hỗ trợ read và write.

### FR-03
Module phải sử dụng `clk` và asynchronous active-low `rst_n`.

### FR-04
Reset phải đặt toàn bộ register storage về:

```text
32'h0000_0000
```

### FR-05
Reset phải đặt toàn bộ `*_written` flag về `0`.

### FR-06
Register có `*_written = 0` phải trả về:

```text
32'hDEAD_BEEF
```

khi được đọc.

### FR-07
Register có `*_written = 1` phải trả về giá trị register hiện tại.

### FR-08
Một write hợp lệ phải cập nhật toàn bộ 32 bit của register.

### FR-09
Sau một write hợp lệ, `*_written` tương ứng phải được set thành `1`.

### FR-10
Một write giá trị `32'h0000_0000` vẫn phải set `*_written = 1`.

### FR-11
Ghi lại một register phải overwrite giá trị cũ.

### FR-12
Invalid write không được thay đổi state.

### FR-13
Invalid read phải trả về:

```text
32'h0000_0000
```

### FR-14
`pready` phải luôn bằng `1` và module không tạo wait state.

### FR-15
`prdata` phải là combinational output.

---

# 15. Example Transactions

## 15.1 Read all registers after reset

Sau:

```text
rst_n = 0
```

và sau khi reset được release:

```text
rst_n = 1
```

thực hiện read:

```text
read 0x0 -> DEAD_BEEF
read 0x4 -> DEAD_BEEF
read 0x8 -> DEAD_BEEF
read 0xC -> DEAD_BEEF
```

---

## 15.2 Write REG0

```text
paddr  = 4'h0
pwrite = 1
pwdata = 32'h1234_5678
```

Tại `posedge clk` của access cycle:

```text
reg0         = 32'h1234_5678
reg0_written = 1
```

Read tiếp theo:

```text
read 0x0 -> 32'h1234_5678
```

---

## 15.3 Write REG2

```text
paddr  = 4'h8
pwrite = 1
pwdata = 32'hA5A5_5A5A
```

Sau access clock:

```text
reg2         = 32'hA5A5_5A5A
reg2_written = 1
```

Read:

```text
read 0x8 -> 32'hA5A5_5A5A
```

---

## 15.4 Write zero

```text
paddr  = 4'h4
pwrite = 1
pwdata = 32'h0000_0000
```

Sau write:

```text
reg1         = 32'h0000_0000
reg1_written = 1
```

Read:

```text
read 0x4 -> 32'h0000_0000
```

---

## 15.5 Partial register state

Chỉ ghi `REG0` và `REG2`:

```text
REG0 = 32'h1111_1111
REG2 = 32'h2222_2222
```

Khi đọc:

```text
0x0 -> 1111_1111
0x4 -> DEAD_BEEF
0x8 -> 2222_2222
0xC -> DEAD_BEEF
```

---

## 15.6 Overwrite

```text
write 0x0 = 32'hAAAA_AAAA
write 0x0 = 32'hBBBB_BBBB
```

Read:

```text
read 0x0 -> 32'hBBBB_BBBB
```

---

# 16. APB Timing

Transaction chuẩn:

```text
              Setup phase        Access phase
             ┌─────────────┐   ┌─────────────┐
PSEL         ────────1───────────────1───────
PENABLE      ────────0───────────────1───────
PWRITE       ────────< valid value >
PADDR        ────────< valid address >
PWDATA       ────────< valid for write >

PREADY       ────────────────────────1───────
PRDATA       ─────────────────────< valid >──
```

Không có wait state:

```text
Setup cycle
    ↓
Access cycle
    ↓
Transfer complete
```

---

# 17. Verification Requirements

Verification environment phải kiểm tra tối thiểu các trường hợp sau.

## 17.1 Reset test

Assert:

```text
rst_n = 0
```

Kiểm tra:

```text
REG0 = 0
REG1 = 0
REG2 = 0
REG3 = 0

reg0_written = 0
reg1_written = 0
reg2_written = 0
reg3_written = 0
```

Sau reset, đọc tất cả register:

```text
DEAD_BEEF
```

---

## 17.2 Read-before-write test

Đọc tất cả address hợp lệ ngay sau reset:

```text
0x0 -> DEAD_BEEF
0x4 -> DEAD_BEEF
0x8 -> DEAD_BEEF
0xC -> DEAD_BEEF
```

---

## 17.3 Single-register write/read test

Ghi từng register với các giá trị khác nhau rồi đọc lại.

---

## 17.4 Write zero test

Ghi:

```text
32'h0000_0000
```

vào từng register và đảm bảo read trả về zero, không phải `DEAD_BEEF`.

---

## 17.5 Overwrite test

Ghi một register nhiều lần và đảm bảo read trả về giá trị write cuối cùng.

---

## 17.6 Independent register state test

Việc ghi một register không được làm thay đổi giá trị hoặc `written` state của các register khác.

---

## 17.7 Invalid address test

Đọc tất cả address unmapped:

```text
0x1, 0x2, 0x3,
0x5, 0x6, 0x7,
0x9, 0xA, 0xB,
0xD, 0xE, 0xF
```

Expected:

```text
prdata = 32'h0000_0000
```

Write vào các address trên không được thay đổi bất kỳ register nào.

---

## 17.8 Back-to-back transaction test

Kiểm tra liên tiếp:

```text
write REG0
read  REG0
write REG1
read  REG1
write REG2
read  REG2
write REG3
read  REG3
```

Module phải xử lý đúng tất cả transaction mà không cần idle cycle bổ sung.

---

## 17.9 PREADY test

Kiểm tra:

```text
pready == 1'b1
```

trong mọi access cycle hợp lệ.

---

# 18. Recommended RTL Structure

Implementation nên được tổ chức thành hai phần logic chính.

## 18.1 Sequential logic

Chịu trách nhiệm:

- Asynchronous reset
- Cập nhật `reg0`...`reg3`
- Cập nhật `reg0_written`...`reg3_written`

Dạng tổng quát:

```systemverilog
always_ff @(posedge clk or negedge rst_n)
```

## 18.2 Combinational logic

Chịu trách nhiệm:

- Decode `paddr`
- Tạo `prdata`
- Tạo `pready`

Dạng tổng quát:

```systemverilog
always_comb
```

hoặc continuous assignment đối với các tín hiệu đơn giản.

---

# 19. Behavioral Summary

Behavior chính của module:

```text
After reset:

read(any register) = DEAD_BEEF

After write(REGx, DATA):

read(REGx) = DATA

After overwrite(REGx, NEW_DATA):

read(REGx) = NEW_DATA
```

`pready` luôn bằng `1`.

Invalid read trả về `0`.

Invalid write không làm thay đổi state.

