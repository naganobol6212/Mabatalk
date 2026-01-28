Rails.application.routes.draw do
  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks" }

  root to: "homes#top"

  resources :categories, only: %i[index] do
    resource :flow, only: :show, controller: "category_flows"
  end

  resources :message_categories, only: %i[index new create] do
    resources :flow_items, only: :index
  end

  resources :flow_items, only: %i[new create] do
    get :confirm, on: :member
  end

  resources :message_logs, only: %i[index create]

  resource :message_completion, only: %i[show]

  # --- 以下はRails標準の補助機能 ---
  get "up" => "rails/health#show", as: :rails_health_check
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
end
