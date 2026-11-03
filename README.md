# Website_nuocgiaikhat

Toàn bộ ứng dụng frontend nằm trong thư mục [`frontend`](./frontend). Hướng dẫn chi tiết: [frontend/README.md](./frontend/README.md).

## Chạy frontend

Yêu cầu Node.js 22.12+ và npm.

```sh
cd frontend
npm install
npm run dev
```

Trên PowerShell, có thể dùng `npm.cmd` nếu `npm.ps1` bị chặn. Truy cập http://127.0.0.1:5173.

## Kiểm tra và build

Chạy trong thư mục `frontend`:

```sh
npm run lint
npm test
npm run build
```

Bản build được tạo ở `frontend/dist`. Kiểm tra trình duyệt: `npm run test:e2e` (cần Chrome).

## Cấu trúc

```text
frontend/
  src/                  Mã nguồn React
  public/               Tài nguyên tĩnh
  tests/                Kiểm thử logic và trình duyệt
  docs/                 Tài liệu và ảnh giao diện
  package.json
  package-lock.json
  .env.example
  vite.config.js
```

`.gitignore` loại trừ thư viện cài đặt, bản build, tệp môi trường riêng và kết quả kiểm thử khi push lên GitHub. Giữ `package-lock.json` và `.env.example` trong mã nguồn.
