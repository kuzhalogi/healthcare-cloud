// Appointment scheduling microservice.
// Handles booking and listing appointments in DynamoDB.
const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const {
  DynamoDBDocumentClient,
  PutCommand,
  ScanCommand,
} = require("@aws-sdk/lib-dynamodb");
const { randomUUID } = require("crypto");

const client = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const TABLE = process.env.APPOINTMENTS_TABLE;

const respond = (status, body) => ({
  statusCode: status,
  headers: {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type,Authorization",
    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
  },
  body: JSON.stringify(body),
});

exports.handler = async (event) => {
  const method = event.requestContext?.http?.method || event.httpMethod;

  if (method === "OPTIONS") return respond(200, {});

  try {
    if (method === "POST") {
      const data = JSON.parse(event.body || "{}");
      if (!data.patientId || !data.date) {
        return respond(400, { error: "patientId and date are required" });
      }

      const appointment = {
        appointmentId: randomUUID(),
        patientId: data.patientId,
        doctorName: data.doctorName || "Unassigned",
        date: data.date,
        reason: data.reason || "General consultation",
        status: "scheduled",
        createdAt: new Date().toISOString(),
      };

      await client.send(new PutCommand({ TableName: TABLE, Item: appointment }));
      return respond(201, appointment);
    }

    if (method === "GET") {
      const all = await client.send(new ScanCommand({ TableName: TABLE }));
      return respond(200, all.Items || []);
    }

    return respond(405, { error: "method not allowed" });
  } catch (err) {
    console.error("appointment service error", err);
    return respond(500, { error: "internal error" });
  }
};
