from flask import Flask, request, jsonify
from flask_cors import CORS  # Add this for React access
import requests
import time
import mysql.connector
import boto3
from apscheduler.schedulers.background import BackgroundScheduler
import getpass  # For hidden password input
from termcolor import colored  # For colors

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes (allows React to connect)

scheduler = BackgroundScheduler()
scheduler.start()

# DB placeholder - update with real Aurora details later
DB = {
    'host': 'myaurora.cluster-xxx.us-east-1.rds.amazonaws.com',  # Replace with your endpoint
    'user': 'admin',
    'password': 'AuroraPass123',  # Replace with your password
    'database': 'mydata'
}

cloudwatch = boto3.client('cloudwatch')
calls = 0
errors = 0

def call_api(link):
    global calls, errors
    try:
        res = requests.get(link)
        conn = mysql.connector.connect(**DB)
        cur = conn.cursor()
        cur.execute("INSERT INTO stuff (data) VALUES (%s)", (res.text,))
        conn.commit()
        conn.close()
        calls += 1
        cloudwatch.put_metric_data(Namespace='MyApp', MetricData=[{'MetricName': 'Calls', 'Value': 1}])
        if res.status_code != 200:
            errors += 1
            cloudwatch.put_metric_data(Namespace='MyApp', MetricData=[{'MetricName': 'Errors', 'Value': 1}])
    except Exception as e:
        print(f"Error in call_api: {e}")  # Log errors for debugging
        errors += 1
        cloudwatch.put_metric_data(Namespace='MyApp', MetricData=[{'MetricName': 'Errors', 'Value': 1}])

@app.route('/start', methods=['GET', 'POST'])
def start():
    if request.method == 'POST':
        data = request.json
        link = data['endpoint']
        mins_between = 60 / data['frequency']
        end = time.time() + (data['duration'] * 3600)
        def job():
            if time.time() > end:
                scheduler.remove_job('job')
                return
            call_api(link)
        scheduler.add_job(job, 'interval', minutes=mins_between, id='job')
        return jsonify({'message': 'Running!'})
    else:  # GET method for testing
        return jsonify({'message': 'This endpoint accepts POST requests with JSON data. Use a form or tool like Postman.'})

@app.route('/', methods=['GET'])
def home():
    return "Welcome to the API Polling Backend! Use /start with a POST request or the React form."

if __name__ == '__main__':
    # Attractive Console Login
    print(colored("🌟 Welcome to the Backend Server! 🌟", 'yellow'))
    print(colored("Please login to start the server:", 'cyan'))
    print("""
    ╔════════════════════════════╗
    ║        LOGIN PORTAL        ║
    ╚════════════════════════════╝
    """)

    username = input(colored("Username: ", 'green'))
    password = getpass.getpass(colored("Password (hidden): ", 'green'))

    # Simple check (change to your real username/password)
    if username == "admin" and password == "123":
        print(colored("✅ Login successful! Starting server...", 'green'))
        app.run(host='0.0.0.0', port=5002)
    else:
        print(colored("❌ Wrong username or password. Server not starting.", 'red'))
