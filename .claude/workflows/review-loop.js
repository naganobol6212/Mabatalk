// review-loop — レビュー→修正→再レビューの収束ループ（design-review を部品として呼ぶ制御層）
//
// 役割分担:
//   - design-review.js = 「1回のレビュー」という部品。本ファイルからは一切変更しない
//   - 本ファイル        = 回す制御。停止判断・回数・履歴・トークン記録はすべてこのコードが持ち、
//                          LLM の主観（「もう十分」）では止めない
//
// 停止条件（コード側で判定。優先順に）:
//   1. critical/major が 0 件         → 収束として終了
//   2. 今周の指摘がすべて既出         → 堂々巡りとして終了（seen には棄却済み指摘も含める。
//                                        含めないと、却下された指摘が毎周復活して永遠に収束しない）
//   3. round >= maxRounds             → 終了（未解消 major が残っていれば未完了フラグ）
//   4. budget 残量 < loopMinBudget    → 未完了フラグを付けて終了
//   5. Claude トークン累計 > tokenBudgetPerRun → 未完了フラグを付けて強制終了（maxRounds とは別の歯止め）
//
// 安全ゲート:
//   - 修正は必ず使い捨てブランチ上のみ。main には触らない・push しない・自動マージしない
//   - コミットは「テストが通った周」だけ、そのペースで 1 コミット。対象はその周の変更ファイルのみ
//     （git add -A 禁止 = 無関係な未コミット変更を巻き込まない）
//   - テスト失敗時はその周の変更ファイルだけを checkout -- で戻す（git reset --hard 禁止）
//   - マージ可否の判断は人間。最終報告で必ず止まる
//
// args:
//   contextPath       : 設計コンテキストのファイルパス（design-review にそのまま渡す）
//   dimensions        : [{key, prompt, engine?}] レビューレンズ（design-review にそのまま渡す）
//   routing?          : design-review の routing。★素通しし、ループ側でモデルを差し替えない。
//                       追加で fixModel（既定 'sonnet'。込み入った修正のときだけ 'opus' に上げる）を読む
//   maxRounds?        : 既定 3
//   testCommand       : 例 "bundle exec rspec" / "npm test"（必須）
//   tokenBudgetPerRun?: このループ実行全体で許す Claude トークン累計の上限（省略可）
//   loopMinBudget?    : budget（+500k 指定等）使用時の残量下限。既定 60000
//   timestamp         : ブランチ名の一意化に使う（必須。ワークフロー内では Date.now() が使えず
//                       一意な名前を自力で作れないため外から渡す。固定名だと再実行で
//                       git switch -c が衝突する）
//   repo?             : リポジトリの絶対パス。省略時はカレントの git リポジトリを使う
//
// トークン記録: Claude 分は budget.spent() の差分で毎周実測する。Codex レンズの消費は
// OpenAI 側で発生するため計測できない — 「実行した回数」だけを分けて記録する。

export const meta = {
  name: 'review-loop',
  description: 'design-review を部品として呼び、レビュー→修正→テスト→再レビューを停止条件まで回す制御ループ',
  whenToUse: '設計/コードレビューの指摘を修正まで自動で収束させたいとき。args に { contextPath, dimensions, testCommand, maxRounds?, routing?, timestamp? } を渡す。マージは常に人間が判断する',
}

const FIX_RESULT = {
  type: 'object',
  required: ['applied', 'changedFiles', 'changedFunctions', 'summary'],
  properties: {
    applied: { type: 'boolean', description: '1 件以上の修正を適用できたら true' },
    baseSha: { type: 'string', description: 'ブランチ作成時に記録した分岐元コミット SHA（ブランチを新規作成した周のみ）' },
    changedFiles: { type: 'array', items: { type: 'string' }, description: '変更したファイルのリポジトリ相対パス' },
    changedFunctions: {
      type: 'array',
      items: {
        type: 'object',
        required: ['file', 'name'],
        properties: {
          file: { type: 'string' },
          name: { type: 'string', description: '変更した関数/メソッド名' },
          directCallers: { type: 'array', items: { type: 'string' }, description: 'この関数を直接呼び出している箇所（file:関数名 形式）' },
        },
      },
    },
    summary: { type: 'string', description: '何をどう直したかの要約' },
    skipped: {
      type: 'array',
      items: {
        type: 'object',
        required: ['title', 'reason'],
        properties: { title: { type: 'string' }, reason: { type: 'string' } },
      },
      description: '対応しなかった指摘とその理由',
    },
  },
}

