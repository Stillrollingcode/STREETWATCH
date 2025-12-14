class CreateComments < ActiveRecord::Migration[8.0]
  def change
    create_table :comments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :film, null: false, foreign_key: true
      t.text :body, null: false

      t.timestamps
    end

    add_index :comments, [:film_id, :created_at]
  end
end
