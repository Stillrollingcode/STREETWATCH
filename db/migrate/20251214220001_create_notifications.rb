class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.references :actor, null: false, foreign_key: { to_table: :users }, index: false
      t.references :notifiable, polymorphic: true, null: false, index: false
      t.string :action, null: false
      t.datetime :read_at

      t.timestamps
    end

    # Add indexes for querying
    add_index :notifications, [:user_id, :read_at, :created_at]
    add_index :notifications, [:notifiable_type, :notifiable_id]
    add_index :notifications, :actor_id
  end
end
