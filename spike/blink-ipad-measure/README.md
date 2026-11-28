# まばたきスキャン PR0.5：iPad 実機の計測ページ（捨てブランチ・PR にしない）

iPad の Safari で、MediaPipe Face Landmarker を

- **Worker 版**：module Worker（`type: "module"`）＋ `useModule: true` ＋ `vision_wasm_module_internal.*`、Worker 内で `new OffscreenCanvas(1,1)` を `canvas` に渡す。GPU→CPU は Worker ごと作り直す
- **画面側版**：メインスレッド ＋ `useModule: false` ＋ `vision_wasm_internal.*`（script 要素で読む経路）

で動かし、同じ条件（tasks-vision 1.2.3 固定・`face_landmarker` float16/1・前面カメラ 640×480・毎秒 15 回まで・前の処理が終わるまで次を送らない）で比べます。

本体アプリ（Rails）とは切り離した静的ページです。本体の CSP・Permissions-Policy・プライバシーポリシーには触れていません。本番にも出しません。

## iPad で開く手順（オーナー向け）

Mac で：

```bash
cd spike/blink-ipad-measure
./serve.sh
```

- 初回だけ MediaPipe（npm の 1.2.3）とモデルをダウンロードし、ハッシュを確かめます（`vendor/` に置く。git には入れない）
- `cloudflared` が無ければ `brew install cloudflared` で入れます（アカウント不要）
- `iPad で開く URL： https://〜.trycloudflare.com` が表示され、クリップボードにも入ります

iPad で：

1. その URL を Safari で開く（同じ Apple ID ならペースト。ほかに AirDrop でも送れます）
2. 「1. 端末のこと」に型番・iPadOS の版・充電しているかを入れる（設定 → 一般 → 情報）
3. 正面に座り「**4 通りを順に比べる**」を押す。カメラの許可が出たら「許可」
   - 最初の組み合わせで「調整」（音が鳴ったら目を開けたまま 3 秒 → 高い音で目を閉じて 3 秒 → 低い音で開ける）
   - 続けて「長いまばたき 10 回」（「目を閉じて」で閉じ、「目を開けて」で開ける）
   - 全部で 5 分ほど。各組み合わせ 60 秒
4. 「この組み合わせだけ開始」を 1 回使い、数秒後に「**停止**」を押す（停止の反応を測る）。途中で「タップ反応」を数回、「ふつうのまばたき 30 秒」も
5. 同じ回のまま、ホームに戻る・別のタブに移るなどして数秒後に戻る（復帰を測る）
6. 長時間：いちばん良かった組み合わせで「長さ 60 分」→「この組み合わせだけ開始」。充電しながら、自動ロックは「なし」に。始めと終わりの電池 % と熱さを入力
7. 初回の読み込み時間を測るなら「キャッシュなしで測る」にチェックしてから開始
8. 「5. 結果を渡す」→「**共有（AirDrop など）**」で Mac に送る。だめなら「JSON を保存」（ファイル App に入る）か「JSON をコピー」してメッセージなどに貼る

Mac 側は Ctrl+C で止めます。止めればその URL は使えなくなります（毎回変わります）。

### トンネルについて

- 外に出るのはこのページの HTML/JS と、公開されている MediaPipe の WASM・モデルだけです。個人情報・秘密・本体アプリのコードやデータは出しません
- カメラの映像はトンネルを通りません（iPad の中だけで処理）。結果の JSON も自動では送りません
- サーバーは `127.0.0.1` だけで待ち受け、決まったファイル以外は 404 です。Mac 確認用のテスト画像はトンネルからは出しません
- 外に出したくない時は、iPad に Tailscale を入れて `tailscale serve --bg http://127.0.0.1:8787` でも開けます（tailnet 内だけ）

## Mac での確認

```bash
node server.mjs &                          # http://localhost:8787/ （Chrome は localhost ならカメラ可）
node tools/mac-check.mjs image 15          # 公開テスト画像（顔あり）で 4 通り＋停止＋再起動
node tools/mac-check.mjs image 10 extra    # ＋調整・長いまばたき・ふつうのまばたき・復帰（擬似）
node tools/mac-check.mjs camera 8          # Chrome の偽カメラ（顔なし）でカメラ経路
BASE=https://〜.trycloudflare.com node tools/mac-check.mjs camera 8   # トンネル経由
```

`?source=image` はテスト画像を入力にする Mac 確認用です。iPad では付けずに開きます。

## 測るもの

| 何を | どう測るか |
|---|---|
| 1 フレームの処理時間 | `detectForVideo` の前後（Worker 版は Worker の中）。中央値・95% 点・最大 |
| 撮影→結果の古さ | 撮影時刻＝ `requestVideoFrameCallback` で送る時の `performance.now()`（設計どおり）。結果を受け取った時刻との差。300ms 超は捨てて数える |
| 有効フレームの間隔 | 有効な結果どうしの撮影時刻の差。顔が消えた区間はまたがない。250ms 超の回数・最大 |
| 落ちたフレーム | 処理中で送れなかった数、300ms 超で捨てた数、見張り（500ms 応答なし）、エラー、1 秒以上の止まり、見逃したカメラフレーム（取れる端末だけ） |
| 初回の読み込み | カメラ起動、import、`createFromOptions`、最初の 1 フレーム（GPU の準備を含む）、WASM・モデルのダウンロード時間（Resource Timing）、キャッシュの有無 |
| 長く動かした時 | 1 分ごとの有効回数・間隔・古さ・処理時間・描画間隔。最初の 5 分と 25〜30 分・55〜60 分を比べる。発熱・電池は Safari から取れないので手入力 |
| まばたきスコア | 顔の検出率、`eyeBlinkLeft/Right` が取れた割合、範囲、20 段の分布。調整で O・C・C−O（左右別） |
| 保持（長いまばたき） | 速さの乱れで保持が取り消されるかを見る簡易版（PR1 の判定モジュールそのものではない） |
| 画面の反応 | 描画間隔（rAF）、2 秒ごとのスキャン切り替えの遅れ、タップ→描画、停止→描画、track と Worker が実際に止まったか |
| 復帰 | `visibilitychange`／`pagehide`／`pageshow` でカメラと推論を止め、戻ったら作り直して再開までの時間 |
| 端末 | UA、Safari の版、WebGL の renderer、コア数、実際の映像サイズ、機能の有無。型番と OS は手入力 |

合格条件の一覧はページの最下部と `criteria.js` にあります。「設計」は設計書の PR0.5 合格条件と時間の値の表から、「仮」は設計に数値が無いのでこのページで先に決めたものです。

## このページで測らないもの

音・日本語の読み上げ（PR3c）、記録と二重送信（PR2・PR3b）、介助者の顔・顔の入れ替わり・項目の境目（PR1 の判定モジュールと画面がそろってから）。

## 渡される JSON

`schema: "mabatalk-blink-pr05/v1"`。`device`（自動）・`manual`（手入力）・`criteria`・`runs[]`（各回の集計・1 分ごと・判定 `evaluation`）。5 分以下の回は `frames`（時間の数字と有効/無効の理由だけ）。映像・画像・フレームごとのスコアは入れません。
