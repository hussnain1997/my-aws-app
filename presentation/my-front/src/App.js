import React, { useState } from 'react';

function App() {
  const [apiLink, setApiLink] = useState('https://api.chucknorris.io/jokes/random');
  const [callsPerHour, setCallsPerHour] = useState(1);
  const [hoursToRun, setHoursToRun] = useState(24);

  const sendToBack = async (e) => {
    e.preventDefault();
    fetch('http://BACKEND-IP:5000/start', {  // Change BACKEND-IP later
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ endpoint: apiLink, frequency: callsPerHour, duration: hoursToRun })
    }).then(res => res.json()).then(data => alert('Started!')).catch(() => alert('Error'));
  };

  return (
    <form onSubmit={sendToBack}>
      <input value={apiLink} onChange={e => setApiLink(e.target.value)} placeholder="API Link" />
      <input type="number" value={callsPerHour} onChange={e => setCallsPerHour(e.target.value)} placeholder="Calls per Hour" />
      <input type="number" value={hoursToRun} onChange={e => setHoursToRun(e.target.value)} placeholder="Hours to Run" />
      <button>Go!</button>
    </form>
  );
}

export default App;
