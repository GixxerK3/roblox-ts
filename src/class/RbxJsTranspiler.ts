import * as ts from "ts-simple-ast";
import {
	getScriptContext,
	getScriptType,
	isValidLuaIdentifier,
	safeLuaIndex,
	ScriptContext,
	ScriptType,
} from "../utility";
import { Compiler } from "./Compiler";
import { TranspilerError, TranspilerErrorType } from "./errors/TranspilerError";

import { Transpiler, getLuaAddExpression, inheritsFrom, isRbxClassType } from './Transpiler';

export class RbxJsTranspiler extends Transpiler {

	constructor(protected compiler: Compiler) {
		super(compiler)
	}

	protected isSameTypePrimitives(nodeX: ts.Node, nodeY: ts.Node) : boolean {
		return ((ts.TypeGuards.isNumericLiteral(nodeX) && ts.TypeGuards.isNumericLiteral(nodeY)) ||
		(ts.TypeGuards.isStringLiteral(nodeX) && ts.TypeGuards.isStringLiteral(nodeY)) ||
		(ts.TypeGuards.isBooleanLiteral(nodeX) && ts.TypeGuards.isBooleanLiteral(nodeY)));
	}

	protected transpileIfStatement(node: ts.IfStatement) {
		let result = "";
		// const expStr = this.transpileExpression(node.getExpression());
		const conditionExp = node.getExpression();
		// const expStr = this.transpileExpression(conditionExp);
		const booleanExpStr = this.transpileBooleanExpression(conditionExp);
		result += this.indent + `if ${booleanExpStr} then\n`;
		this.pushIndent();
		result += this.transpileStatement(node.getThenStatement());
		this.popIndent();
		let elseStatement = node.getElseStatement();
		while (elseStatement && ts.TypeGuards.isIfStatement(elseStatement)) {
			const elseIfExpression = this.transpileExpression(elseStatement.getExpression());
			result += this.indent + `elseif ${elseIfExpression} then\n`;
			this.pushIndent();
			result += this.transpileStatement(elseStatement.getThenStatement());
			this.popIndent();
			elseStatement = elseStatement.getElseStatement();
		}
		if (elseStatement) {
			result += this.indent + "else\n";
			this.pushIndent();
			result += this.transpileStatement(elseStatement);
			this.popIndent();
		}
		result += this.indent + `end;\n`;
		return result;
	}

	protected transpileBooleanExpression(node: ts.Expression): string {
		let result = this.transpileExpression(node);

		let a = node.getType();
		let b = a.getSymbol();

		if (ts.TypeGuards.isNumericLiteral(node)) {
			result += " ~= 0";
			//result = `RbxJs.toBoolean(${result})`;
		}
		else if (ts.TypeGuards.isIdentifier(node)) {
			result = `RbxJs.toBoolean(${result})`;

		}

		return result;
	}

