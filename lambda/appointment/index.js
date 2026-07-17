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

// CORS is enforced at API Gateway, locked to the CloudFront origin, so the
// function does not set Access-Control headers itself. Returning them here
// would both duplicate the gateway's headers and contradict that lock.
const respond = (status, body) => ({
  statusCode: status,
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify(body),
});

// cognito:groups can arrive as an array or a string like "[doctors patients]"
// depending on the token. Normalize to an array either way. The claim is
// trustworthy because API Gateway already verified the JWT signature.
const groupsOf = (event) => {
  let groups =
    event.requestContext?.authorizer?.jwt?.claims?.["cognito:groups"] || [];
  if (typeof groups === "string") {
    groups = groups.replace(/[[\]]/g, "").split(/[\s,]+/).filter(Boolean);
  }
  return groups;
};

exports.handler = async (event) => {
  const method = event.requestContext?.http?.method || event.httpMethod;

  if (method === "OPTIONS") return respond(200, {});

  try {
    if (method === "POST") {
      // Writes are restricted to providers. Any authenticated user may read,
      // but only the doctors group can perform writes.
      if (!groupsOf(event).includes("doctors")) {
        return respond(403, {
          error: "forbidden: writes are restricted to the doctors group",
        });
      }
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
