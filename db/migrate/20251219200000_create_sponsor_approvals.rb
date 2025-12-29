class CreateSponsorApprovals < ActiveRecord::Migration[8.0]
  def change
    create_table :sponsor_approvals do |t|
      t.references :user, null: false, foreign_key: true
      t.references :sponsor, null: false, foreign_key: { to_table: :users }
      t.string :status, default: 'pending', null: false
      t.text :rejection_reason
      t.string :friendly_id

      t.timestamps
    end

    add_index :sponsor_approvals, [:user_id, :sponsor_id], unique: true
    add_index :sponsor_approvals, :friendly_id, unique: true
  end
end
