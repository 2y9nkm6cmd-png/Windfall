//
//  WindfallCoreAI.swift
//
//  Nothing of its own. Where Apple's language model code was built (a
//  Mac, for now), this passes it straight on, so Windfall can use
//  `CoreAILanguageModel` by importing either module. Everywhere else
//  this file is empty and the app carries on without it.
//

#if canImport(CoreAILanguageModels)
@_exported import CoreAILanguageModels
#endif
