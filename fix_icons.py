import os

replacements = {
    'SolarIconsOutline.checkRead': 'SolarIconsOutline.checkCircle',
    'SolarIconsBold.checkRead': 'SolarIconsBold.checkCircle',
    
    'SolarIconsOutline.tuner': 'SolarIconsOutline.filter',
    'SolarIconsBold.tuner': 'SolarIconsBold.filter',
    
    'SolarIconsOutline.timer': 'SolarIconsOutline.clockCircle',
    'SolarIconsBold.timer': 'SolarIconsBold.clockCircle',
    
    'SolarIconsOutline.hamburger': 'SolarIconsOutline.hamburgerMenu',
    'SolarIconsBold.hamburger': 'SolarIconsBold.hamburgerMenu',
    
    'SolarIconsOutline.logout3': 'SolarIconsOutline.logout_3',
    'SolarIconsBold.logout3': 'SolarIconsBold.logout_3',
}

def process_file(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    new_content = content
    for old, new in replacements.items():
        new_content = new_content.replace(old, new)

    if new_content != content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Fixed: {file_path}")

for root, _, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            process_file(os.path.join(root, file))
