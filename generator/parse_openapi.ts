import _ from "lodash";
import { z } from "zod";
import * as fs from "fs/promises";
import yaml from "yaml";

export const walkObject = (
  obj: unknown,
  visitor: (node: unknown, path: Array<string | number>) => void,
  path: Array<string | number> = [],
): void => {
  visitor(obj, path);
  if (!obj || typeof obj !== "object") return;

  if (Array.isArray(obj)) {
    obj.forEach((child, i) => {
      const nextPath = [...path, i];
      walkObject(child, visitor, nextPath);
    });
  } else {
    Object.entries(obj).forEach(([k, child]) => {
      const nextPath = [...path, k];
      walkObject(child, visitor, nextPath);
    });
  }
};

const addKind_ = <T extends string>(obj: unknown, kind: T): void => {
  (obj as { kind: string }).kind = kind;
};
const addSchemaKind = (obj: unknown, kind: JsonSchema['kind']): void => {
  addKind_(obj, kind);
}
const addMessageKind = (obj: unknown, kind: AsyncAPIMessage['kind']): void => {
  addKind_(obj, kind);
}
const addOperationKind = (obj: unknown, kind: OpenAPIOperation['kind']): void => {
  addKind_(obj, kind);
}
const addResponseKind = (obj: unknown, kind: Response['kind']): void => {
  addKind_(obj, kind);
}

type RawJsonSchema = {
  type?: string | null;
  properties?: Record<string, RawJsonSchema> | null;
  items?: RawJsonSchema | null;
  enum?: Array<string | number | boolean | null> | null;
  anyOf?: Array<RawJsonSchema> | null;
  oneOf?: Array<RawJsonSchema> | null;
  allOf?: Array<RawJsonSchema> | null;
  $ref?: string | null;
  title?: string | null;
  description?: string | null;
  nullable?: boolean | null;
  format?: string | null;
  required?: Array<string> | null;
  additionalProperties?: boolean | RawJsonSchema | null;
  default?: string | number | boolean | null | Record<string, unknown> | null;
  const?: string | number | boolean | null | null;
  "x-fern-ignore"?: boolean | null;
  "x-fern-type-name"?: string | null;
  "x-fern-undiscriminated"?: boolean | null;
  discriminator?: {
    propertyName: string | null;
    mapping?: Record<string, string> | null;
  } | null;
};

const RawJsonSchema = z.lazy((): any =>
  z.object({
    type: z.string().nullable().optional(),
    properties: z
      .record(z.lazy(() => z.nullable(RawJsonSchema)))
      .nullable()
      .optional(),
    items: z
      .lazy(() => RawJsonSchema)
      .nullable()
      .optional(),
    enum: z
      .array(z.union([z.string(), z.number(), z.boolean(), z.null()]))
      .nullable()
      .optional(),
    anyOf: z
      .array(z.lazy(() => RawJsonSchema))
      .nullable()
      .optional(),
    oneOf: z
      .array(z.lazy(() => RawJsonSchema))
      .nullable()
      .optional(),
    allOf: z
      .array(z.lazy(() => RawJsonSchema))
      .nullable()
      .optional(),
    $ref: z.string().nullable().optional(),
    title: z.string().nullable().optional(),
    description: z.string().nullable().optional(),
    nullable: z.boolean().nullable().optional(),
    format: z.string().nullable().optional(),
    required: z.array(z.string()).nullable().optional(),
    additionalProperties: z
      .union([z.boolean(), z.lazy(() => RawJsonSchema)])
      .nullable()
      .optional(),
    default: z
      .union([
        z.string(),
        z.number(),
        z.boolean(),
        z.null(),
        z.record(z.string(), z.unknown()),
      ])
      .nullable()
      .optional(),
    const: z
      .union([z.string(), z.number(), z.boolean(), z.null()])
      .nullable()
      .optional(),
    "x-fern-ignore": z.boolean().nullable().optional(),
    "x-fern-undiscriminated": z.boolean().nullable().optional(),
    "x-fern-type-name": z.string().nullable().optional(),
    discriminator: z
      .object({
        propertyName: z.string().nullable(),
        mapping: z.record(z.string(), z.string()).nullable().optional(),
      })
      .nullable()
      .optional(),
  }),
) satisfies z.Schema<RawJsonSchema>;
({}) as RawJsonSchema satisfies z.infer<typeof RawJsonSchema>;

