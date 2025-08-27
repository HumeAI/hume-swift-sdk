import { $ } from "bun";
import { camelCase } from "change-case";
import type { Direction } from "./directions";
import { readFile, writeFile } from "fs/promises";
import { readFileSync } from "fs";

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

// Type for storing parameter orderings
export type Orderings = {
  [name: string]: string[];
};

export class SwiftRenderer {
  private orderings: Orderings;
  private discrepancies: {
    missing: Orderings;
    extra: Orderings;
  }
  public fixedOrderings: Orderings

  constructor(orderings: Orderings) {
    this.orderings = orderings;
    this.discrepancies = {missing: {}, extra: {}};
    this.fixedOrderings = {};
  }

  public checkOrderingDiscrepancies(path: string): void {
    let hadDiscrepancy = false;
    for (const [name, missing] of Object.entries(this.discrepancies.missing)) {
      if (missing.length === 0) continue;
      hadDiscrepancy = true;
      console.warn(`${path} is missing parameters for ${name}": ${missing.join(", ")}`);
    }
    for (const [name, extra] of Object.entries(this.discrepancies.extra)) {
      if (extra.length === 0) continue;
      hadDiscrepancy = true;
      console.warn(`${path} has extra parameters for ${name}": ${extra.join(", ")}`);
    }
    if (hadDiscrepancy) {
      throw new Error(
        `Discrepancies found in parameter orderings for ${path}. See console output for details.`,
      );
    }
  }

  // Public API methods
  public renderSDKMethod(method: SDKMethod): string {
    const methodName = method.name;

    // Use the original parameter order (no need to stabilize for single-parameter methods)
    const stableParameters = method.parameters;

    // Add default parameters for timeout and retries
    const isStreaming =
      methodName.includes("Streaming") || methodName.includes("Stream");
    const timeoutDefault = isStreaming ? "300" : "120";

    const defaultParams = [
      ...stableParameters.map(({ name, type, defaultValue }) => {
        if (!defaultValue) {
          return `${name}: ${this.renderSwiftType(type)}`;
        }
        return `${name}: ${this.renderSwiftType(type)} = ${defaultValue}`;
      }),
      `timeoutDuration: TimeInterval = ${timeoutDefault}`,
      "maxRetries: Int = 0",
    ];

    const renderedParams = this.formatParameters(defaultParams);

    // Determine if this is a streaming method
    const isDataReturn = method.returnType.type === "Data";

    if (isStreaming) {
      // For streaming methods, return AsyncThrowingStream
      const streamType = isDataReturn
        ? "Data"
        : this.renderSwiftType(method.returnType);
      const endpointMethodName = methodName.replace("Streaming", "Stream");
      return `
  public func ${methodName}(
    ${renderedParams}
  ) -> AsyncThrowingStream<${streamType}, Error> {
    return networkClient.stream(
      Endpoint.${endpointMethodName}(
        ${stableParameters.map((p) => `${p.name}: ${p.name}`).join(", ")},
        timeoutDuration: timeoutDuration,
        maxRetries: maxRetries)
    )
  }`;
    } else {
      // For regular methods, use networkClient.send
      return `
  public func ${methodName}(
    ${renderedParams}
  ) async throws -> ${this.renderSwiftType(method.returnType)} {
    return try await networkClient.send(
      Endpoint.${methodName}(
        ${stableParameters.map((p) => `${p.name}: ${p.name}`).join(", ")},
        timeoutDuration: timeoutDuration,
        maxRetries: maxRetries)
    )
  }`;
    }
  }

