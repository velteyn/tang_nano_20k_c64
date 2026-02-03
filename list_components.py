import json
import re
import sys

def extract_pcbdata(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Look for var pcbdata = {...}
    match = re.search(r'var pcbdata = ({.*});', content)
    if not match:
        print(f"Error: Could not find pcbdata in {filepath}")
        return None
    
    try:
        data = json.loads(match.group(1))
        return data
    except json.JSONDecodeError as e:
        print(f"Error decoding JSON: {e}")
        return None

def list_components(data):
    if not data:
        return
    
    print("Components:")
    for footprint in data['footprints']:
        ref = footprint['ref']
        val = footprint['val']
        print(f"{ref}: {val}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python list_components.py <ibom_file>")
        sys.exit(1)
        
    filepath = sys.argv[1]
    data = extract_pcbdata(filepath)
    list_components(data)
