import * as OA from "./parse_openapi";
import type { JsonSchema } from "./parse_openapi";
import { camelCase, pascalCase } from "change-case";
import type { SwiftType, SwiftDefinition } from "./swift_renderer";
import type { SwiftSDK, Endpoint } from "./generator";
import type { Namespace } from "./namespaces";

type UnIgnored<T> = T extends { kind: "ignored" } ? never : T;

const exhaustive = (x: never): any => {
  throw new Error(`Unexpected object: ${x}`);
}
export const normalizeResourceName = (resourceName: string) => {
  return pascalCase(resourceName.replace(/-/g, " "));
};

export const normalizeObjectName = (title: string) => {
  return pascalCase(title.replace(/\[.*\]/, ""));
};

export const normalizedEnumNameFromValue = (enumValue: string, enumName: string) => {
  // Replace /, *, ., or - with underscores
  // trim leading or trailing underscores
  // convert to camel case
  // If the enum value begins with a number, prefix it with an underscore
  let name = enumValue;
  name = name.replace(/\/|\*|-|\(|\)/g, "_");
  name = name.replace(/\./g, "_");
  name = name.replace(/^_+|_+$/g, "");
  if (name.match(/^[0-9]/)) {
    name = "_" + name;
  }
  name = camelCase(name);

  if (/^([0-9]+)/.test(name)) {
    name = `${pascalCase(enumName)}_` + name;
  }
  return name;
};

export const getMethodName = (operation: UnIgnored<OA.OpenAPIOperation>): string => {
  if (operation["x-fern-sdk-method-name"]) {
    return camelCase(operation["x-fern-sdk-method-name"]);
  }
  if (operation.operationId) {
    return camelCase(operation.operationId);
  }
  throw new Error("Missing operationId in OpenAPI operation");
};

export const swiftName = (schema: JsonSchema, surroundingName?: string): string => {
  if (schema.kind === "ignored") {
    return "TODO_IGNORED_TYPE";
  }
  const fail = () => {
    throw new Error(`Cannot determine name from schema: ${JSON.stringify(schema)} beneath ${surroundingName}`);
  }

  if (schema.kind === "enum") {
    return schema["x-fern-type-name"] ??
      schema.title ??
      schema.schemaKey ??
      surroundingName ?? fail();
  }
  if (schema.kind === "object") {
    return normalizeObjectName(
      schema["x-fern-type-name"] ??
      schema.title ??
      schema.schemaKey ?? fail());
  }
  if (schema.kind === "discriminatedUnion") {
    return schema.title ? schema.title : fail();
  }

  if (schema.kind === "dictionary") {
    let result = "Dictionary";
    if (
      "x-fern-type-name" in schema &&
      schema["x-fern-type-name"] &&
      typeof schema["x-fern-type-name"] === "string"
    ) {
      result = schema["x-fern-type-name"];
    } else if (
      "title" in schema &&
      schema.title &&
      typeof schema.title === "string"
    ) {
      result = schema.title;
    } else if (
      "schemaKey" in schema &&
      schema.schemaKey &&
      typeof schema.schemaKey === "string"
    ) {
      result = schema.schemaKey;
    }
    return normalizeObjectName(result);
  }

  if (schema.kind === "anyOfRefs") {
    return normalizeObjectName(
      schema.schemaKey ?? surroundingName ?? fail(),
    );
  }

  if (schema.kind === "stringNumberBool") {
    return "StringNumberBool";
  }

  throw new Error(
    `Attempted to produce name for unnameable schema kind: ${schema.kind}`,
  );
};

export const getResourceName = ({ operation, path }: Endpoint) => {
  if (operation.kind === "ignored") {
    throw new Error();
  }
  if (operation["x-fern-sdk-group-name"])
    // x-fern-sdk-group name is the name of the property that defines the "resource" that the operation belongs to
    return normalizeResourceName(operation["x-fern-sdk-group-name"]);
  if (path.startsWith("/v0/tts")) return "TTS";
  throw new Error(`Unable to determine SDK group of operation ${path}`);
};

// Define a list of type names that need to be renamed due to collisions
// Each entry maps from original name to a Record of namespace to renamed name
const typeRenames: Record<string, Record<string, string>> = {
  Encoding: {
    tts: "AudioEncoding",
  },
  VoiceProvider: {
    tts: "TTSVoiceProvider",
  },
  Voice: {
    tts: "Voice",
  },
};

// Apply renames to a definition name based on the namespace
export const applyRename = (definitionName: string, namespace: Namespace): string => {
  const namespaceStr = namespace === "empathicVoice" ? "empathicVoice" : "tts";
  if (definitionName in typeRenames) {
    // If this definition name is in our rename list and there's a specific rename for this namespace
    if (namespaceStr in typeRenames[definitionName]) {
      return typeRenames[definitionName][namespaceStr];
    }
  }
  return definitionName;
};

