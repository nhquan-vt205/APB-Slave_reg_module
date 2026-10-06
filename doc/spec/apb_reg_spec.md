# apb_reg – Đặc tả
Loại: leaf · Level: L2 · Trạng thái: PASS

## Chức năng

APB Slave Register Block cung cấp giao tiếp APB để đọc/ghi 4 thanh ghi 32-bit. Module không chèn wait state (`pready = 1` luôn). Mỗi thanh ghi có cờ `*_written` theo dõi trạng thái đã-ghi-lần-đầu:

- Chưa ghi (`*_written = 0`): đọc trả về `32'hDEAD_BEEF`.
- Đã ghi (`*_written = 1`): đọc trả về giá trị cuối cùng đã ghi.

Ghi `32'h0000_0000` vẫn set `*_written = 1` – đọc lại trả về `0`, không phải `DEAD_BEEF`.

Quy ước tên port: input dùng tên APB chuẩn không suffix `_i`/`_o` (theo source spec).

## Interface

Clock `clk` sườn lên · Reset `rst_n` async active-low

| Tên port | Hướng | Width | Mô tả |
| --- | --- | --- | --- |
| `clk` | in | 1 | Clock đồng bộ, sườn lên |
| `rst_n` | in | 1 | Reset async active-low |
| `psel` | in | 1 | APB slave select |
| `pwdata` | in | 32 | APB write data |
| `paddr` | in | 4 | APB register address (byte address) |
| `penable` | in | 1 | APB access phase indicator |
| `pwrite` | in | 1 | 1 = write, 0 = read |
| `prdata` | out | 32 | APB read data (combinational) |
| `pready` | out | 1 | APB transfer ready (luôn = 1) |

## Thanh ghi

Bus: APB, base address 0x0, độ rộng 32-bit. Địa chỉ không tồn tại: đọc trả về `32'h0`, ghi bị bỏ qua, transaction vẫn hoàn thành (`pready = 1`, không `pslverr`).

| Offset | Tên | Bit | Field | Truy cập | Reset | Mô tả |
| --- | --- | --- | --- | --- | --- | --- |
| 0x0 | REG0 | 31:0 | REG0 | RW | 0x0000_0000 | Thanh ghi đa dụng 0 |
| 0x4 | REG1 | 31:0 | REG1 | RW | 0x0000_0000 | Thanh ghi đa dụng 1 |
| 0x8 | REG2 | 31:0 | REG2 | RW | 0x0000_0000 | Thanh ghi đa dụng 2 |
| 0xC | REG3 | 31:0 | REG3 | RW | 0x0000_0000 | Thanh ghi đa dụng 3 |

Khoảng cách giữa hai thanh ghi liên tiếp: 4 byte. `paddr` là byte address, chỉ 4 địa chỉ hợp lệ: `4'h0`, `4'h4`, `4'h8`, `4'hC`.

## Cấu trúc

Mỗi thanh ghi gồm:
- `regN` [31:0]: giá trị thanh ghi (flip-flop).
- `regN_written` [0]: cờ đã-ghi (flip-flop). Set `1` khi ghi lần đầu, giữ `1` cho đến reset.

Tổng cộng 4 × (32 + 1) = 132 bit trạng thái.

## Hành vi

### APB transaction (2-phase, không wait state)

- **Setup phase**: `psel = 1`, `penable = 0` – master cung cấp `paddr`, `pwrite`, `pwdata`.
- **Access phase**: `psel = 1`, `penable = 1` – transfer hoàn thành.
- `pready = 1` luôn (assign cứng), không phụ thuộc `paddr`/`pwrite`/`pwdata`.

### Write (tại posedge clk)

Điều kiện: `psel && penable && pwrite`.

```text
paddr = 4'h0 → reg0 <= pwdata, reg0_written <= 1
paddr = 4'h4 → reg1 <= pwdata, reg1_written <= 1
paddr = 4'h8 → reg2 <= pwdata, reg2_written <= 1
paddr = 4'hC → reg3 <= pwdata, reg3_written <= 1
Khác          → không thay đổi state
```

Ghi đè (overwrite): giá trị mới thay giá trị cũ, `*_written` giữ `1`.

### Read (combinational)

Điều kiện: `psel && penable && !pwrite`.

```text
paddr = 4'h0 → prdata = reg0_written ? reg0 : 32'hDEAD_BEEF
paddr = 4'h4 → prdata = reg1_written ? reg1 : 32'hDEAD_BEEF
paddr = 4'h8 → prdata = reg2_written ? reg2 : 32'hDEAD_BEEF
paddr = 4'hC → prdata = reg3_written ? reg3 : 32'hDEAD_BEEF
Khác          → prdata = 32'h0000_0000
```

Ngoài read access (`!(psel && penable && !pwrite)`): `prdata = 32'h0000_0000`.

`prdata` là combinational output – không latency thêm.

## Reset

`rst_n = 0` (async active-low):

```text
reg0 = 0, reg1 = 0, reg2 = 0, reg3 = 0
reg0_written = 0, reg1_written = 0, reg2_written = 0, reg3_written = 0
```

Sau reset, đọc bất kỳ thanh ghi hợp lệ nào trả về `32'hDEAD_BEEF` (do `*_written = 0`).
