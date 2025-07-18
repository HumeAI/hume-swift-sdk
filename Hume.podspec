Pod::Spec.new do |spec|
  spec.name         = "Hume"
  spec.version      = "0.0.1-beta0"
  spec.summary      = "Hume AI Swift SDK"
  spec.description  = <<-DESC
                      Integrate Hume APIs directly into your Swift application.
                      DESC

  spec.homepage     = "https://github.com/HumeAI/hume-swift-sdk"
  spec.license      = { :type => "MIT", :file => "LICENSE" }
  spec.author       = { "Hume AI" => "support@hume.ai" }

  spec.source       = { :git => "https://github.com/HumeAI/hume-swift-sdk.git", :tag => "#{spec.version}" }

  spec.ios.deployment_target = "16.0"

  spec.swift_version = "5.9"

  spec.source_files = "Sources/Hume/**/*.swift"

  spec.frameworks = "Foundation", "AVFoundation", "Combine"

  spec.requires_arc = true
end
