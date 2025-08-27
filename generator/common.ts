import * as OA from "./parse_openapi";
import type { JsonSchema } from "./parse_openapi";

/**
 * Walks through a schema and applies a function to each JsonSchema found.
 * This is a common utility used by both availability and directions calculations.
 */
export const walkSchema = (
  root: unknown,
  f: (schema: OA.JsonSchema, path?: Array<string | number>) => void,
) => {
  OA.walkObject(root, (obj, path) => {
    if (!obj || typeof obj !== "object" || !("kind" in obj)) {
      return;
    }
    const { data, success } = OA.JsonSchema_.safeParse(obj);
    if (success) {
      f(data, path);
    }
  });
};

/**
 * Builds a reference graph from all schemas.
 * Returns a Map where key is schemaKey and value is a Set of referenced schemaKeys.
 * This is a common utility used by both availability and directions calculations.
 */
export const buildReferenceGraph = (
  allSchemas: Record<string, JsonSchema>,
): Map<string, Set<string>> => {
  const graph = new Map<string, Set<string>>();

  for (const [key, schema] of Object.entries(allSchemas)) {
    const refs = new Set<string>();

    // Determine the namespace from the key
    const namespace = key.startsWith("tts:")
      ? "tts"
      : key.startsWith("evi:")
        ? "evi"
        : null;

    walkSchema(schema, (s) => {
      if (s.kind === "ref") {
        const refKey = s.$ref.replace(/^#\/components\/schemas\//, "");
        
        // Only resolve refs within the same namespace
        if (namespace) {
          const namespacedKey = `${namespace}:${refKey}`;
          if (allSchemas[namespacedKey]) {
            refs.add(namespacedKey);
          } else {
            // Fallback to original key if namespaced version doesn't exist
            refs.add(refKey);
          }
        } else {
          // For schemas without namespace prefix, try both (backward compatibility)
          const ttsKey = `tts:${refKey}`;
          const eviKey = `evi:${refKey}`;

          if (allSchemas[ttsKey]) {
            refs.add(ttsKey);
          } else if (allSchemas[eviKey]) {
            refs.add(eviKey);
          } else {
            refs.add(refKey);
          }
        }
      }
    });

    graph.set(key, refs);
  }

  return graph;
};

/**
 * Walks through AsyncAPI messages recursively, handling oneOf and ref cases.
 * This is a common utility used by both availability and directions calculations.
 */
export const walkAsyncAPIMessage = (
  message: OA.AsyncAPIMessage,
  f: (message: OA.AsyncAPIMessage) => void,
  allMessages: OA.AsyncAPISpec["components"]["messages"],
  visited: Set<OA.AsyncAPIMessage> = new Set(),
) => {
  f(message);
  if (message.kind === "oneOf") {
    message.oneOf.forEach((msg) => {
      if (!visited.has(msg)) {
        visited.add(msg);
        walkAsyncAPIMessage(msg, f, allMessages, visited);
      }
    });
  } else if (message.kind === "ref") {
    // Resolve the message reference
    const refName = message.$ref.replace(/^#\/components\/messages\//, "");
    const referencedMessage = allMessages[refName];
    if (referencedMessage && !visited.has(referencedMessage)) {
      visited.add(referencedMessage);
      walkAsyncAPIMessage(referencedMessage, f, allMessages, visited);
    }
  }
};

/**
 * Utility function to handle exhaustive pattern matching.
 */
export const exhaustive = (x: never): any => x;
