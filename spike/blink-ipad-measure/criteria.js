// 合格条件。source が「設計」のものは blink-pr2-design-excerpt.md「PR0.5 の合格条件」と
// 時間の値の表から。「仮」のものは設計に数値が無いので、測る前にここで決めたもの。
// 測ったあとで都合よく緩めない（設計の方針）。

export const LIMITS = {
  targetFps: 15, // 推論の頻度（設計：毎秒 15 回を目標）
  staleMs: 300, // 結果の古さの上限（設計：撮影から 300ms。PR0.5 で決める）
  watchdogMs: 500, // 結果が来ない時の見張り（設計）
  gapMs: 250, // フレーム間隔の上限（設計）
  holdMs: 800, // 保持時間の初期値（設計）
};

export const CRITERIA = [
  { id: "start", group: "起動", source: "設計", text: "組み合わせごとに、モデル読み込みから実際の 1 フレーム処理まで成功したかを記録する" },
  { id: "loadCold", group: "初回の読み込み", source: "仮", text: "キャッシュなしで「開始」→最初の結果から、WASM とモデル（約 18MB）のダウンロード時間を引いて 5 秒以下。合計とダウンロード時間も記録（トンネルの転送速度は本番と違うため判定から外す）" },
  { id: "loadWarm", group: "初回の読み込み", source: "仮", text: "キャッシュありで「開始」→最初の結果まで 5 秒以下" },
  { id: "interval", group: "速さ", source: "設計", text: "有効なフレームの間隔の 95% 点が 150ms 以下" },
  { id: "over250", group: "速さ", source: "仮", text: "有効なフレームの間隔が 250ms を超えた割合が 1% 以下（回数と最大値も記録。設計は記録のみ）" },
  { id: "proc", group: "1 フレームの処理時間", source: "仮", text: "処理時間の 95% 点が 66ms 以下（毎秒 15 回の 1 回分の持ち時間）。中央値も記録" },
  { id: "latency", group: "古さ（撮影→結果）", source: "仮", text: "撮影→結果受信の 95% 点が 200ms 以下、かつ 300ms 超（捨てる結果）が 1% 以下。両方満たせば「上限 300ms は妥当」" },
  { id: "drops", group: "落ちたフレーム", source: "仮", text: "最初の 2 秒（準備）のあと、見張り（500ms 応答なし）0 回・処理エラー 0 回・1 秒以上の止まり 0 回、かつ有効な結果が毎秒 12 回以上（目標 15 回の 8 割）。準備中の見張り・止まりは別に記録" },
  { id: "holdGuided", group: "保持（長いまばたき）", source: "仮", text: "合図に合わせた長いまばたき 10 回のうち 9 回以上を認め、間隔超え・無効フレームでの取消が 0 回（設計：ふつうの長いまばたきがたびたび取り消される組み合わせは不合格）" },
  { id: "normalBlink", group: "意図しない選択", source: "設計", text: "ふつうのまばたき 30 秒の間に「長いまばたき」と判定された回数が 0（0 回でも安全の証明とは扱わない）" },
  { id: "score", group: "まばたきスコア", source: "仮", text: "顔が映ったフレームのうち eyeBlinkLeft/Right が取れた割合が 99% 以上、顔の検出率が 95% 以上（正面に座った状態）" },
  { id: "calib", group: "まばたきスコア", source: "設計", text: "開いた目 3 秒・閉じた目 3 秒の中央値の差 C−O が 0.29 以上" },
  { id: "stop", group: "反応", source: "設計", text: "停止の操作から画面に反映されるまで 250ms 以下。カメラの track と Worker が実際に止まる" },
  { id: "ui", group: "反応", source: "仮", text: "タップ→描画の 95% 点が 100ms 以下、画面の描画間隔の 95% 点が 34ms 以下、スキャンの切り替え（2 秒ごと）の遅れの 95% 点が 50ms 以下" },
  { id: "long", group: "続けて使う", source: "仮", text: "30 分・60 分の時点でも有効間隔の 95% 点が 150ms 以下、処理時間の中央値が最初の 5 分より 30% 以上増えない（設計：遅れ・止まり・再起動できない、が無い）" },
  { id: "restart", group: "続けて使う", source: "設計", text: "停止したあと、同じページで再び開始できる" },
  { id: "resume", group: "復帰", source: "仮", text: "画面ロック・タブ切替から戻って 3 秒以内に有効な結果が再開する。前の閉眼を持ち越さない（設計）" },
];