export type JsonSchema =
  | {
    kind: "ignored";
  }
  | {
    kind: "unionOfRefs";
  }
  | {
    kind: "ref",
    $ref: string
  }
  | {
    kind: "empty";
  }
  | {
    kind: "inheritance";
  }
  | {
    kind: "discriminatedUnion";
    description?: string;
    schemaKey?: string;
    discriminator: {
      propertyName: string;
      mapping: Record<string, string>;
    };
    title: string;
    oneOf: Array<JsonSchema>;
    nullable?: boolean;
  }
  | {
    kind: "anyOfDiscriminatedUnion";
    description?: string;
    discriminant: string;
    anyOf: Array<JsonSchema>;
    nullable?: boolean;
  }
  | {
    kind: "anyOfUndiscriminatedUnion";
    description?: string;
    anyOf: Array<JsonSchema>;
    nullable?: boolean;
  }
  | {
    kind: "oneOfUndiscriminatedUnion";
    description?: string;
    oneOf: Array<JsonSchema>;
    nullable?: boolean;
  }
  | {
    kind: "singletonOrArray";
    description?: string;
    anyOf: [JsonSchema, JsonSchema];
    nullable?: boolean;
  }
  | {
    kind: "metadataObject";
    description?: string;
    nullable?: boolean;
  }
  | {
    kind: "enum";
    description?: string;
    type: "string";
    title?: string;
    schemaKey?: string;
    "x-fern-type-name"?: string;
    enum: Array<string>;
    nullable?: boolean;
  }
  | {
    kind: "primitive";
    description?: string;
    type: "string" | "number" | "boolean" | "integer";
    nullable?: boolean;
  }
  | {
    kind: "stringOrInteger";
    description?: string;
    anyOf: [JsonSchema, JsonSchema];
    nullable?: boolean;
  }
  | {
    kind: "stringNumberBool";
    description?: string;
    oneOf: [JsonSchema, JsonSchema, JsonSchema];
    nullable?: boolean;
  }
  | {
    kind: "object";
    description?: string;
    schemaKey?: string;
    title?: string;
    "x-fern-type-name"?: string;
    properties: Record<string, JsonSchema>;
    required: Array<string>;
    nullable?: boolean;
  }
  | {
    kind: "array";
    description?: string;
    type: "array";
    items: JsonSchema;
    nullable?: boolean;
  }
  | {
    kind: "dictionary";
    description?: string;
    schemaKey?: string;
    type: "object";
    additionalProperties: JsonSchema;
    nullable?: boolean;
  };
const JS: z.Schema<JsonSchema> = z.lazy((): any => JsonSchema_);
export const JsonSchema_ = z.discriminatedUnion("kind", [
  z.object({
    kind: z.literal("ignored"),
  }),
  z.object({
    kind: z.literal("ref"),
    $ref: z.string(),
  }),
  z.object({
    kind: z.literal("unionOfRefs"),
  }),
  z.object({
    kind: z.literal("empty"),
  }),
  z.object({
    kind: z.literal("inheritance"),
  }),
  z.object({
    kind: z.literal("discriminatedUnion"),
    description: z.string().optional(),
    schemaKey: z.string().optional(),
    discriminator: z.object({
      propertyName: z.string(),
      mapping: z.record(z.string(), z.string()),
    }),
    title: z.string(),
    oneOf: z.array(JS),
    nullable: z.boolean().optional(),
  }),
  z.object({
    kind: z.literal("anyOfDiscriminatedUnion"),
    description: z.string().optional(),
    discriminant: z.string(),
    anyOf: z.array(JS),
    nullable: z.boolean().optional(),
  }),
  z.object({
    kind: z.literal("anyOfUndiscriminatedUnion"),
    description: z.string().optional(),
    anyOf: z.array(JS),
    nullable: z.boolean().optional(),
  }),
  z.object({
    kind: z.literal("oneOfUndiscriminatedUnion"),
    description: z.string().optional(),
    oneOf: z.array(JS),
    nullable: z.boolean().optional(),
  }),
  z.object({
    kind: z.literal("singletonOrArray"),
    description: z.string().optional(),
    anyOf: z.tuple([JS, JS]),
    nullable: z.boolean().optional(),
  }),

  z.object({
    kind: z.literal("metadataObject"),
    description: z.string().optional(),
    nullable: z.boolean().optional(),
  }),
  z.object({
    kind: z.literal("enum"),
    description: z.string().optional(),
    title: z.string().optional(),
    schemaKey: z.string().optional(),
    "x-fern-type-name": z.string().optional(),
    type: z.literal("string"),
    enum: z.array(z.string()),
    nullable: z.boolean().optional(),
  }),
  z.object({
    kind: z.literal("primitive"),
    description: z.string().optional(),
    type: z.union([
      z.literal("string"),
      z.literal("number"),
      z.literal("boolean"),
      z.literal("integer"),
    ]),
    nullable: z.boolean().optional(),
  }),
  z.object({
    kind: z.literal("stringOrInteger"),
    description: z.string().optional(),
    anyOf: z.tuple([JS, JS]),
    nullable: z.boolean().optional(),
  }),
  z.object({
    kind: z.literal("stringNumberBool"),
    description: z.string().optional(),
    oneOf: z.tuple([JS, JS, JS]),
    nullable: z.boolean().optional(),
  }),
  z.object({
    kind: z.literal("object"),
    description: z.string().optional(),
    schemaKey: z.string().optional(),
    title: z.string().optional(),
    "x-fern-type-name": z.string().optional(),
    properties: z.record(z.string(), JS),
    required: z.array(z.string()),
    nullable: z.boolean().optional(),
  }),
  z.object({
    kind: z.literal("array"),
    description: z.string().optional(),
    type: z.literal("array"),
    items: JS,
    nullable: z.boolean().optional(),
  }),
  z.object({
    kind: z.literal("dictionary"),
    description: z.string().optional(),
    schemaKey: z.string().optional(),
    type: z.literal("object"),
    additionalProperties: JS,
    nullable: z.boolean().optional(),
  }),
]) satisfies z.Schema<JsonSchema>;
({}) as JsonSchema satisfies z.infer<typeof JsonSchema_>;