const TEST_RESULT = {
  type: 'object',
  required: ['passed', 'committed'],
  properties: {
    passed: { type: 'boolean', description: 'testCommand が exit 0 なら true' },
    committed: { type: 'boolean', description: 'この周の変更をコミットしたら true' },
    commitSha: { type: 'string' },
    reverted: { type: 'boolean', description: 'テスト失敗により変更を戻したら true' },
    outputTail: { type: 'string', description: 'テスト出力の末尾（失敗時は失敗箇所が分かる部分）' },
  },
}

// ---- 入力の検証と既定値 ----------------------------------------------------

const input = typeof args === 'string' ? JSON.parse(args) : args
if (!input || !input.contextPath || !Array.isArray(input.dimensions) || !input.testCommand) {
  throw new Error('args には { contextPath, dimensions: [{key, prompt}], testCommand } が必須です')
}
if (!input.timestamp) {
  // 固定のブランチ名は再実行時に git switch -c が衝突する。Date.now() は使えないため呼び出し側で渡す
  throw new Error('args.timestamp は必須です（ブランチ名 review-loop/<timestamp> の一意化に使う）')
}
const maxRounds = input.maxRounds || 3
const tokenBudgetPerRun = input.tokenBudgetPerRun || null
const loopMinBudget = input.loopMinBudget || 60000
const fixModel = (input.routing && input.routing.fixModel) || 'sonnet'
const branch = `review-loop/${input.timestamp}`
const repo = input.repo || null // 省略時はカレントの git リポジトリ（エージェントの作業ディレクトリ）

// ---- ループが保持する状態（すべてコード側） --------------------------------

let round = 0
const seen = new Set() // 既出指摘の識別キー（confirmed も rejected も入れる）
const history = [] // 各周の記録
const tokenLog = [] // 各周のトークン消費（Claude 実測 / Codex は回数のみ）
let branchCreated = false
let baseSha = null
let stopReason = null
let incomplete = false
let lastScope = null // 次周の再レビュー範囲（変更関数＋直接の呼び出し元）
let lastTest = null

// 指摘の識別キー。LLM は周をまたぐと文言を揺らすため、空白と記号を潰した title で照合する。
// 完全な同一判定は不可能（言い換えには弱い）が、判定を LLM の主観に返さないことを優先する
const normKey = (f) =>
  `${(f.title || '')}`.toLowerCase().replace(/[\s、。・:：()（）\[\]「」]/g, '')

// 再レビュー範囲の限定文。「変更関数＋その直接の呼び出し元」以外は読ませない
const scopeNote = (scope) =>
  [
    '【再レビュー範囲の限定・厳守】',
    '今回のレビュー対象は、直前の修正で変更された以下の関数と、それらを直接呼び出している箇所のみ。',
    '「ファイル全体」「周辺コード」と拡大解釈しない。以下に挙がっていないコードは読まない。',
    JSON.stringify(scope, null, 2),
    '',
    '',
  ].join('\n')

// ---- メインループ ----------------------------------------------------------

