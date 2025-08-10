#!/usr/bin/env python3
import subprocess
import os
import shutil
from PIL import Image

def create_app_icons():
    """Create all required app icon sizes from the source image"""
    source_icon = "/Users/bytedance/Downloads/extension_icon.png"
    
    if not os.path.exists(source_icon):
        print(f"❌ Source icon not found: {source_icon}")
        return
    
    # iOS App Icon sizes (for iPhone)
    ios_sizes = [
        (20, "20pt"),
        (29, "29pt"),  
        (40, "40pt"),
        (58, "58pt"),
        (60, "60pt"),
        (80, "80pt"),
        (87, "87pt"),
        (120, "120pt"),
        (180, "180pt"),
        (1024, "1024pt")
    ]
    
    # watchOS App Icon sizes
    watch_sizes = [
        (24, "24mm"),
        (27.5, "27.5mm"),
        (29, "29mm"),
        (40, "40mm"),
        (44, "44mm"),
        (50, "50mm"),
        (86, "86mm"),
        (98, "98mm"),
        (108, "108mm"),
        (117, "117mm"),
        (129, "129mm"),
        (1024, "1024pt")
    ]
    
    # iOS App Icons directory
    ios_dir = "scroll/Assets.xcassets/AppIcon.appiconset"
    if not os.path.exists(ios_dir):
        os.makedirs(ios_dir, exist_ok=True)
    
    # Watch App Icons directory  
    watch_dir = "scroll-watch Watch App/Assets.xcassets/AppIcon.appiconset"
    if not os.path.exists(watch_dir):
        os.makedirs(watch_dir, exist_ok=True)
    
    print("📱 Creating iOS app icons...")
    create_icons_for_platform(source_icon, ios_dir, ios_sizes, "ios")
    
    print("⌚ Creating Watch app icons...")
    create_icons_for_platform(source_icon, watch_dir, watch_sizes, "watchos")
    
    print("✅ All app icons created successfully!")

def create_icons_for_platform(source_icon, output_dir, sizes, platform):
    """Create icons for a specific platform"""
    try:
        with Image.open(source_icon) as img:
            # Ensure image is in RGBA mode
            if img.mode != 'RGBA':
                img = img.convert('RGBA')
            
            for size_px, size_name in sizes:
                # Handle fractional sizes
                if isinstance(size_px, float):
                    size_px = int(size_px)
                
                # Resize image
                resized = img.resize((size_px, size_px), Image.Resampling.LANCZOS)
                
                # Save icon
                filename = f"icon_{size_px}x{size_px}.png"
                filepath = os.path.join(output_dir, filename)
                resized.save(filepath, "PNG")
                print(f"  ✓ Created {filename} ({size_name})")
                
    except Exception as e:
        print(f"❌ Error creating icons for {platform}: {e}")

def create_contents_json(directory, platform):
    """Create Contents.json file for the icon set"""
    if platform == "ios":
        contents = {
            "images": [
                {"idiom": "iphone", "scale": "2x", "size": "20x20", "filename": "icon_40x40.png"},
                {"idiom": "iphone", "scale": "3x", "size": "20x20", "filename": "icon_60x60.png"},
                {"idiom": "iphone", "scale": "1x", "size": "29x29", "filename": "icon_29x29.png"},
                {"idiom": "iphone", "scale": "2x", "size": "29x29", "filename": "icon_58x58.png"},
                {"idiom": "iphone", "scale": "3x", "size": "29x29", "filename": "icon_87x87.png"},
                {"idiom": "iphone", "scale": "2x", "size": "40x40", "filename": "icon_80x80.png"},
                {"idiom": "iphone", "scale": "3x", "size": "40x40", "filename": "icon_120x120.png"},
                {"idiom": "iphone", "scale": "2x", "size": "60x60", "filename": "icon_120x120.png"},
                {"idiom": "iphone", "scale": "3x", "size": "60x60", "filename": "icon_180x180.png"},
                {"idiom": "ios-marketing", "scale": "1x", "size": "1024x1024", "filename": "icon_1024x1024.png"}
            ],
            "info": {"author": "xcode", "version": 1}
        }
    else:  # watchos
        contents = {
            "images": [
                {"idiom": "watch", "role": "notificationCenter", "scale": "2x", "size": "24x24", "subtype": "38mm", "filename": "icon_48x48.png"},
                {"idiom": "watch", "role": "notificationCenter", "scale": "2x", "size": "27.5x27.5", "subtype": "42mm", "filename": "icon_55x55.png"},
                {"idiom": "watch", "role": "companionSettings", "scale": "2x", "size": "29x29", "filename": "icon_58x58.png"},
                {"idiom": "watch", "role": "appLauncher", "scale": "2x", "size": "40x40", "subtype": "38mm", "filename": "icon_80x80.png"},
                {"idiom": "watch", "role": "appLauncher", "scale": "2x", "size": "44x44", "subtype": "40mm", "filename": "icon_88x88.png"},
                {"idiom": "watch", "role": "appLauncher", "scale": "2x", "size": "50x50", "subtype": "44mm", "filename": "icon_100x100.png"},
                {"idiom": "watch", "role": "quickLook", "scale": "2x", "size": "86x86", "subtype": "38mm", "filename": "icon_172x172.png"},
                {"idiom": "watch", "role": "quickLook", "scale": "2x", "size": "98x98", "subtype": "42mm", "filename": "icon_196x196.png"},
                {"idiom": "watch", "role": "quickLook", "scale": "2x", "size": "108x108", "subtype": "44mm", "filename": "icon_216x216.png"},
                {"idiom": "watch-marketing", "scale": "1x", "size": "1024x1024", "filename": "icon_1024x1024.png"}
            ],
            "info": {"author": "xcode", "version": 1}
        }
    
    import json
    contents_path = os.path.join(directory, "Contents.json")
    with open(contents_path, 'w') as f:
        json.dump(contents, f, indent=2)
    print(f"  ✓ Created Contents.json for {platform}")

if __name__ == "__main__":
    print("🎨 Creating App Icons for WatchScroller")
    print("=====================================")
    
    # Change to project directory
    os.chdir("/Users/bytedance/code/void/WatchScroller/scroll")
    
    try:
        create_app_icons()
        create_contents_json("scroll/Assets.xcassets/AppIcon.appiconset", "ios")
        create_contents_json("scroll-watch Watch App/Assets.xcassets/AppIcon.appiconset", "watchos")
        print("🎉 App icon setup complete!")
    except Exception as e:
        print(f"❌ Error: {e}")
        print("Make sure PIL (Pillow) is installed: pip install pillow")