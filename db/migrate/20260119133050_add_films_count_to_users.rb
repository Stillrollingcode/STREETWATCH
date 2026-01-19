class AddFilmsCountToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :films_count, :integer, default: 0, null: false
  end
end
