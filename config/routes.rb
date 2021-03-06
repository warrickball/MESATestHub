Rails.application.routes.draw do
  get 'sessions/new'

  resources :users do
    resources :computers
  end
  resources :sessions
  resources :computers
  resources :test_cases do
    resources :test_instances
  end

  root to: 'versions#show' #, params: { number: 'latest' }

  get '/versions/:number/test_cases/:test_case',
    to: 'test_case_versions#show', as:'test_case_version', test_case: /[^\/]+/
  get '/versions/:number', to: 'versions#show', as: 'version'

  match '/version/test_case' => 'test_case_versions#show_test_case_version', via: :get
  # get '/:number', to: 'versions#show', as: 'version'
  # get '/:number/:test_case', to: 'test_case_versions#show', as: 'test_case_version'

  get 'versions', to: 'versions#index', as: 'versions'
  get 'versions/:number', to: 'versions#show'  #, as: 'version'
  get 'versions/:number/:test_case', to: 'test_case_versions#show'  #, as: 'test_case_version'
  
  # this one just takes number from params nad redirects to version_path
  get 'show_version', to: 'versions#show_version'

  # meant for remote HTTP requests
  post '/test_instances/submit', to: 'test_instances#submit'
  post '/versions/submit_revision', to: 'versions#submit_revision'

  # searching test_instances (should work for remote JSON requests)
  get '/test_instances/search', to: 'test_instances#search', as: 'search_instances'
  # just for counts; for API access only to prevent disastrous data dump
  get '/test_instances/search_count', to: 'test_instances#search_count'

  get 'admin', to: 'users#admin', as: 'admin'
  get 'admin_edit_user', to: 'users#admin_edit_user', as: 'admin_edit_user'
  delete 'admin_destroy_user', to: 'users#admin_destroy_user',
                               as: 'admin_delete_user'

  get 'signup', to: 'users#new', as: 'signup'
  get 'login', to: 'sessions#new', as: 'login'
  get 'logout', to: 'sessions#destroy', as: 'logout'

  post 'check_user', to: 'sessions#check_credentials', as: 'check_user'
  post 'check_computer', to: 'computers#check_computer', as: 'check_computer'

  # index of a particular user's computers's test instances
  get 'user/:user_id/computers/:id/test_instances',
      to: 'computers#test_instances_index',
      as: 'user_computer_test_instances'

  # global list of all computers (admins only)
  get 'all_computers', to: 'computers#index_all', as: 'all_computers'
end
