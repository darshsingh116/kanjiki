import os
import subprocess
from PIL import Image

WORKSPACE = r"C:\StudioProjects\kanjiapp"
EDGE = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
TEMP_DIR = r"C:\Users\black\AppData\Local\Temp\opencode"

MASTER_SVG = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <defs>
    <!-- Background Gradient: Electric Violet Neobrutalism -->
    <linearGradient id="badgeBg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#7C68FF"/>
      <stop offset="42%" stop-color="#6C55F4"/>
      <stop offset="100%" stop-color="#4C34D8"/>
    </linearGradient>

    <!-- Border Gradient Highlight -->
    <linearGradient id="borderGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#B2A6FF" stop-opacity="0.95"/>
      <stop offset="100%" stop-color="#5841DC" stop-opacity="0.75"/>
    </linearGradient>

    <!-- Ki Energy Radiant Accent Gradient (Sakura Pink to Cyan Spark) -->
    <linearGradient id="kiEnergy" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#FF5CB8"/>
      <stop offset="55%" stop-color="#EC4899"/>
      <stop offset="100%" stop-color="#06B6D4"/>
    </linearGradient>

    <!-- Hard Neobrutalist Shadow for Strokes -->
    <filter id="hardShadow" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="10" stdDeviation="0" flood-color="#241475" flood-opacity="0.9"/>
    </filter>

    <!-- Spark Glow -->
    <radialGradient id="sparkGlow" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#38BDF8" stop-opacity="1"/>
      <stop offset="50%" stop-color="#06B6D4" stop-opacity="0.5"/>
      <stop offset="100%" stop-color="#06B6D4" stop-opacity="0"/>
    </radialGradient>
  </defs>

  <!-- Hard Tactile Neobrutalism Shadow -->
  <rect x="74" y="86" width="880" height="880" rx="208" fill="#090A13"/>

  <!-- Main Squircle Badge -->
  <rect x="50" y="54" width="880" height="880" rx="208" fill="url(#badgeBg)" stroke="url(#borderGrad)" stroke-width="12"/>

  <!-- Inner Inset Highlight Rim -->
  <rect x="62" y="66" width="856" height="856" rx="196" fill="none" stroke="#FFFFFF" stroke-opacity="0.14" stroke-width="4"/>

  <!-- Zen Energy Field (Ki Aura) -->
  <circle cx="490" cy="494" r="336" fill="none" stroke="#FFFFFF" stroke-opacity="0.04" stroke-width="3" stroke-dasharray="16 16"/>
  <circle cx="490" cy="494" r="236" fill="none" stroke="#FFFFFF" stroke-opacity="0.06" stroke-width="3" stroke-dasharray="8 12"/>

  <!-- Kanji 気 Core Japanese Calligraphy -->
  <g transform="translate(112, 112) scale(7.1)" filter="url(#hardShadow)"
     style="fill:none;stroke-linecap:round;stroke-linejoin:round;">

    <!-- Stroke 1: Top Diagonal Slash -->
    <path d="M37.75,9.25c0.25,1.62-0.25,2.75-1,4.25C35.63,15.74,28,25.25,24,29"
          stroke="#FFFFFF" stroke-width="8.2"/>

    <!-- Stroke 2: Upper Horizontal Bar -->
    <path d="M36.5,21.25c1.33-0.03,3.29-0.05,4.8-0.32c9.2-1.68,18.17-3.46,26.98-5.27c1.63-0.33,3.71-0.64,5.21-0.91"
          stroke="#FFFFFF" stroke-width="7.6"/>

    <!-- Stroke 3: Middle Horizontal Bar -->
    <path d="M31.25,32.75c1.5,0.38,3.3,0.26,4.96,0.08c7.67-0.83,19.54-2.58,29.14-4.39c1.94-0.37,3.64-0.41,4.91-0.45"
          stroke="#FFFFFF" stroke-width="7.6"/>

    <!-- Stroke 4: Grand Kamae Wrap and Ascending Hook -->
    <path d="M18.5,47c1.88,0.75,4,0.88,6.25,0.5c15.08-2.51,35-5.62,48.25-8c4.73-0.85,5.6,0.47,4.5,6.25c-4,21,0.71,40.32,11.5,50c7.25,6.5,6.5,0.75,6-5.25"
          stroke="#FFFFFF" stroke-width="8.4"/>

    <!-- Stroke 5: Inner Descending Left Diagonal -->
    <path d="M57,51.75c0.12,1.62-0.17,3.03-1,4.75C49.5,70,40.25,82.75,25.75,93.25"
          stroke="#FFFFFF" stroke-width="7.6"/>

    <!-- Stroke 6: Radiant Ki Energy Slash (Sakura-to-Cyan Accent) -->
    <path d="M30,63.75C41.5,68,54.5,78,62.25,90.5"
          stroke="url(#kiEnergy)" stroke-width="9.4"/>
  </g>

  <!-- Spirit Energy Sparkle (SRS Enlightenment Spark) -->
  <g transform="translate(630, 800)">
    <circle cx="0" cy="0" r="32" fill="url(#sparkGlow)"/>
    <!-- 4-point Diamond Star -->
    <path d="M 0 -26 Q 0 0 26 0 Q 0 0 0 26 Q 0 0 -26 0 Q 0 0 0 -26 Z" fill="#06B6D4"/>
    <path d="M 0 -14 Q 0 0 14 0 Q 0 0 0 14 Q 0 0 -14 0 Q 0 0 0 -14 Z" fill="#FFFFFF"/>
  </g>
