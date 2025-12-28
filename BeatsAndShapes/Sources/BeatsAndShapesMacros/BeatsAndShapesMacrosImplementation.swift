import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder

/// Implementation of custom macros for Beats & Shapes

public struct ObservableMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        
        // Generate @Published properties and ObservableObject conformance
        let className = declaration.as(ClassDeclSyntax.self)?.name.text ?? "Unknown"
        
        let observableObjectExtension = ExtensionDeclSyntax(
            modifiers: [
                .init(name: .identifier("public"))
            ],
            extendedType: SimpleTypeIdentifierSyntax(
                name: .identifier(className),
                genericArgumentClause: nil
            ),
            inheritanceClause: InheritanceClauseSyntax {
                InheritedTypeListSyntax {
                    InheritedTypeSyntax(
                        type: SimpleTypeIdentifierSyntax(
                            name: .identifier("ObservableObject")
                        )
                    )
                }
            },
            members: MemberBlockSyntax {
                MemberBlockItemListSyntax {
                    // Add publisher properties for each stored property
                    if let classDecl = declaration.as(ClassDeclSyntax.self) {
                        for member in classDecl.memberBlock.members {
                            if let varDecl = member.decl.as(VariableDeclSyntax.self),
                               let binding = varDecl.bindings.first,
                               let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier {
                                
                                let publisherName = "\(identifier.text)$publisher"
                                
                                MemberBlockItemSyntax(
                                    decl: VariableDeclSyntax(
                                        modifiers: [
                                            .init(name: .identifier("public"))
                                        ],
                                        bindingSpecifier: .keyword(.var),
                                        bindings: PatternBindingListSyntax {
                                            PatternBindingSyntax(
                                                pattern: IdentifierPatternSyntax(
                                                    identifier: .identifier(publisherName)
                                                ),
                                                typeAnnotation: nil,
                                                initializer: InitializerClauseSyntax(
                                                    equal: .equalToken(),
                                                    value: FunctionCallExprSyntax(
                                                        calledExpression: MemberAccessExprSyntax(
                                                            base: IdentifierExprSyntax(identifier: .identifier("Published")),
                                                            period: .periodToken(),
                                                            name: .identifier("wrappedValue")
                                                        ),
                                                        leftParen: .leftParenToken(),
                                                        arguments: [],
                                                        rightParen: .rightParenToken()
                                                    )
                                                ),
                                                accessorBlock: nil,
                                                trailingComma: nil
                                            )
                                        }
                                    )
                                )
                            }
                        }
                    }
                }
            }
        )
        
        return [DeclSyntax(observableObjectExtension)]
    }
}

public struct DependencyMacro: AccessorMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        
        guard let varDecl = declaration.as(VariableDeclSyntax.self),
              let identifier = varDecl.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier else {
            return []
        }
        
        let typeName = node.arguments?.first?.expression.as(MemberAccessExprSyntax.self)?.name.text ?? "Any"
        
        let getter = AccessorDeclSyntax(
            accessorSpecifier: .keyword(.get),
            parameterClause: nil,
            asyncKeyword: nil,
            effectSpecifiers: nil,
            body: CodeBlockSyntax {
                ReturnStmtSyntax(
                    returnKeyword: .keyword(.return),
                    expression: FunctionCallExprSyntax(
                        calledExpression: MemberAccessExprSyntax(
                            base: IdentifierExprSyntax(identifier: .identifier("DependencyContainer")),
                            period: .periodToken(),
                            name: .identifier("shared")
                        ),
                        leftParen: .leftParenToken(),
                        arguments: [
                            LabeledExprSyntax(
                                label: nil,
                                colon: nil,
                                expression: MemberAccessExprSyntax(
                                    base: MemberAccessExprSyntax(
                                        base: IdentifierExprSyntax(identifier: .identifier("DependencyContainer")),
                                        period: .periodToken(),
                                        name: .identifier("shared")
                                    ),
                                    period: .periodToken(),
                                    name: identifier
                                )
                            )
                        ],
                        rightParen: .rightParenToken()
                    )
                )
            }
        )
        
        return [getter]
    }
}

