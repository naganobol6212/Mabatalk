// 設計レビュー汎用ハーネス v2 — トークン効率版
//
// v1 からの変更（328k トークン枯渇の反省）:
//   1. モデルルーティング: レビュー/検証は Sonnet 既定（Coordinator=メインループのみ上位モデル）
//   2. verify を「指摘1件=1エージェント」から「レンズ1つ=1バッチ検証」に集約
//   3. budget ガード: 残量が閾値未満なら verify をスキップして未検証フラグ付きで返す
//   4. コンテキストはファイル参照（contextPath）推奨 — プロンプトへの全文再埋め込みを避ける
//
// 再開: 失敗時は Workflow({scriptPath, resumeFromRunId, args}) で完了済みエージェントは
// キャッシュ再生される。ただし model/effort を変えると (prompt, opts) が変わりキャッシュミスに
// なるため、routing は最初から決めてから回すこと。
//
// args:
//   context      : 設計コンテキスト全文（contextPath とどちらか必須）
//   contextPath  : コンテキストを書いたファイルの絶対パス（推奨・トークン節約）
//   dimensions   : [{key, prompt, engine?}] レビューレンズ。engine: 'codex' を指定すると
//                  そのレンズは Codex CLI による別ベンダー独立レビューになる
//                  （実行方法は .claude/skills/codex-discussion/SKILL.md に従う）
//   routing      : 省略可 { reviewModel, verifyModel, reviewEffort, verifyEffort, verifyMinBudget,
//                  verifyCodexFindings }
//                  verifyCodexFindings（既定 false）: true のとき Codex 由来の critical/major も
//                  Claude verify で二重検証する。false なら codex-native として検証を省略

export const meta = {
  name: 'design-review',
  description: '設計を複数レンズで並列レビューし、重要指摘をレンズ単位でバッチ反証検証する（Sonnet 既定のトークン効率版）',
  whenToUse: '実装前の設計・計画レビュー。args に { contextPath | context, dimensions: [{key, prompt}], routing? } を渡す',
  phases: [
    { title: 'Review', detail: 'レンズごとに並列レビュー（既定 Sonnet）', model: 'sonnet' },
    { title: 'Verify', detail: 'レンズ単位で critical/major をバッチ反証検証（既定 Sonnet）', model: 'sonnet' },
  ],
}

const FINDINGS = {
  type: 'object',
  required: ['findings'],
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        required: ['title', 'severity', 'detail', 'recommendation'],
        properties: {
          title: { type: 'string', description: '指摘の一行要約' },
          severity: { type: 'string', enum: ['critical', 'major', 'minor', 'info'] },
          detail: { type: 'string', description: '何がどう問題か。具体的な失敗シナリオ' },
          recommendation: { type: 'string', description: '推奨する対処' },
          evidence: { type: 'string', description: '根拠（一次情報 URL、ファイルパスなど）' },
        },
      },
    },
    okPoints: {
      type: 'array',
      items: { type: 'string' },
      description: '調査の結果「問題なし」と確認できた設計判断',
    },
  },
}

const VERDICTS = {
  type: 'object',
  required: ['verdicts'],
  properties: {
    verdicts: {
      type: 'array',
      items: {
        type: 'object',
        required: ['title', 'isReal', 'reasoning'],
        properties: {
          title: { type: 'string', description: '検証対象の指摘 title をそのまま返す' },
          isReal: { type: 'boolean', description: '実在する問題なら true。判断できなければ true（安全側）' },
          reasoning: { type: 'string' },
          correction: { type: 'string', description: '指摘が誤り・誇張の場合の正しい事実' },
        },
      },
    },
  },
}

const input = typeof args === 'string' ? JSON.parse(args) : args
if (!input || !Array.isArray(input.dimensions) || (!input.context && !input.contextPath)) {
  throw new Error('args には { context | contextPath, dimensions: [{key, prompt}] } を渡してください')
}
const dims = input.dimensions
const routing = Object.assign(
  {
    reviewModel: 'sonnet',
    verifyModel: 'sonnet',
    reviewEffort: 'medium',
    verifyEffort: 'medium',
    verifyMinBudget: 30000, // budget 指定時、残りがこれ未満なら verify を省略
    verifyCodexFindings: false, // true: Codex 由来の critical/major も Claude verify で二重検証
  },
  input.routing || {}
)

