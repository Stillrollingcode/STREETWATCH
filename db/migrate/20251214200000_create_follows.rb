class CreateFollows < ActiveRecord::Migration[8.0]
  def change
    create_table :follows do |t|
      t.references :follower, null: false, foreign_key: { to_table: :users }, index: false
      t.references :followed, null: false, foreign_key: { to_table: :users }, index: false

      t.timestamps
    end

    # Add composite index to prevent duplicate follows and improve query performance
    add_index :follows, [:follower_id, :followed_id], unique: true
    # Add index on followed_id for reverse lookups (finding followers of a user)
    add_index :follows, :followed_id
  end
end