public struct GameComponentMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        
        guard let classDecl = declaration.as(ClassDeclSyntax.self),
              let className = classDecl.name.text else {
            return []
        }
        
        // Add component ID and lifecycle methods
        let componentID = VariableDeclSyntax(
            modifiers: [
                .init(name: .keyword(.public)),
                .init(name: .keyword(.static))
            ],
            bindingSpecifier: .keyword(.let),
            bindings: PatternBindingListSyntax {
                PatternBindingSyntax(
                    pattern: IdentifierPatternSyntax(
                        identifier: .identifier("componentID")
                    ),
                    typeAnnotation: TypeAnnotationSyntax(
                        colon: .colonToken(),
                        type: SimpleTypeIdentifierSyntax(
                            name: .identifier("UUID")
                        )
                    ),
                    initializer: InitializerClauseSyntax(
                        equal: .equalToken(),
                        value: FunctionCallExprSyntax(
                            calledExpression: MemberAccessExprSyntax(
                                base: IdentifierExprSyntax(identifier: .identifier("UUID")),
                                period: .periodToken(),
                                name: .identifier("init")
                            ),
                            leftParen: .leftParenToken(),
                            arguments: [],
                            rightParen: .rightParenToken()
                        )
                    ),
                    accessorBlock: nil,
                    trailingComma: nil
                )
            }
        )
        
        let awakeMethod = FunctionDeclSyntax(
            modifiers: [
                .init(name: .keyword(.public))
            ],
            funcKeyword: .keyword(.func),
            name: .identifier("awake"),
            genericParameterClause: nil,
            parameterClause: FunctionParameterClauseSyntax {
                FunctionParameterListSyntax {
                    FunctionParameterSyntax(
                        firstName: .wildcardToken(),
                        type: SimpleTypeIdentifierSyntax(name: .identifier("Void"))
                    )
                }
            },
            asyncKeyword: nil,
            effectSpecifiers: nil,
            returnClause: nil,
            body: CodeBlockSyntax(statements: [])
        )
        
        let sleepMethod = FunctionDeclSyntax(
            modifiers: [
                .init(name: .keyword(.public))
            ],
            funcKeyword: .keyword(.func),
            name: .identifier("sleep"),
            genericParameterClause: nil,
            parameterClause: FunctionParameterClauseSyntax {
                FunctionParameterListSyntax {
                    FunctionParameterSyntax(
                        firstName: .wildcardToken(),
                        type: SimpleTypeIdentifierSyntax(name: .identifier("Void"))
                    )
                }
            },
            asyncKeyword: nil,
            effectSpecifiers: nil,
            returnClause: nil,
            body: CodeBlockSyntax(statements: [])
        )
        
        return [DeclSyntax(componentID), DeclSyntax(awakeMethod), DeclSyntax(sleepMethod)]
    }
}

public struct SingletonMacro: AccessorMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        
        guard let varDecl = declaration.as(VariableDeclSyntax.self) else {
            return []
        }
        
        let typeName = varDecl.bindings.first?.typeAnnotation?.type.description ?? "Any"
        
        let getter = AccessorDeclSyntax(
            accessorSpecifier: .keyword(.get),
            parameterClause: nil,
            asyncKeyword: nil,
            effectSpecifiers: nil,
            body: CodeBlockSyntax {
                // Lazy initialization
                StaticLetDeclSyntax(
                    modifiers: [],
                    name: TokenSyntax(.identifier("instance"), trailingTrivia: .spaces(1)),
                    initializer: InitializerClauseSyntax(
                        equal: .equalToken(),
                        value: FunctionCallExprSyntax(
                            calledExpression: typeName,
                            leftParen: .leftParenToken(),
                            arguments: [],
                            rightParen: .rightParenToken()
                        )
                    )
                )
                
                ReturnStmtSyntax(
                    returnKeyword: .keyword(.return),
                    expression: IdentifierExprSyntax(identifier: .identifier("instance"))
                )
            }
        )
        
        return [getter]
    }
}

