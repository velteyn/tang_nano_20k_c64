import sys

def scan_file(filepath):
    print(f"Scanning {filepath}...")
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
            
        # Search for pcbdata
        idx = content.find('pcbdata')
        if idx != -1:
            print(f"Found 'pcbdata' at index {idx}")
            snippet = content[idx:idx+200]
            print(f"Snippet: {snippet}...")
        else:
            print("'pcbdata' not found")
            
        # Search for HDMI
        idx_hdmi = content.find('HDMI')
        if idx_hdmi != -1:
            print(f"Found 'HDMI' at index {idx_hdmi}")
            snippet = content[idx_hdmi-50:idx_hdmi+100]
            print(f"Snippet: {snippet}...")
        else:
            print("'HDMI' not found")

        # Search for TMDS
        idx_tmds = content.find('TMDS')
        if idx_tmds != -1:
            print(f"Found 'TMDS' at index {idx_tmds}")
            snippet = content[idx_tmds-50:idx_tmds+100]
            print(f"Snippet: {snippet}...")
        else:
            print("'TMDS' not found")
            
    except Exception as e:
        print(f"Error reading file: {e}")

if __name__ == "__main__":
    for arg in sys.argv[1:]:
        scan_file(arg)
