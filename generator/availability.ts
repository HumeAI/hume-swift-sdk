// Every datatype and endpoint is available either for server-side only or for full (both client-side and server-side) use.
// This file contains the logic to walk the OpenAPI specs to determine the availability of each schema and endpoint.

import * as OA from "./parse_openapi";
import type { JsonSchema } from "./parse_openapi";
import type { Endpoint } from "./generator";

export type Availability = "serverOnly" | "full";

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
 * Propagates availability through the reference graph.
 * Given initial availabilities for root schemas, propagates to all referenced schemas.
 * If a schema is referenced with different availabilities, it becomes "full".
 */
const propagate = <T>(
  graph: Map<string, Set<string>>,
  initialValues: Map<string, T>,
  allSchemas: Record<string, JsonSchema>,
  combineValues: (a: T, b: T) => T,
): Map<string, T> => {
  const values = new Map(initialValues);
  let changed = true;

  while (changed) {
    changed = false;

    for (const [key, refs] of graph.entries()) {
      const value = values.get(key);
      if (!value) continue;

      for (const ref of refs) {
        const prev = values.get(ref);
        if (!prev) {
          values.set(ref, value);
          changed = true;
        } else {
          const combined = combineValues(prev, value);
          if (combined !== prev) {
            values.set(ref, combined);
            changed = true;
          }
        }
      }
    }
  }

  return values;
};

/**
 * Determines if an endpoint path indicates server-side only availability.
 * Currently, endpoints containing "/configs" are considered server-side only.
 */
const isServerOnlyEndpoint = (path: string): boolean => {
  return path.includes("/configs");
};

export const calculateSchemaAvailabilities = (
  allEndpoints: Array<Endpoint>,
  allChannels: OA.AsyncAPISpec["channels"],
  allMessages: OA.AsyncAPISpec["components"]["messages"],
  allSchemas: Record<string, JsonSchema>,
): Map<string, Availability> => {
  // Build the reference graph
  const referenceGraph = buildReferenceGraph(allSchemas);

  // Collect initial availabilities from root schemas
  const initialAvailabilities = new Map<string, Availability>();

  const setInitialAvailability = (schema: OA.JsonSchema, availability: Availability) => {
    if ("schemaKey" in schema && typeof schema.schemaKey === "string") {
      const existing = initialAvailabilities.get(schema.schemaKey);
      if (existing && existing !== availability) {
        // If we have conflicting availabilities, make it full (available to all)
        initialAvailabilities.set(schema.schemaKey, "full");
      } else {
        initialAvailabilities.set(schema.schemaKey, availability);
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

      const existing = initialAvailabilities.get(schemaKey);
      if (existing && existing !== availability) {
        // If we have conflicting availabilities, make it full (available to all)
        initialAvailabilities.set(schemaKey, "full");
      } else {
        initialAvailabilities.set(schemaKey, availability);
      }
    }
  };

  // Process AsyncAPI channels - these are typically full availability (websockets available to both)
  for (const channelPath in allChannels) {
    const channel = allChannels[channelPath];

    // Publish messages are sent by client to server
    walkAsyncAPIMessage(
      channel.publish.message,
      (m) => {
        if (m.kind === "message") {
          walkSchema(m.payload, (s) => {
            setInitialAvailability(s, "full");
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
            setInitialAvailability(s, "full");
          });
        }
      },
      allMessages,
    );
  }

  // Process OpenAPI endpoints - check if they're server-side only based on path
  for (const endpoint of allEndpoints) {
    if (endpoint.operation.kind === "ignored") {
      continue;
    }

    const availability: Availability = isServerOnlyEndpoint(endpoint.path) ? "serverOnly" : "full";

    // Request body schemas
    if (endpoint.operation.kind === "jsonBody") {
      walkSchema(
        endpoint.operation.requestBody.content["application/json"].schema,
        (s) => setInitialAvailability(s, availability),
      );
    }

    // Parameter schemas
    endpoint.operation.parameters.forEach(({ schema }) => {
      walkSchema(schema, (s) => setInitialAvailability(s, availability));
    });

    // Response schemas
    Object.values(endpoint.operation.responses ?? []).forEach((response) => {
      switch (response.kind) {
        case "jsonResponse":
          walkSchema(response.content["application/json"].schema, (s) =>
            setInitialAvailability(s, availability),
          );
          return;
        case "binaryResponse":
          walkSchema(response.content["audio/*"].schema, (s) =>
            setInitialAvailability(s, availability),
          );
          return;
        case "noContent":
          return;
        default:
          return exhaustive(response);
      }
    });
  }

  // Propagate availabilities through the reference graph
  // If a schema is referenced from both server-only and full endpoints, it becomes full
  const propagatedAvailabilities = propagate(
    referenceGraph,
    initialAvailabilities,
    allSchemas,
    (a: Availability, b: Availability) => {
      if (a === "full" || b === "full") return "full";
      return "serverOnly";
    },
  );

  // Set "serverOnly" as default for any schemas that weren't reached
  for (const schemaKey of Object.keys(allSchemas)) {
    if (!propagatedAvailabilities.has(schemaKey)) {
      propagatedAvailabilities.set(schemaKey, "serverOnly");
    }
  }

  return propagatedAvailabilities;
};