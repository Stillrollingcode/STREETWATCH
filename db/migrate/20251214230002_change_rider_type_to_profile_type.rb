class ChangeRiderTypeToProfileType < ActiveRecord::Migration[8.0]
  def change
    # Rename the column
    rename_column :users, :rider_type, :profile_type

    # Change existing values to match new enum
    # Assuming existing rider_type values should become 'individual'
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE users
          SET profile_type = 'individual'
          WHERE profile_type IS NULL OR profile_type = '';
        SQL
      end
    end
  end
end