const RawAsyncAPIMessage = z.lazy((): any =>
  z.union([
    z.object({
      name: z.string(),
      description: z.string(),
      payload: RawJsonSchema,
    }),
    z.object({
      $ref: z.string().nullable(),
    }),
    z.object({
      oneOf: z.array(RawAsyncAPIMessage).nullable(),
    }),
  ]),
);
type RawAsyncAPIMessage = z.infer<typeof RawAsyncAPIMessage>;

export type AsyncAPIMessage =
  | {
    kind: "message";
    name: string;
    description: string;
    payload: JsonSchema;
  }
  | {
    kind: "oneOf";
    oneOf: Array<AsyncAPIMessage>;
  } | {
    kind: 'ref';
    $ref: string;
  };

const AsyncAPIMessage_ = z.discriminatedUnion("kind", [
  z.object({
    kind: z.literal("message"),
    name: z.string(),
    description: z.string(),
    payload: JsonSchema_,
  }),
  z.object({
    kind: z.literal("oneOf"),
    oneOf: z.array(
      z.lazy((): any => AsyncAPIMessage_) as z.Schema<AsyncAPIMessage>,
    ),
  }),
  z.object({
    kind: z.literal("ref"),
    $ref: z.string(),
  }),
]) satisfies z.Schema<AsyncAPIMessage>;
({}) as AsyncAPIMessage satisfies z.infer<typeof AsyncAPIMessage_>;

const lookForDiscriminant = (schemas: Array<JsonSchema>): string | null => {
  if (schemas.length === 0) {
    return null;
  }
  if (schemas.find((s) => s.kind !== "object" || !s.properties)) {
    return null;
  }

  const isEligible = (s: RawJsonSchema): boolean => {
    return s.type === "string" && !!s.const;
  };
  const propertyNameCount: Record<string, number> = {};
  for (const schema_ of schemas) {
    const schema = schema_ as RawJsonSchema & { properties: any };
    for (const k in schema.properties) {
      if (!isEligible(schema.properties[k])) {
        continue;
      }
      if (!propertyNameCount[k]) {
        propertyNameCount[k] = 0;
      }
      propertyNameCount[k] += 1;
    }
  }

  const candidates = Object.entries(propertyNameCount)
    .filter(([_, v]) => v === schemas.length)
    .map(([k]) => k);
  if (candidates.length !== 1) {
    return null;
  }
  return candidates[0];
};

const decorateJsonSchema = async (
  schema: RawJsonSchema,
  _back?: RawJsonSchema,
  schemaKey?: string,
): Promise<JsonSchema> => {
  try {
    decorateJsonSchema_(schema, null);
    return (JsonSchema_ as z.ZodType).parseAsync(schema);
  } catch (e) {
    console.error(`Error decorating schema ${schemaKey || "unknown"}:`, e);
    return { kind: "ignored" };
  }
};

