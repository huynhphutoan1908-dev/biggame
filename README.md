# hi — app API test iOS

App SwiftUI nhỏ: nhập URL, bấm Fetch, xem JSON trả về.

## Cấu trúc

```
hi/
├── Sources/
│   ├── HiApp.swift          # entry point
│   └── ContentView.swift    # UI goi API
├── project.yml              # cau hinh XcodeGen
├── Makefile                 # make ipa -> build/ipa/hi-unsigned.ipa
└── .github/workflows/build-ipa.yml
```

## Cach tao IPA (khong can may Mac)

1. Tao repo GitHub (public) va day toan bo thu muc `hi/` len.
2. GitHub Actions tu chay workflow tren runner macOS -> mo tab **Actions**, tai artifact `hi-ipa`.
3. Ky + cai IPA bang 1 trong:
   - **AltStore / SideStore** (Apple ID mien phi, tu gia han 7 ngay)
   - **Sideloadly** (cay cap USB)
   - **Xcode > Signing & Capabilities** neu co may Mac + ching chi: mo `project.yml` bang `xcodegen` roi chay thang tren may.

## Chay local neu co Mac

```bash
brew install xcodegen
cd hi && make ipa
```

## Doi API mac dinh / tenant

Sua `urlText` trong `Sources/ContentView.swift`, hoac thay `PRODUCT_BUNDLE_IDENTIFIER` trong `project.yml` (hien tai: `com.app.toanbakhi`).