	protected transpileBinaryExpression(node: ts.BinaryExpression) {
		const opToken = node.getOperatorToken();
		const opKind = opToken.getKind();

		if (opKind === ts.SyntaxKind.CaretToken) {
			throw new TranspilerError(
				"Binary XOR operator ( `^` ) is not supported! Did you mean to use `**`?",
				node,
				TranspilerErrorType.NoXOROperator,
			);
		} else if (opKind === ts.SyntaxKind.CaretEqualsToken) {
			throw new TranspilerError(
				"Binary XOR operator ( `^` ) is not supported! Did you mean to use `**=`?",
				node,
				TranspilerErrorType.NoXOROperator,
			);
		}

		const lhs = node.getLeft();
		const rhs = node.getRight();
		let lhsStr: string;
		const rhsStr = this.transpileExpression(rhs);
		const statements = new Array<string>();

		function getOperandStr() {
			switch (opKind) {
				case ts.SyntaxKind.EqualsToken:
					return `${lhsStr} = ${rhsStr}`;
				case ts.SyntaxKind.PlusEqualsToken:
					const addExpStr = getLuaAddExpression(node, lhsStr, rhsStr, true);
					return `${lhsStr} = ${addExpStr}`;
				case ts.SyntaxKind.MinusEqualsToken:
					return `${lhsStr} = ${lhsStr} - (${rhsStr})`;
				case ts.SyntaxKind.AsteriskEqualsToken:
					return `${lhsStr} = ${lhsStr} * (${rhsStr})`;
				case ts.SyntaxKind.SlashEqualsToken:
					return `${lhsStr} = ${lhsStr} / (${rhsStr})`;
				case ts.SyntaxKind.AsteriskAsteriskEqualsToken:
					return `${lhsStr} = ${lhsStr} ^ (${rhsStr})`;
				case ts.SyntaxKind.PercentEqualsToken:
					return `${lhsStr} = ${lhsStr} % (${rhsStr})`;
			}
			throw new TranspilerError("Unrecognized operation! #1", node, TranspilerErrorType.UnrecognizedOperation1);
		}

		if (
			opKind === ts.SyntaxKind.EqualsToken ||
			opKind === ts.SyntaxKind.PlusEqualsToken ||
			opKind === ts.SyntaxKind.MinusEqualsToken ||
			opKind === ts.SyntaxKind.AsteriskEqualsToken ||
			opKind === ts.SyntaxKind.SlashEqualsToken ||
			opKind === ts.SyntaxKind.AsteriskAsteriskEqualsToken ||
			opKind === ts.SyntaxKind.PercentEqualsToken
		) {
			if (ts.TypeGuards.isPropertyAccessExpression(lhs) && opKind !== ts.SyntaxKind.EqualsToken) {
				const expression = lhs.getExpression();
				const opExpStr = this.transpileExpression(expression);
				const propertyStr = lhs.getName();
				const id = this.getNewId();
				statements.push(`local ${id} = ${opExpStr}`);
				lhsStr = `${id}.${propertyStr}`;
			} else {
				lhsStr = this.transpileExpression(lhs);
			}
			statements.push(getOperandStr());
			const parentKind = node.getParentOrThrow().getKind();
			if (parentKind === ts.SyntaxKind.ExpressionStatement || parentKind === ts.SyntaxKind.ForStatement) {
				return statements.join("; ");
			} else {
				const statementsStr = statements.join("; ");
				return `(function() ${statementsStr}; return ${lhsStr}; end)()`;
			}
		} else {
			lhsStr = this.transpileExpression(lhs);
		}

		switch (opKind) {
			case ts.SyntaxKind.EqualsEqualsToken: {
				if (this.isSameTypePrimitives(lhs, rhs)) {
					return `${lhsStr} == ${rhsStr}`;
				}
				return `RbxJs.abstractEquality(${lhsStr}, ${rhsStr})`
			}
			case ts.SyntaxKind.EqualsEqualsEqualsToken: {
				if (this.isSameTypePrimitives(lhs, rhs)) {
					return `${lhsStr} == ${rhsStr}`;
				}
				return `RbxJs.strictEquality(${lhsStr}, ${rhsStr})`
			}
			case ts.SyntaxKind.ExclamationEqualsToken:{
				if (this.isSameTypePrimitives(lhs, rhs)) {
					return `${lhsStr} == ${rhsStr}`;
				}
				return `not RbxJs.abstractEquality(${lhsStr}, ${rhsStr})`
			}
			case ts.SyntaxKind.ExclamationEqualsEqualsToken: {
				if (this.isSameTypePrimitives(lhs, rhs)) {
					return `${lhsStr} ~= ${rhsStr}`;
				}
				return `not RbxJs.strictEquality(${lhsStr}, ${rhsStr})`
			}
			case ts.SyntaxKind.PlusToken:
				return getLuaAddExpression(node, lhsStr, rhsStr);
			case ts.SyntaxKind.MinusToken:
				return `${lhsStr} - ${rhsStr}`;
			case ts.SyntaxKind.AsteriskToken:
				return `${lhsStr} * ${rhsStr}`;
			case ts.SyntaxKind.SlashToken:
				return `${lhsStr} / ${rhsStr}`;
			case ts.SyntaxKind.AsteriskAsteriskToken:
				return `${lhsStr} ^ ${rhsStr}`;
			case ts.SyntaxKind.InKeyword:
				return `${rhsStr}[${lhsStr}] ~= nil`;
			case ts.SyntaxKind.AmpersandAmpersandToken:
				return `${lhsStr} and ${rhsStr}`;
			case ts.SyntaxKind.BarBarToken:
				return `${lhsStr} or ${rhsStr}`;
			case ts.SyntaxKind.GreaterThanToken:
				return `${lhsStr} > ${rhsStr}`;
			case ts.SyntaxKind.LessThanToken:
				return `${lhsStr} < ${rhsStr}`;
			case ts.SyntaxKind.GreaterThanEqualsToken:
				return `${lhsStr} >= ${rhsStr}`;
			case ts.SyntaxKind.LessThanEqualsToken:
				return `${lhsStr} <= ${rhsStr}`;
			case ts.SyntaxKind.PercentToken:
				return `${lhsStr} % ${rhsStr}`;
			case ts.SyntaxKind.InstanceOfKeyword:
				if (inheritsFrom(node.getRight().getType(), "Rbx_Instance")) {
					return `TS.isA(${lhsStr}, "${rhsStr}")`;
				} else if (isRbxClassType(node.getRight().getType())) {
					return `(TS.typeof(${lhsStr}) == "${rhsStr}")`;
				} else {
					return `TS.instanceof(${lhsStr}, ${rhsStr})`;
				}
			default:
				const opKindName = node.getOperatorToken().getKindName();
				throw new TranspilerError(
					`Bad binary expression! (${opKindName})`,
					opToken,
					TranspilerErrorType.BadBinaryExpression,
				);
		}
	}

	public transpileSourceFile(node: ts.SourceFile, noHeader = false) {
		this.scriptContext = getScriptContext(node);
		const scriptType = getScriptType(node);

		let result = "";
		result += this.transpileStatementedNode(node);
		if (this.isModule) {
			if (!this.compiler.noHeuristics && scriptType !== ScriptType.Module) {
				throw new TranspilerError(
					"Attempted to export in a non-ModuleScript!",
					node,
					TranspilerErrorType.ExportInNonModuleScript,
				);
			}

			if (node.getDescendantsOfKind(ts.SyntaxKind.ExportAssignment).length > 0) {
				result = this.indent + `local _exports;\n` + result;
			} else {
				result = this.indent + `local _exports = {};\n` + result;
			}
			result += this.indent + "return _exports;\n";
		} else {
			if (!this.compiler.noHeuristics && scriptType === ScriptType.Module) {
				throw new TranspilerError(
					"ModuleScript contains no exports!",
					node,
					TranspilerErrorType.ModuleScriptContainsNoExports,
				);
			}
		}
		let runtimeLibImport = `local TS = require(game:GetService("ReplicatedStorage").RobloxTS.Include.RuntimeLib);\n` +
		`local RbxJs = require(game:GetService("ReplicatedStorage").RobloxTS.Include.RbxJsRuntimeLib);\n`;
		if (noHeader) {
			runtimeLibImport = "-- " + runtimeLibImport;
		}
		result = this.indent + runtimeLibImport + result;
		result = this.indent + "-- luacheck: ignore\n" + result;
		return result;
	}
}
