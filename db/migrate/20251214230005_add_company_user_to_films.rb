class AddCompanyUserToFilms < ActiveRecord::Migration[8.0]
  def change
    add_column :films, :company_user_id, :integer
    add_index :films, :company_user_id
  end
end
