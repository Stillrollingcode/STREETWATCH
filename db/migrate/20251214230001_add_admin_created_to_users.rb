class AddAdminCreatedToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :admin_created, :boolean, default: false
    add_column :users, :claim_token, :string
    add_column :users, :claimed_at, :datetime

    add_index :users, :claim_token, unique: true
  end
end
