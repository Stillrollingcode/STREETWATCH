class CreateFilmApprovals < ActiveRecord::Migration[8.0]
  def change
    create_table :film_approvals do |t|
      t.references :film, null: false, foreign_key: true
      t.references :approver, null: false, foreign_key: { to_table: :users }
      t.string :approval_type, null: false # 'filmer', 'editor', 'rider', 'company'
      t.string :status, default: 'pending', null: false # 'pending', 'approved', 'rejected'
      t.text :rejection_reason

      t.timestamps
    end

    add_index :film_approvals, [:film_id, :approver_id, :approval_type], unique: true, name: 'index_film_approvals_unique'
  end
end
