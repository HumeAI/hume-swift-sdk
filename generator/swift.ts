import { $ } from "bun";
import { camelCase } from "change-case";
import type { Direction } from "./directions";

export type SwiftType =
  | { type: "Int" }
  | { type: "Float" }
  | { type: "Double" }
  | { type: "Bool" }
  | { type: "String" }
  | { type: "Optional"; wrapped: SwiftType }
  | { type: "Array"; element: SwiftType }
  | { type: "Reference"; name: string }
  | { type: "Dictionary"; key: SwiftType; value: SwiftType }
  | { type: "void" }
  | { type: "Data" }
  | { type: "TODO"; message: string };

export type SwiftStruct = {
  type: "struct";
  name: string;
  properties: Array<{
    name: string;
    type: SwiftType;
    docstring?: string;
    constValue?: string;
    isCommentedOut?: boolean;
  }>;
  direction: Direction;
};

export type SwiftClass = {
  type: "class";
  name: string;
  properties: Array<{
    name: string;
    type: SwiftType;
    keyName: string;
    docstring?: string;
  }>;
  direction: Direction;
};

export type SwiftDictionaryWithAccessors = {
  type: "dictionaryWithAccessors";
  name: string;
  properties: Array<{
    name: string;
    type: SwiftType;
    keyName: string;
    docstring?: string;
  }>;
  direction: Direction;
};

export type SwiftEnum = {
  type: "enum";
  name: string;
  members: Array<[string, string]>;
  direction: Direction;
};

export type SwiftDiscriminatedUnion = {
  type: "discriminatedUnion";
  name: string;
  discriminator: string;
  cases: Array<{
    caseName: string;
    type: SwiftType;
    discriminatorValue?: string;
  }>;
  discriminatorValues?: Array<{ caseName: string; value: string }>;
  direction: Direction;
};

export type SwiftTypeAlias = {
  type: "typeAlias";
  name: string;
  underlyingType: SwiftType;
  direction: Direction;
};

export type SwiftCommentedOutDefinition = {
  type: "commentedOut";
  name: string;
  reason: string;
  direction: Direction;
};

export type SwiftUndiscriminatedUnion = {
  type: "undiscriminatedUnion";
  name: string;
  variants: Array<SwiftType>;
  direction: Direction;
};

export type SwiftDefinition =
  | SwiftStruct
  | SwiftEnum
  | SwiftDiscriminatedUnion
  | SwiftTypeAlias
  | SwiftClass
  | SwiftDictionaryWithAccessors
  | SwiftCommentedOutDefinition
  | SwiftUndiscriminatedUnion;

export type SDKMethodParam = {
  name: string;
  type: SwiftType;
  in: "path" | "query" | "body";
  defaultValue?: string;
};

export type SDKMethod = {
  name: string;
  verb: "get" | "post" | "put" | "patch" | "delete";
  path: string;
  parameters: Array<SDKMethodParam>;
  returnType: SwiftType;
};

export type File = {
  path: string;
  content: string;
};

const walkSwiftType = (type: SwiftType, f: (type: SwiftType) => void) => {
  f(type);
  switch (type.type) {
    case "Int":
    case "Float":
    case "Double":
    case "Bool":
    case "String":
    case "TODO":
      return;
    case "Optional":
      f(type.wrapped);
      return;
    case "Array":
      f(type.element);
      return;
    case "Reference":
      return;
    case "Dictionary":
      f(type.value);
      return;
  }
};

export const hasTodo = (type: SwiftType): boolean => {
  let result = false;
  walkSwiftType(type, (t) => {
    if (t.type === "TODO") {
      result = true;
    }
  });
  return result;
};

export const renderSwiftType = (type: SwiftType): string => {
  switch (type.type) {
    case "Int":
      return "Int";
    case "Float":
      return "Float";
    case "Double":
      return "Double";
    case "Bool":
      return "Bool";
    case "String":
      return "String";
    case "Optional":
      return `${renderSwiftType(type.wrapped)}?`;
    case "Array":
      return `[${renderSwiftType(type.element)}]`;
    case "Reference":
      return type.name;
    case "Dictionary":
      return `[String: ${renderSwiftType(type.value)}]`;
    case "void":
      return "Void";
    case "Data":
      return "Data";
    case "TODO":
      return "TODO";
  }
};