// Update references within a SwiftType to use renamed types
export const updateTypeReferences = (
  type: SwiftType,
  namespace: Namespace,
): SwiftType => {
  switch (type.type) {
    case "Reference":
      return {
        type: "Reference",
        name: applyRename(type.name, namespace),
      };
    case "Optional":
      return {
        type: "Optional",
        wrapped: updateTypeReferences(type.wrapped, namespace),
      };
    case "Array":
      return {
        type: "Array",
        element: updateTypeReferences(type.element, namespace),
      };
    case "Dictionary":
      return {
        type: "Dictionary",
        key: type.key,
        value: updateTypeReferences(type.value, namespace),
      };
    default:
      return type;
  }
};

export const resolveNamingCollisions = (sdk: SwiftSDK): SwiftSDK => {
  // First, detect all collisions
  const nameToNamespaces: Record<string, string[]> = {};

  for (const namespaceName in sdk.namespaces) {
    const namespace = sdk.namespaces[namespaceName];
    for (const definition of namespace.definitions) {
      if (!nameToNamespaces[definition.name]) {
        nameToNamespaces[definition.name] = [];
      }
      nameToNamespaces[definition.name].push(namespaceName);
    }
  }

  const newSdk: SwiftSDK = {
    namespaces: {},
  };

  for (const namespaceName in sdk.namespaces) {
    newSdk.namespaces[namespaceName] = {
      resourceClients: [],
      definitions: [],
    };
  }

  for (const namespaceName in sdk.namespaces) {
    const namespace = sdk.namespaces[namespaceName];
    const namespaceEnum = namespaceName === "empathicVoice" ? "empathicVoice" : "tts";

    for (const definition of namespace.definitions) {
      let newDef: SwiftDefinition;
      const newName = applyRename(definition.name, namespaceEnum);

      switch (definition.type) {
        case "enum": {
          newDef = {
            ...definition,
            name: newName,
          };
          break
        } case "struct": {
          // Update property types to use renamed references
          const newProperties = definition.properties.map((prop) => ({
            ...prop,
            type: updateTypeReferences(prop.type, namespaceEnum),
          }));

          newDef = {
            ...definition,
            name: newName,
            properties: newProperties,
          };
          break;
        } case "discriminatedUnion": {
          // Update case types to use renamed references
          const newCases = definition.cases.map((c) => ({
            ...c,
            type: updateTypeReferences(c.type, namespaceEnum),
          }));

          newDef = {
            ...definition,
            name: newName,
            cases: newCases,
          };
          break;
        }
        case "undiscriminatedUnion": {
          const newVariants = definition.variants.map((v) => (updateTypeReferences(v, namespaceEnum)));
          newDef = {
            ...definition,
            name: newName,
            variants: newVariants,
          };
          break;
        } 
        case "class": {
          newDef = {
            ...definition,
            properties: definition.properties.map((prop) => ({
              ...prop,
              type: updateTypeReferences(prop.type, namespaceEnum),
            })),
          }
          break
        }
        case "typeAlias":
          newDef = {
            ...definition,
            underlyingType: updateTypeReferences(definition.underlyingType, namespaceEnum),
          };
          break;
        case "commentedOut":
          newDef = definition
          break;
        case "dictionaryWithAccessors":
          newDef = {
            ...definition,
            properties: definition.properties.map((prop) => ({
              ...prop,
              type: updateTypeReferences(prop.type, namespaceEnum),
            })),
          };
          break;
        default: {
          return exhaustive(definition)
        }
      }

      newSdk.namespaces[namespaceName].definitions.push(newDef);
    }

    // Handle resource clients - update references in methods
    for (const resourceClient of namespace.resourceClients) {
      const updatedMethods = resourceClient.methods.map((method) => {
        // Update parameter types
        const newParams = method.parameters.map((param) => ({
          ...param,
          type: updateTypeReferences(param.type, namespaceEnum),
        }));

        // Update return type
        const newReturnType = updateTypeReferences(
          method.returnType,
          namespaceEnum,
        );

        return {
          ...method,
          parameters: newParams,
          returnType: newReturnType,
        };
      });

      newSdk.namespaces[namespaceName].resourceClients.push({
        name: resourceClient.name,
        methods: updatedMethods,
      });
    }
  }

  return newSdk;
};

export const detectNamingCollisions = (sdk: SwiftSDK) => {
  const allNames = new Set<string>();
  for (const namespaceName in sdk.namespaces) {
    const namespace = sdk.namespaces[namespaceName];
    for (const definition of namespace.definitions) {
      if (allNames.has(definition.name)) {
        // Naming collision detected
      }
      allNames.add(definition.name);
    }
  }
}; 
