// Every datatype defined in the spec is sent, received, either, or it is orphaned (and should be omitted from the client.

// This file just contains the logic to walk the OpenAPI and AsyncAPI specs to determine this direction of each schema.

import * as OA from "./parse_openapi";
import type { JsonSchema } from "./parse_openapi";
import type { Endpoint } from "./generator";

export type Direction = "sent" | "received" | "both" | "orphaned";

const exhaustive = (x: never): any => x;

const walkAsyncAPIMessage = (
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

const walkSchema = (
  root: unknown,
  f: (schema: OA.JsonSchema, path: Array<string | number>) => void,
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
 */
const buildReferenceGraph = (
  allSchemas: Record<string, JsonSchema>,
): Map<string, Set<string>> => {
  const graph = new Map<string, Set<string>>();

  for (const [key, schema] of Object.entries(allSchemas).sort(([a], [b]) => a.localeCompare(b))) {
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
 * Propagates direction through the reference graph.
 * Given initial directions for root schemas, propagates to all referenced schemas.
 * If a schema is referenced with different directions, it becomes "both".
 */
const propagateDirection = (
  graph: Map<string, Set<string>>,
  initialDirections: Map<string, Direction>,
  allSchemas: Record<string, JsonSchema>,
): Map<string, Direction> => {
  const directions = new Map(initialDirections);
  let changed = true;

  while (changed) {
    changed = false;

    for (const [key, refs] of graph.entries()) {
      const dir = directions.get(key);
      if (!dir || dir === "orphaned") continue;

      for (const ref of refs) {
        const prev = directions.get(ref);
        if (!prev) {
          directions.set(ref, dir);
          changed = true;
        } else if (prev !== dir && prev !== "both") {
          directions.set(ref, "both");
          changed = true;
        }
      }
    }
  }

  return directions;
};

export const calculateSchemaDirections = (
  allEndpoints: Array<Endpoint>,
  allChannels: OA.AsyncAPISpec["channels"],
  allMessages: OA.AsyncAPISpec["components"]["messages"],
  allSchemas: Record<string, JsonSchema>,
): Map<string, Direction> => {
  // Build the reference graph
  const referenceGraph = buildReferenceGraph(allSchemas);

  // Collect initial directions from root schemas
  const initialDirections = new Map<string, Direction>();

  const setInitialDirection = (schema: OA.JsonSchema, direction: Direction) => {
    if ("schemaKey" in schema && typeof schema.schemaKey === "string") {
      const existing = initialDirections.get(schema.schemaKey);
      if (existing && existing !== direction) {
        initialDirections.set(schema.schemaKey, "both");
      } else {
        initialDirections.set(schema.schemaKey, direction);
      }
    } else if (schema.kind === "ref") {
      // For refs, extract the schema name and try to find the prefixed version
      const refName = schema.$ref.replace(/^#\/components\/schemas\//, "");

      // Try both namespace prefixes since all schemas are now prefixed
      const ttsKey = `tts:${refName}`;
      const eviKey = `evi:${refName}`;

      let schemaKey = refName; // fallback to original name
      if (allSchemas[ttsKey]) {
        schemaKey = ttsKey;
      } else if (allSchemas[eviKey]) {
        schemaKey = eviKey;
      }

      const existing = initialDirections.get(schemaKey);
      if (existing && existing !== direction) {
        initialDirections.set(schemaKey, "both");
      } else {
        initialDirections.set(schemaKey, direction);
      }
    }
  };

  // Process AsyncAPI channels - these are the roots for websocket communication
  for (const channelPath in allChannels) {
    const channel = allChannels[channelPath];

    // Publish messages are sent by client to server
    walkAsyncAPIMessage(
      channel.publish.message,
      (m) => {
        if (m.kind === "message") {
          walkSchema(m.payload, (s) => {
            setInitialDirection(s, "sent");
          });
        }
      },
      allMessages,
    );

    // Subscribe messages are received by client from server
    walkAsyncAPIMessage(
      channel.subscribe.message,
      (m) => {
        if (m.kind === "message") {
          walkSchema(m.payload, (s) => {
            setInitialDirection(s, "received");
          });
        }
      },
      allMessages,
    );
  }

  // Process OpenAPI endpoints - these are the roots for HTTP communication
  for (const endpoint of allEndpoints) {
    if (endpoint.operation.kind === "ignored") {
      continue;
    }

    // Request body schemas are sent by client
    if (endpoint.operation.kind === "jsonBody") {
      walkSchema(
        endpoint.operation.requestBody.content["application/json"].schema,
        (s) => setInitialDirection(s, "sent"),
      );
    }

    // Parameter schemas are sent by client
    endpoint.operation.parameters.forEach(({ schema }) => {
      walkSchema(schema, (s) => setInitialDirection(s, "sent"));
    });

    // Response schemas are received by client
    Object.values(endpoint.operation.responses ?? []).forEach((response) => {
      switch (response.kind) {
        case "jsonResponse":
          walkSchema(response.content["application/json"].schema, (s) =>
            setInitialDirection(s, "received"),
          );
          return;
        case "binaryResponse":
          walkSchema(response.content["audio/*"].schema, (s) =>
            setInitialDirection(s, "received"),
          );
          return;
        case "noContent":
          return;
        default:
          return exhaustive(response);
      }
    });
  }

  // Propagate directions through the reference graph
  const propagatedDirections = propagateDirection(
    referenceGraph,
    initialDirections,
    allSchemas,
  );

  // Set "orphaned" for any schemas that weren't reached
  for (const schemaKey of Object.keys(allSchemas).sort((a, b) => a.localeCompare(b))) {
    if (!propagatedDirections.has(schemaKey)) {
      propagatedDirections.set(schemaKey, "orphaned");
    }
  }

  return propagatedDirections;
};
