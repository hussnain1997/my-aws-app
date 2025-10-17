from flask import Flask, request, jsonify
from flask_cors import CORS  # Add this for React access
import requests
import time
import mysql.connector
import boto3
from apscheduler.schedulers.background import BackgroundScheduler
import os  # Added for environment variables
from dotenv import load_dotenv  # Added for loading .env file
from termcolor import colored  # For colors

# Load environment variables from .env file (for local development)
load_dotenv()

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes (allows React to connect)

scheduler = BackgroundScheduler()
scheduler.start()

# DB configuration using environment variables
DB = {
    'host': os.getenv('DB_HOST'),
    'user': os.getenv('DB_USER'),
    'password': os.getenv('DB_PASSWORD'),
    'database': os.getenv('DB_DATABASE')
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
    print(colored("🌟 Starting Backend Server... 🌟", 'yellow'))
    app.run(host='0.0.0.0', port=5002)
