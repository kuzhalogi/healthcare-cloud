import { useState } from "react";
import {
  CognitoUserPool,
  CognitoUser,
  AuthenticationDetails,
} from "amazon-cognito-identity-js";
import config from "./config";

const pool = new CognitoUserPool({
  UserPoolId: config.userPoolId,
  ClientId: config.clientId,
});

export default function App() {
  const [token, setToken] = useState(null);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [view, setView] = useState("patients");
  const [error, setError] = useState("");

  const signIn = () => {
    setError("");
    const user = new CognitoUser({ Username: email, Pool: pool });
    const details = new AuthenticationDetails({
      Username: email,
      Password: password,
    });
    user.authenticateUser(details, {
      onSuccess: (result) => setToken(result.getIdToken().getJwtToken()),
      onFailure: (err) => setError(err.message || "sign in failed"),
    });
  };

  if (!token) {
    return (
      <div className="auth">
        <h1>MedShare</h1>
        <p className="sub">Hospital data sharing platform</p>
        <input
          placeholder="Email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
        />
        <input
          type="password"
          placeholder="Password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
        />
        <button onClick={signIn}>Sign in</button>
        {error && <p className="error">{error}</p>}
      </div>
    );
  }

  return (
    <div className="app">
      <header>
        <h1>MedShare</h1>
        <nav>
          <button onClick={() => setView("patients")}>Patients</button>
          <button onClick={() => setView("appointments")}>Appointments</button>
          <button onClick={() => setView("records")}>Records</button>
          <button onClick={() => setToken(null)}>Sign out</button>
        </nav>
      </header>
      <main>
        {view === "patients" && <Patients token={token} />}
        {view === "appointments" && <Appointments token={token} />}
        {view === "records" && <Records token={token} />}
      </main>
    </div>
  );
}

function useApi(token) {
  return async (path, method = "GET", body) => {
    const res = await fetch(`${config.apiUrl}/${path}`, {
      method,
      headers: {
        "Content-Type": "application/json",
        Authorization: token,
      },
      body: body ? JSON.stringify(body) : undefined,
    });
    return res.json();
  };
}

function Patients({ token }) {
  const api = useApi(token);
  const [list, setList] = useState([]);
  const [name, setName] = useState("");
  const [bloodType, setBloodType] = useState("");

  const load = async () => setList(await api("patients"));
  const add = async () => {
    await api("patients", "POST", { name, bloodType });
    setName("");
    setBloodType("");
    load();
  };

  return (
    <section>
      <h2>Patients</h2>
      <div className="row">
        <input placeholder="Full name" value={name} onChange={(e) => setName(e.target.value)} />
        <input placeholder="Blood type" value={bloodType} onChange={(e) => setBloodType(e.target.value)} />
        <button onClick={add}>Add patient</button>
        <button onClick={load}>Refresh</button>
      </div>
      <ul>
        {list.map((p) => (
          <li key={p.patientId}>
            <strong>{p.name}</strong> {p.bloodType && `· ${p.bloodType}`}
          </li>
        ))}
      </ul>
    </section>
  );
}

function Appointments({ token }) {
  const api = useApi(token);
  const [list, setList] = useState([]);
  const [patientId, setPatientId] = useState("");
  const [date, setDate] = useState("");
  const [reason, setReason] = useState("");

  const load = async () => setList(await api("appointments"));
  const add = async () => {
    await api("appointments", "POST", { patientId, date, reason });
    setPatientId("");
    setDate("");
    setReason("");
    load();
  };

  return (
    <section>
      <h2>Appointments</h2>
      <div className="row">
        <input placeholder="Patient ID" value={patientId} onChange={(e) => setPatientId(e.target.value)} />
        <input type="date" value={date} onChange={(e) => setDate(e.target.value)} />
        <input placeholder="Reason" value={reason} onChange={(e) => setReason(e.target.value)} />
        <button onClick={add}>Book</button>
        <button onClick={load}>Refresh</button>
      </div>
      <ul>
        {list.map((a) => (
          <li key={a.appointmentId}>
            {a.date} · {a.reason} · <span className="tag">{a.status}</span>
          </li>
        ))}
      </ul>
    </section>
  );
}

function Records({ token }) {
  const api = useApi(token);
  const [list, setList] = useState([]);
  const [patientId, setPatientId] = useState("");
  const [title, setTitle] = useState("");

  const load = async () => setList(await api("records"));
  const add = async () => {
    await api("records", "POST", { patientId, title, fileName: "note.txt" });
    setPatientId("");
    setTitle("");
    load();
  };

  return (
    <section>
      <h2>Medical records</h2>
      <div className="row">
        <input placeholder="Patient ID" value={patientId} onChange={(e) => setPatientId(e.target.value)} />
        <input placeholder="Record title" value={title} onChange={(e) => setTitle(e.target.value)} />
        <button onClick={add}>Add record</button>
        <button onClick={load}>Refresh</button>
      </div>
      <ul>
        {list.map((r) => (
          <li key={r.recordId}>
            <strong>{r.title}</strong> · patient {r.patientId}
          </li>
        ))}
      </ul>
    </section>
  );
}
