class CreateCommentLikes < ActiveRecord::Migration[8.0]
  def change
    create_table :comment_likes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :likeable, polymorphic: true, null: false

      t.timestamps
    end

    # Ensure a user can only like a comment once
    add_index :comment_likes, [:user_id, :likeable_type, :likeable_id], unique: true, name: 'index_comment_likes_uniqueness'
  end
end
