import SwiftSyntax
import SwiftSyntaxMacros

/// Swift 5.9 macros for reducing boilerplate in Beats & Shapes (2025 standards)

// MARK: - Observable Macro
@attached(peer, names: arbitrary)
public macro Observable() = #externalMacro(module: "BeatsAndShapesMacros", type: "ObservableMacro")

// MARK: - Dependency Macro
@attached(accessor)
public macro Dependency<T>(_ type: T.Type) = #externalMacro(module: "BeatsAndShapesMacros", type: "DependencyMacro")

// MARK: - GameComponent Macro
@attached(member, names: arbitrary)
public macro GameComponent() = #externalMacro(module: "BeatsAndShapesMacros", type: "GameComponentMacro")

// MARK: - Singleton Macro
@attached(accessor)
public macro Singleton() = #externalMacro(module: "BeatsAndShapesMacros", type: "SingletonMacro")

// MARK: - PerformanceTrace Macro
@attached(peer, names: arbitrary)
public macro PerformanceTrace(_ category: String = "default") = #externalMacro(module: "BeatsAndShapesMacros", type: "PerformanceTraceMacro")

// MARK: - SafeAccess Macro
@attached(accessor)
public macro SafeAccess<T>(_ defaultValue: T) = #externalMacro(module: "BeatsAndShapesMacros", type: "SafeAccessMacro")