</svg>'''

MASKABLE_SVG = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <defs>
    <!-- Background Gradient Full Bleed for Adaptive/Maskable Icons -->
    <linearGradient id="maskableBg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#7C68FF"/>
      <stop offset="45%" stop-color="#6C55F4"/>
      <stop offset="100%" stop-color="#4C34D8"/>
    </linearGradient>

    <!-- Ki Energy Radiant Accent Gradient -->
    <linearGradient id="kiEnergy" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#FF5CB8"/>
      <stop offset="55%" stop-color="#EC4899"/>
      <stop offset="100%" stop-color="#06B6D4"/>
    </linearGradient>

    <!-- Hard Neobrutalist Shadow for Strokes -->
    <filter id="hardShadow" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="10" stdDeviation="0" flood-color="#241475" flood-opacity="0.9"/>
    </filter>

    <radialGradient id="sparkGlow" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#38BDF8" stop-opacity="1"/>
      <stop offset="50%" stop-color="#06B6D4" stop-opacity="0.5"/>
      <stop offset="100%" stop-color="#06B6D4" stop-opacity="0"/>
    </radialGradient>
  </defs>

  <!-- Full Bleed Background for Safe Zone Cropping -->
  <rect x="0" y="0" width="1024" height="1024" fill="url(#maskableBg)"/>

  <!-- Zen Energy Field -->
  <circle cx="512" cy="512" r="320" fill="none" stroke="#FFFFFF" stroke-opacity="0.06" stroke-width="3" stroke-dasharray="16 16"/>
  <circle cx="512" cy="512" r="220" fill="none" stroke="#FFFFFF" stroke-opacity="0.08" stroke-width="3" stroke-dasharray="8 12"/>

  <!-- Kanji 気 Core Japanese Calligraphy centered inside safe circle -->
  <g transform="translate(134, 130) scale(6.7)" filter="url(#hardShadow)"
     style="fill:none;stroke-linecap:round;stroke-linejoin:round;">

    <path d="M37.75,9.25c0.25,1.62-0.25,2.75-1,4.25C35.63,15.74,28,25.25,24,29"
          stroke="#FFFFFF" stroke-width="8.2"/>
    <path d="M36.5,21.25c1.33-0.03,3.29-0.05,4.8-0.32c9.2-1.68,18.17-3.46,26.98-5.27c1.63-0.33,3.71-0.64,5.21-0.91"
          stroke="#FFFFFF" stroke-width="7.6"/>
    <path d="M31.25,32.75c1.5,0.38,3.3,0.26,4.96,0.08c7.67-0.83,19.54-2.58,29.14-4.39c1.94-0.37,3.64-0.41,4.91-0.45"
          stroke="#FFFFFF" stroke-width="7.6"/>
    <path d="M18.5,47c1.88,0.75,4,0.88,6.25,0.5c15.08-2.51,35-5.62,48.25-8c4.73-0.85,5.6,0.47,4.5,6.25c-4,21,0.71,40.32,11.5,50c7.25,6.5,6.5,0.75,6-5.25"
          stroke="#FFFFFF" stroke-width="8.4"/>
    <path d="M57,51.75c0.12,1.62-0.17,3.03-1,4.75C49.5,70,40.25,82.75,25.75,93.25"
          stroke="#FFFFFF" stroke-width="7.6"/>
    <path d="M30,63.75C41.5,68,54.5,78,62.25,90.5"
          stroke="url(#kiEnergy)" stroke-width="9.4"/>
  </g>

  <!-- Spirit Energy Sparkle -->
  <g transform="translate(625, 780)">
    <circle cx="0" cy="0" r="30" fill="url(#sparkGlow)"/>
    <path d="M 0 -24 Q 0 0 24 0 Q 0 0 0 24 Q 0 0 -24 0 Q 0 0 0 -24 Z" fill="#06B6D4"/>
    <path d="M 0 -13 Q 0 0 13 0 Q 0 0 0 13 Q 0 0 -13 0 Q 0 0 0 -13 Z" fill="#FFFFFF"/>
  </g>
</svg>'''