const fmt = (v, d = 0) => (v == null || Number.isNaN(v) ? "—" : Number(v).toFixed(d));

function row(c, status, value) {
  return { id: c.id, group: c.group, source: c.source, text: c.text, status, value };
}

// status: 合格 / 不合格 / 未測定 / 記録
export function evaluate(run) {
  const byId = Object.fromEntries(CRITERIA.map((c) => [c.id, c]));
  const out = [];
  const s = run.stats || {};
  const ok = run.ok;

  out.push(row(byId.start, ok ? "合格" : "不合格",
    ok ? `成功（初期化 ${fmt(run.startup?.createMs)}ms・最初の処理 ${fmt(run.startup?.firstDetectMs)}ms）` : `失敗：${run.error || "不明"}`));

  const total = run.startup?.firstResultTotalMs;
  if (ok && total != null) {
    const cold = run.startup.cold;
    const dl = run.startup.downloadMs || 0;
    const judged = cold ? total - dl : total;
    out.push(row(cold ? byId.loadCold : byId.loadWarm,
      judged <= 5000 ? "合格" : "不合格",
      cold
        ? `ダウンロードを除き ${fmt(judged / 1000, 1)} 秒（合計 ${fmt(total / 1000, 1)} 秒・ダウンロード ${fmt(dl / 1000, 1)} 秒・最初の処理 ${fmt(run.startup.firstDetectMs)}ms）`
        : `${fmt(total / 1000, 1)} 秒（キャッシュあり・最初の処理 ${fmt(run.startup.firstDetectMs)}ms）`));
    out.push(row(cold ? byId.loadWarm : byId.loadCold, "未測定", cold ? "キャッシュありの回で測る" : "「キャッシュなしで測る」にチェックして測る"));
  } else {
    out.push(row(byId.loadCold, "未測定", "—"));
    out.push(row(byId.loadWarm, "未測定", "—"));
  }

  const vi = s.validIntervalMs;
  const enough = vi && vi.n >= 30;
  out.push(row(byId.interval, !enough ? "未測定" : vi.p95 <= 150 ? "合格" : "不合格",
    enough ? `95%点 ${fmt(vi.p95)}ms（中央値 ${fmt(vi.p50)}・最大 ${fmt(vi.max)}・n=${vi.n}）` : "有効フレームが 30 未満"));

  if (enough) {
    const rate = s.counts.over250 / vi.n;
    out.push(row(byId.over250, rate <= 0.01 ? "合格" : "不合格",
      `${s.counts.over250} 回（${fmt(rate * 100, 2)}%）・最大 ${fmt(vi.max)}ms・保持の取消 ${run.blink?.holds?.canceled?.gap ?? 0} 回`));
  } else out.push(row(byId.over250, "未測定", "—"));

  const pr = s.procMs;
  out.push(row(byId.proc, !pr?.n ? "未測定" : pr.p95 <= 66 ? "合格" : "不合格",
    pr?.n ? `中央値 ${fmt(pr.p50, 1)}ms・95%点 ${fmt(pr.p95, 1)}ms・最大 ${fmt(pr.max)}ms` : "—"));

  const la = s.latencyMs;
  if (la?.n) {
    const staleRate = s.counts.stale / Math.max(1, s.counts.results);
    out.push(row(byId.latency, la.p95 <= 200 && staleRate <= 0.01 ? "合格" : "不合格",
      `95%点 ${fmt(la.p95)}ms・99%点 ${fmt(la.p99)}ms・最大 ${fmt(la.max)}ms・300ms 超 ${s.counts.stale} 回（${fmt(staleRate * 100, 2)}%）`));
  } else out.push(row(byId.latency, "未測定", "—"));

  if (s.counts?.results) {
    const c = s.counts;
    const pass = c.watchdog === 0 && c.errors === 0 && c.stalls1s === 0 && s.validRate >= 12;
    out.push(row(byId.drops, pass ? "合格" : "不合格",
      `有効 ${fmt(s.validRate, 1)} 回/秒・見張り ${c.watchdog}（準備中 ${c.watchdogWarmup ?? 0}）・エラー ${c.errors}・止まり ${c.stalls1s}（準備中 ${c.stalls1sWarmup ?? 0}）・処理中で送れず ${c.busySkips}・古くて捨て ${c.stale}・顔なし ${c.noFace}`));
  } else out.push(row(byId.drops, "未測定", "—"));

  const g = run.blink?.guidedLong;
  out.push(row(byId.holdGuided, !g || g.prompts < 10 ? "未測定" : g.recognized >= 9 && g.canceled === 0 ? "合格" : "不合格",
    g ? `${g.prompts} 回中 ${g.recognized} 回認識・取消 ${g.canceled} 回` : "「長いまばたき 10 回」で測る"));

  const nb = run.blink?.normalBlink;
  out.push(row(byId.normalBlink, !nb || nb.seconds < 30 ? "未測定" : nb.falseLong === 0 ? "合格" : "不合格",
    nb ? `${nb.seconds} 秒で誤判定 ${nb.falseLong} 回（短いまばたき ${nb.shortBlinks} 回を検出）` : "「ふつうのまばたき 30 秒」で測る"));

  const b = run.blink;
  if (b && s.counts?.results) {
    const pass = b.scoreAvailRate >= 0.99 && b.faceRate >= 0.95;
    out.push(row(byId.score, pass ? "合格" : "不合格",
      `スコアあり ${fmt(b.scoreAvailRate * 100, 1)}%・顔あり ${fmt(b.faceRate * 100, 1)}%・スコアの範囲 ${fmt(b.min, 2)}〜${fmt(b.max, 2)}`));
  } else out.push(row(byId.score, "未測定", "—"));

  const cal = b?.calibration;
  out.push(row(byId.calib, !cal ? "未測定" : cal.diff >= 0.29 ? "合格" : "不合格",
    cal ? `O=${fmt(cal.O, 3)}・C=${fmt(cal.C, 3)}・C−O=${fmt(cal.diff, 3)}（左 ${fmt(cal.diffLeft, 3)}・右 ${fmt(cal.diffRight, 3)}）` : "「調整（開 3 秒→閉 3 秒）」で測る"));

  const ui = run.ui || {};
  if (ui.stopToPaintMs != null) {
    const pass = ui.stopToPaintMs <= 250 && ui.tracksEnded && ui.engineStopped;
    out.push(row(byId.stop, pass ? "合格" : "不合格",
      `${fmt(ui.stopToPaintMs)}ms・track 停止 ${ui.tracksEnded ? "済" : "未"}・${run.mode === "worker" ? "Worker" : "推論"} 停止 ${ui.engineStopped ? "済" : "未"}`));
  } else out.push(row(byId.stop, "未測定", "「停止」ボタンで止めた回で測る（時間切れの終了では測らない）"));

  if (ui.rafGapMs?.n) {
    const tapOk = !ui.tapToPaintMs?.n || ui.tapToPaintMs.p95 <= 100;
    const pass = tapOk && ui.rafGapMs.p95 <= 34 && (ui.scanLateMs?.p95 ?? 0) <= 50;
    out.push(row(byId.ui, pass ? "合格" : "不合格",
      `タップ→描画 95%点 ${fmt(ui.tapToPaintMs?.p95)}ms（n=${ui.tapToPaintMs?.n || 0}）・描画間隔 95%点 ${fmt(ui.rafGapMs.p95)}ms（50ms 超 ${ui.longFrames} 回）・スキャンの遅れ 95%点 ${fmt(ui.scanLateMs?.p95)}ms`));
  } else out.push(row(byId.ui, "未測定", "—"));

  const lc = run.longCheck;
  out.push(row(byId.long, !lc ? "未測定" : lc.pass ? "合格" : "不合格", lc ? lc.text : "30 分か 60 分の回で測る"));

  const rs = run.restart;
  out.push(row(byId.restart, rs?.isRestart ? (ok ? "合格" : "不合格") : "未測定",
    rs?.isRestart ? `同じページで ${rs.index} 回目の開始：${ok ? "成功" : "失敗"}` : "停止後にもう一度「開始」すると測れる"));

  const re = run.resume;
  out.push(row(byId.resume, !re?.attempts ? "未測定" : re.successes === re.attempts && re.resumeMs.every((x) => x <= 3000) ? "合格" : "不合格",
    re?.attempts ? `${re.attempts} 回中 ${re.successes} 回再開・${re.resumeMs.map((x) => fmt(x)).join(", ")}ms` : "動作中に画面ロック・タブ切替をして戻ると測れる"));

  return out;
}