const decorateJsonSchema_ = (
  schema: RawJsonSchema,
  _back?: RawJsonSchema | null,
): void => {
  const recurse = (s: RawJsonSchema) => {
    decorateJsonSchema(s, schema);
  };
  if (schema["x-fern-ignore"]) {
    addSchemaKind(schema, "ignored");
    return;
  }
  if (Object.keys(schema).length === 0) {
    addSchemaKind(schema, "empty");
    return;
  }
  if ("additionalProperties" in schema && !schema.additionalProperties) {
    delete schema.additionalProperties;
  }
  if (schema.allOf) {
    addSchemaKind(schema, "inheritance");
    return;
  }
  if (schema.anyOf) {
    if (schema.anyOf.every((x: RawJsonSchema) => x.allOf)) {
      addSchemaKind(schema, "inheritance");
    }
    {
      // Logic for handling nullability via `anyOf`.
      const nullAt = schema.anyOf.findIndex(
        (x: RawJsonSchema) => x.type === "null",
      );
      if (nullAt !== -1) {
        schema.nullable = true;
        schema.anyOf.splice(nullAt, 1);
      }

      if (schema.anyOf.length === 1) {
        recurse(schema.anyOf[0]);
        Object.assign(schema, schema.anyOf[0]);
        return;
      }
    }

    for (const variant of schema.anyOf) {
      recurse(variant);
    }
    const anyOf = schema.anyOf as Array<JsonSchema>;

    if (schema.anyOf.length === 2) {
      const [a, b] = anyOf;
      const schemaKeyOf = (s: unknown): string | null => {
        return s &&
          typeof s === "object" &&
          "schemaKey" in s &&
          s.schemaKey &&
          typeof s.schemaKey === "string"
          ? s.schemaKey
          : null;
      };
      const equalBySchemaKey = (a: unknown, b: unknown): boolean => {
        const sa = schemaKeyOf(a);
        if (!sa) {
          return false;
        }
        return sa === schemaKeyOf(b);
      };
      if (b.kind === "array" && equalBySchemaKey(b.items, a)) {
        addSchemaKind(schema, "singletonOrArray");
        return;
      }
      if (a.kind === "array" && equalBySchemaKey(a.items, b)) {
        addSchemaKind(schema, "singletonOrArray");
        schema.anyOf = [b as RawJsonSchema, a as RawJsonSchema];
        return;
      }

      if (
        a.kind === "primitive" &&
        b.kind === "primitive" &&
        a.type === "string" &&
        b.type === "integer"
      ) {
        addSchemaKind(schema, "stringOrInteger");
        return;
      }
      if (
        b.kind === "primitive" &&
        a.kind === "primitive" &&
        b.type === "string" &&
        a.type === "integer"
      ) {
        addSchemaKind(schema, "stringOrInteger");
        return;
      }
    }
    if (anyOf.every((x: JsonSchema) => x.kind === "object")) {
      const discriminant = lookForDiscriminant(anyOf);
      if (discriminant) {
        addSchemaKind(schema, "anyOfDiscriminatedUnion");
        (
          schema as JsonSchema & { kind: "anyOfDiscriminatedUnion" }
        ).discriminant = discriminant;
        return;
      } else {
        addSchemaKind(schema, "anyOfUndiscriminatedUnion");
        return;
      }
    }
    if (anyOf.every((x: JsonSchema) => x.kind === "ref")) {
      addSchemaKind(schema, "unionOfRefs")
    }
    
    if (!(schema as any).kind) {
      throw new Error("Unknown type of anyOf");
    }
  }
  if (schema.oneOf) {
    console.log(schema.oneOf)
    for (const variant of schema.oneOf) {
      recurse(variant);
    }
    const oneOf = schema.oneOf as Array<JsonSchema>;
    if (oneOf.every((x: JsonSchema) => x.kind === "primitive")) {
      if (oneOf.length === 3) {
        if (
          ["string", "number", "boolean"].every((x) =>
            oneOf.some(
              (y: JsonSchema) =>
                (y as JsonSchema & { type: "primitive" }).type === x,
            ),
          )
        ) {
          addSchemaKind(schema, "stringNumberBool");
          return;
        }
      }
      throw new Error(
        "oneOf of primitives that is not string, number, boolean",
      );
    }
    if (oneOf.every((x: JsonSchema) => x.kind === "ref")) {
      if (schema['x-fern-undiscriminated']) {
        addSchemaKind(schema, "oneOfUndiscriminatedUnion");
        for (const k in schema.oneOf) {
          recurse(schema.oneOf[k]);
        }
        return;
      }
      addSchemaKind(schema, "discriminatedUnion");
      for (const k in schema.oneOf) {
        recurse(schema.oneOf[k]);
      }
      return;
    }
    throw new Error("Unknown type of oneOf");
  }
  if (schema['$ref']) {
    addSchemaKind(schema, "ref");
    return;
  }
  if (schema.enum) {
    addSchemaKind(schema, "enum");
    return;
  }
  if (schema.type === "object" && schema.properties) {
    addSchemaKind(schema, "object");
    if (!schema.required) {
      schema.required = [];
    }
    for (const k in schema.properties) {
      if (!schema.properties[k]) {
        delete schema.properties[k];
      } else {
        recurse(schema.properties[k]);
      }
    }
    return;
  }
  if (
    schema.type === "object" &&
    schema.additionalProperties &&
    typeof schema.additionalProperties === "object"
  ) {
    addSchemaKind(schema, "dictionary");
    recurse(schema.additionalProperties);
    return;
  }
  if (schema.type === "object") {
    addSchemaKind(schema, "metadataObject");
    return;
  }
  if (schema.type === "array" && schema.items) {
    addSchemaKind(schema, "array");
    recurse(schema.items);
  }
  if (
    schema.type === "string" ||
    schema.type === "number" ||
    schema.type === "boolean" ||
    schema.type === "integer"
  ) {
    addSchemaKind(schema, "primitive");
  }
};

