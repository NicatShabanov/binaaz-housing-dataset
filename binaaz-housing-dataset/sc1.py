import requests
from bs4 import BeautifulSoup

url = "https://example.com"
response = requests.get(url)

if response.status_code == 200:
    soup = BeautifulSoup(response.text, "html.parser")
    
    for img in soup.find_all("img"):
        img.decompose()
        
    with open("temizlenmis_sayfa.html", "w", encoding="utf-8") as file:
        file.write(str(soup))
        
    print("Sayfa başarıyla indirildi, tüm resimler (img) silindi ve kaydedildi.")
else:
    print(f"Sayfaya erişilemedi. Hata kodu: {response.status_code}")