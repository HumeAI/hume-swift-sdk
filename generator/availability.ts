import * as OA from "./parse_openapi";
import type { JsonSchema } from "./parse_openapi";
import type { Endpoint } from "./generator";
import { walkSchema, buildReferenceGraph, walkAsyncAPIMessage } from "./common";

export type Availability = "serverOnly" | "full";

const propagateAvailability = (
  graph: Map<string, Set<string>>,
  initialAvailability: Map<string, Availability>,
): Map<string, Availability> => {
  const result = new Map(initialAvailability);
  let changed = true;
  while (changed) {
    changed = false;
    for (const [key, refs] of graph.entries()) {
      const avail = result.get(key);
      if (!avail) continue;
      if (avail !== "full") continue;
      for (const ref of refs) {
        const prev = result.get(ref);
        if (prev !== "full") {
          result.set(ref, "full");
          changed = true;
        }
      }
    }
  }
  return result;
};

export const calculateAvailability = (
  allEndpoints: Array<Endpoint>,
  allChannels: OA.AsyncAPISpec["channels"],
  allMessages: OA.AsyncAPISpec["components"]["messages"],
  allSchemas: Record<string, JsonSchema>,
): {
  schemaAvailability: Map<string, Availability>;
  endpointAvailability: Map<Endpoint, Availability>;
} => {
  const endpointAvailability = new Map<Endpoint, Availability>();

  // Mark endpoints: default serverOnly, all except /v0/evi/configs are full
  for (const endpoint of allEndpoints) {
    const shouldBeFull = endpoint.path !== "/v0/evi/configs";
    endpointAvailability.set(endpoint, shouldBeFull ? "full" : "serverOnly");
  }

  // Initial availability roots: all full endpoints + all async messages
  const initialAvailability = new Map<string, Availability>();
  const setFull = (schema: OA.JsonSchema) => {
    if (schema.kind === "ref") {
      const refName = schema.$ref.replace(/^#\/components\/schemas\//, "");
      const ttsKey = `tts:${refName}`;
      const eviKey = `evi:${refName}`;
      if (allSchemas[ttsKey]) initialAvailability.set(ttsKey, "full");
      if (allSchemas[eviKey]) initialAvailability.set(eviKey, "full");
      return;
    }
    if ("schemaKey" in schema && typeof (schema as any).schemaKey === "string") {
      initialAvailability.set((schema as any).schemaKey, "full");
    }
  };

  for (const endpoint of allEndpoints) {
    if (endpointAvailability.get(endpoint) !== "full") continue;
    const op = endpoint.operation;
    if (op.kind === "ignored") continue;
    if (op.kind === "jsonBody") {
      setFull(op.requestBody.content["application/json"].schema);
    }
    op.parameters.forEach(({ schema }) => setFull(schema));
    Object.values(op.responses ?? {}).forEach((response) => {
      switch (response.kind) {
        case "jsonResponse":
          setFull(response.content["application/json"].schema);
          break;
        case "binaryResponse":
          setFull(response.content["audio/*"].schema);
          break;
        case "noContent":
          break;
      }
    });
  }

  for (const channelPath in allChannels) {
    const channel = allChannels[channelPath];
    walkAsyncAPIMessage(
      channel.publish.message,
      (m) => {
        if (m.kind === "message") {
          walkSchema(m.payload, (s) => setFull(s));
        }
      },
      allMessages,
    );
    walkAsyncAPIMessage(
      channel.subscribe.message,
      (m) => {
        if (m.kind === "message") {
          walkSchema(m.payload, (s) => setFull(s));
        }
      },
      allMessages,
    );
  }

  const graph = buildReferenceGraph(allSchemas);
  const schemaAvailability = propagateAvailability(graph, initialAvailability);

  // Default all non-marked schemas to serverOnly
  for (const key of Object.keys(allSchemas)) {
    if (!schemaAvailability.has(key)) {
      schemaAvailability.set(key, "serverOnly");
    }
  }

  return { schemaAvailability, endpointAvailability };
};