const RawParameter = z.object({
  name: z.string(),
  in: z.union([z.literal("path"), z.literal("query"), z.literal("header")]),
  required: z.boolean(),
  schema: RawJsonSchema,
});
type RawParameter = z.infer<typeof RawParameter>;

const Parameter_ = z.object({
  name: z.string(),
  in: z.union([z.literal("path"), z.literal("query"), z.literal("header")]),
  required: z.boolean(),
  schema: JsonSchema_,
});

// Make schema fields more optional to handle missing fields in the API spec
const RawResponse_ = z.object({
  content: z
    .object({
      "application/json": z.union([
        z.object({
          schema: RawJsonSchema.optional(),
        }),
        z.null(),
      ])
        .optional(),
      "audio/*": z
        .object({
          schema: RawJsonSchema.optional(),
        })
        .optional(),
    })
    .optional(),
});
type RawResponse = z.infer<typeof RawResponse_>;

const Response_ = z.discriminatedUnion("kind", [
  z.object({
    kind: z.literal("jsonResponse"),
    content: z.object({
      "application/json": z.object({
        schema: JsonSchema_,
      }),
    }),
  }),
  z.object({
    kind: z.literal("binaryResponse"),
    content: z.object({
      "audio/*": z.object({
        schema: JsonSchema_,
      }),
    }),
  }),
  z.object({
    kind: z.literal("noContent"),
  }),
]);
type Response = z.infer<typeof Response_>;

const decorateResponse = async (response: RawResponse): Promise<Response> => {
  decorateResponse_(response);
  return Response_.parseAsync(response);
};
const decorateResponse_ = (response: RawResponse): void => {
  if (!response.content) {
    addResponseKind(response, "noContent");
    return;
  }

  if (response.content["audio/*"] && response.content["audio/*"].schema) {
    addResponseKind(response, "binaryResponse");
    decorateJsonSchema(response.content["audio/*"].schema);
    return;
  }

  if (response.content["application/json"] && response.content["application/json"].schema) {
    addResponseKind(response, "jsonResponse");
    decorateJsonSchema(response.content["application/json"].schema);
    return;
  }

  addResponseKind(response, "noContent");
};

const RawOpenAPIOperation = z.object({
  // Make responses optional to handle endpoints without defined responses
  responses: z.record(RawResponse_).optional(),
  operationId: z.string().optional(), // Make operationId optional to handle missing fields
  parameters: z.array(RawParameter).optional(),
  requestBody: z
    .object({
      content: z
        .record(
          z.string(),
          z
            .object({
              schema: RawJsonSchema,
            })
            .optional(),
        )
        .optional(),
    })
    .optional(),
  "x-fern-ignore": z.boolean().optional(),
  "x-fern-sdk-group-name": z.string().optional(),
  "x-fern-sdk-method-name": z.string().optional(),
});
type RawOpenAPIOperation = z.infer<typeof RawOpenAPIOperation>;

const OpenAPIOperation_ = z.discriminatedUnion("kind", [
  z.object({
    kind: z.literal("ignored"),
  }),
  z.object({
    kind: z.literal("noBody"),
    operationId: z.string().optional(), // Made optional to match RawOpenAPIOperation
    parameters: z.array(Parameter_),
    responses: z.record(Response_).optional(), // Make responses optional
    "x-fern-sdk-group-name": z.string().optional(),
    "x-fern-sdk-method-name": z.string().optional(),
  }),
  z.object({
    kind: z.literal("jsonBody"),
    operationId: z.string().optional(), // Made optional to match RawOpenAPIOperation
    parameters: z.array(Parameter_),
    requestBody: z.object({
      content: z.object({
        "application/json": z.object({ schema: JsonSchema_ }),
      }),
    }),
    responses: z.record(Response_).optional(), // Make responses optional
    "x-fern-sdk-group-name": z.string().optional(),
    "x-fern-sdk-method-name": z.string().optional(),
  }),
]);
export type OpenAPIOperation = z.infer<typeof OpenAPIOperation_>;

const decorateOpenApiOperation = async (
  operation: RawOpenAPIOperation,
): Promise<OpenAPIOperation> => {
  decorateOpenApiOperation_(operation);
  return OpenAPIOperation_.parseAsync(operation);
};