def render_svg(svg_code, out_png_path, width=1024, height=1024):
    temp_html = os.path.join(TEMP_DIR, "render.html")
    with open(temp_html, "w", encoding="utf-8") as f:
        f.write(f'''<!DOCTYPE html><html><head><style>
          html,body{{margin:0;padding:0;background:transparent;overflow:hidden;width:{width}px;height:{height}px;}}
        </style></head><body>{svg_code}</body></html>''')
    
    html_url = "file:///" + temp_html.replace("\\", "/")
    subprocess.run([
        EDGE,
        "--headless=new",
        "--disable-gpu",
        "--default-background-color=00000000",
        f"--screenshot={out_png_path}",
        f"--window-size={width},{height}",
        html_url
    ], check=True)

def main():
    os.makedirs(os.path.join(WORKSPACE, "assets", "icons"), exist_ok=True)
    os.makedirs(os.path.join(WORKSPACE, "web", "icons"), exist_ok=True)

    # 1. Save SVGs
    svg_dest = os.path.join(WORKSPACE, "assets", "icons", "kanjiki_icon.svg")
    with open(svg_dest, "w", encoding="utf-8") as f:
        f.write(MASTER_SVG)
    print(f"Saved: {svg_dest}")

    web_svg_dest = os.path.join(WORKSPACE, "web", "favicon.svg")
    with open(web_svg_dest, "w", encoding="utf-8") as f:
        f.write(MASTER_SVG)
    print(f"Saved: {web_svg_dest}")

    # 2. Render master 1024x1024 PNGs
    master_png = os.path.join(TEMP_DIR, "master_1024.png")
    maskable_png = os.path.join(TEMP_DIR, "maskable_1024.png")
    render_svg(MASTER_SVG, master_png, 1024, 1024)
    render_svg(MASKABLE_SVG, maskable_png, 1024, 1024)

    base_im = Image.open(master_png)
    mask_im = Image.open(maskable_png)

    # 3. Save Flutter assets
    base_im.save(os.path.join(WORKSPACE, "assets", "icons", "kanjiki_icon.png"))
    base_im.resize((512, 512), Image.Resampling.LANCZOS).save(os.path.join(WORKSPACE, "assets", "icons", "kanjiki_icon_512.png"))
    base_im.resize((128, 128), Image.Resampling.LANCZOS).save(os.path.join(WORKSPACE, "assets", "icons", "kanjiki_icon_128.png"))
    base_im.resize((64, 64), Image.Resampling.LANCZOS).save(os.path.join(WORKSPACE, "assets", "icons", "kanjiki_icon_64.png"))

    # 4. Web Favicon & Icons
    base_im.resize((32, 32), Image.Resampling.LANCZOS).save(os.path.join(WORKSPACE, "web", "favicon.png"))
    base_im.resize((192, 192), Image.Resampling.LANCZOS).save(os.path.join(WORKSPACE, "web", "icons", "Icon-192.png"))
    base_im.resize((512, 512), Image.Resampling.LANCZOS).save(os.path.join(WORKSPACE, "web", "icons", "Icon-512.png"))

    # Web Maskable Icons
    mask_im.resize((192, 192), Image.Resampling.LANCZOS).save(os.path.join(WORKSPACE, "web", "icons", "Icon-maskable-192.png"))
    mask_im.resize((512, 512), Image.Resampling.LANCZOS).save(os.path.join(WORKSPACE, "web", "icons", "Icon-maskable-512.png"))
    print("Saved Web icons and favicons")

    # 5. Android Mipmap Icons
    android_res = os.path.join(WORKSPACE, "android", "app", "src", "main", "res")
    android_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, size in android_sizes.items():
        out_dir = os.path.join(android_res, folder)
        if os.path.exists(out_dir):
            out_file = os.path.join(out_dir, "ic_launcher.png")
            base_im.resize((size, size), Image.Resampling.LANCZOS).save(out_file)
            print(f"Saved Android {folder} ({size}x{size})")

    # 6. Windows .ico icon (Multi-size ICO)
    win_ico = os.path.join(WORKSPACE, "windows", "runner", "resources", "app_icon.ico")
    ico_sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    base_im.save(win_ico, format="ICO", sizes=ico_sizes)
    print(f"Saved Windows ICO: {win_ico}")

    # 7. macOS Icons
    mac_appicon = os.path.join(WORKSPACE, "macos", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    if os.path.exists(mac_appicon):
        mac_sizes = [16, 32, 64, 128, 256, 512, 1024]
        for sz in mac_sizes:
            fname = f"app_icon_{sz}.png"
            base_im.resize((sz, sz), Image.Resampling.LANCZOS).save(os.path.join(mac_appicon, fname))
        print("Saved macOS app icons")

    # 8. iOS Icons
    ios_appicon = os.path.join(WORKSPACE, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    if os.path.exists(ios_appicon):
        ios_targets = {
            "Icon-App-20x20@1x.png": 20,
            "Icon-App-20x20@2x.png": 40,
            "Icon-App-20x20@3x.png": 60,
            "Icon-App-29x29@1x.png": 29,
            "Icon-App-29x29@2x.png": 58,
            "Icon-App-29x29@3x.png": 87,
            "Icon-App-40x40@1x.png": 40,
            "Icon-App-40x40@2x.png": 80,
            "Icon-App-40x40@3x.png": 120,
            "Icon-App-60x60@2x.png": 120,
            "Icon-App-60x60@3x.png": 180,
            "Icon-App-76x76@1x.png": 76,
            "Icon-App-76x76@2x.png": 152,
            "Icon-App-83.5x83.5@2x.png": 167,
            "Icon-App-1024x1024@1x.png": 1024,
        }
        for fname, sz in ios_targets.items():
            base_im.resize((sz, sz), Image.Resampling.LANCZOS).save(os.path.join(ios_appicon, fname))
        print("Saved iOS app icons")

    print("\nALL PLATFORM ICONS GENERATED SUCCESSFULLY!")

if __name__ == "__main__":
    main()