// コンテキストはファイル参照を優先（各エージェントのプロンプトを短く保つ）
const contextBlock = input.contextPath
  ? `設計コンテキストはファイル ${input.contextPath} に置いてある。最初に Read ツールで全文を読んでから作業すること。`
  : input.context

// Claude レビュアーの依頼文（従来の依頼文を一字一句変えず関数化したもの）
const claudeReviewPrompt = (d) =>
  [
    'あなたは設計レビュアーです。以下のレンズの観点でのみレビューしてください（他レンズの領域には踏み込まない）。',
    '',
    '## レンズ',
    d.prompt,
    '',
    '## レビュー対象の設計コンテキスト',
    contextBlock,
    '',
    '## 進め方',
    '- 事実確認が必要な外部仕様（ライブラリ API・ブラウザ挙動など）は、推測せず Web で一次情報を調査する（WebSearch / WebFetch が未ロードなら ToolSearch でロードして使う）',
    '- リポジトリの実態確認が必要なら実ファイルを読む。ただし調査は指摘の裏取りに必要な範囲に絞り、網羅的な読み歩きはしない',
    '- severity 基準: critical = このままだと設計が動かない/壊れる、major = 高確率で問題化する、minor = 改善余地、info = 補足',
    '- 指摘には必ず evidence（URL かファイルパス）を付ける',
    '- 「問題なし」と確認できた設計判断は okPoints に列挙する',
    '- 日本語で書く',
  ].join('\n')

// Codex レビュアーの依頼文: 設計評価はエージェント自身が行わず、Codex CLI（別ベンダー）に実行させて
// 結果を FINDINGS に正規化する係。実行方法は codex-discussion skill に厳密に従う
const codexReviewPrompt = (d) =>
  [
    'あなたは Codex CLI の実行係です。設計レビューの中身はあなた自身では行わず、必ず Codex（別ベンダーの独立レビュアー）に実行させ、その結果を回収・正規化してください。',
    '',
    '## 手順',
    '1. まずリポジトリルート直下の .claude/skills/codex-discussion/SKILL.md を Read し（ルートは `git rev-parse --show-toplevel` で解決する。個人環境の絶対パスを仮定しない）、そこに書かれた実行コマンド形・運用ルール（--sandbox read-only 必須、-o で結果回収、Bash timeout 600000 など）に厳密に従う',
    '2. 下記レンズの観点でのレビュー依頼文を SKILL.md の「依頼文の型」に沿って組み立て、codex exec を実行する',
    '3. 回収した出力を FINDINGS スキーマ（findings + okPoints）に正規化して返す。Codex が言っていない指摘を足さない・severity を付け直さない（欠損フィールドの補完のみ可）',
    '',
    '## レンズ（Codex への依頼観点）',
    d.prompt,
    '',
    '## レビュー対象',
    input.contextPath
      ? `Codex への依頼文には「設計コンテキストはファイル ${input.contextPath} にあるので読むこと」と指示する（全文をプロンプトに貼らない）`
      : ['contextPath がないため、以下の設計コンテキスト全文を Codex への依頼文の末尾に貼ること:', '', input.context].join('\n'),
    '',
    '## 失敗時',
    'codex の exit code が非 0、または出力ファイルが空・存在しない場合は、findings: [] とし、okPoints に "codex 実行失敗:<理由>" を 1 件だけ入れて返す。あなた自身がレビューして findings を埋めることは絶対にしない。',
  ].join('\n')

// レンズの engine に応じてレビュアーを切り替える（engine 未指定 = 従来どおり Claude レビュー）
const reviewAgent = (d) =>
  agent(d.engine === 'codex' ? codexReviewPrompt(d) : claudeReviewPrompt(d), {
    label: d.engine === 'codex' ? `review:codex:${d.key}` : `review:${d.key}`,
    phase: 'Review',
    schema: FINDINGS,
    model: routing.reviewModel,
    effort: routing.reviewEffort,
  })

phase('Review')
log(`${dims.length} レンズで並列レビュー開始（review=${routing.reviewModel}/${routing.reviewEffort}, verify=${routing.verifyModel}/${routing.verifyEffort}）`)