const decorateOpenApiOperation_ = (operation: RawOpenAPIOperation): void => {
  if (operation["x-fern-ignore"]) {
    addOperationKind(operation, "ignored");
    return;
  }
  if (!operation.parameters) {
    operation.parameters = [];
  }
  for (const p of operation.parameters) {
    decorateJsonSchema(p.schema);
  }
  const jsonBody = operation.requestBody?.content?.["application/json"];
  if (jsonBody) {
    addOperationKind(operation, "jsonBody");
    decorateJsonSchema(jsonBody.schema);
  } else {
    addOperationKind(operation, "noBody");
  }
  // Ensure responses exists
  if (!operation.responses) {
    operation.responses = {};
  }
  for (const k in operation.responses) {
    decorateResponse(operation.responses[k]);
  }
};

const decorateAsyncApiMessage = (
  message: RawAsyncAPIMessage,
): AsyncAPIMessage => {
  decorateAsyncApiMessage_(message);
  const { data, success, error } = AsyncAPIMessage_.safeParse(message);
  if (!success) {
    console.error(JSON.stringify(message));
    console.error(JSON.stringify(error));
    throw new Error("error parsing message");
  }
  return data;
};

const decorateAsyncApiMessage_ = (message: RawAsyncAPIMessage): void => {
  if ("$ref" in message) {
    addMessageKind(message, "ref");
    return;
  }
  if ("oneOf" in message) {
    addMessageKind(message, "oneOf");
    for (const m of message.oneOf) {
      decorateAsyncApiMessage(m);
    }
    return;
  }
  decorateJsonSchema(message.payload);
  addMessageKind(message, "message");
};

const RawOpenAPISpec_ = z.object({
  paths: z.optional(
    z.record(z.string(), z.record(z.string(), RawOpenAPIOperation)),
  ),
  components: z.object({
    schemas: z.record(z.string(), RawJsonSchema),
  }),
  "x-fern-base-path": z.string().optional(),
});
type RawOpenAPISpec = z.infer<typeof RawOpenAPISpec_>;

const OpenAPISpec_ = z.object({
  paths: z.record(z.string(), z.record(z.string(), OpenAPIOperation_)),
  components: z.object({
    schemas: z.record(z.string(), JsonSchema_),
  }),
  "x-fern-base-path": z.string().optional(),
});
export type OpenAPISpec = z.infer<typeof OpenAPISpec_>;

const decorateOpenApiSpec = (openApi: RawOpenAPISpec): OpenAPISpec => {
  decorateOpenApiSpec_(openApi);
  
  // Check if all schemas have been properly decorated with a 'kind' property
  if (openApi.components && openApi.components.schemas) {
    for (const key in openApi.components.schemas) {
      const schema = openApi.components.schemas[key];
      if (!schema.kind) {
        console.error(`Schema '${key}' dump:`, JSON.stringify(schema, null, 2));
        throw new Error(`Schema '${key}' is missing a 'kind' property after decoration. This indicates a bug in the decorateJsonSchema_ function.`);
      }
    }
  }
  
  const { data, success, error } = OpenAPISpec_.safeParse(openApi);
  if (!success) {
    console.error("OpenAPI spec validation failed:");
    
    // Log each validation error with its path
    if (error.errors) {
      error.errors.forEach((err, index) => {
        console.error(`Error ${index + 1}:`);
        console.error(`- Path: ${err.path.join('.')}`);
        console.error(`- Message: ${err.message}`);
        console.error(`- Code: ${err.code}`);
        
        // Try to display the actual value that failed validation
        try {
          let value = openApi;
          for (const segment of err.path) {
            value = (value as any)[segment];
          }
          console.error(`- Value: ${JSON.stringify(value, null, 2).substring(0, 1000)}`);
        } catch (e) {
          console.error("- Could not extract problematic value");
        }
        console.error("---");
      });
    }
    
    throw error;
  }
  return data;
};
const decorateOpenApiSpec_ = (openApi: RawOpenAPISpec): void => {
  for (const path in openApi.paths) {
    for (const verb in openApi.paths[path]) {
      const operation = openApi.paths[path][verb];
      decorateOpenApiOperation(operation);
    }
  }
  openApi.paths;
  if (!openApi.paths) {
    openApi.paths = {};
  }
  for (const k in openApi.components.schemas) {
    decorateJsonSchema(openApi.components.schemas[k], undefined, k);
  }
};
const decorateAsyncApiSpec = (asyncApi: RawAsyncAPISpec): AsyncAPISpec => {
  decorateAsyncApiSpec_(asyncApi);
  const { data, success, error } = AsyncAPISpec.safeParse(asyncApi);
  if (!success) {
    console.error("AsyncAPI spec validation failed:");
    
    // Log each validation error with its path
    if (error.errors) {
      error.errors.forEach((err, index) => {
        console.error(`Error ${index + 1}:`);
        console.error(`- Path: ${err.path.join('.')}`);
        console.error(`- Message: ${err.message}`);
        console.error(`- Code: ${err.code}`);
        
        // Try to display the actual value that failed validation
        try {
          let value = asyncApi;
          for (const segment of err.path) {
            value = (value as any)[segment];
          }
          console.error(`- Value: ${JSON.stringify(value, null, 2).substring(0, 1000)}`);
        } catch (e) {
          console.error("- Could not extract problematic value");
        }
        console.error("---");
      });
    }
    
    throw new Error("Error parsing AsyncAPI spec");
  }
  return data;
};

