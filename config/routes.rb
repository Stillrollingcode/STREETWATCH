Rails.application.routes.draw do
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)
  devise_for :users, controllers: {
    omniauth_callbacks: "users/omniauth_callbacks",
    registrations: "users/registrations",
    sessions: "users/sessions"
  }
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
  get "/search", to: "search#index"
  get "/favorites", to: "favorites_films#index"
  get "/settings", to: "settings#show"
  patch "/settings", to: "settings#update"
  post "/notifications/mark_as_read", to: "notifications#mark_as_read"

  # Policy pages
  get "/about", to: "pages#about", as: :about
  get "/subscription", to: "pages#subscription", as: :subscription
  get "/privacy", to: "pages#privacy", as: :privacy
  get "/sellers-disclaimer", to: "pages#sellers_disclaimer", as: :sellers_disclaimer

  # Coming soon pages
  get "/articles", to: "pages#articles", as: :articles
  get "/shop", to: "pages#shop", as: :shop

  resources :users, only: [:index, :show] do
    member do
      post 'follow', to: 'follows#create'
      delete 'unfollow', to: 'follows#destroy'
      get 'following', to: 'users#following'
      get 'followers', to: 'users#followers'
      post 'claim', to: 'profile_claims#create'
      # Lazy loading endpoints for profile tabs
      get 'tab/:tab', to: 'users#tab_content', as: :tab_content
      get 'film_subtab/:subtab', to: 'users#film_subtab_content', as: :film_subtab_content
    end
    resource :notification_setting, only: [:show, :update, :destroy], controller: 'profile_notification_settings'
  end
  resources :films do
    resources :comments, only: [:create, :destroy]
    resource :favorite, only: [:create, :destroy]
    resources :tag_requests, only: [:create]
    resources :film_reviews, only: [:index, :create, :update, :destroy]
    collection do
      get 'video_metadata', to: 'films#video_metadata'
    end
    member do
      post 'hide_from_profile', to: 'films#hide_from_profile'
      delete 'unhide_from_profile', to: 'films#unhide_from_profile'
      get 'navigation', to: 'films#navigation'
    end
  end

  resources :tag_requests, only: [] do
    member do
      post 'approve'
      post 'deny'
    end
  end

  resources :film_approvals, only: [:index] do
    member do
      post 'approve'
      post 'reject'
      patch 'reset'
    end
  end

  resources :sponsor_approvals, only: [:index] do
    member do
      post 'approve'
      post 'reject'
      patch 'reset'
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
      post 'hide_from_profile', to: 'photos#hide_from_profile'
      delete 'unhide_from_profile', to: 'photos#unhide_from_profile'
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
      patch 'reset'
    end
  end
end
