#!/usr/bin/env python3
from PIL import Image
import os

source_icon = '/Users/bytedance/Downloads/extension_icon.png'
watch_dir = 'scroll-watch Watch App/Assets.xcassets/AppIcon.appiconset'

# Create missing Watch icon sizes based on Contents.json
missing_sizes = [48, 55, 88, 100, 172, 196, 216]

print("🔧 Creating missing Watch app icon sizes...")

try:
    with Image.open(source_icon) as img:
        if img.mode != 'RGBA':
            img = img.convert('RGBA')
        
        for size in missing_sizes:
            resized = img.resize((size, size), Image.Resampling.LANCZOS)
            filename = f'icon_{size}x{size}.png'
            filepath = os.path.join(watch_dir, filename)
            resized.save(filepath, 'PNG')
            print(f'  ✓ Created {filename}')

    print('✅ Missing Watch icons created!')
except Exception as e:
    print(f'❌ Error: {e}')