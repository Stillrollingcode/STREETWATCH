class AddFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :name, :string
    add_column :users, :rider_type, :string
    add_column :users, :subscription_active, :boolean
  end
end
