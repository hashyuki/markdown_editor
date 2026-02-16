# AGENTS.md

このファイルは、このリポジトリで作業するAIコーディングエージェント向けの実装規約です。

## 1. Scope / 優先順位
- この`AGENTS.md`はリポジトリルート配下に適用します。
- より深いディレクトリに別の`AGENTS.md`がある場合は、そちらを優先します。
- 人間の明示的な指示がこの規約より優先されます。

## 2. Project Overview
- プロダクト: Flutter製 Markdown エディタ
- 主要レイヤ: `lib/src/domain` / `lib/src/application` / `lib/src/presentation`
- 方針: DDD + SOLID を維持し、ドメインモデルを中心に設計する

## 3. Local Commands (必須)
- 依存解決: `flutter pub get`
- テスト: `flutter test`
- 静的解析: `flutter analyze`
- 実行: `flutter run`

変更提出前は少なくとも以下を通すこと:
1. `flutter test`
2. `flutter analyze`

## 4. Architecture Rules (DDD/SOLID)

### 4.1 Dependency Direction
- `domain` は Flutter/UI 依存を持たない（純粋Dart）。
- `application` はユースケースのオーケストレーション層。
- `presentation` はUIと入力処理を担当し、ドメインロジックを直接埋め込まない。
- 依存は `presentation -> application -> domain` の一方向を維持する。

### 4.2 DIP / Interface First
- ユースケースから利用するサービスは、可能な限り抽象（interface）に依存する。
- 新規サービスを追加するときは「実装」より先に「境界（interface）」を設計する。

### 4.3 SRP
- ユースケース肥大化を避ける。1クラスに責務を詰め込みすぎない。
- 選択処理・編集処理・表示処理などは分離し、テストも分ける。

## 5. Domain Invariants (破壊禁止)
- `RichDocument` / `BlockNode` / `InlineText` は値オブジェクトとして扱う。
- 外部からの破壊的変更を許さない（防御的コピー + 不変ビュー前提）。
- `BlockNode`の不変条件:
  - `heading` のときのみ `headingLevel` を持つ
  - `indent` はリストブロック（bullet/ordered）でのみ意味を持つ
  - `codeLanguage` は `codeBlock` でのみ利用する

## 6. Markdown Model Semantics
- リストの`indent`は「スペース数」ではなく「論理レベル」。
- 1レベル = 先頭2スペース。
- 見出し/リスト/引用の`plainText`はMarkdown記法を含んだ内部表現として維持する。
- 構文判定ロジックを複数箇所に重複させない。既存の構文サービスに寄せる。

## 7. Editing / UI Behavior
- Undo/Redo、選択、IME入力の既存挙動を壊さない。
- `presentation`で表示スタイルを変える場合、`domain`の意味（例: `InlineMark`）と乖離させない。
- コントロールモード（外部状態管理）とローカルモードの両方を想定して実装する。

## 8. Testing Policy
- 仕様変更時は、最小でも以下のいずれかを追加・更新する:
  - `test/domain/...`（モデル/サービス）
  - `test/application/...`（ユースケース）
  - `test/presentation/...` または `test/rich_document_view_test.dart`
- バグ修正時は「再発防止テスト」を先に書くか、同時に追加する。
- テスト名は「何を保証するか」を具体的に書く。

## 9. Change Scope / Safety
- 要求されていない大規模リネーム・無関係リファクタは避ける。
- プラットフォーム生成ファイル（`android/`, `ios/`, `macos/`, `linux/`, `windows/`, `web/`）は、要求がない限り触らない。
- 公開API（`lib/markdown_editor.dart`）を変更する場合、互換性影響を明記しテストを追加する。

## 10. Output Expectations for Agents
- 変更理由を「設計意図」と「トレードオフ」で説明する。
- 最終報告には以下を必ず含める:
  1. 変更ファイル一覧
  2. 主要な設計判断
  3. 実行した検証コマンドと結果
  4. 残課題（あれば）