while (true) {
  round += 1
  phase(`Round ${round}: Review`)
  const spentAtRoundStart = budget.spent()

  // 1. design-review を部品として呼ぶ（routing は素通し。ループ側でモデルを差し替えない）
  const dims = lastScope
    ? input.dimensions.map((d) => ({ ...d, prompt: scopeNote(lastScope) + d.prompt }))
    : input.dimensions
  const review = await workflow('design-review', {
    contextPath: input.contextPath,
    dimensions: dims,
    routing: input.routing,
  })
  const reviewTokens = budget.spent() - spentAtRoundStart

  const confirmedAll = (review && review.confirmed) || []
  const rejectedAll = (review && review.rejected) || []
  const majors = confirmedAll.filter((f) => f.severity === 'critical' || f.severity === 'major')

  // 新規性判定は seen 更新「前」に行う
  const freshKeys = majors.map(normKey).filter((k) => !seen.has(k))
  // ★confirmed だけでなく棄却分も seen に入れる（却下された指摘の毎周復活を防ぐ）
  confirmedAll.forEach((f) => seen.add(normKey(f)))
  rejectedAll.forEach((f) => seen.add(normKey(f)))

  history.push({
    round,
    majorsCount: majors.length,
    freshCount: freshKeys.length,
    confirmed: confirmedAll.map((f) => ({ title: f.title, severity: f.severity, lens: f.lens })),
    rejected: rejectedAll.map((f) => ({ title: f.title, lens: f.lens })),
  })
  log(`Round ${round}: critical/major ${majors.length} 件（うち新規 ${freshKeys.length} 件）`)

  // 2. 停止条件（修正を「回す前に」コードで判定）
  if (majors.length === 0) {
    stopReason = `収束: Round ${round} で critical/major が 0 件`
    tokenLog.push({ round, claudeTokens: reviewTokens, codexLensCount: dims.filter((d) => d.engine === 'codex').length })
    break
  }
  if (freshKeys.length === 0) {
    stopReason = `堂々巡り: Round ${round} の指摘 ${majors.length} 件はすべて既出（棄却済み含む）`
    incomplete = true
    tokenLog.push({ round, claudeTokens: reviewTokens, codexLensCount: dims.filter((d) => d.engine === 'codex').length })
    break
  }
  if (round >= maxRounds) {
    stopReason = `maxRounds (${maxRounds}) 到達。未解消の critical/major が ${majors.length} 件残っている`
    incomplete = true
    tokenLog.push({ round, claudeTokens: reviewTokens, codexLensCount: dims.filter((d) => d.engine === 'codex').length })
    break
  }
  if (budget.total && budget.remaining() < loopMinBudget) {
    stopReason = `budget 残量不足: 残 ${Math.round(budget.remaining() / 1000)}k < ${Math.round(loopMinBudget / 1000)}k`
    incomplete = true
    tokenLog.push({ round, claudeTokens: reviewTokens, codexLensCount: dims.filter((d) => d.engine === 'codex').length })
    break
  }
  const claudeTotalSoFar = tokenLog.reduce((s, t) => s + t.claudeTokens, 0) + reviewTokens
  if (tokenBudgetPerRun && claudeTotalSoFar > tokenBudgetPerRun) {
    stopReason = `tokenBudgetPerRun 超過: 累計 ${Math.round(claudeTotalSoFar / 1000)}k > ${Math.round(tokenBudgetPerRun / 1000)}k`
    incomplete = true
    tokenLog.push({ round, claudeTokens: reviewTokens, codexLensCount: dims.filter((d) => d.engine === 'codex').length })
    break
  }

  // 3. 修正の適用（使い捨てブランチ上のみ・confirmed の critical/major に限定）
  phase(`Round ${round}: Fix`)
  const fix = await agent(
    [
      'あなたは修正担当です。以下のレビュー指摘（critical/major のみ）をリポジトリに適用してください。',
      '',
      '## ブランチ規律（厳守）',
      branchCreated
        ? `- 既に作業ブランチ ${branch} があるので \`git switch ${branch}\` で移ってから作業する`
        : `- 最初に \`git rev-parse HEAD\` の結果を baseSha として記録し、\`git switch -c ${branch}\` で使い捨てブランチを作ってから作業する`,
      '- main ブランチには絶対に触らない。push しない。コミットもしない（コミットはテスト担当が行う）',
      '- 修正対象は下記の指摘のみ。minor/info の対応や「ついで」のリファクタは禁止',
      '',
      '## 修正する指摘（JSON）',
      JSON.stringify(majors.map(({ title, severity, detail, recommendation, evidence }) => ({ title, severity, detail, recommendation, evidence })), null, 2),
      '',
      `## 参考: 設計コンテキストは ${input.contextPath} にある（必要なら Read する）`,
      '',
      '## 返すもの',
      '- changedFiles: 変更したファイルのリポジトリ相対パス',
      '- changedFunctions: 変更した関数と、それを直接呼び出している箇所（grep で調べて directCallers に列挙）',
      '- 対応できない指摘は無理に直さず skipped に理由付きで返す',
    ].join('\n'),
    { label: `fix:round${round}`, phase: `Round ${round}: Fix`, schema: FIX_RESULT, model: fixModel }
  )
  if (fix && fix.baseSha && !baseSha) baseSha = fix.baseSha
  if (fix && fix.applied) branchCreated = true

  if (!fix || !fix.applied || fix.changedFiles.length === 0) {
    stopReason = `Round ${round}: 修正エージェントが変更を適用できなかった`
    incomplete = true
    tokenLog.push({ round, claudeTokens: budget.spent() - spentAtRoundStart, codexLensCount: dims.filter((d) => d.engine === 'codex').length })
    break
  }

  // 4. テスト → 通れば 1 コミット / 落ちればその周の変更だけ revert
  const test = await agent(
    [
      'あなたはテスト・コミット担当です。以下を厳密に実行してください。',
      '',
      `1. \`git switch ${branch}\` で作業ブランチにいることを確認する`,
      `2. テストを実行する: \`${input.testCommand}\`（Bash の timeout は 600000 にする）`,
      '3. exit 0（成功）の場合のみ、以下のファイル「だけ」を git add してコミットする。git add -A / git add . は禁止（無関係な未コミット変更を巻き込まないため）:',
      JSON.stringify(fix.changedFiles, null, 2),
      `   コミットメッセージ: "review-loop round ${round}: ${fix.summary.slice(0, 60)}"`,
      '4. テストが失敗した場合はコミットせず、上記ファイル「だけ」を `git checkout -- <ファイル>` で元に戻す。`git reset --hard` は禁止',
      '5. どちらの場合も push はしない。main には触らない',
      '',
      '結果を passed / committed / commitSha / reverted / outputTail（テスト出力の末尾）で返す。',
    ].join('\n'),
    { label: `test:round${round}`, phase: `Round ${round}: Fix`, schema: TEST_RESULT, model: 'sonnet', effort: 'low' }
  )
  lastTest = test
  tokenLog.push({
    round,
    claudeTokens: budget.spent() - spentAtRoundStart,
    codexLensCount: dims.filter((d) => d.engine === 'codex').length,
  })

  const roundRec = history[history.length - 1]
  roundRec.fix = { summary: fix.summary, changedFiles: fix.changedFiles, skipped: fix.skipped || [] }
  roundRec.test = test ? { passed: test.passed, committed: test.committed, reverted: !!test.reverted } : { passed: false, committed: false, error: 'テスト担当が結果を返さなかった' }

  if (test && test.passed) {
    // 次周の再レビューは「今周の変更関数＋直接の呼び出し元」に限定。
    // ただし報告が空配列だと限定範囲が実質ゼロ（何も読まないレビュー）になるため全域に戻す
    lastScope = fix.changedFunctions && fix.changedFunctions.length > 0 ? fix.changedFunctions : null
    log(
      lastScope
        ? `Round ${round}: テスト通過・コミット済み。次周は変更 ${lastScope.length} 関数に限定して再レビュー`
        : `Round ${round}: テスト通過・コミット済み。変更関数の報告が空のため次周は全域レビュー`
    )
  } else {
    // 失敗は history に残した。変更は revert 済みなので次周は同じコードを見る
    // → 同じ指摘が出て「堂々巡り」条件で止まる（無限に修正リトライしない）
    lastScope = null
    log(`Round ${round}: テスト失敗のため revert。失敗を記録して停止条件の判断に進む`)
  }
}

