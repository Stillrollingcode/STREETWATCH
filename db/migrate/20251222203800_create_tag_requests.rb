class CreateTagRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :tag_requests do |t|
      t.references :film, null: false, foreign_key: true
      t.references :requester, null: false, foreign_key: { to_table: :users }
      t.string :role, null: false
      t.string :status, null: false, default: 'pending'
      t.text :message

      t.timestamps
    end

    add_index :tag_requests, [:film_id, :requester_id, :role], unique: true, name: 'index_tag_requests_unique'
  end
end