export const renderSwiftEnum = (def: SwiftEnum): string => {
  return `
    public enum ${def.name}: String, Codable {
      ${def.members.map(([name, value]) => `case ${name} = "${value}"`).join("\n")}
    }
    `;
};

export const renderSwiftDiscriminatedUnion = (
  def: SwiftDiscriminatedUnion,
): string => {
  // Each case becomes an enum case with an associated value.
  const cases = def.cases
    .map(({ caseName, type }) => `case ${caseName}(${renderSwiftType(type)})`)
    .join("\n    ");

  // Generate proper decoder using discriminator values if available
  const decoderCode = def.discriminatorValues
    ? `
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .${def.discriminator})
        switch typeValue {
        ${def.discriminatorValues
          .map(({ caseName, value }) => {
            const caseType = def.cases.find(
              (c) => c.caseName === caseName,
            )?.type;
            return `case "${value}": self = .${caseName}(try ${renderSwiftType(caseType!)}(from: decoder))`;
          })
          .join("\n        ")}
        default:
            throw DecodingError.dataCorruptedError(forKey: .${def.discriminator}, in: container, debugDescription: "Unexpected type value: \\(typeValue)")
        }
    }`
    : `
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .${def.discriminator})
        switch typeValue {
        ${def.cases
          .map(
            ({ caseName, type }) =>
              `case "${caseName}": self = .${caseName}(try ${renderSwiftType(type)}(from: decoder))`,
          )
          .join("\n        ")}
        default:
            throw DecodingError.dataCorruptedError(forKey: .${def.discriminator}, in: container, debugDescription: "Unexpected type value: \\(typeValue)")
        }
    }`;

  // Generate proper encoder
  const encoderCode = `
    public func encode(to encoder: Encoder) throws {
        switch self {
        ${def.cases
          .map(
            ({ caseName }) =>
              `case .${caseName}(let value): try value.encode(to: encoder)`,
          )
          .join("\n        ")}
        }
    }`;

  return `
public enum ${def.name}: Codable, Hashable {
    ${cases}
    
    private enum CodingKeys: String, CodingKey {
        case ${def.discriminator}
    }${decoderCode}${encoderCode}
}
`;
};

export const renderSwiftStruct = (struct: SwiftStruct) => {
  // Separate commented-out properties from regular properties
  const commentedOutProperties = struct.properties.filter(
    (p) => p.isCommentedOut,
  );
  const regularProperties = struct.properties.filter(
    (p) => !p.isCommentedOut && !hasTodo(p.type),
  );

  // Only include init for types that can be sent (sent or both)
  const shouldIncludeInit = struct.direction !== "received";

  // Separate constant and settable properties (only for regular properties)
  const constantProperties = regularProperties.filter(
    (p) => p.constValue !== undefined,
  );
  const settableProperties = regularProperties.filter(
    (p) => p.constValue === undefined,
  );

  const initParameters = formatParameters(
    settableProperties.map((prop) => {
      const typeString = renderSwiftType(prop.type);
      return `${prop.name}: ${typeString}`;
    }),
  );

  const initAssignments = settableProperties
    .map((prop) => `    self.${prop.name} = ${prop.name}`)
    .join("\n");

  // Add assignments for constant properties
  const constantAssignments = constantProperties
    .map((prop) => `    self.${prop.name} = "${prop.constValue}"`)
    .join("\n");

  const initConstructor = shouldIncludeInit
    ? `
  
  public init(${initParameters}) {
${initAssignments}${constantAssignments ? "\n" + constantAssignments : ""}
  }`
    : "";

  // Render regular properties
  const regularPropertyLines = regularProperties
    .map((prop) => `  public let ${prop.name}: ${renderSwiftType(prop.type)}`)
    .join("\n");

  // Render commented-out properties
  const commentedOutPropertyLines = commentedOutProperties
    .map(
      (prop) =>
        `  // TODO: ${prop.name}: ${renderSwiftType(prop.type)} - ${prop.type.type === "TODO" ? prop.type.message : "unsupported type"}`,
    )
    .join("\n");

  const allPropertyLines = [regularPropertyLines, commentedOutPropertyLines]
    .filter(Boolean)
    .join("\n");

  return `public struct ${struct.name}: Codable, Hashable {
    ${allPropertyLines}${initConstructor}
  }`;
};

