import glob
for filepath in glob.glob('.github/workflows/*.yml'):
    with open(filepath, 'r') as f:
        content = f.read()
    
    # Safely inject the new branch into the trigger list
    if "media-kit-engine" not in content:
        content = content.replace('- main', '- main\n      - media-kit-engine')
        content = content.replace('[ "main" ]', '[ "main", "media-kit-engine" ]')
        
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"✅ Successfully updated {filepath}")
    else:
        print(f"⚠️ {filepath} already has the trigger.")
