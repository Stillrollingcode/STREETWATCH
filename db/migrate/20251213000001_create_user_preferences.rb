class CreateUserPreferences < ActiveRecord::Migration[8.0]
  def change
    return if table_exists?(:user_preferences)

    create_table :user_preferences do |t|
      t.references :user, null: false, foreign_key: true
      t.string :theme, default: "dark"
      t.integer :accent_hue, default: 145

      t.timestamps
    end

    add_index :user_preferences, :user_id, unique: true, if_not_exists: true
  end
end
