// Medical records microservice.
// Stores record metadata in DynamoDB and issues presigned S3 URLs
// so documents upload directly to the encrypted bucket.
const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const {
  DynamoDBDocumentClient,
  PutCommand,
  ScanCommand,
} = require("@aws-sdk/lib-dynamodb");
const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");
const { getSignedUrl } = require("@aws-sdk/s3-request-presigner");
const { randomUUID } = require("crypto");

const db = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const s3 = new S3Client({});
const TABLE = process.env.RECORDS_TABLE;
const BUCKET = process.env.DOCUMENTS_BUCKET;

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
      if (!data.patientId || !data.title) {
        return respond(400, { error: "patientId and title are required" });
      }

      const recordId = randomUUID();
      const key = `records/${data.patientId}/${recordId}-${data.fileName || "document"}`;

      const record = {
        recordId,
        patientId: data.patientId,
        title: data.title,
        s3Key: key,
        createdAt: new Date().toISOString(),
      };

      await db.send(new PutCommand({ TableName: TABLE, Item: record }));

      // Presigned URL lets the browser upload the file straight to S3
      const uploadUrl = await getSignedUrl(
        s3,
        new PutObjectCommand({ Bucket: BUCKET, Key: key }),
        { expiresIn: 300 }
      );

      return respond(201, { record, uploadUrl });
    }

    if (method === "GET") {
      const all = await db.send(new ScanCommand({ TableName: TABLE }));
      return respond(200, all.Items || []);
    }

    return respond(405, { error: "method not allowed" });
  } catch (err) {
    console.error("records service error", err);
    return respond(500, { error: "internal error" });
  }
};
