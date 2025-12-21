Rails.application.routes.draw do
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)
  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks", registrations: "users/registrations" }
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "pages#home"
  get "/username/check", to: "usernames#show"
  get "/search", to: "search#index", defaults: { format: :json }
  get "/favorites", to: "favorites_films#index"
  get "/settings", to: "settings#show"
  patch "/settings", to: "settings#update"
  post "/notifications/mark_as_read", to: "notifications#mark_as_read"

  resources :users, only: [:index, :show] do
    member do
      post 'follow', to: 'follows#create'
      delete 'unfollow', to: 'follows#destroy'
      get 'following', to: 'users#following'
      get 'followers', to: 'users#followers'
      post 'claim', to: 'profile_claims#create'
    end
    resource :notification_setting, only: [:show, :update, :destroy], controller: 'profile_notification_settings'
  end
  resources :films do
    resources :comments, only: [:create, :destroy]
    resource :favorite, only: [:create, :destroy]
  end

  resources :film_approvals, only: [:index] do
    member do
      post 'approve'
      post 'reject'
    end
  end

  resources :playlists do
    member do
      post 'add_film/:film_id', to: 'playlists#add_film', as: :add_film
      delete 'remove_film/:film_id', to: 'playlists#remove_film', as: :remove_film
    end
  end

  # Albums and Photos
  resources :albums do
    resources :photos, only: [:new, :create], shallow: true
  end

  resources :photos do
    resources :photo_comments, only: [:create, :edit, :update, :destroy]
    member do
      delete 'remove_tag/:tag_type/:tag_id', to: 'photos#remove_tag', as: :remove_tag
    end
    collection do
      get 'batch_upload'
      post 'batch_create'
    end
  end

  resources :photo_approvals, only: [:index] do
    member do
      patch 'approve'
      patch 'reject'
    end
  end
end
