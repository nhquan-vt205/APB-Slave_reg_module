# apb_reg – Direct Test VPLAN

Module: `apb_reg` · Spec: `doc/spec/apb_reg_spec.md` · RTL: `rtl/apb_reg.sv`
Định dạng theo `vplan_template/Direct_Test_VPLAN_Checklist_Template.md` (direct test, không UVM / coverage / assertion).

## 1. Quy ước chung

- Mọi truy cập APB là 2-phase, không wait state: **setup** (`psel=1`, `penable=0`) → **access** (`psel=1`, `penable=1`), `pready=1` nên transfer kết thúc ngay ở access phase.
- Giá trị đọc khi thanh ghi chưa từng được ghi: `UNWRIT = 32'hDEAD_BEEF`.
- Địa chỉ hợp lệ: `4'h0` (REG0), `4'h4` (REG1), `4'h8` (REG2), `4'hC` (REG3). Mọi `paddr` khác là không hợp lệ.
- Mẫu dữ liệu dùng lại: `P0 = 32'h0000_0000`, `P1 = 32'hFFFF_FFFF`, `P5 = 32'h5555_5555`, `PA = 32'hAAAA_AAAA`.
- "Đọc `addr`" = chạy trọn một read transfer và lấy `prdata` tại chu kỳ access phase.

## 2. Direct Test VPLAN

| ID | Item | Sub item 1 | Sub item 2 | Test sequence | Pass condition |
|---:|---|---|---|---|---|
| 1 | Reset | Trạng thái sau reset | Giá trị đọc mặc định | Giữ `rst_n=0` ≥ 2 chu kỳ rồi thả. Không ghi gì. Đọc lần lượt `0x0`, `0x4`, `0x8`, `0xC`. | Cả 4 lần đọc `prdata = 32'hDEAD_BEEF` (vì `regN_written_q = 0`). |
| 2 | Reset | Trạng thái sau reset | Async reset khi đang chạy | Ghi `P5` vào `0x0`, đọc lại xác nhận `P5`. Hạ `rst_n=0` bất đồng bộ (giữa chu kỳ, không cạnh clk), giữ 1 chu kỳ, thả. Đọc `0x0`. | Sau reset `prdata = 32'hDEAD_BEEF` (cả `reg0_q` và `reg0_written_q` bị xóa). |
| 3 | Register access | REG0 `0x0` | Ghi / đọc lại | Ghi `P1` vào `0x0`, đọc `0x0`. Ghi `P5` vào `0x0`, đọc `0x0`. Ghi `PA` vào `0x0`, đọc `0x0`. | Lần lượt `prdata` = `32'hFFFF_FFFF`, `32'h5555_5555`, `32'hAAAA_AAAA`. |
| 4 | Register access | REG1 `0x4` | Ghi / đọc lại | Như ID 3 nhưng địa chỉ `0x4`. | Lần lượt `prdata` = `32'hFFFF_FFFF`, `32'h5555_5555`, `32'hAAAA_AAAA`. |
| 5 | Register access | REG2 `0x8` | Ghi / đọc lại | Như ID 3 nhưng địa chỉ `0x8`. | Lần lượt `prdata` = `32'hFFFF_FFFF`, `32'h5555_5555`, `32'hAAAA_AAAA`. |
| 6 | Register access | REG3 `0xC` | Ghi / đọc lại | Như ID 3 nhưng địa chỉ `0xC`. | Lần lượt `prdata` = `32'hFFFF_FFFF`, `32'h5555_5555`, `32'hAAAA_AAAA`. |
| 7 | Written flag | Ghi giá trị 0 | Ghi `0x0000_0000` vẫn set cờ | Sau reset, đọc `0x8` (kỳ vọng `DEAD_BEEF`). Ghi `P0` vào `0x8`. Đọc `0x8`. | Lần đọc đầu = `32'hDEAD_BEEF`; lần đọc sau = `32'h0000_0000`, **không** phải `DEAD_BEEF`. |
| 8 | Written flag | Ghi đè | Cờ giữ `1` sau nhiều lần ghi | Ghi `PA` vào `0xC`, đọc. Ghi `P0` vào `0xC`, đọc. Ghi `P1` vào `0xC`, đọc. | Lần lượt `32'hAAAA_AAAA`, `32'h0000_0000`, `32'hFFFF_FFFF` – không lần nào trả `DEAD_BEEF`. |
| 9 | Register access | Độc lập giữa các thanh ghi | Ghi một, không ảnh hưởng ba cái còn lại | Sau reset, chỉ ghi `P5` vào `0x4`. Đọc `0x0`, `0x4`, `0x8`, `0xC`. | `0x0` = `DEAD_BEEF`; `0x4` = `32'h5555_5555`; `0x8` = `DEAD_BEEF`; `0xC` = `DEAD_BEEF`. |
| 10 | Register access | Nhiều thanh ghi | Ghi cả 4 rồi đọc lại | Sau reset, ghi `0x0`=`P0`, `0x4`=`P1`, `0x8`=`P5`, `0xC`=`PA` (4 transfer liên tiếp). Đọc `0x0`, `0x4`, `0x8`, `0xC`. | `32'h0000_0000`, `32'hFFFF_FFFF`, `32'h5555_5555`, `32'hAAAA_AAAA` theo đúng thứ tự. |
| 11 | Invalid address | Ghi | Ghi địa chỉ không hợp lệ bị bỏ qua | Sau reset, ghi `P1` vào `0x1`, `0x7`, `0xF`. Sau đó đọc `0x0`, `0x4`, `0x8`, `0xC`. | Cả 4 lần đọc = `32'hDEAD_BEEF` (không thanh ghi nào bị ghi); 3 write transfer đều hoàn thành với `pready=1`. |
| 12 | Invalid address | Đọc | Đọc địa chỉ không hợp lệ trả 0 | Ghi `P1` vào cả 4 thanh ghi hợp lệ. Đọc `0x1`, `0x2`, `0x5`, `0xD`, `0xF`. | Mọi lần đọc `prdata = 32'h0000_0000` (không phải `DEAD_BEEF`, không phải `FFFF_FFFF`). |
| 13 | Bus protocol | `prdata` ngoài read access | Không có access / sai phase | Ghi `P1` vào `0x0`. Lấy mẫu `prdata` ở các điều kiện: (a) `psel=0`; (b) `psel=1, penable=0, pwrite=0, paddr=0x0` (setup phase của read); (c) `psel=1, penable=1, pwrite=1, paddr=0x0` (write access phase). | Cả ba trường hợp `prdata = 32'h0000_0000`. |
| 14 | Bus protocol | Write chỉ ở access phase | Setup phase không ghi | Sau reset, đặt `psel=1, penable=0, pwrite=1, paddr=0x4, pwdata=PA` trong 1 chu kỳ rồi hạ `psel=0` (hủy, không vào access phase). Đọc `0x4`. | `prdata = 32'hDEAD_BEEF` – `reg1_q` chưa bị ghi. |
| 15 | Bus protocol | `pready` | Luôn bằng 1 | Lấy mẫu `pready` mỗi chu kỳ trong toàn bộ test: lúc idle (`psel=0`), setup phase, access phase của write và read, cả với địa chỉ hợp lệ và không hợp lệ. | `pready = 1'b1` ở mọi chu kỳ, không có chu kỳ wait state nào. |
| 16 | Timing | Read latency | `prdata` tổ hợp, không thêm chu kỳ | Ghi `P5` vào `0x8`. Chạy read `0x8`: lấy mẫu `prdata` **ngay tại chu kỳ access phase** (`psel=1, penable=1, pwrite=0`), không chờ thêm chu kỳ nào. | `prdata = 32'h5555_5555` ngay tại chu kỳ đó (0 chu kỳ latency thêm). |
| 17 | Timing | Back-to-back | Write rồi read liên tiếp | Sau reset: write `0x0`=`PA` (setup+access), ngay chu kỳ kế tiếp bắt đầu read `0x0` (setup+access), không chèn idle. | Read trả `32'hAAAA_AAAA` – giá trị ghi ở transfer trước đã có hiệu lực. |