  public renderNamespaceClient(
    namespaceName: string,
    resourceNames: string[],
    basePath: string,
    targetModule: "Hume" | "HumeServer" = "Hume",
  ): File {
    // Capitalize the namespace name for the class name
    const className = namespaceName.toUpperCase() + "Client";

    // Use uppercase directory names for TTS and proper-case for EmpathicVoice
    const directoryName = namespaceName === "tts" ? "TTS" : "EmpathicVoice";
    
    // Debug logging
    console.log(`Namespace client: namespaceName="${namespaceName}", directoryName="${directoryName}"`);

    const targetRoot = targetModule === "Hume" ? "Hume" : "HumeServer";
    return {
      path: `${basePath}/Sources/${targetRoot}/API/${directoryName}/Client/${directoryName}Client.swift`,
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
  }

  public renderResourceClient(
    namespaceName: string,
    resourceName: string,
    methods: SDKMethod[],
    basePath: string,
    targetModule: "Hume" | "HumeServer" = "Hume",
  ): File {
    // Generate endpoint extensions
    const endpointExtensions = methods
      .map((method) => {
        const methodName = method.name;
        const isStreaming =
          methodName.includes("Streaming") || methodName.includes("Stream");
        const isDataReturn = method.returnType.type === "Data";
        const responseType = isDataReturn
          ? "Data"
          : this.renderSwiftType(method.returnType);

        // Use the original parameter order for endpoints
        const stableParameters = method.parameters;

        // For streaming methods, use the shorter name without "Streaming" suffix
        const endpointMethodName = isStreaming
          ? methodName.replace("Streaming", "Stream")
          : methodName;

        if (isStreaming) {
          const endpointParams = [
            ...stableParameters.map(
              (p) => `${p.name}: ${this.renderSwiftType(p.type)}`,
            ),
            "timeoutDuration: TimeInterval",
            "maxRetries: Int",
          ];

          return `
extension Endpoint where Response == ${responseType} {
  fileprivate static func ${endpointMethodName}(
    ${this.formatParameters(endpointParams)}
  ) -> Endpoint<${responseType}> {
    return Endpoint(
      path: "${method.path}",
      method: .${method.verb},
      headers: ["Content-Type": "application/json"],
      body: ${stableParameters.find((p) => p.in === "body")?.name || "nil"},
      cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
      timeoutDuration: timeoutDuration,
      maxRetries: maxRetries
    )
  }
}`;
        } else {
          const endpointParams = [
            ...stableParameters.map(
              (p) => `${p.name}: ${this.renderSwiftType(p.type)}`,
            ),
            "timeoutDuration: TimeInterval",
            "maxRetries: Int",
          ];

          return `
extension Endpoint where Response == ${responseType} {
  fileprivate static func ${endpointMethodName}(
    ${this.formatParameters(endpointParams)}
  ) -> Endpoint<${responseType}> {
    Endpoint(
      path: "${method.path}",
      method: .${method.verb},
      headers: ["Content-Type": "application/json"],
      body: ${stableParameters.find((p) => p.in === "body")?.name || "nil"},
      cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
      timeoutDuration: timeoutDuration,
      maxRetries: maxRetries)
  }
}`;
        }
      })
      .join("\n");

    // Use uppercase directory names for TTS and proper-case for EmpathicVoice
    const directoryName = namespaceName === "tts" ? "TTS" : "EmpathicVoice";
    const targetRoot = targetModule === "Hume" ? "Hume" : "HumeServer";

    return {
      path: `${basePath}/Sources/${targetRoot}/API/${directoryName}/Resources/${resourceName}/${resourceName}.swift`,
      content: `
    import Foundation
    
    public class ${resourceName} {
        
        private let networkClient: NetworkClient
        
        init(networkClient: NetworkClient) {
            self.networkClient = networkClient
        }
        ${methods.map((method) => this.renderSDKMethod(method)).join("\n")}
    }

// MARK: - Endpoint Definitions${endpointExtensions}
`,
    };
  }

  public renderSwiftDefinition(
    namespaceName: string,
    def: SwiftDefinition,
    basePath: string,
    targetModule: "Hume" | "HumeServer" = "Hume",
  ): File {
    // Use uppercase directory names for TTS and proper-case for EmpathicVoice
    const directoryName = namespaceName === "tts" ? "TTS" : "EmpathicVoice";
    const targetRoot = targetModule === "Hume" ? "Hume" : "HumeServer";
    const path = `${basePath}/Sources/${targetRoot}/API/${directoryName}/Models/${def.name}.swift`;
    if (def.type === "enum") {
      return {
        path,
        content: this.renderSwiftEnum(def),
      };
    }
    if (def.type === "struct") {
      return {
        path,
        content: this.renderSwiftStruct(def),
      };
    }
    if (def.type === "discriminatedUnion") {
      return {
        path,
        content: this.renderSwiftDiscriminatedUnion(def),
      };
    }
    if (def.type === "typeAlias") {
      const content = `public typealias ${def.name} = ${this.renderSwiftType(def.underlyingType)}`;
      return {
        path,
        content,
      };
    }
    if (def.type === "class") {
      return {
        path,
        content: this.renderSwiftClass(def),
      };
    }
    if (def.type === "dictionaryWithAccessors") {
      return {
        path,
        content: this.renderSwiftDictionaryWithAccessors(def),
      };
    }
    if (def.type === "commentedOut") {
      return {
        path,
        content: this.renderSwiftCommentedOutDefinition(def),
      };
    }
    if (def.type === "undiscriminatedUnion") {
      return {
        path,
        content: this.renderSwiftUndiscriminatedUnion(def),
      };
    }
    throw new Error(`Unhandled Swift definition type: ${(def as any).type}`);
  }

  public renderServerHumeClientExtension(
    namespaceName: string,
    resourceName: string,
    basePath: string,
  ): File {
    return {
      path: `${basePath}/Sources/HumeServer/Extensions/HumeClient+${resourceName}.swift`,
      content: `
import Hume

#if HUME_SERVER
extension HumeClient {
  public var ${camelCase(resourceName)}: ${resourceName} {
    return ${resourceName}(networkClient: self.serverNetworkClient)
  }
}
#endif
`,
    };
  }

  public async swiftFormat(input: string): Promise<string> {
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
  }

  private stabilize(methodName: string, currentOrder: string[]): string[] {
    const recordedOrder = this.orderings[methodName] || [];
    const missing = currentOrder.filter(x => !recordedOrder.includes(x));
    const extra = recordedOrder.filter(x => !currentOrder.includes(x));
    this.discrepancies.missing[methodName] = missing;
    this.discrepancies.extra[methodName] = extra;
    const ret = [...recordedOrder.filter(x => !extra.includes(x)), ...missing];
    this.fixedOrderings[methodName] = ret;
    return ret;
  }

  private hasTodo(type: SwiftType): boolean {
    let result = false;
    this.walkSwiftType(type, (t) => {
      if (t.type === "TODO") {
        result = true;
      }
    });
    return result;
  }

  private walkSwiftType(type: SwiftType, f: (type: SwiftType) => void) {
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
  }

  private renderSwiftType(type: SwiftType): string {
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
        return `${this.renderSwiftType(type.wrapped)}?`;
      case "Array":
        return `[${this.renderSwiftType(type.element)}]`;
      case "Reference":
        return type.name;
      case "Dictionary":
        return `[String: ${this.renderSwiftType(type.value)}]`;
      case "void":
        return "Void";
      case "Data":
        return "Data";
      case "TODO":
        return "TODO";
    }
  }

