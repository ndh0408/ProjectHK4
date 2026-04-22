# LUMA — Setup Guide (Nhóm 5)

Hướng dẫn cho thành viên clone repo về máy mới và chạy đầy đủ backend + admin + mobile (web hoặc Android native).

---

## 1. Cài đặt phần mềm cần có

| Phần mềm | Version | Bắt buộc? |
|---|---|---|
| **Git** | mới nhất | ✅ |
| **Java JDK** | 21 | ✅ (backend Spring Boot) |
| **Node.js** | 18+ | ✅ (admin React) |
| **Flutter SDK** | 3.41+ | ✅ (mobile) |
| **SQL Server** | Express/Developer 2019+ | ✅ (port 1433, user `sa`) |
| **Android Studio + AVD** | mới nhất | ⚠️ chỉ nếu muốn chạy **mobile native** |

Thêm các biến môi trường hệ thống: `JAVA_HOME`, `FLUTTER_HOME` (tuỳ chọn), `ANDROID_HOME` → `%LOCALAPPDATA%\Android\sdk`.

---

## 2. Clone repo

```cmd
git clone https://github.com/ndh0408/ProjectHK4.git
cd ProjectHK4
```

---

## 3. Import file nhạy cảm từ archive chung

Nhóm trưởng (Huy) sẽ gửi file **`LUMA-secrets.zip`** qua Zalo/Drive. File này chứa:
- `backend.env` — credentials (DB password, JWT, Stripe, Cloudinary, OpenAI, Google OAuth client)
- `admin.env` — config URL cho admin React
- `debug.keystore` — keystore dùng chung để Google Sign-In trên Android hoạt động với cùng 1 SHA-1 đã đăng ký Cloud Console
- `import-secrets.bat` — script auto-copy các file vào đúng chỗ

### Cách dùng

1. Giải nén `LUMA-secrets.zip` vào **thư mục bất kỳ** (ví dụ: Desktop).
2. **Chuột phải** `import-secrets.bat` → **Run as administrator** *(không bắt buộc nhưng an toàn hơn)*.
3. Khi script hỏi, nhập **đường dẫn tuyệt đối tới repo** vừa clone (ví dụ: `D:\ProjectHK4`).
4. Script sẽ tự copy:
   - `backend.env` → `<repo>\backend\.env`
   - `admin.env` → `<repo>\admin\.env`
   - `debug.keystore` → `%USERPROFILE%\.android\debug.keystore`

---

## 4. Setup database

1. Cài **SQL Server Express 2019+**, dùng chế độ **Mixed Authentication**, đặt password cho user `sa` là `1` (hoặc đổi `DB_PASSWORD` trong `backend/.env` cho khớp).
2. Bật TCP/IP port 1433 (SQL Server Configuration Manager).
3. Restore DB từ file `luma_db.bak` có sẵn trong repo:

```sql
RESTORE DATABASE luma_db FROM DISK = N'<đường_dẫn_tuyệt_đối>\luma_db.bak'
WITH REPLACE,
  MOVE 'luma_db'     TO '<SQL_DATA_PATH>\luma_db.mdf',
  MOVE 'luma_db_log' TO '<SQL_DATA_PATH>\luma_db_log.ldf';
```

Thay `<SQL_DATA_PATH>` bằng đường thư mục DATA của instance (thường là `C:\Program Files\Microsoft SQL Server\MSSQL16.SQLEXPRESS\MSSQL\DATA\`).

Hoặc dùng SSMS (SQL Server Management Studio): chuột phải `Databases` → Restore Database → chọn file `.bak`.

---

## 5. Chạy hệ thống

Có 2 script sẵn:

### `start-all.bat` — chế độ Web (mobile chạy qua browser)

- Backend :8080, Admin React :3000, Mobile Flutter Web :5000.
- Google Sign-In hoạt động ngay trên web.

### `start-all-app.bat` — chế độ App (mobile chạy native trên Android emulator)

- Backend :8080, Admin :3000, Mobile chạy native trên **Pixel_6_API_34** AVD (tự launch nếu chưa chạy).
- Yêu cầu: đã cài Android Studio + tạo AVD tên `Pixel_6_API_34` (API 34, Google APIs).
- Google Sign-In hoạt động nhờ `debug.keystore` chung có trong `LUMA-secrets.zip`.

Double-click 1 trong 2 file là xong.

---

## 6. URL truy cập

| Service | URL |
|---|---|
| Backend API | http://localhost:8080 |
| Swagger UI | http://localhost:8080/swagger-ui.html |
| Admin Panel (React) | http://localhost:3000 |
| Mobile Web | http://localhost:5000 |
| Mobile App (native) | chạy trên Android emulator/thiết bị |

---

## 7. Troubleshooting

**"Backend không kết nối được SQL Server"** — kiểm tra TCP/IP port 1433 đã bật trong SQL Server Configuration Manager, và `DB_PASSWORD` trong `.env` khớp với password thật của user `sa`.

**"Google Sign-In fail `ApiException: 10` trên Android"** — chưa import `debug.keystore` đúng chỗ. Kiểm tra file `C:\Users\<username>\.android\debug.keystore` có khớp MD5 với file trong ZIP không. Nếu vừa copy, cần **xóa thư mục `mobile/build`** rồi chạy lại để rebuild APK bằng keystore mới.

**"Kotlin compile daemon crash với `IllegalArgumentException: different roots`"** — pub cache ở ổ C: nhưng project ở ổ D: (hoặc ngược lại). Đã có `kotlin.incremental=false` trong `mobile/android/gradle.properties` xử lý rồi, chỉ cần xóa `mobile/build` và build lại.

**"Android emulator không mở"** — kiểm tra AVD tên có đúng `Pixel_6_API_34` không. Nếu tên khác, mở `start-all-app.bat` sửa dòng `flutter emulators --launch Pixel_6_API_34` thành tên AVD của bạn, hoặc tạo AVD mới đúng tên.

**"Bàn phím máy tính gõ không nhận trên emulator"** — sửa file `C:\Users\<username>\.android\avd\Pixel_6_API_34.avd\config.ini`, đổi `hw.keyboard = no` thành `hw.keyboard = yes`, rồi cold boot AVD lại.