// ---- 最終集約・報告（司令塔 = opus）。マージ可否は人間が判断する -------------

phase('Report')
const claudeTotal = tokenLog.reduce((s, t) => s + t.claudeTokens, 0)
const codexRuns = tokenLog.reduce((s, t) => s + t.codexLensCount, 0)

const report = await agent(
  [
    'あなたはこのレビューループの司令塔です。以下の実行記録を、人間がブランチのマージ可否を判断できる形に集約・報告してください。',
    '',
    '## 実行記録（JSON）',
    JSON.stringify(
      {
        stopReason,
        incomplete,
        rounds: round,
        branch: branchCreated ? branch : null,
        baseSha,
        history,
        tokenLog,
        claudeTokensTotal: claudeTotal,
        codexLensRuns: codexRuns,
        lastTest,
      },
      null,
      2
    ),
    '',
    '## やること',
    branchCreated
      ? `1. \`git diff ${baseSha || 'HEAD'} ${branch} --stat\` と必要なら本文を確認し、全体の変更を要約する${repo ? `（リポジトリ: ${repo}）` : '（カレントの git リポジトリで実行。必要なら `git rev-parse --show-toplevel` で確認）'}`
      : '1. ブランチは作成されていない（修正前に停止）。その旨を明記する',
    '2. 確定した指摘・棄却された指摘・各周のトークン消費（Claude は実測値、Codex は OpenAI 側のため実行回数のみ）・最終テスト結果を表で整理する',
    '3. 未解消の指摘が残っていれば、マージ判断に必要な残リスクとして明示する',
    '4. 絶対にしないこと: マージ・push・main への操作。報告のみ',
    '',
    '日本語で、結論（マージ推奨/非推奨/条件付き）を先頭に書くこと。',
  ].join('\n'),
  { label: 'report', phase: 'Report', model: 'opus' }
)

return {
  stopReason,
  incomplete,
  rounds: round,
  branch: branchCreated ? branch : null,
  baseSha,
  tokenLog,
  claudeTokensTotal: claudeTotal,
  codexLensRuns: codexRuns,
  history,
  report,
}
