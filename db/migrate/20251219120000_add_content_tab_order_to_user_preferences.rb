class AddContentTabOrderToUserPreferences < ActiveRecord::Migration[8.0]
  def change
    add_column :user_preferences, :content_tab_order, :string, default: "films,photos,articles"
  end
end