public struct PerformanceTraceMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self),
              let funcName = funcDecl.name.text else {
            return []
        }
        
        let category = node.arguments?.first?.expression.as(StringLiteralExprSyntax.self)?.representedValue ?? "default"
        
        let tracedFunction = funcDecl.with(
            \.body,
            CodeBlockSyntax {
                // Insert performance measurement
                FunctionCallExprSyntax(
                    calledExpression: MemberAccessExprSyntax(
                        base: IdentifierExprSyntax(identifier: .identifier("Logger")),
                        period: .periodToken(),
                        name: .identifier("shared")
                    ),
                    leftParen: .leftParenToken(),
                    arguments: [
                        LabeledExprSyntax(
                            expression: StringLiteralExprSyntax(content: "Starting \(funcName)")
                        )
                    ],
                    rightParen: .rightParenToken()
                )
                
                // Original function body
                funcDecl.body?.statements ?? []
                
                // End performance measurement
                FunctionCallExprSyntax(
                    calledExpression: MemberAccessExprSyntax(
                        base: IdentifierExprSyntax(identifier: .identifier("Logger")),
                        period: .periodToken(),
                        name: .identifier("shared")
                    ),
                    leftParen: .leftParenToken(),
                    arguments: [
                        LabeledExprSyntax(
                            expression: StringLiteralExprSyntax(content: "Completed \(funcName)")
                        )
                    ],
                    rightParen: .rightParenToken()
                )
            }
        )
        
        return [DeclSyntax(tracedFunction)]
    }
}

public struct SafeAccessMacro: AccessorMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        
        guard let varDecl = declaration.as(VariableDeclSyntax.self),
              let defaultValue = node.arguments?.first?.expression else {
            return []
        }
        
        let getter = AccessorDeclSyntax(
            accessorSpecifier: .keyword(.get),
            parameterClause: nil,
            asyncKeyword: nil,
            effectSpecifiers: nil,
            body: CodeBlockSyntax {
                IfStmtSyntax(
                    ifKeyword: .keyword(.if),
                    conditions: ConditionElementListSyntax {
                        ConditionElementSyntax(
                            condition: OptionalBindingConditionSyntax(
                                bindingSpecifier: .keyword(.let),
                                pattern: IdentifierPatternSyntax(
                                    identifier: .identifier("value")
                                ),
                                initializer: InitializerClauseSyntax(
                                    equal: .equalToken(),
                                    value: MemberAccessExprSyntax(
                                        base: SelfExprSyntax(keyword: .keyword(.self)),
                                        period: .periodToken(),
                                        name: IdentifierExprSyntax(identifier: .identifier("_value"))
                                    )
                                )
                            )
                        )
                    },
                    body: CodeBlockSyntax {
                        ReturnStmtSyntax(
                            returnKeyword: .keyword(.return),
                            expression: IdentifierExprSyntax(identifier: .identifier("value"))
                        )
                    }
                )
                
                ReturnStmtSyntax(
                    returnKeyword: .keyword(.return),
                    expression: defaultValue
                )
            }
        )
        
        let setter = AccessorDeclSyntax(
            accessorSpecifier: .keyword(.set),
            parameterClause: FunctionParameterClauseSyntax {
                FunctionParameterListSyntax {
                    FunctionParameterSyntax(
                        firstName: .identifier("newValue")
                    )
                }
            },
            asyncKeyword: nil,
            effectSpecifiers: nil,
            body: CodeBlockSyntax {
                AssignmentExprSyntax(
                    left: MemberAccessExprSyntax(
                        base: SelfExprSyntax(keyword: .keyword(.self)),
                        period: .periodToken(),
                        name: IdentifierExprSyntax(identifier: .identifier("_value"))
                    ),
                    assignOperator: .equalToken(),
                    value: IdentifierExprSyntax(identifier: .identifier("newValue"))
                )
            }
        )
        
        return [getter, setter]
    }
}