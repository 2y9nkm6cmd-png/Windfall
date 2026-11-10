//
//  EiraMLXLoader.swift
//  Windfall
//
//  Loads a model by name with MLX, as an alternative to Core AI.
//
//  MLX is Apple's open-source machine learning library. Its advantage is
//  choice: thousands of models are already published in its format on
//  Hugging Face and can be downloaded by name, with no conversion step.
//  It runs on the graphics chip and does not use the Neural Engine.
//
//  This whole file only exists in the app if the mlx-swift-lm package
//  has been added to the Xcode project. Without the package the fence
//  below removes it, and choosing an MLX model gives a clear message.
//
//  NOT YET BUILT ON A MAC, and the least certain file in the app. It
//  follows the example in the package's own guide, which uses a macro
//  (the line starting with #) to fill in the downloading code.
//

#if canImport(FoundationModels) && canImport(CoreAI) && canImport(MLXFoundationModels) && canImport(MLXHuggingFace)

import Foundation
import FoundationModels
import HuggingFace
import MLXFoundationModels
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers

@available(iOS 27.0, macOS 27.0, *)
enum EiraMLXLoader {

    /// `modelID` is the model's name on Hugging Face, such as
    /// "mlx-community/Qwen3-4B-4bit". It is downloaded on first use.
    @MainActor
    static func engine(modelID: String, displayName: String, tools: [any Tool]) -> OnDeviceEngine {
        // What the model is allowed to do must be declared. Tool calling
        // is needed for Eira's lookups. Add .reasoning here for a model
        // that shows its thinking.
        let model = #huggingFaceLanguageModel(
            configuration: ModelConfiguration(id: modelID),
            capabilities: [.toolCalling])

        return OnDeviceEngine(
            displayName: displayName,
            makeSession: { LanguageModelSession(model: model, tools: tools, instructions: $0) },
            unloadModel: {})
    }
}

#endif
