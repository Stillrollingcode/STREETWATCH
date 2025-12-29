class AddStatusIndexToFilmApprovals < ActiveRecord::Migration[8.0]
  def change
    add_index :film_approvals, :status
    add_index :film_approvals, [:film_id, :status]
  end
end
