/**
 * MongoDB Atlas — policy_chunks collection schema
 *
 * Run with mongosh:
 *   mongosh "<connection-string>" --file policy_chunks_schema.js
 *
 * Feature: continuum-ml-pipelines
 * Requirements: 10.2
 */

// Create the collection with a JSON Schema validator
db.createCollection("policy_chunks", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["chunk_id", "source_type", "content", "embedding", "created_at", "updated_at"],
      properties: {
        _id: {
          bsonType: "objectId"
        },
        chunk_id: {
          bsonType: "string",
          description: "Unique chunk identifier, e.g. 'policy_doc_v2_chunk_042'"
        },
        source_type: {
          bsonType: "string",
          enum: ["policy_document", "disruption_event", "advisory"],
          description: "Origin of the chunk content"
        },
        content: {
          bsonType: "string",
          description: "Raw text content of the chunk"
        },
        embedding: {
          bsonType: "array",
          minItems: 768,
          maxItems: 768,
          items: {
            bsonType: "double"
          },
          description: "768-dimensional BGE-Large embedding vector"
        },
        metadata: {
          bsonType: "object",
          properties: {
            zone_id: {
              bsonType: "string"
            },
            event_type: {
              bsonType: "string"
            },
            effective_date: {
              bsonType: "date"
            },
            source_url: {
              bsonType: "string"
            }
          }
        },
        created_at: {
          bsonType: "date",
          description: "Timestamp when the chunk was first inserted"
        },
        updated_at: {
          bsonType: "date",
          description: "Timestamp of the most recent update"
        }
      }
    }
  },
  validationLevel: "strict",
  validationAction: "error"
});

print("Created collection: policy_chunks");

// Index on source_type for filtered queries (e.g. fetch only policy_document chunks)
db.policy_chunks.createIndex(
  { source_type: 1 },
  { name: "idx_source_type" }
);

print("Created index: idx_source_type");

// Compound index on (metadata.zone_id, metadata.event_type) for zone-scoped RAG retrieval
db.policy_chunks.createIndex(
  { "metadata.zone_id": 1, "metadata.event_type": 1 },
  { name: "idx_zone_event_type" }
);

print("Created index: idx_zone_event_type");
print("policy_chunks schema setup complete.");
