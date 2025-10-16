import React, { useState } from 'react';

function App() {
  const [endpoint, setEndpoint] = useState('https://api.chucknorris.io/jokes/random');
  const [frequency, setFrequency] = useState(1);
  const [duration, setDuration] = useState(24);

const handleSubmit = async (e) => {
  e.preventDefault();
  try {
    const loginRes = await fetch('http://192.168.100.160:5002/login', {  // Change to localhost for local test
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'admin', password: '123' }),
    });
    const loginData = await loginRes.json();
    const token = loginData.token;

    const startRes = await fetch('http://192.168.100.160:5002/start', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
      body: JSON.stringify({ endpoint, frequency, duration }),
    });
    const startData = await startRes.json();
    alert(startData.message);
  } catch (err) {
    alert('Error: ' + err.message);
  }
};

  return (
    <div style={{ padding: '20px' }}>
      <h2>API Polling Form</h2>
      <form onSubmit={handleSubmit}>
        <label>API Endpoint:</label><br />
        <input
          type="text"
          value={endpoint}
          onChange={(e) => setEndpoint(e.target.value)}
          placeholder="Enter API URL"
          style={{ width: '300px', marginBottom: '10px' }}
        /><br />
        <label>Frequency (calls/hour):</label><br />
        <input
          type="number"
          value={frequency}
          onChange={(e) => setFrequency(Number(e.target.value))}
          placeholder="Calls per Hour"
          min="1"
          style={{ width: '300px', marginBottom: '10px' }}
        /><br />
        <label>Duration (hours):</label><br />
        <input
          type="number"
          value={duration}
          onChange={(e) => setDuration(Number(e.target.value))}
          placeholder="Hours to Run"
          min="1"
          style={{ width: '300px', marginBottom: '10px' }}
        /><br />
        <button type="submit">Start Polling</button>
      </form>
    </div>
  );
}

export default App;
