import requests
from bs4 import BeautifulSoup

url = "https://example.com"
response = requests.get(url)

if response.status_code == 200:
    soup = BeautifulSoup(response.text, "html.parser")
    
    page_title = soup.find("title").text
    print(f"Sayfa Başlığı: {page_title}")

    print("\n--- H1 Başlıkları ---")
    h1_tags = soup.find_all("h1")
    
    if h1_tags:
        for tag in h1_tags:
            print(tag.text.strip())
    else:
        print("Bu sayfada hiç <h1> etiketi bulunamadı.")
else:
    print(f"Sayfaya erişilemedi. Hata kodu: {response.status_code}")