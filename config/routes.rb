Rails.application.routes.draw do
  get "feedbacks/new"
  get "feedbacks/create"
  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks" }

  root to: "homes#top"

  resources :message_categories, only: %i[index new create] do
    resources :flow_items, only: %i[index new create] do
      get :confirm, on: :member
    end
  end

  resources :message_logs, only: %i[index create]

  resource :message_completion, only: %i[show]

  resource :settings, only: %i[show]

  get "/guide", to: "pages#guide", as: :guide
  get "/terms", to: "pages#terms", as: :terms
  get "/privacy_policy", to: "pages#privacy_policy", as: :privacy_policy

  resources :feedbacks, only: %i[new create]

  # --- 以下はRails標準の補助機能 ---
  get "up" => "rails/health#show", as: :rails_health_check
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
end
