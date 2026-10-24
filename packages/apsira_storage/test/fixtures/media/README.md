# test/fixtures/media

From relay test/fixtures/media @ 09b28810, byte for byte (D-APK-015).

Tiny two-tone images (red left half, blue right half) for the image-meta
and photo-source tests (RELAY 07 P2-06). Pillow wrote them; each holds only what
its name says.

| File | Stored size | What |
|---|---|---|
| `photo.jpg` | 40 × 30 | JPEG, JFIF, no EXIF; `FakePhotoSource`'s default photo |
| `orientation_6.jpg` | 40 × 20 | JPEG, big-endian EXIF orientation 6: shows 20 × 40, turned a quarter clockwise |
| `orientation_3.jpg` | 40 × 20 | JPEG, EXIF orientation 3: shows 40 × 20, upside down |
| `photo.png` | 12 × 7 | PNG |
| `photo.gif` | 9 × 5 | GIF89a |
| `lossy.webp` | 16 × 8 | WebP, `VP8 ` chunk |
| `lossless.webp` | 10 × 6 | WebP, `VP8L` chunk |
| `orientation_6.webp` | 16 × 8 | WebP, `VP8X` with an `EXIF` chunk, orientation 6 |
