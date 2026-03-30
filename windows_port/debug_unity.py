import requests
import json
import urllib.parse

API_KEY = "EA486DB0B43192E8846A7EB374AD7BED"
PHP_BASE = "http://xboxunity.net/Resources/Lib"

def test_php(filename, params):
    url = f"{PHP_BASE}/{filename}"
    print(f"\n--- Testing PHP Endpoint: {url} with {params} ---")
    try:
        # Some endpoints use the key as a parameter 'api'
        params['apiKey'] = API_KEY
        resp = requests.get(url, params=params, timeout=10)
        print(f"Status Code: {resp.status_code}")
        print(f"Response: {resp.text[:500]}...")
    except Exception as e:
        print(f"Exception: {e}")

if __name__ == "__main__":
    # Test Title Search
    test_php("TitleSearch.php", {"search": "FIFA 19"})
    test_php("TitleSearch.php", {"name": "FIFA 19"})
    
    # Test Title Updates
    test_php("TitleUpdate.php", {"titleid": "454109E6"})
    test_php("TitleUpdate.php", {"tid": "454109E6"})
    
    # Test GetCover
    test_php("GetCover.php", {"titleid": "454109E6"})
