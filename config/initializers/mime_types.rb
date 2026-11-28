# 静的ファイル（public/）の Content-Type を足す。
# まばたき入力のモデル（public/mediapipe/models/*.task）は中身がバイナリ。
# 拡張子を知らないと text/plain で返ってしまうので、application/octet-stream にする。
Rack::Mime::MIME_TYPES[".task"] = "application/octet-stream"
