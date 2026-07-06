// Patient management microservice.
// Handles create, read, list of patient records in DynamoDB.
const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const {
  DynamoDBDocumentClient,
  PutCommand,
  GetCommand,
  ScanCommand,
} = require("@aws-sdk/lib-dynamodb");
const { randomUUID } = require("crypto");

const client = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const TABLE = process.env.PATIENTS_TABLE;

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
      if (!data.name) return respond(400, { error: "name is required" });

      const patient = {
        patientId: randomUUID(),
        name: data.name,
        dateOfBirth: data.dateOfBirth || null,
        bloodType: data.bloodType || null,
        createdAt: new Date().toISOString(),
      };

      await client.send(new PutCommand({ TableName: TABLE, Item: patient }));
      return respond(201, patient);
    }

    if (method === "GET") {
      const id = event.pathParameters?.id || event.queryStringParameters?.id;

      if (id) {
        const result = await client.send(
          new GetCommand({ TableName: TABLE, Key: { patientId: id } })
        );
        if (!result.Item) return respond(404, { error: "patient not found" });
        return respond(200, result.Item);
      }

      const all = await client.send(new ScanCommand({ TableName: TABLE }));
      return respond(200, all.Items || []);
    }

    return respond(405, { error: "method not allowed" });
  } catch (err) {
    console.error("patient service error", err);
    return respond(500, { error: "internal error" });
  }
};