const decorateAsyncApiSpec_ = (asyncApi: RawAsyncAPISpec): void => {
  for (const k in asyncApi.components.schemas) {
    decorateJsonSchema(asyncApi.components.schemas[k], undefined, k);
  }
  for (const k in asyncApi.components.messages) {
    decorateAsyncApiMessage(asyncApi.components.messages[k]);
  }
  for (const k in asyncApi.channels) {
    decorateAsyncApiMessage(asyncApi.channels[k].subscribe.message);
    decorateAsyncApiMessage(asyncApi.channels[k].publish.message);
  }
};

const RawAsyncAPISpec = z.object({
  channels: z.record(
    z.string(),
    z.object({
      subscribe: z.object({ message: RawAsyncAPIMessage }),
      publish: z.object({ message: RawAsyncAPIMessage }),
    }),
  ),
  components: z.object({
    messages: z.record(z.string(), RawAsyncAPIMessage),
    schemas: z.record(z.string(), RawJsonSchema),
  }),
});
type RawAsyncAPISpec = z.infer<typeof RawAsyncAPISpec>;

const AsyncAPISpec = z.object({
  channels: z.record(
    z.string(),
    z.object({
      subscribe: z.object({ message: AsyncAPIMessage_ }),
      publish: z.object({ message: AsyncAPIMessage_ }),
    }),
  ),
  components: z.object({
    messages: z.record(z.string(), AsyncAPIMessage_),
    schemas: z.record(z.string(), JsonSchema_),
  }),
});
export type AsyncAPISpec = z.infer<typeof AsyncAPISpec>;