export const renderSwiftClass = (classDef: SwiftClass) => {
  const properties = classDef.properties
    .map((prop) => {
      const docstring = prop.docstring ? `\n  /// ${prop.docstring}` : "";
      return `${docstring}\n  public var ${prop.name}: Double {\n    return self["${prop.keyName}"] ?? 0.0\n  }`;
    })
    .join("\n");

  return `public class ${classDef.name}: Dictionary<String, Double> {
  public override init() {
    super.init()
  }
  
  public override init(dictionaryLiteral elements: (String, Double)...) {
    super.init(dictionaryLiteral: elements)
  }
  
  public override init(minimumCapacity: Int) {
    super.init(minimumCapacity: minimumCapacity)
  }
  
  public override init<S>(_ elements: S) where S : Sequence, S.Element == (String, Double) {
    super.init(elements)
  }
  
  public override init(dictionary: [String : Double]) {
    super.init(dictionary: dictionary)
  }
  
  // Named accessors for emotion scores
${properties}
}`;
};

export const renderSwiftDictionaryWithAccessors = (
  dictAccessors: SwiftDictionaryWithAccessors,
) => {
  const properties = dictAccessors.properties
    .map((prop) => {
      const docstring = prop.docstring ? `\n  /// ${prop.docstring}` : "";
      return `${docstring}\n  public var ${prop.name}: Double {\n    return self["${prop.keyName}"] ?? 0.0\n  }`;
    })
    .join("\n");

  const content =
    `public typealias ${dictAccessors.name} = [String: Double]\n\n` +
    `extension ${dictAccessors.name} {\n` +
    "  // Named accessors for emotion scores\n" +
    properties +
    "\n}";

  return content;
};

export const renderSwiftCommentedOutDefinition = (
  def: SwiftCommentedOutDefinition,
): string => {
  return `// TODO: ${def.name} - ${def.reason}
// This type is not yet supported by the Swift SDK generator.
// 
// Reason: ${def.reason}
// 
// When support is added for this type, this file will be replaced with the actual implementation.
// 
// For now, this file serves as a placeholder to indicate that this type exists in the API
// but is not yet implemented in the Swift SDK.

// TODO: Implement ${def.name}
// TODO: Add support for ${def.reason}
`;
};

export const renderSwiftUndiscriminatedUnion = (
  def: SwiftUndiscriminatedUnion,
): string => {
  // Generate case names based on the variant types
  const cases = def.variants
    .map((variant, index) => {
      const variantType = renderSwiftType(variant);
      // Extract a meaningful case name from the type
      let caseName: string;
      if (variant.type === "Reference") {
        caseName = variant.name.charAt(0).toLowerCase() + variant.name.slice(1);
      } else {
        caseName = `case${index + 1}`;
      }
      return `  case ${caseName}(${variantType})`;
    })
    .join("\n");

  // Generate decoder logic
  const decoderCases = def.variants
    .map((variant, index) => {
      const variantType = renderSwiftType(variant);
      let caseName: string;
      if (variant.type === "Reference") {
        caseName = variant.name.charAt(0).toLowerCase() + variant.name.slice(1);
      } else {
        caseName = `case${index + 1}`;
      }

      if (variant.type === "Reference") {
        return `    if let ${caseName} = try? container.decode(${variantType}.self) {
      self = .${caseName}(${caseName})
    }`;
      } else {
        return `    if let ${caseName} = try? container.decode(${variantType}) {
      self = .${caseName}(${caseName})
    }`;
      }
    })
    .join(" else ");

  return `import Foundation

public enum ${def.name}: Codable, Hashable {
${cases}

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    ${decoderCases} else {
      throw DecodingError.typeMismatch(
        ${def.name}.self,
        DecodingError.Context(
          codingPath: decoder.codingPath,
          debugDescription: "Invalid value for ${def.name}"
        )
      )
    }
  }
}
`;
};

