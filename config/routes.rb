Rails.application.routes.draw do
  # 認証(devise + Google OAuth)
  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks" }
  # 未ログイン時の入り口・振り分けページ
  root to: "homes#top"
  # ログイン後のメイン機能(カテゴリ一覧)
  resources :categories, only: %i[index] do
    resource :flow, only: :show, controller: "category_flows"
  end
  # メッセージカテゴリ(ユーザー操作用)
  resources :message_categories, only: %i[new create]
  # メッセージ確認画面(FlowItem確認)
  resources :flow_items, only: [] do
    get :confirm, on: :member
  end
  # メッセージログ作成とメッセージログ一覧表示
  resources :message_logs, only: %i[index create]
  # メッセージ完了画面(表側)
  resource :message_completion, only: %i[show]

  # --- 以下はRails標準の補助機能 ---
  get "up" => "rails/health#show", as: :rails_health_check
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
end