const lookupRef = (
  ref: string,
  schemas: Record<string, unknown>,
  messages: Record<string, unknown>,
): unknown => {
  if (ref.startsWith("#/components/schemas/")) {
    return schemas[ref.replace(/^#\/components\/schemas\//, "")];
  }
  if (ref.startsWith("#/components/messages/")) {
    return messages[ref.replace(/^#\/components\/messages\//, "")];
  }
  throw new Error(`Unknown ref: ${ref}`);
};

const dereference = (
  schema: unknown,
  allSchemas: Record<string, unknown>,
  allMessages: Record<string, unknown>,
): void => {
  walkObject(schema, (s) => {
    if (
      typeof s === "object" &&
      s &&
      "$ref" in s &&
      typeof s.$ref === "string"
    ) {
      const dereferenced = lookupRef(s.$ref, allSchemas, allMessages);
      Object.assign(s, dereferenced);
      delete s.$ref;
    }
  });
};

const applyOverrides = <T extends RawOpenAPISpec | RawAsyncAPISpec>(
  overrides: any,
  spec: T,
): T => {
  // Remove the code that deletes new schemas from overrides
  // This was preventing new schemas defined in override files from being added
  
  const merged = _.merge(spec, overrides) as T;
  if (
    "x-fern-base-path" in merged &&
    "paths" in merged &&
    merged["x-fern-base-path"] &&
    merged.paths
  ) {
    merged.paths = Object.fromEntries(
      Object.entries(merged.paths).map(([path, operations]) => {
        return [merged["x-fern-base-path"] + path, operations];
      }),
    );
  }
  return merged;
};

export type KnownSpecs = {
  // steno: OpenAPISpec;
  // assistant: OpenAPISpec;
  tts: OpenAPISpec;
  eviAsync: AsyncAPISpec;
};
export const readKnownSpecs = async (
  baseDir = `${process.cwd()}/apis`,
): Promise<KnownSpecs> => {
  try {
    console.log("Reading API specs from:", baseDir);
    
    // Read TTS specs (these files match the expected names)
    console.log("Reading TTS specs...");
    const ttsOverridesPath = baseDir + "/tts/tts-overrides.yml";
    const ttsOpenApiPath = baseDir + "/tts/tts-openapi.yml";
    
    console.log(`Loading TTS overrides from ${ttsOverridesPath}`);
    const ttsOverrides = yaml.parse(
      (await fs.readFile(ttsOverridesPath)).toString(),
    );
    
    console.log(`Loading TTS OpenAPI from ${ttsOpenApiPath}`);
    const ttsOpenApiRaw = applyOverrides(
      ttsOverrides,
      yaml.parse(
        (await fs.readFile(ttsOpenApiPath)).toString(),
      ),
    );
    
    console.log("Parsing TTS OpenAPI...");
    let ttsOpenApiResult;
    try {
      ttsOpenApiResult = await RawOpenAPISpec_.safeParseAsync(ttsOpenApiRaw);
      if (!ttsOpenApiResult.success) {
        console.error("Failed to parse TTS OpenAPI spec:");
        console.error(JSON.stringify(ttsOpenApiResult.error, null, 2));
        throw new Error("Failed to parse TTS OpenAPI spec");
      }
    } catch (e) {
      console.error("Exception parsing TTS OpenAPI spec:", e);
      throw e;
    }
    const ttsOpenApi: RawOpenAPISpec = ttsOpenApiResult.data;
    
    // Read EVI specs (using the new file names)
    console.log("Reading EVI specs...");
    const eviOverridesPath = baseDir + "/empathic-voice-interface/evi-openapi-overrides.yml";
    const eviOpenApiPath = baseDir + "/empathic-voice-interface/evi-openapi.json";
    
    console.log(`Loading EVI overrides from ${eviOverridesPath}`);
    const eviOverrides = yaml.parse(
      (await fs.readFile(eviOverridesPath)).toString(),
    );
    
    console.log(`Loading EVI OpenAPI from ${eviOpenApiPath}`);
    const eviOpenApiRaw = applyOverrides(
      eviOverrides,
      yaml.parse(
        (await fs.readFile(eviOpenApiPath)).toString(),
      ),
    );
    
    console.log("Parsing EVI OpenAPI...");
    let eviOpenApiResult;
    try {
      eviOpenApiResult = await RawOpenAPISpec_.safeParseAsync(eviOpenApiRaw);
      if (!eviOpenApiResult.success) {
        console.error("Failed to parse EVI OpenAPI spec:");
        console.error(JSON.stringify(eviOpenApiResult.error, null, 2));
        throw new Error("Failed to parse EVI OpenAPI spec");
      }
    } catch (e) {
      console.error("Exception parsing EVI OpenAPI spec:", e);
      throw e;
    }
    const eviOpenApi: RawOpenAPISpec = eviOpenApiResult.data;

    console.log("Reading EVI AsyncAPI specs...");
    const eviAsyncApiOverridesPath = baseDir + "/empathic-voice-interface/evi-asyncapi-overrides.yml";
    const eviAsyncApiPath = baseDir + "/empathic-voice-interface/evi-asyncapi.json";
    
    console.log(`Loading EVI AsyncAPI overrides from ${eviAsyncApiOverridesPath}`);
    const eviAsyncApiOverrides = yaml.parse(
      (await fs.readFile(eviAsyncApiOverridesPath)).toString(),
    );
    
    console.log(`Loading EVI AsyncAPI from ${eviAsyncApiPath}`);
    const eviAsyncApiRaw = applyOverrides(
      eviAsyncApiOverrides,
      yaml.parse(
        (await fs.readFile(eviAsyncApiPath)).toString(),
      ),
    );
    
    console.log("Parsing EVI AsyncAPI...");
    let eviAsyncApiResult;
    try {
      eviAsyncApiResult = await RawAsyncAPISpec.safeParseAsync(eviAsyncApiRaw);
      if (!eviAsyncApiResult.success) {
        console.error("Failed to parse EVI AsyncAPI spec:");
        console.error(JSON.stringify(eviAsyncApiResult.error, null, 2));
        throw new Error("Failed to parse EVI AsyncAPI spec");
      }
    } catch (e) {
      console.error("Exception parsing EVI AsyncAPI spec:", e);
      throw e;
    }
    const eviAsyncApi: RawAsyncAPISpec = eviAsyncApiResult.data;

    // Add schema key
    [
      // eviOpenApi,
      ttsOpenApi,
      eviAsyncApi,
    ]
      .forEach((x) => {
        if (!x.components?.schemas) {
          return;
        }
        for (const k in x.components.schemas) {
          x.components.schemas[k].schemaKey = k;
        }
      })

    const parseOpenApi = (openApi: RawOpenAPISpec): OpenAPISpec => {
      return decorateOpenApiSpec(openApi);
    };
    const parseAsyncApi = (asyncApi: RawAsyncAPISpec): AsyncAPISpec => {
      return decorateAsyncApiSpec(asyncApi);
    };

    return {
      tts: parseOpenApi(ttsOpenApi),
      eviAsync: parseAsyncApi(eviAsyncApi),
    };
  } catch (error) {
    console.error("Error reading specs:", error);
    throw error;
  }
};