export const renderSwiftDefinition = (
  namespaceName: string,
  def: SwiftDefinition,
  basePath: string,
): File => {
  // Use uppercase directory names for TTS
  const directoryName = namespaceName === "tts" ? "TTS" : namespaceName;
  const path = `${basePath}/Sources/Hume/API/${directoryName}/Models/${def.name}.swift`;
  if (def.type === "enum") {
    return {
      path,
      content: renderSwiftEnum(def),
    };
  }
  if (def.type === "struct") {
    return {
      path,
      content: renderSwiftStruct(def),
    };
  }
  if (def.type === "discriminatedUnion") {
    return {
      path,
      content: renderSwiftDiscriminatedUnion(def),
    };
  }
  if (def.type === "typeAlias") {
    const content = `public typealias ${def.name} = ${renderSwiftType(def.underlyingType)}`;
    return {
      path,
      content,
    };
  }
  if (def.type === "class") {
    return {
      path,
      content: renderSwiftClass(def),
    };
  }
  if (def.type === "dictionaryWithAccessors") {
    return {
      path,
      content: renderSwiftDictionaryWithAccessors(def),
    };
  }
  if (def.type === "commentedOut") {
    return {
      path,
      content: renderSwiftCommentedOutDefinition(def),
    };
  }
  if (def.type === "undiscriminatedUnion") {
    return {
      path,
      content: renderSwiftUndiscriminatedUnion(def),
    };
  }
  throw new Error(`Unhandled Swift definition type: ${(def as any).type}`);
};

// Helper function to format parameters with one per line when there are multiple
const formatParameters = (params: string[]): string => {
  if (params.length <= 1) {
    return params.join(", ");
  }
  return params.join(",\n    ");
};

export const renderSDKMethod = (method: SDKMethod): string => {
  const methodName = method.name;

  // Add default parameters for timeout and retries
  const isStreaming =
    methodName.includes("Streaming") || methodName.includes("Stream");
  const timeoutDefault = isStreaming ? "300" : "120";

  const defaultParams = [
    ...method.parameters.map(({ name, type, defaultValue }) => {
      if (!defaultValue) {
        return `${name}: ${renderSwiftType(type)}`;
      }
      return `${name}: ${renderSwiftType(type)} = ${defaultValue}`;
    }),
    `timeoutDuration: TimeInterval = ${timeoutDefault}`,
    "maxRetries: Int = 0",
  ];

  const renderedParams = formatParameters(defaultParams);

  // Determine if this is a streaming method
  const isDataReturn = method.returnType.type === "Data";

  if (isStreaming) {
    // For streaming methods, return AsyncThrowingStream
    const streamType = isDataReturn
      ? "Data"
      : renderSwiftType(method.returnType);
    const endpointMethodName = methodName.replace("Streaming", "Stream");
    return `
  public func ${methodName}(
    ${renderedParams}
  ) -> AsyncThrowingStream<${streamType}, Error> {
    return networkClient.stream(
      Endpoint.${endpointMethodName}(
        ${method.parameters.map((p) => `${p.name}: ${p.name}`).join(", ")},
        timeoutDuration: timeoutDuration,
        maxRetries: maxRetries)
    )
  }`;
  } else {
    // For regular methods, use networkClient.send
    return `
  public func ${methodName}(
    ${renderedParams}
  ) async throws -> ${renderSwiftType(method.returnType)} {
    return try await networkClient.send(
      Endpoint.${methodName}(
        ${method.parameters.map((p) => `${p.name}: ${p.name}`).join(", ")},
        timeoutDuration: timeoutDuration,
        maxRetries: maxRetries)
    )
  }`;
  }
};

