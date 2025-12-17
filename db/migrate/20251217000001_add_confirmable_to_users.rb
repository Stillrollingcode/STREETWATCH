class AddConfirmableToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :confirmation_token, :string
    add_column :users, :confirmed_at, :datetime
    add_column :users, :confirmation_sent_at, :datetime
    add_column :users, :unconfirmed_email, :string
    add_index :users, :confirmation_token, unique: true

    # Auto-confirm existing users so they don't get locked out
    reversible do |dir|
      dir.up do
        # Use database-agnostic approach that works for both SQLite and PostgreSQL
        User.where(confirmed_at: nil).update_all(confirmed_at: Time.current)
      end
    end
  end
end