const results = await pipeline(
  dims,
  (d) => reviewAgent(d),
  (r, d) => {
    if (!r) return null
    const toVerify = r.findings.filter((f) => f.severity === 'critical' || f.severity === 'major')
    const rest = r.findings.filter((f) => f.severity !== 'critical' && f.severity !== 'major')
    const base = { lens: d.key, okPoints: r.okPoints || [] }

    if (toVerify.length === 0) {
      return { ...base, findings: rest.map((f) => ({ ...f, lens: d.key })) }
    }
    // Codex 由来レンズ: Codex 自身が evidence 提示済みのため、既定では Claude verify による
    // 二重検証を行わない（routing.verifyCodexFindings: true のときのみ従来どおり検証に回す）。
    // 注意: verdict は文字列でなくオブジェクトにする。下流の confirmed 集計が
    // 「!f.verdict || f.verdict.isReal」で判定するため、文字列 "codex-native" を入れると
    // isReal が undefined になり codex の major が黙って全滅する
    if (d.engine === 'codex' && !routing.verifyCodexFindings) {
      return {
        ...base,
        findings: [
          ...toVerify.map((f) => ({
            ...f,
            lens: d.key,
            verdict: {
              title: f.title,
              isReal: true,
              reasoning: 'codex-native（Codex 自身が根拠提示済みのため二重検証を省略。routing.verifyCodexFindings: true で検証可能）',
            },
          })),
          ...rest.map((f) => ({ ...f, lens: d.key })),
        ],
      }
    }
    // budget ガード: 残量僅少なら未検証のまま返す（黙って落とさず明示する）
    if (budget.total && budget.remaining() < routing.verifyMinBudget) {
      log(`budget 残 ${Math.round(budget.remaining() / 1000)}k < ${Math.round(routing.verifyMinBudget / 1000)}k: ${d.key} の検証をスキップ（unverified 扱い）`)
      return {
        ...base,
        findings: [...toVerify, ...rest].map((f) => ({ ...f, lens: d.key, verdict: null })),
      }
    }
    // レンズ単位のバッチ検証: 1 エージェントが当該レンズの critical/major を全件まとめて反証する
    return agent(
      [
        'あなたは懐疑的な検証者です。以下の設計レビュー指摘（複数件）を 1 件ずつ「反証」してみてください。',
        '事実確認には Web 調査（WebSearch / WebFetch。未ロードなら ToolSearch でロード）やリポジトリの実ファイル読解を使い、推測で判定しないこと。',
        '',
        '## 対象設計コンテキスト',
        contextBlock,
        '',
        '## 検証対象の指摘（JSON）',
        JSON.stringify(toVerify.map(({ title, detail, evidence }) => ({ title, detail, evidence })), null, 2),
        '',
        '各指摘について: 実在する問題なら isReal: true。誤り・誇張なら isReal: false とし correction に正しい事実を書く。判断できない場合は isReal: true（安全側）。title は入力のものをそのまま返す。日本語で。',
      ].join('\n'),
      {
        label: `verify:${d.key}`,
        phase: 'Verify',
        schema: VERDICTS,
        model: routing.verifyModel,
        effort: routing.verifyEffort,
      }
    ).then((v) => {
      const byTitle = new Map((v?.verdicts || []).map((x) => [x.title, x]))
      return {
        ...base,
        findings: [
          ...toVerify.map((f) => ({ ...f, lens: d.key, verdict: byTitle.get(f.title) || null })),
          ...rest.map((f) => ({ ...f, lens: d.key })),
        ],
      }
    })
  }
)

const all = results.filter(Boolean)
const allFindings = all.flatMap((r) => r.findings)
const confirmed = allFindings.filter((f) => !f.verdict || f.verdict.isReal)
const rejected = allFindings.filter((f) => f.verdict && !f.verdict.isReal)
const unverified = confirmed.filter((f) => (f.severity === 'critical' || f.severity === 'major') && !f.verdict)
log(`確定 ${confirmed.length} 件（うち未検証 ${unverified.length} 件）/ 反証棄却 ${rejected.length} 件 / 完了レンズ ${all.length}/${dims.length}`)
return {
  confirmed,
  rejected,
  okPoints: all.flatMap((r) => r.okPoints),
  completedLenses: all.map((r) => r.lens),
  unverifiedCount: unverified.length,
}
