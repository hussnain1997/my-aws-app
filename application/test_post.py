import requests

url = 'http://192.168.100.160:5002/start'
payload = {
    'endpoint': 'https://api.chucknorris.io/jokes/random',
    'frequency': 1,
    'duration': 1
}
headers = {'Content-Type': 'application/json'}
response = requests.post(url, json=payload, headers=headers)
print(response.json())
