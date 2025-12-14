Rails.application.routes.draw do
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
  get "/search", to: "search#index"
  get "/favorites", to: "favorites_films#index"
  get "/settings", to: "settings#show"
  patch "/settings", to: "settings#update"

  resources :films do
    resources :comments, only: [:create, :destroy]
    resource :favorite, only: [:create, :destroy]
  end

  resources :playlists do
    member do
      post 'add_film/:film_id', to: 'playlists#add_film', as: :add_film
      delete 'remove_film/:film_id', to: 'playlists#remove_film', as: :remove_film
    end
  end
end