  private renderSwiftEnum(def: SwiftEnum): string {
    return `
    public enum ${def.name}: String, Codable {
      ${def.members.map(([name, value]) => `case ${name} = "${value}"`).join("\n")}
    }
    `;
  }

  private renderSwiftDiscriminatedUnion(
    def: SwiftDiscriminatedUnion,
  ): string {
    // Each case becomes an enum case with an associated value.
    const cases = def.cases
      .map(({ caseName, type }) => `case ${caseName}(${this.renderSwiftType(type)})`)
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
            return `case "${value}": self = .${caseName}(try ${this.renderSwiftType(caseType!)}(from: decoder))`;
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
              `case "${caseName}": self = .${caseName}(try ${this.renderSwiftType(type)}(from: decoder))`,
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
  }

  private renderSwiftStruct(struct: SwiftStruct) {
    // Separate commented-out properties from regular properties
    const commentedOutProperties = struct.properties.filter(
      (p) => p.isCommentedOut,
    );
    const regularProperties = struct.properties.filter(
      (p) => !p.isCommentedOut && !this.hasTodo(p.type),
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

    // Stabilize the property order for the init method
    const propertyNames = settableProperties.map(p => p.name);
    const stablePropertyNames = this.stabilize(`${struct.name}.init`, propertyNames);
    
    // Reorder properties according to stable order
    const stableSettableProperties = stablePropertyNames.map(name => 
      settableProperties.find(p => p.name === name)!
    );

    const initParameters = this.formatParameters(
      stableSettableProperties.map((prop) => {
        const typeString = this.renderSwiftType(prop.type);
        return `${prop.name}: ${typeString}`;
      }),
    );

    const initAssignments = stableSettableProperties
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
      .map((prop) => `  public let ${prop.name}: ${this.renderSwiftType(prop.type)}`)
      .join("\n");

    // Render commented-out properties
    const commentedOutPropertyLines = commentedOutProperties
      .map(
        (prop) =>
          `  // TODO: ${prop.name}: ${this.renderSwiftType(prop.type)} - ${prop.type.type === "TODO" ? prop.type.message : "unsupported type"}`,
      )
      .join("\n");

    const allPropertyLines = [regularPropertyLines, commentedOutPropertyLines]
      .filter(Boolean)
      .join("\n");

    return `public struct ${struct.name}: Codable, Hashable {
    ${allPropertyLines}${initConstructor}
  }`;
  }

  private renderSwiftClass(classDef: SwiftClass) {
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
  }

  private renderSwiftDictionaryWithAccessors(
    dictAccessors: SwiftDictionaryWithAccessors,
  ) {
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
  }

  private renderSwiftCommentedOutDefinition(
    def: SwiftCommentedOutDefinition,
  ): string {
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
  }

  private renderSwiftUndiscriminatedUnion(
    def: SwiftUndiscriminatedUnion,
  ): string {
    // Generate case names based on the variant types
    const cases = def.variants
      .map((variant, index) => {
        const variantType = this.renderSwiftType(variant);
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
        const variantType = this.renderSwiftType(variant);
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
  }

  // Helper function to format parameters with one per line when there are multiple
  private formatParameters(params: string[]): string {
    if (params.length <= 1) {
      return params.join(", ");
    }
    return params.join(",\n    ");
  }
}