## 3. Chức năng → test ID

| Chức năng trong spec | Test ID |
|---|---|
| Reset: 4 thanh ghi và 4 cờ `written` về 0, async active-low | 1, 2 |
| Đọc thanh ghi chưa ghi trả `32'hDEAD_BEEF` | 1, 7, 9, 14 |
| Ghi / đọc lại từng thanh ghi RW 32-bit (0x0/0x4/0x8/0xC) | 3, 4, 5, 6, 10 |
| Ghi `32'h0000_0000` vẫn set `written` → đọc trả 0 | 7, 8, 10 |
| Ghi đè: giá trị mới thay cũ, `written` giữ 1 | 8 |
| Các thanh ghi độc lập với nhau | 9, 10 |
| Địa chỉ không tồn tại: ghi bị bỏ qua | 11 |
| Địa chỉ không tồn tại: đọc trả `32'h0`, transfer vẫn hoàn thành | 11, 12, 15 |
| `prdata = 32'h0` ngoài read access | 13 |
| Write chỉ xảy ra khi `psel & penable & pwrite` | 14 |
| `pready = 1` luôn, không wait state | 11, 15 |
| `prdata` tổ hợp, không latency thêm | 16, 17 |

Không có chức năng chính nào trong spec còn thiếu test. Không có trường `TBD`: mọi kết quả mong đợi tính trực tiếp từ bảng register map và mục "Hành vi" của spec.

Ngoài phạm vi (spec không định nghĩa, không test): `pslverr`, `pprot`, `pstrb`, truy cập không căn chỉnh theo byte-lane, nhiều master.
