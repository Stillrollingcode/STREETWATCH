class AddUsernameIndexForSearch < ActiveRecord::Migration[8.0]
  def change
    # Add index for case-insensitive username sorting (LOWER(username))
    # This speeds up the ORDER BY LOWER(username) clause on the users index page
    add_index :users, "LOWER(username)", name: "index_users_on_lower_username"
  end
end