export const renderNamespaceClient = (
  namespaceName: string,
  resourceNames: string[],
  basePath: string,
): File => {
  // Capitalize the namespace name for the class name
  const className = namespaceName.toUpperCase() + "Client";

  // Use uppercase directory names for TTS
  const directoryName = namespaceName === "tts" ? "TTS" : namespaceName;
  
  // Debug logging
  console.log(`Namespace client: namespaceName="${namespaceName}", directoryName="${directoryName}"`);

  return {
    path: `${basePath}/Sources/Hume/API/${directoryName}/Client/${directoryName}Client.swift`,
    content: `
    import Foundation
    
    public class ${className} {
        
        private let networkClient: NetworkClient
        
        init(networkClient: NetworkClient) {
            self.networkClient = networkClient
        }
        ${resourceNames.map((resourceName) => `public lazy var ${camelCase(resourceName)}: ${resourceName} = { ${resourceName}(networkClient: networkClient) }()`).join("\n")}
    }
`,
  };
};

export const renderResourceClient = (
  namespaceName: string,
  resourceName: string,
  methods: SDKMethod[],
  basePath: string,
): File => {
  // Generate endpoint extensions
  const endpointExtensions = methods
    .map((method) => {
      const methodName = method.name;
      const isStreaming =
        methodName.includes("Streaming") || methodName.includes("Stream");
      const isDataReturn = method.returnType.type === "Data";
      const responseType = isDataReturn
        ? "Data"
        : renderSwiftType(method.returnType);

      // For streaming methods, use the shorter name without "Streaming" suffix
      const endpointMethodName = isStreaming
        ? methodName.replace("Streaming", "Stream")
        : methodName;

      if (isStreaming) {
        const endpointParams = [
          ...method.parameters.map(
            (p) => `${p.name}: ${renderSwiftType(p.type)}`,
          ),
          "timeoutDuration: TimeInterval",
          "maxRetries: Int",
        ];

        return `
extension Endpoint where Response == ${responseType} {
  fileprivate static func ${endpointMethodName}(
    ${formatParameters(endpointParams)}
  ) -> Endpoint<${responseType}> {
    return Endpoint(
      path: "${method.path}",
      method: .${method.verb},
      headers: ["Content-Type": "application/json"],
      body: ${method.parameters.find((p) => p.in === "body")?.name || "nil"},
      cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
      timeoutDuration: timeoutDuration,
      maxRetries: maxRetries
    )
  }
}`;
      } else {
        const endpointParams = [
          ...method.parameters.map(
            (p) => `${p.name}: ${renderSwiftType(p.type)}`,
          ),
          "timeoutDuration: TimeInterval",
          "maxRetries: Int",
        ];

        return `
extension Endpoint where Response == ${responseType} {
  fileprivate static func ${endpointMethodName}(
    ${formatParameters(endpointParams)}
  ) -> Endpoint<${responseType}> {
    Endpoint(
      path: "${method.path}",
      method: .${method.verb},
      headers: ["Content-Type": "application/json"],
      body: ${method.parameters.find((p) => p.in === "body")?.name || "nil"},
      cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
      timeoutDuration: timeoutDuration,
      maxRetries: maxRetries)
  }
}`;
      }
    })
    .join("\n");

  // Use uppercase directory names for TTS
  const directoryName = namespaceName === "tts" ? "TTS" : namespaceName;

  return {
    path: `${basePath}/Sources/Hume/API/${directoryName}/Resources/${resourceName}/${resourceName}.swift`,
    content: `
    import Foundation
    
    public class ${resourceName} {
        
        private let networkClient: NetworkClient
        
        init(networkClient: NetworkClient) {
            self.networkClient = networkClient
        }
        ${methods.map((method) => renderSDKMethod(method)).join("\n")}
    }

// MARK: - Endpoint Definitions${endpointExtensions}
`,
  };
};

export const swiftFormat = async (input: string): Promise<string> => {
  const buf = Buffer.from(input);
  try {
    return await $`swift format < ${buf}`.text();
  } catch (e: unknown) {
    const inputNumbered = input
      .split("\n")
      .map((line, i) => `${i + 1}: ${line}`)
      .join("\n");
    const errorOutput = (e as any).stderr.toString();
    throw new Error(
      `Error formatting swift code:\n${inputNumbered}\n${errorOutput}`,
    );
  }
};
