# tweak-builder

Drop any `.x` or `.xm` Logos tweak file into this repo and GitHub Actions will automatically compile it into a `.deb` using Theos.

## How to use

### Option 1 — Just drop your file in
1. Fork or clone this repo
2. Delete `ExampleTweak.x`
3. Add your `YourTweak.x` (or `.xm`) file
4. Push — the workflow auto-detects the file and builds it
5. Download the `.deb` from the **Actions** tab → latest run → **Artifacts**

### Option 2 — Bring your own Makefile
If you need custom flags, frameworks, or bundle filters, include a `Makefile` alongside your `.x` file. The workflow will use it as-is.

### Option 3 — Tag a release
Push a git tag (e.g. `v1.0.0`) and the workflow will also create a GitHub Release with the `.deb` attached.

## Auto-generated files

If either of these are missing, the workflow generates them automatically:

| File | What it generates |
|------|-------------------|
| `Makefile` | `ARCHS = arm64 arm64e`, target iOS 14+, `-fobjc-arc`, UIKit + Foundation |
| `control` | `com.example.<tweakname>`, version `1.0.0` |

Edit and commit them if you want to customize package ID, version, linked frameworks, etc.

## SDK / Theos

- Theos is cloned from the official repo and cached between runs
- SDK: **iPhoneOS 16.5** (cached)
- Target: **iOS 14.0+**, `arm64 + arm64e`

## File structure

```
tweak-builder/
├── .github/
│   └── workflows/
│       └── build.yml      ← the whole pipeline lives here
├── YourTweak.x            ← put your file here
├── control                ← optional, auto-generated if missing
└── Makefile               ← optional, auto-generated if missing
```
