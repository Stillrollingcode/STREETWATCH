class CreatePhotoApprovals < ActiveRecord::Migration[8.0]
  def change
    create_table :photo_approvals do |t|
      t.references :photo, null: false, foreign_key: true
      t.references :approver, null: false, foreign_key: { to_table: :users }
      t.string :approval_type, null: false
      t.string :status, null: false, default: 'pending'
      t.text :rejection_reason
      t.string :friendly_id

      t.timestamps
    end

    add_index :photo_approvals, [:photo_id, :approver_id, :approval_type], unique: true, name: 'index_photo_approvals_unique'
    add_index :photo_approvals, :friendly_id, unique: true
  end
end
